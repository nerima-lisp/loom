"""Enforce one deadline around a complete end-to-end scenario."""

import math
import signal
import time
from contextlib import contextmanager
from contextvars import ContextVar

from .phases import PhaseTimeline
from .results import current_result


SCENARIO_TIMEOUT_SECONDS = 10.0
SCENARIO_CLEANUP_TIMEOUT_SECONDS = 5.0
SCENARIO_EXECUTION_TIMEOUT_SECONDS = (
    SCENARIO_TIMEOUT_SECONDS - SCENARIO_CLEANUP_TIMEOUT_SECONDS
)
# Whole-scenario deadline for the R9 day scenario only. Provisional: it is
# replaced by a value measured five times on both OSes once all twelve R9
# scenes exist.
R9_SCENARIO_TIMEOUT_SECONDS = 60.0


class ScenarioDeadlineExceeded(TimeoutError):
    """Raised when the scenario's pre-cleanup execution budget is exhausted."""


class ScenarioCleanupDeadlineExceeded(ScenarioDeadlineExceeded):
    """Raised when timeout cleanup exceeds its reserved wall-clock budget."""


class ScenarioDeadlineBudget:
    """Expose execution and total deadlines to scenario cleanup owners."""

    def __init__(self, deadline, execution_deadline, timeline=None):
        self.deadline = deadline
        self.execution_deadline = execution_deadline
        self.expired = False
        self.timeline = PhaseTimeline() if timeline is None else timeline
        self._cleanup_processes = []
        self._preparation_started = None

    def _preparation_elapsed(self, now):
        if self._preparation_started is None:
            return 0.0
        return now - self._preparation_started

    def remaining(self):
        now = time.monotonic()
        return max(0.0, self.deadline - now + self._preparation_elapsed(now))

    def execution_remaining(self):
        """Return time before execution ends and the cleanup reserve begins."""
        now = time.monotonic()
        return max(
            0.0,
            self.execution_deadline - now + self._preparation_elapsed(now),
        )

    def register_process(self, process):
        self._cleanup_processes.append(process)

    def unregister_process(self, process):
        try:
            self._cleanup_processes.remove(process)
        except ValueError:
            pass

    def force_cleanup(self):
        first_error = None
        for process in tuple(self._cleanup_processes):
            try:
                process.force_kill()
            except BaseException as error:
                first_error = first_error or error
        if first_error is not None:
            raise first_error


_ACTIVE_DEADLINE = ContextVar("loom_active_scenario_deadline", default=None)


def current_deadline():
    return _ACTIVE_DEADLINE.get()


def mark_phase(name):
    """Start phase NAME in the active scenario's timeline, if any."""
    budget = current_deadline()
    if budget is not None and budget.timeline.step_depth == 0:
        budget.timeline.mark(name)


def note_phase_event(text):
    budget = current_deadline()
    if budget is not None:
        budget.timeline.note(text)


@contextmanager
def phase_step(name):
    """Mark NAME as a phase unless an enclosing step already owns the time.

    NAME may be a zero-argument callable so callers on hot input paths only
    build the label when it is recorded.
    """
    budget = current_deadline()
    if budget is None:
        yield
        return
    timeline = budget.timeline
    if timeline.step_depth == 0:
        timeline.mark(name() if callable(name) else name)
    timeline.step_depth += 1
    try:
        yield
    finally:
        timeline.step_depth -= 1


@contextmanager
def scenario_preparation():
    """Pause the active scenario budget while it waits for external readiness."""
    budget = current_deadline()
    if budget is None or budget.expired:
        yield
        return
    if budget._preparation_started is not None:
        yield
        return

    delay, interval = signal.getitimer(signal.ITIMER_REAL)
    if delay <= 0.0:
        signal.getsignal(signal.SIGALRM)(signal.SIGALRM, None)

    started = time.monotonic()
    signal.setitimer(signal.ITIMER_REAL, 0.0, 0.0)
    budget._preparation_started = started
    budget.timeline.set_paused(True)
    try:
        yield
    finally:
        elapsed = time.monotonic() - started
        budget.deadline += elapsed
        budget.execution_deadline += elapsed
        budget._preparation_started = None
        budget.timeline.set_paused(False)
        if not budget.expired:
            signal.setitimer(signal.ITIMER_REAL, delay, interval)


def _validate_seconds(seconds):
    seconds = float(seconds)
    if not math.isfinite(seconds) or seconds <= 0:
        raise ValueError("scenario deadline must be a finite positive number")
    return seconds


def _cleanup_seconds(seconds, cleanup_seconds):
    if cleanup_seconds is None:
        cleanup_seconds = min(SCENARIO_CLEANUP_TIMEOUT_SECONDS, seconds / 2.0)
    cleanup_seconds = _validate_seconds(cleanup_seconds)
    if cleanup_seconds >= seconds:
        raise ValueError("cleanup deadline must be shorter than the scenario deadline")
    return cleanup_seconds


def _elapsed_timer(timer, elapsed):
    delay, interval = timer
    if delay <= 0:
        return timer
    if interval <= 0:
        return max(delay - elapsed, 0.0), 0.0
    if elapsed < delay:
        return delay - elapsed, interval
    since_first_expiration = elapsed - delay
    next_expiration = interval - (since_first_expiration % interval)
    return next_expiration, interval


def _restore_signal_state(handler, timer, elapsed):
    signal.setitimer(signal.ITIMER_REAL, 0.0, 0.0)
    signal.signal(signal.SIGALRM, handler)
    remaining, interval = _elapsed_timer(timer, elapsed)
    if timer[0] <= 0.0:
        signal.setitimer(signal.ITIMER_REAL, 0.0, interval)
        return
    if remaining <= 0.0:
        remaining = 1e-6
    signal.setitimer(signal.ITIMER_REAL, remaining, interval)


@contextmanager
def scenario_deadline(
    seconds=SCENARIO_TIMEOUT_SECONDS,
    cleanup_seconds=None,
    execution_elapsed_callback=None,
):
    """Run a scenario with one Unix wall-clock deadline.

    The total deadline includes a reserved cleanup phase. The first alarm
    starts cleanup; a one-shot cleanup alarm bounds that phase without
    repeatedly interrupting it. The previous SIGALRM handler is restored on
    every exit path, and any prior real timer resumes with elapsed time
    deducted rather than being extended by this context.
    """
    seconds = _validate_seconds(seconds)
    cleanup_seconds = _cleanup_seconds(seconds, cleanup_seconds)
    previous_handler = signal.getsignal(signal.SIGALRM)
    previous_timer = signal.getitimer(signal.ITIMER_REAL)
    started = time.monotonic()
    execution_seconds = seconds - cleanup_seconds
    parent = current_deadline()
    budget = ScenarioDeadlineBudget(
        started + seconds,
        started + execution_seconds,
        timeline=None if parent is None else parent.timeline,
    )
    execution_elapsed = None
    propagating = None
    budget_token = _ACTIVE_DEADLINE.set(budget)

    def expire(_signum, _frame):
        nonlocal execution_elapsed
        if execution_elapsed_callback is not None:
            execution_elapsed = time.monotonic() - started
        budget.expired = True
        budget.timeline.note(f"execution budget ({execution_seconds:g}s) expired")
        remaining = min(cleanup_seconds, budget.remaining())
        if remaining <= 0.0:
            cleanup_expire(_signum, _frame)
        signal.signal(signal.SIGALRM, cleanup_expire)
        signal.setitimer(signal.ITIMER_REAL, remaining, 0.0)
        raise ScenarioDeadlineExceeded(
            f"scenario execution budget expired after {execution_seconds:g} "
            f"seconds; cleanup has {remaining:g} seconds "
            f"within the {seconds:g}-second total budget"
        )

    def cleanup_expire(_signum, _frame):
        budget.expired = True
        signal.setitimer(signal.ITIMER_REAL, 0.0, 0.0)
        budget.timeline.note(f"cleanup reserve ({cleanup_seconds:g}s) expired")
        raise ScenarioCleanupDeadlineExceeded(
            f"scenario cleanup exceeded {cleanup_seconds:g} seconds"
        )

    try:
        signal.signal(signal.SIGALRM, expire)
        signal.setitimer(
            signal.ITIMER_REAL, execution_seconds, 0.0
        )
    except BaseException:
        _restore_signal_state(
            previous_handler, previous_timer, time.monotonic() - started
        )
        _ACTIVE_DEADLINE.reset(budget_token)
        raise

    try:
        yield
    except BaseException as error:
        propagating = error
        raise
    finally:
        if execution_elapsed_callback is not None and execution_elapsed is None:
            execution_elapsed = time.monotonic() - started
        _restore_signal_state(
            previous_handler, previous_timer, time.monotonic() - started
        )
        _ACTIVE_DEADLINE.reset(budget_token)
        _publish_timeline(
            budget, parent, propagating, execution_seconds, cleanup_seconds
        )
        if execution_elapsed_callback is not None:
            execution_elapsed_callback(execution_elapsed)


def _publish_timeline(
    budget, parent, propagating, execution_seconds, cleanup_seconds
):
    if parent is None:
        result = current_result()
        if result is not None:
            result.phases = budget.timeline.records()
            result.phase_events = budget.timeline.event_records()
    if (
        budget.expired
        and propagating is not None
        and getattr(propagating, "scenario_timeout_report", None) is None
    ):
        propagating.scenario_timeout_report = budget.timeline.format_report(
            execution_seconds, cleanup_seconds
        )


def r9_scenario(function):
    """Mark FUNCTION as the R9 day scenario, which runs under its own deadline."""
    function.r9_scenario = True
    return function


def run_scenario(
    function,
    binary,
    seconds=None,
    cleanup_seconds=None,
    execution_elapsed_callback=None,
):
    """Call one registered scenario under its complete wall-clock budget."""
    if seconds is None:
        seconds = (
            R9_SCENARIO_TIMEOUT_SECONDS
            if getattr(function, "r9_scenario", False)
            else SCENARIO_TIMEOUT_SECONDS
        )
    with scenario_deadline(
        seconds,
        cleanup_seconds,
        execution_elapsed_callback=execution_elapsed_callback,
    ):
        return function(binary)
