"""Run the lang-lisp R1 command paths through a PTY."""

import os
import tempfile
from pathlib import Path

from loom_e2e import keys
from loom_e2e.command_path_scenarios import load_command_path_scenarios
from loom_e2e.registry import scenario
from loom_e2e.session import Session


_CASES = load_command_path_scenarios(Path(__file__).with_name("command-paths.json"))


def _write(path, contents):
    with open(path, "wb") as handle:
        handle.write(contents)


def _send_key(session, name):
    if name == "C-M-\\":
        session.send(keys.meta("\x1c"))
    elif name.startswith("C-") and len(name) == 3:
        session.send(keys.ctrl(name[2]))
    elif name.startswith("M-") and len(name) == 3:
        session.send(keys.meta(name[2]))
    elif name in {"RET", "TAB", "UP", "DOWN", "RIGHT", "LEFT", "ESC"}:
        session.key(name)
    else:
        session.type(name)


def _send_actions(session, actions):
    for action in actions:
        for _ in range(action.get("repeat", 1)):
            _send_key(session, action["key"])


def _assert_effect(session, case, path):
    for expectation in case["expected_screen"]:
        region = expectation["region"]
        index = expectation.get("index", 0)
        session.wait_for_region_exact_text(
            region, expectation["text"], index=index, strip_right=True
        )
        session.assert_screen_text(
            expectation["text"],
            region=region,
            index=index,
            strip_right=True,
        )
    for expectation in case.get("expected_prefixes", []):
        session.assert_screen_text(
            expectation["text"],
            match="starts_with",
            region=expectation["region"],
            index=expectation.get("index", 0),
        )

    expected_cursor = tuple(case["expected_cursor"])
    cursor_region = case.get("expected_cursor_region", "body")
    session.wait_for_region_cursor(
        cursor_region, expected_cursor[1], index=expected_cursor[0]
    )
    if session.observe_cursor(
        expected=expected_cursor,
        region=cursor_region,
    ) is not True:
        raise AssertionError(
            f"{case['name']}: cursor did not match {expected_cursor!r}"
        )

    session.send(keys.ctrl("x") + keys.ctrl("s"))
    expected_bytes = case["expected_bytes"].encode("utf-8")
    session.wait_for_file(path, expected_bytes)
    session.assert_file_bytes(path, expected_bytes)


def _run_editor_case(binary, case):
    initial = case["initial_bytes"].encode("utf-8")
    with tempfile.TemporaryDirectory(prefix="loom-e2e-lang-lisp-path-") as directory:
        path = os.path.join(directory, "buffer." + case["extension"])
        _write(path, initial)

        with Session(binary, [path]) as session:
            session.wait_ready()
            _send_actions(session, case.get("pre_keys", []))
            _send_actions(session, [{"key": key} for key in case["entry_keys"]])
            _assert_effect(session, case, path)
            output, code = session.quit()

        if code != 0:
            raise AssertionError(f"{case['name']} exited with {code}: {output!r}")


def _open_file(session, path, target):
    session.extended_command("find-file")
    session.wait_for_region_text("minibuffer", "Find file: ")
    session.type(path)
    session.key("RET")
    session.wait_for_region_exact_text(
        "body", target["text"], strip_right=True
    )
    session.wait_for_region_text("mode-line", target["mode"])
    session.assert_screen_text(target["text"], region="body", strip_right=True)
    session.assert_screen_text(
        target["mode"], match="contains", region="mode-line", strip_right=True
    )
    session.wait_for_region_cursor("body", 0)
    if session.observe_cursor(expected=(0, 0), region="body") is not True:
        raise AssertionError(
            f"{target['filename']}: cursor was not at the start of the file"
        )
    session.assert_file_bytes(path, target["bytes"].encode("utf-8"))


def _run_mode_assignment(binary, case):
    initial = case["initial_bytes"].encode("utf-8")
    with tempfile.TemporaryDirectory(prefix="loom-e2e-lang-lisp-mode-path-") as directory:
        starter = os.path.join(directory, "starter.txt")
        _write(starter, initial)
        targets = []
        for target in case["mode_targets"]:
            path = os.path.join(directory, target["filename"])
            _write(path, target["bytes"].encode("utf-8"))
            targets.append((path, target))

        with Session(binary, [starter]) as session:
            session.wait_ready()
            for path, target in targets:
                _open_file(session, path, target)
            output, code = session.quit()

        if code != 0:
            raise AssertionError(f"{case['name']} exited with {code}: {output!r}")


def _scenario_function(case):
    def run(binary):
        if case["path_id"] == "r1:lang-lisp:mode-assignment":
            return _run_mode_assignment(binary, case)
        return _run_editor_case(binary, case)

    return run


for _case in _CASES:
    scenario(_case["name"], commands=_case["commands"])(_scenario_function(_case))
