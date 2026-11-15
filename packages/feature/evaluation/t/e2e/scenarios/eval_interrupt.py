"""Interrupt running evaluations through real terminal input and signals (WP2)."""

import os
import signal
import tempfile
import time
from pathlib import Path

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


_SOURCE = b"(+ 1 2)\n"
_RECOVERY_MARKER = "WP2-RECOVERY-MARKER"
_INTERRUPTED = "Evaluation interrupted"
_MARKER_TIMEOUT_SECONDS = 2.0
# The watchdog waits *evaluation-signal-exit-grace-seconds* (1.0) before it
# ends a stuck evaluation; the limit covers shutdown under a loaded machine.
_TERMINATION_EXIT_LIMIT_SECONDS = 4.0


def _write_source(directory, contents, name="expression.lisp"):
    path = Path(directory) / name
    path.write_bytes(contents)
    return path


def _touch_form(marker):
    """Return a Lisp form that creates MARKER once the evaluation runs.

    The screen cannot change while the main thread evaluates, so a file
    written by the evaluated code is the observable sign that evaluation, and
    with it the input monitor, has started."""
    return f'(close (open "{marker}" :direction :output :if-exists :supersede))'


def _hold_form(release):
    """Return a Lisp form that keeps evaluating until RELEASE exists.

    The evaluation cannot end on its own, so input sent before the scenario
    creates RELEASE is certain to arrive while the evaluation runs."""
    return f'(loop until (probe-file "{release}") do (sleep 0.01))'


def _release(release):
    Path(release).write_bytes(b"")


def _wait_for_marker(session, marker):
    session.wait_until(
        lambda _screen: os.path.exists(marker),
        _MARKER_TIMEOUT_SECONDS,
        f"evaluation marker {marker}",
    )


def _start_expression(session, expression):
    session.send(keys.meta(":"))
    session.wait_for_region_text("minibuffer", "Eval: ", timeout=1.0)
    session.type(expression)
    session.key("RET")


def _start_marked_expression(session, directory, make_forms, name="started"):
    """Evaluate the expression MAKE_FORMS builds around a marker form through
    M-: and wait for the marker.

    MAKE_FORMS places the marker inside the dynamic extent the scenario checks,
    so the marker proves that extent is active."""
    marker = os.path.join(directory, name)
    _start_expression(session, make_forms(_touch_form(marker)))
    _wait_for_marker(session, marker)


def _has_body_line(session, text):
    return any(
        line.strip() == text for line in session.region_contents("body").split("\n")
    )


def _assert_interrupted(session):
    session.wait_for_region_exact_text(
        "minibuffer", _INTERRUPTED, timeout=1.0, strip_right=True
    )
    session.assert_screen_text(_INTERRUPTED, region="minibuffer", strip_right=True)


def _quit_cleanly(session, name):
    output, code = session.quit(timeout=1.0)
    if code != 0:
        raise AssertionError(f"{name} exited with {code}: {output!r}")


def _interrupt_expression(binary, name, make_forms, quit_bytes):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-wp2-") as directory:
        path = _write_source(directory, _SOURCE)
        with Session(binary, [str(path)]) as session:
            session.wait_ready(timeout=2.0)
            _start_marked_expression(session, directory, make_forms)
            session.send(quit_bytes)
            _assert_interrupted(session)
            session.assert_file_bytes(str(path), _SOURCE)
            _quit_cleanly(session, name)


@scenario("evaluation/interrupt/loop-c-g", commands=["eval-expression"])
def interrupt_loop(binary):
    _interrupt_expression(
        binary,
        "evaluation/interrupt/loop-c-g",
        lambda marker: f"(progn {marker} (loop))",
        keys.ctrl("g"),
    )


@scenario("evaluation/interrupt/ignore-errors-c-g", commands=["eval-expression"])
def interrupt_ignore_errors(binary):
    _interrupt_expression(
        binary,
        "evaluation/interrupt/ignore-errors-c-g",
        # The marker is written inside IGNORE-ERRORS, so C-g arrives while
        # that handler is active.
        lambda marker: f"(loop (ignore-errors {marker} (sleep 0.1)))",
        keys.ctrl("g"),
    )


@scenario("evaluation/interrupt/csi-u-c-g", commands=["eval-expression"])
def interrupt_csi_u(binary):
    _interrupt_expression(
        binary,
        "evaluation/interrupt/csi-u-c-g",
        lambda marker: f"(progn {marker} (loop))",
        b"\x1b[103;5u",
    )


@scenario(
    "evaluation/interrupt/type-ahead", commands=["eval-expression", "forward-char"]
)
def type_ahead(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-wp2-") as directory:
        path = _write_source(directory, _SOURCE)
        with Session(binary, [str(path)]) as session:
            session.wait_ready(timeout=2.0)
            marker = os.path.join(directory, "started")
            session.send(keys.meta(":"))
            session.wait_for_region_text("minibuffer", "Eval: ", timeout=1.0)
            # The prompt is eval-expression's own effect. The screen cannot
            # change again until C-f has run, so this is the only observation
            # that falls in eval-expression's trace attribution window.
            session.assert_screen_text("Eval:", region="minibuffer", strip_right=True)
            release = os.path.join(directory, "release")
            session.type(f"(progn {_touch_form(marker)} {_hold_form(release)}) 42")
            session.key("RET")
            _wait_for_marker(session, marker)
            session.send(keys.ctrl("f"))
            _release(release)
            # forward-char clears the echo line before it runs
            # (src/application/input-routing-effects.lisp:27-28), so an empty
            # echo line with point moved shows that C-f ran after "42" was
            # reported; C-f run first would leave "42" on the echo line.
            session.wait_for_region_cursor("body", 1, timeout=2.0)
            session.wait_for_region_exact_text(
                "minibuffer", "", timeout=1.0, strip_right=True
            )
            session.assert_screen_text("", region="minibuffer", strip_right=True)
            if session.observe_cursor(expected=(0, 1), region="body") is not True:
                raise AssertionError(
                    f"cursor was {session.region_cursor('body')!r}, expected (0, 1)"
                )
            session.send(keys.ctrl("x") + b"b")
            session.wait_for_region_text("minibuffer", "Switch to buffer: ", timeout=1.0)
            session.type("*Messages*")
            session.key("RET")
            session.wait_until(
                lambda _screen: _has_body_line(session, "42"),
                1.0,
                "*Messages* to contain the evaluation result 42",
            )
            session.assert_external_state(
                "*Messages* has the evaluation result line 42",
                _has_body_line(session, "42"),
                True,
            )
            _quit_cleanly(session, "evaluation/interrupt/type-ahead")


@scenario(
    "evaluation/interrupt/other-entries", commands=["eval-last-sexp", "eval-buffer"]
)
def other_entries(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-wp2-") as directory:
        marker = os.path.join(directory, "started")
        source = f"(progn {_touch_form(marker)} (loop))\n".encode("utf-8")
        path = _write_source(directory, source)
        with Session(binary, [str(path)]) as session:
            session.wait_ready(timeout=2.0)
            # The marker path can wrap the source line, so point is not
            # checked by row; keys are dispatched in order regardless.
            session.send(keys.meta(">") + keys.ctrl("x") + keys.ctrl("e"))
            _wait_for_marker(session, marker)
            session.send(keys.ctrl("g"))
            _assert_interrupted(session)
            session.assert_file_bytes(str(path), source)

            os.remove(marker)
            # An idle C-g replaces the message, so the next one is fresh.
            session.send(keys.ctrl("g"))
            session.wait_for_region_exact_text(
                "minibuffer", "Quit", timeout=1.0, strip_right=True
            )
            session.extended_command("eval-buffer")
            _wait_for_marker(session, marker)
            session.send(keys.ctrl("g"))
            _assert_interrupted(session)
            session.assert_file_bytes(str(path), source)
            _quit_cleanly(session, "evaluation/interrupt/other-entries")


_PUBLIC_API_SOURCE = (
    "(buffer-line-count\n"
    " (loom/core/window-tree:window-buffer\n"
    "  (loom/core/window-tree:window-tree-selected-window\n"
    "   (editor-state-window-tree *editor-state*))))\n"
)


@scenario("evaluation/interrupt/public-api", commands=["eval-last-sexp"])
def public_api(binary):
    line_count = _PUBLIC_API_SOURCE.count("\n") + 1
    expected = (
        f"{line_count} (#o{line_count:o}, #x{line_count:X}, "
        f"?\\C-{chr(line_count + 96)})"
    )
    with tempfile.TemporaryDirectory(prefix="loom-e2e-wp2-") as directory:
        path = _write_source(directory, _PUBLIC_API_SOURCE.encode("utf-8"))
        with Session(binary, [str(path)]) as session:
            session.wait_ready(timeout=2.0)
            session.send(keys.meta(">"))
            session.wait_for_region_cursor("body", 0, index=line_count - 1, timeout=1.0)
            session.send(keys.ctrl("x") + keys.ctrl("e"))
            session.wait_for_region_exact_text(
                "minibuffer", expected, timeout=2.0, strip_right=True
            )
            session.assert_screen_text(expected, region="minibuffer", strip_right=True)
            _quit_cleanly(session, "evaluation/interrupt/public-api")


@scenario("evaluation/interrupt/resize", commands=["eval-expression"])
def resize_during_evaluation(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-wp2-") as directory:
        path = _write_source(directory, _SOURCE)
        with Session(binary, [str(path)]) as session:
            session.wait_ready(timeout=2.0)
            release = os.path.join(directory, "release")
            _start_marked_expression(
                session,
                directory,
                lambda marker: f"(progn {marker} {_hold_form(release)}) 42",
            )
            session.resize(100, 30)
            _release(release)
            session.wait_for_region_exact_text(
                "minibuffer", "42", timeout=2.0, strip_right=True
            )
            session.assert_screen_text("42", region="minibuffer", strip_right=True)
            session.assert_file_bytes(str(path), _SOURCE)
            _quit_cleanly(session, "evaluation/interrupt/resize")


@scenario("evaluation/interrupt/paste-bell", commands=["eval-expression", "save-buffer"])
def paste_bell_does_not_interrupt(binary):
    pasted = b"a\x07b"
    with tempfile.TemporaryDirectory(prefix="loom-e2e-wp2-") as directory:
        path = _write_source(directory, _SOURCE)
        with Session(binary, [str(path)]) as session:
            session.wait_ready(timeout=2.0)
            release = os.path.join(directory, "release")
            _start_marked_expression(
                session,
                directory,
                lambda marker: f"(progn {marker} {_hold_form(release)}) 42",
            )
            session.send(b"\x1b[200~" + pasted + b"\x1b[201~")
            _release(release)
            session.wait_for_region_exact_text(
                "minibuffer", "42", timeout=2.0, strip_right=True
            )
            session.save_buffer(str(path), pasted + _SOURCE)
            session.assert_file_bytes(str(path), pasted + _SOURCE)
            _quit_cleanly(session, "evaluation/interrupt/paste-bell")


@scenario(
    "evaluation/interrupt/second-c-g-forces", commands=["eval-expression"]
)
def second_c_g_forces(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-wp2-") as directory:
        path = _write_source(directory, _SOURCE)
        cleanup_marker = os.path.join(directory, "cleanup")
        with Session(binary, [str(path)]) as session:
            session.wait_ready(timeout=2.0)
            # The first C-g unwinds into a cleanup that never finishes; only a
            # forced request can abandon it.
            # Both markers sit inside the protected body or its cleanup, so a
            # C-g cannot land between the start marker and the unwind-protect.
            marker = os.path.join(directory, "started")
            _start_expression(
                session,
                f"(unwind-protect (progn {_touch_form(marker)} (loop)) "
                f"{_touch_form(cleanup_marker)} (loop))",
            )
            _wait_for_marker(session, marker)
            session.send(keys.ctrl("g"))
            _wait_for_marker(session, cleanup_marker)
            session.send(keys.ctrl("g"))
            _assert_interrupted(session)
            session.assert_file_bytes(str(path), _SOURCE)
            _quit_cleanly(session, "evaluation/interrupt/second-c-g-forces")


def _recovery_contains(session, payload):
    recovery_dir = Path(session.home_dir) / ".loom" / "recovery"
    contents = []
    if recovery_dir.is_dir():
        contents = [
            path.read_bytes() for path in recovery_dir.rglob("*") if path.is_file()
        ]
    session.assert_external_state(
        "recovery files contain unsaved buffer bytes",
        any(payload in content for content in contents),
        True,
    )


def _terminate_evaluation(binary, termination_signal, expected_exit, make_forms):
    """MAKE_FORMS receives the start marker form and returns the expression."""
    with tempfile.TemporaryDirectory(prefix="loom-e2e-wp2-") as directory:
        path = _write_source(directory, b"")
        with Session(binary, [str(path)]) as session:
            session.wait_ready(timeout=2.0)
            session.type(_RECOVERY_MARKER)
            session.wait_for_text(_RECOVERY_MARKER, timeout=1.0)
            marker = os.path.join(directory, "started")
            _start_expression(session, make_forms(_touch_form(marker)))
            _wait_for_marker(session, marker)
            signalled = time.monotonic()
            os.kill(session.process._pid, termination_signal)
            _output, exit_code = session.process.wait(
                timeout=_TERMINATION_EXIT_LIMIT_SECONDS
            )
            elapsed = time.monotonic() - signalled
            session.assert_external_state(
                "exit within the termination limit after the signal",
                elapsed < _TERMINATION_EXIT_LIMIT_SECONDS,
                True,
            )
            session.observe_exit_code(exit_code, expected=expected_exit)
            session.assert_external_state(
                "exit status after a termination signal during evaluation",
                exit_code,
                expected_exit,
            )
            session.assert_file_bytes(str(path), b"")
            _recovery_contains(session, _RECOVERY_MARKER.encode("ascii"))


@scenario("evaluation/interrupt/sigterm", commands=["eval-expression"])
def sigterm_during_evaluation(binary):
    _terminate_evaluation(
        binary, signal.SIGTERM, 143, lambda marker: f"(progn {marker} (loop))"
    )


@scenario("evaluation/interrupt/sighup", commands=["eval-expression"])
def sighup_during_evaluation(binary):
    _terminate_evaluation(
        binary, signal.SIGHUP, 129, lambda marker: f"(progn {marker} (loop))"
    )


# Interrupts are enabled only inside the protected form, so every deferrable
# interrupt -- the SIGTERM handler, the evaluator's marker, and each
# cl-concurrent-kit transfer -- runs there (SBCL code/signal.lisp:71-91 and
# code/target-thread.lisp:2394-2395: SIGTERM handlers and INTERRUPT-THREAD are
# deferred inside WITHOUT-INTERRUPTS). A transfer is the kit's INTERRUPT-THREAD
# function doing RETURN-FROM to its boundary (cl-concurrent-kit
# src/timeout.lisp:46-55); the cleanup, which runs with interrupts disabled
# again, replaces it with RETURN-FROM R, and the loop never leaves the
# WITHOUT-INTERRUPTS. No transfer can reach the boundary, so only the D20
# watchdog can end the process; reaching exit 143 is the evidence, with no
# timing check. The SIGTERM handler is not starved: it runs at the next SLEEP,
# within 0.1 seconds.
_STUCK_CLEANUP_FORM = (
    "(sb-sys:without-interrupts"
    " (loop (block r (unwind-protect"
    " (sb-sys:with-local-interrupts {marker} (sleep 0.1))"
    " (return-from r)))))"
)


@scenario("evaluation/interrupt/sigterm-stuck-cleanup", commands=["eval-expression"])
def sigterm_with_replacing_cleanup(binary):
    _terminate_evaluation(
        binary,
        signal.SIGTERM,
        143,
        lambda marker: _STUCK_CLEANUP_FORM.format(marker=marker),
    )
