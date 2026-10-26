"""Data-driven R1 command-path cases for S-expression commands."""

from pathlib import Path
from tempfile import TemporaryDirectory

from loom_e2e import keys
from loom_e2e.command_path_scenarios import (
    _deadline_stage,
    load_command_path_scenarios,
    run_command_path_scenario,
)
from loom_e2e.registry import scenario
from loom_e2e.session import Session


_CASES = load_command_path_scenarios(Path(__file__).with_name("command-paths.json"))
_R3_COMMANDS = {
    command
    for case in _CASES
    if case["rule"] == "r3"
    for command in (case["command"], case.get("read_only_command"))
    if command is not None
}


class _SynchronizedSession(Session):
    def send(self, data):
        payload = bytes(data)
        super().send(payload)
        if payload == keys.meta("x"):
            self.wait_for_region_text("minibuffer", "M-x ")
        elif payload == keys.ctrl("f"):
            self.wait_for_region_cursor("body", 1)
        else:
            try:
                command = payload.decode("utf-8")
            except UnicodeDecodeError:
                return
            if command in _R3_COMMANDS:
                self.wait_for_region_exact_text("minibuffer", f"M-x {command}")


def _cursor_synchronized_session(case):
    trigger = keys.ctrl(case["entry_keys"][-1][2])
    expected_row, expected_column = case["expected_cursor"]

    class CursorSynchronizedSession(Session):
        def send(self, data):
            payload = bytes(data)
            super().send(payload)
            if payload == trigger:
                self.wait_for_region_cursor(
                    "body", expected_column, index=expected_row
                )

    return CursorSynchronizedSession


def _send_path_keys(session, names):
    for name in names:
        if name.startswith("C-") and len(name) == 3:
            session.send(keys.ctrl(name[2]))
        elif name.startswith("M-") and len(name) == 3:
            session.send(keys.meta(name[2]))
        elif name == "ESC":
            session.key("ESC")
        elif name == "RET":
            session.key("RET")
        else:
            session.type(name)


def _run_read_only_scenario(binary, case):
    initial = case["initial_bytes"].encode("utf-8")
    with TemporaryDirectory(prefix="loom-e2e-command-path-") as directory:
        path = Path(directory) / "buffer.txt"
        path.write_bytes(initial)
        with _SynchronizedSession(
            binary, [str(path)], rows=case.get("rows", 24)
        ) as session:
            session.wait_ready()
            session.send(keys.meta("x"))
            session.type(case["read_only_command"])
            session.wait_for_region_exact_text(
                "minibuffer", f"M-x {case['read_only_command']}"
            )
            session.key("RET")
            with _deadline_stage(
                case["name"], "read-only status", session=session
            ):
                session.wait_for_region_exact_text(
                    "minibuffer",
                    case["expected_read_only_status"],
                    strip_right=True,
                )
            _send_path_keys(session, case["command_keys"])
            with _deadline_stage(
                case["name"], "read-only refusal", session=session
            ):
                session.wait_for_region_exact_text(
                    "minibuffer", case["expected_minibuffer"], strip_right=True
                )
            for expectation in case["expected_screen"]:
                session.wait_for_region_exact_text(
                    expectation["region"],
                    expectation["text"],
                    index=expectation.get("index", 0),
                    strip_right=True,
                )
            for expectation in case["expected_screen"]:
                session.assert_screen_text(
                    expectation["text"],
                    region=expectation["region"],
                    index=expectation.get("index", 0),
                    strip_right=True,
                )
            if session.observe_cursor(
                expected=tuple(case["expected_cursor"]), region="body"
            ) is not True:
                raise AssertionError("read-only command moved the body cursor")
            session.assert_file_bytes(path, initial)
            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"{case['name']} exited with {code}: {output!r}"
                )


def _scenario_function(case):
    def run(binary):
        if case["rule"] == "r3" and case["mutation_case"] == "read-only":
            return _run_read_only_scenario(binary, case)
        if case["rule"] == "r3":
            session_factory = _SynchronizedSession
        elif (
            case["rule"] == "r1"
            and case["entry_mode"] == "key"
            and case["entry_keys"][0] == "ESC"
        ):
            session_factory = _cursor_synchronized_session(case)
        else:
            session_factory = Session
        return run_command_path_scenario(binary, case, session_factory=session_factory)

    return run


for _case in _CASES:
    scenario(_case["name"], commands=_case["commands"])(
        _scenario_function(_case)
    )
