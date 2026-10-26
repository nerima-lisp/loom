"""Load strict command-path examples and run their shared PTY flows."""

import json
import tempfile
from contextlib import contextmanager, nullcontext
from pathlib import Path

from . import keys
from .deadline import ScenarioDeadlineExceeded
from .session import Session


_DEFAULT_NAME = object()
_PROMPT_CASES = {"accept", "cancel", "empty", "tab", "history", "invalid"}
_MUTATION_CASES = {
    "effect",
    "undo",
    "read-only",
    "narrow",
    "split-window",
    "macro-replay",
    "prefix-u4",
}
_EFFECT_MUTATION_CASES = {
    "effect",
    "narrow",
    "split-window",
    "macro-replay",
    "prefix-u4",
}


class CommandPathScenarioError(ValueError):
    """A command-path sidecar is missing a strict scenario expectation."""


@contextmanager
def _deadline_stage(name, stage, session=None):
    try:
        yield
    except ScenarioDeadlineExceeded as error:
        screen = ""
        if session is not None:
            screen = (
                f"; cursor={session.screen.cursor!r}\n"
                f"--- screen ---\n{session.screen.dump()}"
            )
        raise ScenarioDeadlineExceeded(
            f"{name} [{stage}]: {error}{screen}"
        ) from error


def _nonempty_string(value, location):
    if not isinstance(value, str) or not value or value != value.strip():
        raise CommandPathScenarioError(
            f"{location} must be a non-empty trimmed string"
        )
    return value


def _validate_screen_expectations(value, location):
    if not isinstance(value, list) or not value:
        raise CommandPathScenarioError(f"{location} must be a non-empty list")
    for index, expectation in enumerate(value):
        where = f"{location}[{index}]"
        if not isinstance(expectation, dict):
            raise CommandPathScenarioError(f"{where} must be an object")
        if expectation.get("region") not in {"body", "minibuffer"}:
            raise CommandPathScenarioError(
                f"{where}.region must be body or minibuffer"
            )
        if not isinstance(expectation.get("text"), str):
            raise CommandPathScenarioError(f"{where}.text must be a string")
        if "index" in expectation and (
            type(expectation["index"]) is not int or expectation["index"] < 0
        ):
            raise CommandPathScenarioError(f"{where}.index must be non-negative")


def _validate_cursor(value, location):
    if (
        not isinstance(value, list)
        or len(value) != 2
        or any(type(coordinate) is not int or coordinate < 0 for coordinate in value)
    ):
        raise CommandPathScenarioError(
            f"{location} must be a region-relative row and column"
        )


def _validate_case(case, index):
    location = f"scenarios[{index}]"
    if not isinstance(case, dict):
        raise CommandPathScenarioError(f"{location} must be an object")
    for field in ("name", "path_id", "lane", "rule", "command", "entry"):
        _nonempty_string(case.get(field), f"{location}.{field}")
    if case["rule"] not in {"r1", "r2", "r3"}:
        raise CommandPathScenarioError(f"{location}.rule must be r1, r2, or r3")
    if not isinstance(case.get("commands"), list) or not case["commands"]:
        raise CommandPathScenarioError(f"{location}.commands must be non-empty")
    for command_index, command in enumerate(case["commands"]):
        _nonempty_string(command, f"{location}.commands[{command_index}]")
    for field in ("initial_bytes", "expected_bytes", "expected_minibuffer"):
        if not isinstance(case.get(field), str):
            raise CommandPathScenarioError(f"{location}.{field} must be a string")
    _validate_cursor(case.get("expected_cursor"), f"{location}.expected_cursor")
    cursor_region = case.get("expected_cursor_region", "body")
    if not isinstance(cursor_region, str) or cursor_region not in {
        "body",
        "minibuffer",
    }:
        raise CommandPathScenarioError(
            f"{location}.expected_cursor_region must be body or minibuffer"
        )
    _validate_screen_expectations(case.get("expected_screen"), f"{location}.expected_screen")

    if case["rule"] == "r1":
        if case.get("entry_mode") not in {"key", "mx", "open-mx"}:
            raise CommandPathScenarioError(
                f"{location}.entry_mode must be key, mx, or open-mx"
            )
        if case["entry_mode"] == "key":
            _validate_key_list(case.get("entry_keys"), f"{location}.entry_keys")
        _validate_key_actions(case.get("pre_keys", []), f"{location}.pre_keys")
    elif case["rule"] == "r2":
        if case.get("command") != "execute-extended-command":
            raise CommandPathScenarioError(
                f"{location}.command must be execute-extended-command"
            )
        if case.get("prompt_case") not in _PROMPT_CASES:
            raise CommandPathScenarioError(
                f"{location}.prompt_case is not a supported completion case"
            )
        if not isinstance(case.get("input_text"), str):
            raise CommandPathScenarioError(f"{location}.input_text must be a string")
        if "accepted_command" in case:
            _nonempty_string(case["accepted_command"], f"{location}.accepted_command")
        if case["prompt_case"] in {"accept", "tab", "history"} and not case.get(
            "accepted_command"
        ):
            raise CommandPathScenarioError(
                f"{location}.accepted_command is required for accepted completion"
            )
        if case["prompt_case"] == "tab":
            _nonempty_string(case.get("tab_expected"), f"{location}.tab_expected")
        if case["prompt_case"] == "history":
            _nonempty_string(
                case.get("history_seed_command"),
                f"{location}.history_seed_command",
            )
            _nonempty_string(
                case.get("history_expected"), f"{location}.history_expected"
            )
    else:
        if case.get("mutation_case") not in _MUTATION_CASES:
            raise CommandPathScenarioError(
                f"{location}.mutation_case is not a supported R3 case"
            )
        if case["mutation_case"] == "undo":
            _validate_cursor(
                case.get("expected_undo_cursor"),
                f"{location}.expected_undo_cursor",
            )
        _validate_key_list(case.get("command_keys"), f"{location}.command_keys")
        if not isinstance(case.get("effect_bytes"), str):
            raise CommandPathScenarioError(f"{location}.effect_bytes must be a string")
        _validate_screen_expectations(
            case.get("effect_screen"), f"{location}.effect_screen"
        )
        if case["mutation_case"] == "macro-replay":
            _validate_screen_expectations(
                case.get("restore_screen"), f"{location}.restore_screen"
            )
            _validate_key_list(
                case.get("replay_prefix_keys"),
                f"{location}.replay_prefix_keys",
            )
        if case["mutation_case"] == "read-only":
            _nonempty_string(
                case.get("read_only_command"), f"{location}.read_only_command"
            )
        if "major_mode" in case:
            _nonempty_string(case["major_mode"], f"{location}.major_mode")
        for field in ("prepare_keys", "post_setup_keys"):
            if field in case:
                _validate_key_list(case[field], f"{location}.{field}")
        prepare_commands = case.get("prepare_commands", [])
        if not isinstance(prepare_commands, list):
            raise CommandPathScenarioError(
                f"{location}.prepare_commands must be a list"
            )
        for command_index, command in enumerate(prepare_commands):
            _nonempty_string(
                command, f"{location}.prepare_commands[{command_index}]"
            )
        if case["mutation_case"] == "narrow" and (
            "narrow-to-region" not in prepare_commands
        ):
            raise CommandPathScenarioError(
                f"{location}.prepare_commands must include narrow-to-region"
            )
        if case["mutation_case"] == "split-window" and (
            "split-window-below" not in prepare_commands
        ):
            raise CommandPathScenarioError(
                f"{location}.prepare_commands must include split-window-below"
            )
        if case["mutation_case"] == "prefix-u4" and case["command_keys"][0] != "C-u":
            raise CommandPathScenarioError(
                f"{location}.command_keys must start with C-u for prefix-u4"
            )
        expected_bytes_source = (
            "effect_bytes"
            if case["mutation_case"] in _EFFECT_MUTATION_CASES
            else "initial_bytes"
        )
        if case["expected_bytes"] != case[expected_bytes_source]:
            raise CommandPathScenarioError(
                f"{location}.expected_bytes must match {expected_bytes_source}"
            )

    if case["expected_bytes"] != case["initial_bytes"] and case["rule"] != "r3":
        if case.get("save_after_effect") is not True:
            raise CommandPathScenarioError(
                f"{location} must save changed bytes before asserting them"
            )
    return dict(case)


def _validate_key_list(value, location):
    if not isinstance(value, list) or not value:
        raise CommandPathScenarioError(f"{location} must be a non-empty list")
    for index, name in enumerate(value):
        _nonempty_string(name, f"{location}[{index}]")


def _validate_key_actions(value, location):
    if not isinstance(value, list):
        raise CommandPathScenarioError(f"{location} must be a list")
    for index, action in enumerate(value):
        where = f"{location}[{index}]"
        if not isinstance(action, dict):
            raise CommandPathScenarioError(f"{where} must be an object")
        _nonempty_string(action.get("key"), f"{where}.key")
        repeat = action.get("repeat", 1)
        if type(repeat) is not int or repeat < 1:
            raise CommandPathScenarioError(f"{where}.repeat must be positive")


def load_command_path_scenarios(path):
    """Read and validate all command-path scenario records from JSON."""
    source = Path(path)
    try:
        data = json.loads(source.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise CommandPathScenarioError(f"cannot read scenario data: {source}") from error
    if not isinstance(data, dict) or data.get("schema_version") != 1:
        raise CommandPathScenarioError("scenario data must use schema_version 1")
    scenarios = data.get("scenarios")
    if not isinstance(scenarios, list) or not scenarios:
        raise CommandPathScenarioError("scenario data must contain non-empty scenarios")
    normalized = [_validate_case(case, index) for index, case in enumerate(scenarios)]
    names = [case["name"] for case in normalized]
    path_ids = [case["path_id"] for case in normalized]
    if len(set(names)) != len(names):
        raise CommandPathScenarioError("scenario names must be unique")
    if len(set(path_ids)) != len(path_ids):
        raise CommandPathScenarioError("path IDs must be unique")
    return normalized


def _key_bytes(name):
    if name == "C-space":
        return keys.ctrl("@")
    if name.startswith("C-") and len(name) == 3:
        return keys.ctrl(name[2])
    if name.startswith("M-") and len(name) == 3:
        return keys.meta(name[2])
    if name in {"RET", "TAB", "UP", "DOWN", "RIGHT", "LEFT", "ESC"}:
        return keys.key(name)
    return keys.text(name)


def _send_key(session, name):
    payload = _key_bytes(name)
    if name in {"RET", "TAB", "UP", "DOWN", "RIGHT", "LEFT", "ESC"}:
        session.key(name)
    else:
        session.send(payload)


def _send_keys(session, names):
    for name in names:
        _send_key(session, name)


def _send_mx(session, command):
    session.send(keys.meta("x"))
    session.wait_for_region_text("minibuffer", "M-x ")
    if command is not None:
        session.type(command)
        session.key("RET")


def _select_major_mode(session, mode):
    _send_mx(session, "set-major-mode")
    session.wait_for_region_text("minibuffer", "Major mode: ")
    session.type(mode)
    session.key("RET")
    session.wait_for_region_text("minibuffer", f"Mode: {mode}")


def _assert_minibuffer(session, expected):
    expected = expected.rstrip()
    session.wait_for_region_exact_text(
        "minibuffer", expected, strip_right=True
    )
    session.assert_screen_text(
        expected, region="minibuffer", strip_right=True
    )


def _assert_screen(session, expectations):
    for expectation in expectations:
        session.assert_screen_text(
            expectation["text"],
            region=expectation["region"],
            index=expectation.get("index", 0),
            strip_right=True,
        )


def _assert_cursor(session, expected, region):
    expected = tuple(expected)
    if session.observe_cursor(expected=expected, region=region) is not True:
        row, column = session.screen.cursor
        row_origin = session.layout.row(region, 0)
        column_origin = session.layout.body_x if region == "body" else 0
        actual = (row - row_origin, column - column_origin)
        raise AssertionError(
            f"{region} cursor was {actual!r}; expected {expected!r}"
        )


def _save_and_assert(session, path, expected_bytes):
    session.send(keys.ctrl("x") + keys.ctrl("s"))
    session.wait_for_file(path, expected_bytes)
    return session.assert_file_bytes(path, expected_bytes)


def _save_and_assert_precondition(session, path, expected_bytes):
    session.send(keys.ctrl("x") + keys.ctrl("s"))
    session.wait_for_file(path, expected_bytes)
    actual = session.observe_file_bytes(
        path, expected_bytes, purpose="precondition"
    )
    if actual != expected_bytes:
        raise AssertionError("restored precondition bytes did not match exactly")


def _assert_final_state(
    session,
    case,
    path,
    expected_bytes,
    *,
    save=False,
    stage_prefix=None,
    check_minibuffer=True,
    expected_cursor=None,
):
    def stage(label):
        if stage_prefix is None:
            return nullcontext()
        return _deadline_stage(
            case["name"], f"{stage_prefix} {label}", session=session
        )

    if check_minibuffer:
        with stage("minibuffer"):
            _assert_minibuffer(session, case["expected_minibuffer"])
    for expectation in case["expected_screen"]:
        with stage(f"{expectation['region']} screen"):
            session.wait_for_region_exact_text(
                expectation["region"],
                expectation["text"],
                index=expectation.get("index", 0),
                strip_right=True,
            )
    _assert_screen(session, case["expected_screen"])
    with stage("cursor"):
        _assert_cursor(
            session,
            case["expected_cursor"] if expected_cursor is None else expected_cursor,
            case.get("expected_cursor_region", "body"),
        )
    expected_bytes = expected_bytes.encode("utf-8")
    with stage("file"):
        if save:
            _save_and_assert(session, path, expected_bytes)
        else:
            session.assert_file_bytes(path, expected_bytes)


def _run_r1(session, case, path):
    for action in case.get("pre_keys", []):
        _send_keys(session, [action["key"]] * action.get("repeat", 1))
    entry_mode = case["entry_mode"]
    if entry_mode == "key":
        _send_keys(session, case["entry_keys"])
    elif entry_mode == "mx":
        _send_mx(session, case["command"])
    else:
        _send_mx(session, None)
    _assert_final_state(
        session,
        case,
        path,
        case["expected_bytes"],
        save=case.get("save_after_effect", False),
    )
    if entry_mode == "open-mx":
        _send_key(session, "C-g")
        session.wait_for_region_exact_text(
            "minibuffer", "Quit", strip_right=True
        )


def _run_r2(session, case, path):
    prompt_case = case["prompt_case"]
    if prompt_case == "history":
        _send_mx(session, case["history_seed_command"])

    session.send(keys.meta("x"))
    session.wait_for_region_text("minibuffer", "M-x ")
    if prompt_case == "history":
        session.key("UP")
        session.wait_for_region_exact_text(
            "minibuffer", case["history_expected"], strip_right=True
        )
    else:
        session.type(case["input_text"])
        if prompt_case == "tab":
            session.key("TAB")
            session.wait_for_region_exact_text(
                "minibuffer", case["tab_expected"], strip_right=True
            )
    if prompt_case == "cancel":
        _send_key(session, "C-g")
    else:
        session.key("RET")

    _assert_final_state(
        session,
        case,
        path,
        case["expected_bytes"],
        save=case.get("save_after_effect", False),
    )


def _assert_effect_state(session, case, *, check_minibuffer=True):
    with _deadline_stage(case["name"], "effect screen", session=session):
        for expectation in case["effect_screen"]:
            session.wait_for_region_exact_text(
                expectation["region"],
                expectation["text"],
                index=expectation.get("index", 0),
                strip_right=True,
            )
    if check_minibuffer:
        with _deadline_stage(case["name"], "effect minibuffer", session=session):
            _assert_minibuffer(session, case["expected_minibuffer"])
    _assert_screen(session, case["effect_screen"])
    with _deadline_stage(case["name"], "effect cursor", session=session):
        _assert_cursor(
            session,
            case["expected_cursor"],
            case.get("expected_cursor_region", "body"),
        )


def _run_r3(session, case, path):
    operation = case["mutation_case"]
    initial = case["initial_bytes"].encode("utf-8")
    effect = case["effect_bytes"].encode("utf-8")

    if "major_mode" in case:
        _select_major_mode(session, case["major_mode"])
    _send_keys(session, case.get("prepare_keys", []))
    for command in case.get("prepare_commands", []):
        _send_mx(session, command)
    _send_keys(session, case.get("post_setup_keys", []))

    if operation == "read-only":
        _send_mx(session, case["read_only_command"])
        session.wait_for_region_text("minibuffer", case["expected_minibuffer"])
        _send_keys(session, case["command_keys"])
        _assert_final_state(session, case, path, case["expected_bytes"])
        return

    if operation == "macro-replay":
        with _deadline_stage(case["name"], "record and undo macro", session=session):
            _send_mx(session, "start-kbd-macro")
            _send_keys(session, case["command_keys"])
            _assert_effect_state(session, case, check_minibuffer=False)
            _send_keys(session, ["C-x", ")"])
            _assert_minibuffer(session, case["expected_minibuffer"])
            _save_and_assert(session, path, effect)
            session.send(keys.ctrl("x") + keys.text("u"))
            restore = case["restore_screen"][0]
            session.wait_for_region_exact_text(
                restore["region"],
                restore["text"],
                index=restore.get("index", 0),
                strip_right=True,
            )
            _save_and_assert_precondition(session, path, initial)

        with _deadline_stage(case["name"], "replay command", session=session):
            _send_keys(session, case["replay_prefix_keys"])
            _send_keys(session, ["C-x", "e"])
        _assert_effect_state(session, case, check_minibuffer=False)
        with _deadline_stage(case["name"], "replay save", session=session):
            _save_and_assert(
                session, path, case["expected_bytes"].encode("utf-8")
            )
        return

    with _deadline_stage(case["name"], "effect", session=session):
        _send_keys(session, case["command_keys"])
        _assert_effect_state(session, case)
    expected_effect = (
        effect if operation == "undo" else case["expected_bytes"].encode("utf-8")
    )
    with _deadline_stage(case["name"], "save effect", session=session):
        _save_and_assert(session, path, expected_effect)
    if operation == "undo":
        with _deadline_stage(case["name"], "undo command", session=session):
            session.send(keys.ctrl("x") + keys.text("u"))
        _assert_final_state(
            session,
            case,
            path,
            case["expected_bytes"],
            save=True,
            stage_prefix="undo result",
            check_minibuffer=False,
            expected_cursor=case["expected_undo_cursor"],
        )


def run_command_path_scenario(binary, case, *, session_factory=Session):
    """Execute one strict R1, R2, or R3 example against a loom binary."""
    initial = case["initial_bytes"].encode("utf-8")
    with tempfile.TemporaryDirectory(prefix="loom-e2e-command-path-") as directory:
        path = Path(directory) / "buffer.txt"
        path.write_bytes(initial)
        with session_factory(
            binary, [str(path)], rows=case.get("rows", 24)
        ) as session:
            session.wait_ready()
            if case["rule"] == "r1":
                _run_r1(session, case, path)
            elif case["rule"] == "r2":
                _run_r2(session, case, path)
            else:
                _run_r3(session, case, path)
            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"{case['name']} exited with {code}: {output!r}"
                )
