"""Real PTY regressions for lifecycle commands and process signals."""

import json
import os
import signal
import termios
import tempfile
from pathlib import Path

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


_RECOVERY_MARKER = b"LOOM-RECOVERY-SNAPSHOT"
_TERMINAL_FLAGS = termios.ECHO | termios.ICANON
_PATH_DATA = json.loads(
    Path(__file__).with_name("command-paths.json").read_text(encoding="utf-8")
)
_PATH_CASES_BY_ID = {case["path_id"]: case for case in _PATH_DATA["scenarios"]}
_PATH_CASES_BY_NAME = {case["name"]: case for case in _PATH_DATA["scenarios"]}


def _path_case(path_id=None, *, name=None):
    cases = _PATH_CASES_BY_ID if path_id is not None else _PATH_CASES_BY_NAME
    key = path_id if path_id is not None else name
    try:
        return cases[key]
    except KeyError as error:
        raise AssertionError(f"missing lifecycle path record: {key}") from error


def _assert_path_state(session, path, case):
    for expectation in case["expected_screen"]:
        session.wait_for_region_exact_text(
            expectation["region"],
            expectation["text"],
            index=expectation.get("index", 0),
            strip_right=True,
        )
        session.assert_screen_text(
            expectation["text"],
            region=expectation["region"],
            index=expectation.get("index", 0),
            strip_right=True,
        )
    if session.observe_cursor(
        expected=tuple(case["expected_cursor"]),
        region=case.get("expected_cursor_region", "body"),
    ) is not True:
        raise AssertionError(
            f"{case['name']} cursor did not match {case['expected_cursor']!r}"
        )
    session.assert_file_bytes(
        str(path), case["expected_bytes"].encode("utf-8")
    )


def _make_buffer(directory, initial_bytes=b""):
    path = Path(directory) / "state.txt"
    path.write_bytes(initial_bytes)
    return path


def _terminal_flags(session):
    return termios.tcgetattr(session.process._fd)[3] & _TERMINAL_FLAGS


def _assert_terminal_flags(session, expected, timeout=1.0):
    session.wait_until(
        lambda _screen: _terminal_flags(session) == expected,
        timeout,
        f"terminal flags to become {expected}",
    )
    session.assert_external_state(
        "terminal ECHO and ICANON flags", _terminal_flags(session), expected
    )


def _recovery_contains(session, payload):
    recovery_dir = Path(session.home_dir) / ".loom" / "recovery"
    contents = []
    if recovery_dir.is_dir():
        contents = [
            path.read_bytes()
            for path in recovery_dir.rglob("*")
            if path.is_file()
        ]
    session.assert_external_state(
        "recovery files contain unsaved buffer bytes",
        any(payload in content for content in contents),
        True,
    )


def _run_termination_signal(binary, termination_signal, expected_exit):
    with tempfile.TemporaryDirectory(prefix="loom-lifecycle-") as directory:
        path = _make_buffer(directory)
        with Session(binary, [str(path)]) as session:
            session.wait_ready(timeout=1.5)
            session.type(_RECOVERY_MARKER.decode("ascii"))
            session.wait_for_text(_RECOVERY_MARKER.decode("ascii"), timeout=1.0)
            os.kill(session.process._pid, termination_signal)
            _assert_terminal_flags(session, _TERMINAL_FLAGS)
            _output, exit_code = session.process.wait(timeout=1.5)
            session.observe_exit_code(exit_code, expected=expected_exit)
            if exit_code != expected_exit:
                raise AssertionError(
                    f"termination signal exit status was {exit_code}, "
                    f"expected {expected_exit}"
                )
            session.assert_file_bytes(str(path), b"")
            _recovery_contains(session, _RECOVERY_MARKER)


def _child_is_stopped(session):
    process_id = session.process._pid
    if hasattr(os, "waitid"):
        result = os.waitid(
            os.P_PID,
            process_id,
            os.WSTOPPED | os.WNOHANG | os.WNOWAIT,
        )
        return result is not None and result.si_pid == process_id

    waited_pid, status = os.waitpid(
        process_id, os.WNOHANG | os.WUNTRACED
    )
    return waited_pid == process_id and os.WIFSTOPPED(status)


def _suspend_resume(session, send_suspend, path, path_case=None):
    _assert_terminal_flags(session, 0)
    send_suspend(session)
    session.wait_until(
        lambda _screen: _child_is_stopped(session),
        1.0,
        "loom process to stop",
    )
    _assert_terminal_flags(session, _TERMINAL_FLAGS)
    while session.pump(poll_timeout=0.0):
        pass
    stopped_output_length = len(session.output_bytes)

    os.kill(session.process._pid, signal.SIGCONT)
    session.wait_until(
        lambda _screen: (
            _terminal_flags(session) == 0
            and len(session.output_bytes) > stopped_output_length
        ),
        1.0,
        "loom to resume raw mode and redraw",
    )
    session.assert_external_state(
        "terminal ECHO and ICANON flags", _terminal_flags(session), 0
    )
    session.wait_for_text(_RECOVERY_MARKER.decode("ascii"), timeout=1.0)
    if path_case is None:
        session.assert_screen_text(
            _RECOVERY_MARKER.decode("ascii"), match="contains", region="screen"
        )
    else:
        _assert_path_state(session, path, path_case)
    _output, exit_code = session.quit(timeout=1.0)
    session.assert_external_state("exit after resumed clean quit", exit_code, 0)


@scenario(
    "lifecycle/abort-exits-one",
    commands=["execute-extended-command", "kill-loom-abort"],
)
def abort_exits_one(binary):
    case = _path_case(name="lifecycle/abort-exits-one")
    with tempfile.TemporaryDirectory(prefix="loom-lifecycle-") as directory:
        path = _make_buffer(directory, case["initial_bytes"].encode("utf-8"))
        with Session(binary, [str(path)]) as session:
            session.wait_ready(timeout=1.5)
            session.type("UNSAVED-ABORT-DATA")
            session.wait_for_text("UNSAVED-ABORT-DATA", timeout=1.0)
            session.extended_command("kill-loom-abort", timeout=1.0)
            _assert_path_state(session, path, case)
            session.type("d")
            session.key("RET")
            _assert_terminal_flags(session, _TERMINAL_FLAGS)
            _output, exit_code = session.process.wait(timeout=1.5)
            session.observe_exit_code(exit_code, expected=1)
            if exit_code != 1:
                raise AssertionError(f"kill-loom-abort exited {exit_code}, expected 1")
            session.assert_file_bytes(str(path), b"")


@scenario("lifecycle/sigterm-recovery", commands=[])
def sigterm_recovery(binary):
    _run_termination_signal(binary, signal.SIGTERM, 143)


@scenario("lifecycle/sighup-recovery", commands=[])
def sighup_recovery(binary):
    _run_termination_signal(binary, signal.SIGHUP, 129)


@scenario("lifecycle/c-z-suspend-resume", commands=["suspend-frame"])
def c_z_suspend_resume(binary):
    case = _path_case(name="lifecycle/c-z-suspend-resume")
    with tempfile.TemporaryDirectory(prefix="loom-lifecycle-") as directory:
        path = _make_buffer(directory, case["initial_bytes"].encode("utf-8"))
        with Session(binary, [str(path)], supervise_job_control=True) as session:
            session.wait_ready(timeout=1.5)
            session.wait_for_text(_RECOVERY_MARKER.decode("ascii"), timeout=1.0)
            _suspend_resume(
                session, lambda current: current.send(keys.ctrl("z")), path, case
            )


@scenario("lifecycle/sigtstp-sigcont-suspend-resume", commands=[])
def sigtstp_sigcont_suspend_resume(binary):
    with tempfile.TemporaryDirectory(prefix="loom-lifecycle-") as directory:
        path = _make_buffer(directory, _RECOVERY_MARKER)
        with Session(binary, [str(path)], supervise_job_control=True) as session:
            session.wait_ready(timeout=1.5)
            session.wait_for_text(_RECOVERY_MARKER.decode("ascii"), timeout=1.0)
            _suspend_resume(
                session,
                lambda current: os.kill(current.process.application_pid, signal.SIGTSTP),
                path,
            )


def _wait_lifecycle_prompt(session):
    prompt_fragments = ("Save", "Discard", "Abort", "modified")
    session.wait_until(
        lambda _screen: any(
            fragment.casefold() in session.region_text("minibuffer").casefold()
            for fragment in prompt_fragments
        ),
        0.8,
        "lifecycle confirmation prompt",
    )


def _invoke_quit_command(session, command, route):
    if route == "key":
        session.send(keys.ctrl("x") + keys.ctrl("c"))
    else:
        session.extended_command(command, timeout=0.8)


def _run_quit_prompt_case(binary, command, route, outcome, expected_exit):
    path_case = _path_case(
        path_id=f"r2:{command}:prompt-1:free-string:{outcome}"
    )
    with tempfile.TemporaryDirectory(prefix="loom-lifecycle-") as directory:
        path = _make_buffer(directory, path_case["initial_bytes"].encode("utf-8"))
        with Session(binary, [str(path)]) as session:
            session.wait_ready(timeout=1.0)
            session.type("PROMPT-CASE-UNSAVED")
            session.wait_for_text("PROMPT-CASE-UNSAVED", timeout=0.8)
            _invoke_quit_command(session, command, route)
            _wait_lifecycle_prompt(session)
            _assert_path_state(session, path, path_case)

            if outcome == "accept":
                session.type("d")
                session.key("RET")
                _assert_terminal_flags(session, _TERMINAL_FLAGS, timeout=0.8)
                _output, exit_code = session.process.wait(timeout=1.0)
                session.assert_external_state(
                    "accepted quit exit status", exit_code, expected_exit
                )
                session.assert_file_bytes(str(path), b"")
                return

            if outcome == "cancel":
                session.type("c")
                session.key("RET")
            elif outcome == "empty":
                session.key("RET")
            elif outcome == "tab":
                session.key("TAB")
            elif outcome == "history":
                session.send(keys.meta("p"))
            else:
                raise AssertionError(f"unknown prompt case: {outcome}")

            session.assert_external_state(
                "process remains active after prompt outcome",
                session.process.has_exited(),
                False,
            )
            session.assert_screen_text(
                "PROMPT-CASE-UNSAVED", match="contains", region="screen"
            )
            session.assert_file_bytes(str(path), b"")

            if outcome == "cancel":
                _invoke_quit_command(session, command, route)
            _wait_lifecycle_prompt(session)
            session.send(keys.ctrl("a"))
            session.send(keys.ctrl("k"))
            session.type("d")
            session.key("RET")
            _assert_terminal_flags(session, _TERMINAL_FLAGS, timeout=0.8)
            _output, exit_code = session.process.wait(timeout=1.0)
            session.assert_external_state(
                "cleanup quit exit status", exit_code, expected_exit
            )


@scenario(
    "lifecycle/save-buffers-kill-terminal-key",
    commands=["save-buffers-kill-terminal"],
)
def save_buffers_kill_terminal_key(binary):
    case = _path_case(name="lifecycle/save-buffers-kill-terminal-key")
    with tempfile.TemporaryDirectory(prefix="loom-lifecycle-") as directory:
        path = _make_buffer(directory, case["initial_bytes"].encode("utf-8"))
        with Session(binary, [str(path)]) as session:
            session.wait_ready(timeout=1.0)
            session.send(keys.ctrl("e"))
            session.type(case["dirty_input"])
            session.wait_for_text(case["expected_screen"][0]["text"], timeout=0.8)
            session.send(keys.ctrl("x") + keys.ctrl("c"))
            _assert_path_state(session, path, case)
            session.type("d")
            session.key("RET")
            _assert_terminal_flags(session, _TERMINAL_FLAGS, timeout=0.8)
            _output, exit_code = session.process.wait(timeout=1.0)
            session.assert_external_state("key quit exit status", exit_code, 0)
            session.assert_file_bytes(str(path), case["expected_bytes"].encode("utf-8"))


@scenario(
    "lifecycle/save-buffers-kill-terminal-mx",
    commands=["execute-extended-command", "save-buffers-kill-terminal"],
)
def save_buffers_kill_terminal_mx(binary):
    case = _path_case(name="lifecycle/save-buffers-kill-terminal-mx")
    with tempfile.TemporaryDirectory(prefix="loom-lifecycle-") as directory:
        path = _make_buffer(directory, case["initial_bytes"].encode("utf-8"))
        with Session(binary, [str(path)]) as session:
            session.wait_ready(timeout=1.0)
            session.send(keys.ctrl("e"))
            session.type(case["dirty_input"])
            session.wait_for_text(case["expected_screen"][0]["text"], timeout=0.8)
            session.extended_command("save-buffers-kill-terminal", timeout=0.8)
            _assert_path_state(session, path, case)
            session.type("d")
            session.key("RET")
            _assert_terminal_flags(session, _TERMINAL_FLAGS, timeout=0.8)
            _output, exit_code = session.process.wait(timeout=1.0)
            session.assert_external_state("M-x quit exit status", exit_code, 0)
            session.assert_file_bytes(str(path), case["expected_bytes"].encode("utf-8"))


@scenario(
    "lifecycle/suspend-frame-mx",
    commands=["execute-extended-command", "suspend-frame"],
)
def suspend_frame_mx(binary):
    case = _path_case(name="lifecycle/suspend-frame-mx")
    with tempfile.TemporaryDirectory(prefix="loom-lifecycle-") as directory:
        path = _make_buffer(directory, case["initial_bytes"].encode("utf-8"))
        with Session(binary, [str(path)], supervise_job_control=True) as session:
            session.wait_ready(timeout=1.0)
            session.wait_for_text(_RECOVERY_MARKER.decode("ascii"), timeout=0.8)
            _suspend_resume(
                session,
                lambda current: current.extended_command("suspend-frame", timeout=0.8),
                path,
                case,
            )


for _outcome in ("cancel", "empty", "tab", "history"):
    scenario(
        f"lifecycle/save-buffer-prompt-{_outcome}",
        commands=["save-buffers-kill-terminal"],
    )(
        lambda binary, outcome=_outcome: _run_quit_prompt_case(
            binary,
            "save-buffers-kill-terminal",
            "key",
            outcome,
            0,
        )
    )

for _outcome in ("cancel", "empty", "tab", "history"):
    scenario(
        f"lifecycle/abort-prompt-{_outcome}",
        commands=["execute-extended-command", "kill-loom-abort"],
    )(
        lambda binary, outcome=_outcome: _run_quit_prompt_case(
            binary,
            "kill-loom-abort",
            "mx",
            outcome,
            1,
        )
    )



@scenario(
    "lifecycle/abort-prompt-accept",
    commands=["execute-extended-command", "kill-loom-abort"],
)
def abort_prompt_accept(binary):
    _run_quit_prompt_case(
        binary,
        "kill-loom-abort",
        "mx",
        "accept",
        1,
    )


@scenario(
    "lifecycle/save-buffer-prompt-accept",
    commands=["save-buffers-kill-terminal"],
)
def save_buffer_prompt_accept(binary):
    _run_quit_prompt_case(
        binary,
        "save-buffers-kill-terminal",
        "key",
        "accept",
        0,
    )
