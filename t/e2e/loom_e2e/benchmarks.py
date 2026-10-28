"""PTY benchmark scenarios for startup, redraw, file open, and key response."""

import math
import os
import statistics
from functools import partial
import tempfile
import time

from . import keys
from .deadline import (
    SCENARIO_CLEANUP_TIMEOUT_SECONDS,
    SCENARIO_EXECUTION_TIMEOUT_SECONDS,
    SCENARIO_TIMEOUT_SECONDS,
    ScenarioCleanupDeadlineExceeded,
    current_deadline,
)
from .results import record_observation
from .session import Session


_LINE_COUNT = 100_000
_LINE_BYTES = 50
_OPEN_MARKER = b"LOOM_E2E_OPEN_BENCHMARK"
_OPEN_LAST_LINE_MARKER = b"LOOM_E2E_LAST_LINE_MARKER"
_STARTUP_TRIALS = 3
_FILE_OPEN_TRIALS = 3
_REDRAW_SAMPLES = 100
_REDRAW_BATCHES = 4
_REDRAW_BATCH_SAMPLES = _REDRAW_SAMPLES // _REDRAW_BATCHES
_STARTUP_TARGET_SECONDS = 0.3
_FILE_OPEN_TARGET_SECONDS = 1.0
_REDRAW_TARGET_MILLISECONDS = 50.0
_D13_KEY_RESPONSE_TARGET_MS = 50.0


def _large_file(path):
    line = _OPEN_MARKER + b"x" * (_LINE_BYTES - len(_OPEN_MARKER) - 1) + b"\n"
    last_line = (
        _OPEN_LAST_LINE_MARKER
        + b"x" * (_LINE_BYTES - len(_OPEN_LAST_LINE_MARKER) - 1)
        + b"\n"
    )
    with open(path, "wb") as handle:
        for _line in range(_LINE_COUNT - 1):
            handle.write(line)
        handle.write(last_line)
    return _LINE_COUNT, _LINE_COUNT * len(line)


def _redraw_samples(session, sample_count=_REDRAW_SAMPLES):
    samples = []
    budget = current_deadline()
    if budget is None:
        raise RuntimeError("PTY benchmarks require an active scenario deadline")
    for sample in range(sample_count):
        before = session.screen.cursor
        expected = (before[0], before[1] + 1)
        started = time.monotonic()
        session.send(keys.ctrl("f"))
        while budget.remaining() > 0:
            session.pump(poll_timeout=0.001)
            if session.screen.cursor != before:
                if session.observe_cursor(
                    expected=expected, sample=sample
                ) is not True:
                    raise AssertionError(
                        f"cursor moved to {session.screen.cursor!r}, "
                        f"expected {expected!r}"
                    )
                samples.append(time.monotonic() - started)
                break
        else:
            raise TimeoutError("PTY input did not produce a screen redraw")
    return samples


def _percentile_95(values):
    ordered = sorted(values)
    return ordered[math.ceil(0.95 * len(ordered)) - 1]


def _require_active_deadline():
    if current_deadline() is None:
        raise RuntimeError("PTY benchmarks require an active scenario deadline")


def _record_measurement(metric, value, unit, samples=None, **extra_details):
    details = {"metric": metric, "unit": unit}
    if samples is not None:
        details["samples"] = samples
    details.update(extra_details)
    record_observation(
        "benchmark_measurement", value, **details
    )


def _mark_execution_deadline_if_expired(budget):
    if budget.execution_remaining() <= 0:
        budget.expired = True


def _wait_for_benchmark_text(session, text, budget, started):
    timeout = budget.execution_remaining()
    if timeout <= 0:
        budget.expired = True
        return time.monotonic() - started, False
    try:
        session.wait_for_text(text, timeout=timeout)
    except ScenarioCleanupDeadlineExceeded:
        raise
    except TimeoutError:
        _mark_execution_deadline_if_expired(budget)
        return time.monotonic() - started, False
    return time.monotonic() - started, True


def _open_benchmark_file(session, path, budget):
    session.wait_ready()
    session.send(keys.ctrl("x") + keys.ctrl("f"))
    session.wait_for_region_text(
        "minibuffer", "Find file: ",
        timeout=budget.execution_remaining(),
    )
    session.type(path)
    started = time.monotonic()
    session.key("RET")
    return _wait_for_benchmark_text(
        session,
        _OPEN_MARKER.decode("ascii"),
        budget,
        started,
    )


def _measure_startup(binary):
    _require_active_deadline()
    with Session(binary) as session:
        session.wait_ready()
        measurement = session.first_screen_at - session.started_at
        session.quit()
    samples = [measurement]
    _record_measurement(
        "startup_to_first_screen_seconds", measurement, "seconds", samples
    )
    return {
        "startup_to_first_screen_seconds": measurement,
        "samples": samples,
    }


def _measure_redraw(binary, sample_count=_REDRAW_BATCH_SAMPLES):
    _require_active_deadline()
    with tempfile.TemporaryDirectory(prefix="loom-e2e-benchmark-") as directory:
        path = os.path.join(directory, "redraw.txt")
        with open(path, "wb") as handle:
            handle.write(b"x" * 64)
        with Session(binary, [path]) as session:
            session.wait_ready()
            session.wait_for_text("x" * 64)
            session.wait_for_region_cursor("body", 0)
            samples = [
                sample * 1000.0
                for sample in _redraw_samples(session, sample_count=sample_count)
            ]
            measurement = _percentile_95(samples)
            _record_measurement(
                "input_to_redraw_p95_milliseconds",
                measurement,
                "milliseconds",
                samples,
            )
            session.quit()
    return {
        "input_to_redraw_p95_milliseconds": measurement,
        "samples": samples,
    }


def _measure_large_file_open(binary):
    _require_active_deadline()
    budget = current_deadline()
    with tempfile.TemporaryDirectory(prefix="loom-e2e-benchmark-") as directory:
        path = os.path.join(directory, "large.txt")
        line_count, byte_count = _large_file(path)
        with Session(binary) as session:
            measurement, first_row_observed = _open_benchmark_file(
                session, path, budget
            )
            session.observe_external_state(
                "benchmark input size",
                os.path.getsize(path),
                expected=byte_count,
            )
            session.observe_external_state(
                "benchmark input line count",
                line_count,
                expected=_LINE_COUNT,
            )
            samples = [measurement]
            _record_measurement(
                "open_100000_lines_5mb_seconds",
                measurement,
                "seconds",
                samples,
                first_row_observed=first_row_observed,
            )
            if first_row_observed:
                session.quit()
    return {
        "open_100000_lines_5mb_seconds": measurement,
        "samples": samples,
        "first_row_observed": first_row_observed,
        "input": {"lines": line_count, "bytes": byte_count},
    }


def _measure_large_file_eof(binary):
    _require_active_deadline()
    budget = current_deadline()
    with tempfile.TemporaryDirectory(prefix="loom-e2e-benchmark-") as directory:
        path = os.path.join(directory, "large.txt")
        line_count, byte_count = _large_file(path)
        eof_elapsed = None
        eof_reached = False
        with Session(binary) as session:
            _first_row_elapsed, first_row_observed = _open_benchmark_file(
                session, path, budget
            )
            session.observe_external_state(
                "benchmark input size",
                os.path.getsize(path),
                expected=byte_count,
            )
            session.observe_external_state(
                "benchmark input line count",
                line_count,
                expected=_LINE_COUNT,
            )
            if first_row_observed:
                try:
                    session.send(keys.meta("x"))
                    session.wait_for_region_text(
                        "minibuffer", "M-x ",
                        timeout=budget.execution_remaining(),
                    )
                    session.type("end-of-buffer")
                    eof_started = time.monotonic()
                    session.key("RET")
                    eof_elapsed, eof_reached = _wait_for_benchmark_text(
                        session,
                        _OPEN_LAST_LINE_MARKER.decode("ascii"),
                        budget,
                        eof_started,
                    )
                except ScenarioCleanupDeadlineExceeded:
                    raise
                except TimeoutError:
                    _mark_execution_deadline_if_expired(budget)
                if eof_elapsed is not None:
                    _record_measurement(
                        "end_of_buffer_100000_lines_5mb_seconds",
                        eof_elapsed,
                        "seconds",
                        [eof_elapsed],
                        last_line_observed=eof_reached,
                    )
            if first_row_observed and eof_reached:
                session.quit()
    return {
        "end_of_buffer_100000_lines_5mb_seconds": eof_elapsed,
        "eof_samples": [eof_elapsed] if eof_elapsed is not None else [],
        "last_line_observed": eof_reached,
        "input": {"lines": line_count, "bytes": byte_count},
    }


def benchmark_scenarios(registered=None):
    scenarios = {}
    for trial in range(1, _STARTUP_TRIALS + 1):
        scenarios[f"startup-trial-{trial}"] = _measure_startup
    for trial in range(1, _REDRAW_BATCHES + 1):
        scenarios[f"redraw-trial-{trial}"] = partial(
            _measure_redraw, sample_count=_REDRAW_BATCH_SAMPLES
        )
    for trial in range(1, _FILE_OPEN_TRIALS + 1):
        scenarios[f"large-file-open-trial-{trial}"] = _measure_large_file_open
    for trial in range(1, _FILE_OPEN_TRIALS + 1):
        scenarios[f"large-file-eof-trial-{trial}"] = _measure_large_file_eof
    if registered is not None:
        d13_scenario = next(
            (
                function
                for name, _commands, function in registered
                if name == "d13/20k-line-key-response"
            ),
            None,
        )
        if d13_scenario is not None:
            def measure_d13_key_response(binary):
                return d13_scenario(
                    binary,
                    benchmark_target_ms=_D13_KEY_RESPONSE_TARGET_MS,
                )

            scenarios["d13-20k-line-key-response"] = measure_d13_key_response
    return scenarios


def _aggregate_trials(
    measurements,
    scenario,
    metric,
    sample_count,
    aggregate,
    sample_field="samples",
    allow_direct=True,
):
    direct = measurements.get(scenario)
    if allow_direct and isinstance(direct, dict):
        return direct

    trial_count = {
        "startup": _STARTUP_TRIALS,
        "redraw": _REDRAW_BATCHES,
        "large-file-open": _FILE_OPEN_TRIALS,
        "large-file-eof": _FILE_OPEN_TRIALS,
    }[scenario]
    trials = [
        measurements.get(f"{scenario}-trial-{trial}")
        for trial in range(1, trial_count + 1)
    ]
    if any(not isinstance(trial, dict) for trial in trials):
        return None

    samples = []
    for trial in trials:
        trial_samples = trial.get(sample_field)
        if not isinstance(trial_samples, list):
            return None
        samples.extend(trial_samples)
    if len(samples) != sample_count:
        return None

    result = {metric: aggregate(samples), "samples": samples}
    if scenario in {"large-file-open", "large-file-eof"}:
        completion_field = (
            "first_row_observed"
            if scenario == "large-file-open"
            else "last_line_observed"
        )
        result["completed_samples"] = [
            trial.get(completion_field, True)
            for trial in trials
        ]
        result["completed"] = all(result["completed_samples"])
        input_details = trials[0].get("input")
        if not isinstance(input_details, dict) or any(
            trial.get("input") != input_details for trial in trials
        ):
            return None
        result["input"] = input_details
    return result


def build_benchmark_report(measurements):
    metric_specs = {
        "startup_to_first_screen_seconds": (
            "startup",
            _STARTUP_TRIALS,
            statistics.median,
            _STARTUP_TARGET_SECONDS,
        ),
        "open_100000_lines_5mb_seconds": (
            "large-file-open",
            _FILE_OPEN_TRIALS,
            statistics.median,
            _FILE_OPEN_TARGET_SECONDS,
        ),
        "input_to_redraw_p95_milliseconds": (
            "redraw",
            _REDRAW_SAMPLES,
            _percentile_95,
            _REDRAW_TARGET_MILLISECONDS,
        ),
    }
    values = {}
    samples = {}
    sample_completion = {}
    missing_metrics = []
    targets = {}
    within_targets = {}
    for metric, (scenario, sample_count, aggregate, target) in metric_specs.items():
        gate = {
            "startup": "startup_to_first_screen",
            "large-file-open": "open_100000_lines_5mb",
            "redraw": "input_to_redraw_p95",
        }[scenario]
        targets[metric] = target
        result = _aggregate_trials(
            measurements, scenario, metric, sample_count, aggregate
        )
        value = result.get(metric) if isinstance(result, dict) else None
        if not isinstance(value, (int, float)) or not math.isfinite(value):
            missing_metrics.append(metric)
            within_targets[gate] = False
            continue
        values[metric] = value
        completed = result.get("completed", True)
        within_targets[gate] = value <= target and completed
        if isinstance(result.get("samples"), list):
            samples[metric] = result["samples"]
        if isinstance(result.get("completed_samples"), list):
            sample_completion[metric] = result["completed_samples"]

    eof_metric = "end_of_buffer_100000_lines_5mb_seconds"
    eof_result = _aggregate_trials(
        measurements,
        "large-file-eof",
        eof_metric,
        _FILE_OPEN_TRIALS,
        statistics.median,
        sample_field="eof_samples",
        allow_direct=False,
    )
    informational_measurements = {}
    informational_samples = {}
    informational_completion = {}
    missing_informational_metrics = []
    if isinstance(eof_result, dict):
        informational_measurements[eof_metric] = eof_result[eof_metric]
        informational_samples[eof_metric] = eof_result["samples"]
        informational_completion[eof_metric] = eof_result["completed_samples"]
    else:
        missing_informational_metrics.append(eof_metric)
    report = {
        "measurements": values,
        "samples": samples,
        "sample_completion": sample_completion,
        "informational_measurements": informational_measurements,
        "informational_samples": informational_samples,
        "informational_completion": informational_completion,
        "targets": targets,
        "within_targets": within_targets,
        "missing_metrics": missing_metrics,
        "missing_informational_metrics": missing_informational_metrics,
        "protocol": {
            "startup_samples": _STARTUP_TRIALS,
            "startup_aggregation": "median of independent processes",
            "file_open_samples": _FILE_OPEN_TRIALS,
            "file_open_aggregation": "median of independent processes",
            "end_of_buffer_samples": _FILE_OPEN_TRIALS,
            "end_of_buffer_aggregation": "median of independent processes",
            "redraw_samples": _REDRAW_SAMPLES,
            "redraw_aggregation": "nearest-rank p95",
            "redraw_batches": _REDRAW_BATCHES,
            "redraw_batch_samples": _REDRAW_BATCH_SAMPLES,
            "warmup_runs": 0,
            "redraw_interval": (
                "from C-f input to cursor-position output in a loaded "
                "64-character buffer"
            ),
            "file_open_interval": (
                "from RET after filename entry to the first visible row marker; "
                "if the execution deadline expires first, record elapsed time "
                "as a lower bound and mark the row unobserved"
            ),
            "file_open_deadline": (
                "uses the remaining existing 5-second execution budget; fixture "
                "creation and PTY startup consume that budget but are excluded "
                "from the measured interval"
            ),
            "end_of_buffer_interval": (
                "from RET invoking end-of-buffer to rendering the unique "
                "last-line marker; informational only, with no target"
            ),
            "end_of_buffer_deadline": (
                "uses the remaining existing 5-second execution budget after "
                "the first visible row; fixture creation, PTY startup, and "
                "file loading consume that budget but are excluded from the "
                "measured interval"
            ),
            "scenario_deadline_seconds": SCENARIO_TIMEOUT_SECONDS,
            "execution_budget_seconds": SCENARIO_EXECUTION_TIMEOUT_SECONDS,
            "cleanup_budget_seconds": SCENARIO_CLEANUP_TIMEOUT_SECONDS,
        },
    }
    input_details = _aggregate_trials(
        measurements,
        "large-file-open",
        "open_100000_lines_5mb_seconds",
        _FILE_OPEN_TRIALS,
        statistics.median,
    )
    if input_details is not None and input_details.get("input") is not None:
        report["input"] = input_details["input"]
    d13_measurement = measurements.get("d13-20k-line-key-response")
    if d13_measurement is not None:
        d13_milliseconds = d13_measurement[
            "d13_20k_line_key_response_milliseconds"
        ]
        report["measurements"][
            "d13_20k_line_key_response_milliseconds"
        ] = d13_milliseconds
        report["targets"][
            "d13_20k_line_key_response_milliseconds"
        ] = _D13_KEY_RESPONSE_TARGET_MS
        report["within_targets"]["d13_20k_line_key_response"] = (
            d13_milliseconds <= _D13_KEY_RESPONSE_TARGET_MS
        )
        report["protocol"]["d13_key_response_samples"] = 1
        report["protocol"]["d13_key_response_interval"] = (
            "from C-f input to cursor-position output in a loaded "
            "20,000-line buffer"
        )
    return report
