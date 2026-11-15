"""Real PTY regressions for lifecycle commands and process signals."""

import json
import os
import re
import shlex
import signal
import stat
import termios
import tempfile
import time
from contextlib import contextmanager
from pathlib import Path

from loom_e2e import keys
from loom_e2e.command_path_scenarios import (
    load_command_path_scenarios,
    run_command_path_scenario,
)
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
    expected_cursor = tuple(case["expected_cursor"])
    cursor_region = case.get("expected_cursor_region", "body")
    session.wait_for_region_cursor(
        cursor_region, expected_cursor[1], index=expected_cursor[0]
    )
    if session.observe_cursor(
        expected=expected_cursor, region=cursor_region
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


# WP1: recovery from auto-save sidecars and signal recovery entries.

_CANDIDATE_AGE_SECONDS = 30
_UNIVERSAL_TIME_OFFSET = 2208988800
_SPECIAL_NAME = "a*b?c[d]\\e.txt"
_META_TOKEN = re.compile(r'\s*(?:(\()|(\))|"((?:[^"\\]|\\.)*)"|([^\s()"]+))')


def _recovery_prompt(kind):
    return f"Recover from {kind} (<1 min newer)? (r, d, i, C-g)"


def _unsaved_notice(kind):
    return (
        f"Unsaved work found ({kind}, <1 min newer); "
        "M-x recover-file to restore"
    )


def _recovered_message(kind):
    return f"Recovered from {kind}; save to keep"


def _sidecar(path):
    path = Path(path)
    return path.with_name(f"#{path.name}#")


def _make_candidates_newer(path, candidates):
    # file-write-date has whole-second resolution, so the gap must cross seconds.
    now = int(time.time())
    os.utime(path, (now - _CANDIDATE_AGE_SECONDS, now - _CANDIDATE_AGE_SECONDS))
    for candidate in candidates:
        os.utime(candidate, (now, now))


def _lisp_string(value):
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def _recovery_directory(home_dir):
    return Path(home_dir) / ".loom" / "recovery"


def _write_recovery_entry(home_dir, stem, text, path=None):
    directory = _recovery_directory(home_dir)
    directory.mkdir(parents=True, exist_ok=True)
    body = directory / f"{stem}.txt"
    body.write_text(text, encoding="utf-8")
    if path is None:
        return [body]
    meta = directory / f"{stem}.sexp"
    meta.write_text(
        f"(:version 1 :path {_lisp_string(str(path))}"
        f" :buffer-name {_lisp_string(Path(path).name)}"
        f" :reason :sigterm :time {int(time.time()) + _UNIVERSAL_TIME_OFFSET})\n",
        encoding="utf-8",
    )
    return [body, meta]


def _read_flat_plist(text):
    text = text.strip()
    tokens = []
    position = 0
    while position < len(text):
        match = _META_TOKEN.match(text, position)
        if match is None or match.end() == position:
            raise AssertionError(f"unreadable recovery metadata: {text!r}")
        tokens.append(match)
        position = match.end()
    if (
        len(tokens) < 2
        or tokens[0].group(1) is None
        or tokens[-1].group(2) is None
        or any(token.group(1) or token.group(2) for token in tokens[1:-1])
    ):
        raise AssertionError(f"recovery metadata is not one flat list: {text!r}")
    values = []
    for token in tokens[1:-1]:
        if token.group(3) is not None:
            values.append(re.sub(r"\\(.)", r"\1", token.group(3)))
        elif re.fullmatch(r"-?\d+", token.group(4)):
            values.append(int(token.group(4)))
        else:
            values.append(token.group(4).lower())
    if len(values) % 2:
        raise AssertionError(f"recovery metadata is not a plist: {text!r}")
    return dict(zip(values[0::2], values[1::2]))


def _mode(path):
    try:
        return oct(stat.S_IMODE(os.stat(path).st_mode))
    except FileNotFoundError:
        return None


@contextmanager
def _scenario_directory():
    # Resolve /var -> /private/var so displayed paths equal the truename.
    with tempfile.TemporaryDirectory(prefix="loom-lifecycle-") as directory:
        yield Path(directory).resolve()


def _assert_minibuffer_text(session, text):
    session.wait_for_region_exact_text("minibuffer", text, strip_right=True)
    session.assert_screen_text(text, region="minibuffer", strip_right=True)


def _assert_body_row(session, index, text):
    session.wait_for_region_exact_text("body", text, index=index, strip_right=True)
    session.assert_screen_text(text, region="body", index=index, strip_right=True)


def _find_file(session, path):
    session.send(keys.ctrl("x") + keys.ctrl("f"))
    session.wait_for_region_text("minibuffer", "Find file: ")
    session.type(str(path))
    session.key("RET")


def _auto_save_now(session, buffer_name):
    session.extended_command("auto-save-current-buffer")
    session.wait_for_region_exact_text(
        "minibuffer", f"Auto-saved {buffer_name}", strip_right=True
    )


def _terminate(session, signal_number, expected_exit):
    os.kill(session.process._pid, signal_number)
    _output, exit_code = session.process.wait(timeout=1.5)
    session.observe_exit_code(exit_code, expected=expected_exit)
    if exit_code != expected_exit:
        raise AssertionError(f"signal exit status was {exit_code}, expected {expected_exit}")


def _load_recovery_cases():
    shared = {
        "schema_version": 1,
        "scenarios": [
            case
            for case in _PATH_DATA["scenarios"]
            if case["name"].startswith("command-path/")
        ],
    }
    with tempfile.TemporaryDirectory(prefix="loom-e2e-lifecycle-paths-") as directory:
        path = Path(directory) / "command-paths.json"
        path.write_text(json.dumps(shared), encoding="utf-8")
        return load_command_path_scenarios(path)


class _RecoverySession(Session):
    """Start on a buffer whose auto-save sidecar is newer than the file."""

    def __init__(self, binary, arguments=None, **options):
        super().__init__(binary, arguments, **options)
        path = Path(self.arguments[0])
        sidecar = _sidecar(path)
        _make_candidates_newer(path, [sidecar] if sidecar.exists() else [])


class _RecoveryDirectorySession(_RecoverySession):
    """Restart once a recovery entry exists in the session's scratch HOME."""

    def __enter__(self):
        super().__enter__()
        try:
            self.wait_ready()
            lost = Path(self.arguments[0]).parent.resolve() / "lost.txt"
            _write_recovery_entry(
                self.home_dir, "buffer-sigterm-3970000000-1-0-0", "lost draft\n", lost
            )
            self.restart()
        except BaseException as error:
            self.__exit__(type(error), error, error.__traceback__)
            raise
        return self


class _RecreatedCandidateSession(_RecoverySession):
    """Put the sidecar back after each save, which deletes it, for macro replay."""

    def __init__(self, binary, arguments=None, **options):
        super().__init__(binary, arguments, **options)
        self._sidecar_bytes = _sidecar(self.arguments[0]).read_bytes()

    def save_buffer(self, path, expected_bytes, **options):
        super().save_buffer(path, expected_bytes, **options)
        sidecar = _sidecar(path)
        sidecar.write_bytes(self._sidecar_bytes)
        written = int(os.stat(path).st_mtime)
        os.utime(sidecar, (written + 5, written + 5))


def _recovery_session_factory(case):
    if case["command"] == "list-recoverable-files":
        return _RecoveryDirectorySession
    if case.get("mutation_case") == "macro-replay":
        return _RecreatedCandidateSession
    return _RecoverySession


def _recovery_command_path(case):
    def run(binary):
        return run_command_path_scenario(
            binary, case, session_factory=_recovery_session_factory(case)
        )

    return run


for _case in _load_recovery_cases():
    scenario(_case["name"], commands=_case["commands"])(_recovery_command_path(_case))


@scenario(
    "lifecycle/recovery-auto-save-kill9",
    commands=[
        "execute-extended-command",
        "auto-save-mode",
        "auto-save-current-buffer",
        "recover-file",
        "save-buffer",
    ],
)
def recovery_auto_save_kill9(binary):
    with _scenario_directory() as directory:
        path = _make_buffer(directory, b"draft one\n")
        sidecar = _sidecar(path)
        with Session(binary, [str(path)], columns=120) as session:
            session.wait_ready(timeout=1.5)
            session.extended_command("auto-save-mode")
            _assert_minibuffer_text(session, "Auto-save mode enabled")
            session.type("UNSAVED ")
            _assert_body_row(session, 0, "UNSAVED draft one")
            _auto_save_now(session, "state.txt")
            session.wait_for_untraced_file(str(sidecar), b"UNSAVED draft one\n")
            sidecar_bytes = sidecar.read_bytes()
            os.kill(session.process._pid, signal.SIGKILL)
            session.process.wait(timeout=1.5)
            _make_candidates_newer(path, [sidecar])

            session.restart()
            session.wait_ready(timeout=1.5)
            _assert_minibuffer_text(session, _unsaved_notice("auto-save"))
            session.extended_command("recover-file")
            _assert_minibuffer_text(session, _recovery_prompt("auto-save"))
            session.type("r")
            _assert_minibuffer_text(session, _recovered_message("auto-save"))
            _assert_body_row(session, 0, "UNSAVED draft one")
            session.save_buffer(str(path), sidecar_bytes)
            session.assert_file_bytes(str(path), sidecar_bytes)
            session.quit()


@scenario(
    "lifecycle/recovery-sigterm-meta",
    commands=["find-file"],
)
def recovery_sigterm_meta(binary):
    with _scenario_directory() as directory:
        path = _make_buffer(directory, b"draft one\n")
        with Session(binary, [str(path)], columns=200) as session:
            session.wait_ready(timeout=1.5)
            session.type("UNSAVED ")
            _assert_body_row(session, 0, "UNSAVED draft one")
            _terminate(session, signal.SIGTERM, 143)

            entry = _assert_recovery_entry(session, path, "UNSAVED draft one\n")
            _make_candidates_newer(path, entry)

            session.arguments = []
            session.restart()
            session.wait_ready(timeout=1.5)
            _assert_minibuffer_text(
                session, "1 recoverable file(s); M-x list-recoverable-files"
            )
            _find_file(session, path)
            _assert_minibuffer_text(session, _unsaved_notice("recovery"))
            session.quit()


def _assert_recovery_entry(session, path, body_text):
    recovery = _recovery_directory(session.home_dir)
    bodies = sorted(recovery.glob("*.txt"))
    metas = sorted(recovery.glob("*.sexp"))
    session.assert_external_state(
        "recovery body and metadata counts", [len(bodies), len(metas)], [1, 1]
    )
    session.assert_external_state(
        "recovery metadata shares the body stem", metas[0].stem, bodies[0].stem
    )
    session.assert_external_state(
        "recovery body bytes", bodies[0].read_bytes().decode("utf-8"), body_text
    )
    meta = _read_flat_plist(metas[0].read_text(encoding="utf-8"))
    session.assert_external_state(
        "recovery metadata fields",
        {key: meta.get(key) for key in (":version", ":path", ":buffer-name", ":reason")},
        {
            ":version": 1,
            ":path": str(path),
            ":buffer-name": path.name,
            ":reason": ":sigterm",
        },
    )
    session.assert_external_state(
        "recovery metadata time is a universal time",
        isinstance(meta.get(":time"), int) and meta[":time"] > _UNIVERSAL_TIME_OFFSET,
        True,
    )
    return bodies + metas


# Copied from WP2's evaluation/interrupt/sigterm-stuck-cleanup: the cleanup
# keeps the evaluation away from its boundary, so only the D20 watchdog thread
# can run the :shutdown hooks and exit. That watchdog exists only after WP2.
_STUCK_EVALUATION_FORM = (
    "(sb-sys:without-interrupts"
    " (loop (block r (unwind-protect"
    " (sb-sys:with-local-interrupts {marker} (sleep 0.1))"
    " (return-from r)))))"
)
_WATCHDOG_EXIT_LIMIT_SECONDS = 4.0


@scenario(
    "lifecycle/recovery-sigterm-meta-watchdog",
    commands=["eval-expression"],
)
def recovery_sigterm_meta_watchdog(binary):
    with _scenario_directory() as directory:
        path = _make_buffer(directory, b"draft one\n")
        marker = directory / "evaluation-started"
        with Session(binary, [str(path)], columns=200) as session:
            session.wait_ready(timeout=1.5)
            session.type("UNSAVED ")
            _assert_body_row(session, 0, "UNSAVED draft one")
            session.send(keys.meta(":"))
            session.wait_for_region_text("minibuffer", "Eval: ", timeout=1.0)
            session.type(
                _STUCK_EVALUATION_FORM.format(
                    marker=f'(close (open "{marker}" :direction :output'
                    " :if-exists :supersede))"
                )
            )
            session.key("RET")
            session.wait_until(
                lambda _screen: marker.exists(), 2.0, "evaluation start marker"
            )
            os.kill(session.process._pid, signal.SIGTERM)
            _output, exit_code = session.process.wait(
                timeout=_WATCHDOG_EXIT_LIMIT_SECONDS
            )
            session.observe_exit_code(exit_code, expected=143)
            session.assert_external_state(
                "exit status after SIGTERM during a stuck evaluation", exit_code, 143
            )
            _assert_recovery_entry(session, path, "UNSAVED draft one\n")


def _assert_no_unsaved_work(session, path):
    session.assert_screen_text("", region="minibuffer", strip_right=True)
    session.extended_command("recover-file")
    _assert_minibuffer_text(session, f"No unsaved work for {path}")


@scenario(
    "lifecycle/recovery-older-candidate",
    commands=["execute-extended-command", "recover-file"],
)
def recovery_older_candidate(binary):
    with _scenario_directory() as directory:
        path = _make_buffer(directory, b"draft one\n")
        sidecar = _sidecar(path)
        sidecar.write_bytes(b"draft two\n")
        now = int(time.time())
        os.utime(sidecar, (now - 60, now - 60))
        os.utime(path, (now, now))
        with Session(binary, [str(path)], columns=200) as session:
            session.wait_ready(timeout=1.5)
            _assert_body_row(session, 0, "draft one")
            _assert_no_unsaved_work(session, path)
            session.quit()


@scenario(
    "lifecycle/recovery-same-content",
    commands=["execute-extended-command", "recover-file"],
)
def recovery_same_content(binary):
    with _scenario_directory() as directory:
        path = _make_buffer(directory, b"draft one\n")
        sidecar = _sidecar(path)
        sidecar.write_bytes(b"draft one\n")
        with Session(binary, [str(path)], columns=200) as session:
            session.wait_ready(timeout=1.5)
            entry = _write_recovery_entry(
                session.home_dir, "buffer-sigterm-3970000000-1-0-0", "draft one\n", path
            )
            _make_candidates_newer(path, [sidecar] + entry)
            session.restart()
            session.wait_ready(timeout=1.5)
            _assert_body_row(session, 0, "draft one")
            _assert_no_unsaved_work(session, path)
            session.quit()


def _home_wrapper(directory, binary, home_dir):
    wrapper = Path(directory) / "loom-shared-home"
    wrapper.write_text(
        "#!/bin/sh\n"
        f"HOME={shlex.quote(str(home_dir))}\n"
        "export HOME\n"
        f'exec {shlex.quote(os.path.abspath(binary))} "$@"\n',
        encoding="utf-8",
    )
    wrapper.chmod(0o755)
    return str(wrapper)


@scenario("lifecycle/recovery-other-loom", commands=[])
def recovery_other_loom(binary):
    with _scenario_directory() as directory, tempfile.TemporaryDirectory(
        prefix="loom-lifecycle-wrapper-"
    ) as wrapper_directory:
        path = _make_buffer(directory, b"draft one\n")
        sidecar = _sidecar(path)
        sidecar.write_bytes(b"draft two\n")
        _make_candidates_newer(path, [sidecar])
        with Session(binary, [str(path)], columns=200) as holder:
            holder.wait_ready(timeout=1.5)
            _assert_minibuffer_text(holder, _unsaved_notice("auto-save"))
            wrapper = _home_wrapper(wrapper_directory, binary, holder.home_dir)
            with Session(wrapper, [str(path)], columns=200) as other:
                other.wait_ready(timeout=1.5)
                _assert_minibuffer_text(
                    other,
                    f"{path} is open in another loom (pid {holder.process._pid})",
                )
                other.quit()
            holder.quit()


@scenario(
    "lifecycle/recovery-save-deletes",
    commands=["save-buffer"],
)
def recovery_save_deletes(binary):
    with _scenario_directory() as directory:
        path = _make_buffer(directory, b"draft one\n")
        sidecar = _sidecar(path)
        sidecar.write_bytes(b"draft two\n")
        with Session(binary, [str(path)], columns=200) as session:
            session.wait_ready(timeout=1.5)
            matching = _write_recovery_entry(
                session.home_dir, "buffer-sigterm-3970000000-1-0-0", "draft two\n", path
            )
            unrelated = _write_recovery_entry(
                session.home_dir,
                "buffer-sigterm-3970000000-2-0-0",
                "other\n",
                directory / "other.txt",
            )
            legacy = _write_recovery_entry(
                session.home_dir, "buffer-sighup-3970000000-3-0-0", "legacy\n"
            )
            _make_candidates_newer(path, [sidecar] + matching)
            session.restart()
            session.wait_ready(timeout=1.5)
            session.type("X")
            _assert_body_row(session, 0, "Xdraft one")
            session.save_buffer(str(path), b"Xdraft one\n")
            session.assert_file_bytes(str(path), b"Xdraft one\n")
            session.assert_external_state(
                "existence after save: sidecar, matching body and metadata",
                [candidate.exists() for candidate in [sidecar] + matching],
                [False, False, False],
            )
            session.assert_external_state(
                "existence after save: unrelated body and metadata, legacy body",
                [candidate.exists() for candidate in unrelated + legacy],
                [True, True, True],
            )
            session.quit()


@scenario(
    "lifecycle/recovery-permissions",
    commands=[
        "execute-extended-command",
        "auto-save-mode",
        "auto-save-current-buffer",
        "save-buffer",
        "find-file",
    ],
)
def recovery_permissions(binary):
    with _scenario_directory() as directory:
        path = _make_buffer(directory, b"draft one\n")
        path.chmod(0o640)
        new_path = directory / "new.txt"
        with Session(binary, [str(path)], columns=200) as session:
            session.wait_ready(timeout=1.5)
            home = Path(session.home_dir)
            locks = home / ".loom" / "locks"
            session.assert_external_state("lock directory mode", _mode(locks), oct(0o700))
            lock_files = (
                sorted(entry for entry in locks.iterdir() if entry.is_file())
                if locks.is_dir()
                else []
            )
            session.assert_external_state(
                "lock file modes",
                [_mode(entry) for entry in lock_files] or None,
                [oct(0o600)] * max(1, len(lock_files)),
            )

            session.extended_command("auto-save-mode")
            _assert_minibuffer_text(session, "Auto-save mode enabled")
            session.type("X")
            _assert_body_row(session, 0, "Xdraft one")
            _auto_save_now(session, "state.txt")
            session.assert_external_state(
                "sidecar mode follows the 0640 original", _mode(_sidecar(path)), oct(0o640)
            )
            session.save_buffer(str(path), b"Xdraft one\n")
            backup = home / ".loom" / "backups" / "state.txt.1~"
            session.assert_external_state(
                "backup mode follows the 0640 original", _mode(backup), oct(0o640)
            )

            _find_file(session, new_path)
            session.wait_for_region_text("mode-line", "new.txt")
            session.type("N")
            _assert_body_row(session, 0, "N")
            _auto_save_now(session, "new.txt")
            session.assert_external_state(
                "sidecar mode without an original file",
                _mode(_sidecar(new_path)),
                oct(0o600),
            )
            _terminate(session, signal.SIGTERM, 143)

            recovery = _recovery_directory(home)
            session.assert_external_state(
                "recovery directory mode", _mode(recovery), oct(0o700)
            )
            entries = sorted(recovery.iterdir())
            session.assert_external_state(
                "recovery file modes",
                [_mode(entry) for entry in entries],
                [oct(0o600)] * 2,
            )


@scenario(
    "lifecycle/recovery-backup-collision",
    commands=["save-buffer"],
)
def recovery_backup_collision(binary):
    with _scenario_directory() as directory:
        path = _make_buffer(directory, b"draft one\n")
        with Session(binary, [str(path)]) as session:
            session.wait_ready(timeout=1.5)
            backups = Path(session.home_dir) / ".loom" / "backups"
            backups.mkdir(parents=True)
            (backups / "state.txt.1~").write_bytes(b"OLDER BACKUP\n")
            session.type("X")
            _assert_body_row(session, 0, "Xdraft one")
            session.save_buffer(str(path), b"Xdraft one\n")
            session.assert_file_bytes(str(backups / "state.txt.1~"), b"OLDER BACKUP\n")
            session.assert_file_bytes(str(backups / "state.txt.2~"), b"draft one\n")
            session.quit()


@scenario(
    "lifecycle/recovery-special-name-writes",
    commands=[
        "execute-extended-command",
        "auto-save-mode",
        "auto-save-current-buffer",
        "save-buffer",
    ],
)
def recovery_special_name_writes(binary):
    with _scenario_directory() as directory:
        path = directory / _SPECIAL_NAME
        path.write_bytes(b"draft one\n")
        sidecar = _sidecar(path)
        with Session(binary, [str(path)], columns=200) as session:
            session.wait_ready(timeout=1.5)
            session.extended_command("auto-save-mode")
            _assert_minibuffer_text(session, "Auto-save mode enabled")
            session.type("X")
            _assert_body_row(session, 0, "Xdraft one")
            _auto_save_now(session, _SPECIAL_NAME)
            session.assert_file_bytes(str(sidecar), b"Xdraft one\n")
            session.assert_external_state(
                "directory entries after auto-save",
                sorted(entry.name for entry in directory.iterdir()),
                sorted([_SPECIAL_NAME, sidecar.name]),
            )
            session.save_buffer(str(path), b"Xdraft one\n")
            session.assert_file_bytes(str(path), b"Xdraft one\n")
            backup = Path(session.home_dir) / ".loom" / "backups" / f"{_SPECIAL_NAME}.1~"
            session.assert_file_bytes(str(backup), b"draft one\n")
            session.assert_external_state(
                "directory entries after save",
                sorted(entry.name for entry in directory.iterdir()),
                [_SPECIAL_NAME],
            )
            session.quit()


@scenario(
    "lifecycle/recovery-special-name-file-tree",
    commands=["toggle-file-tree", "file-tree-select-next", "file-tree-open-selected"],
)
def recovery_special_name_file_tree(binary):
    with _scenario_directory() as directory:
        (directory / _SPECIAL_NAME).write_bytes(b"special content\n")
        with Session(binary, [str(directory)]) as session:
            session.wait_ready(timeout=1.5)
            session.send(keys.ctrl("x") + keys.text("d"))
            session.wait_for_row_text(0, _SPECIAL_NAME)
            # A new tree has no selection; C-c n selects its first entry.
            session.send(keys.ctrl("c") + keys.text("n"))
            session.send(keys.ctrl("c") + keys.text("o"))
            session.wait_for_region_text("body", "special content")
            session.assert_screen_text(
                "special content", match="contains", region="body"
            )
            session.quit()
