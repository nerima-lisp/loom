"""Load strict command-path examples and run their shared PTY flows."""

import json
import tempfile
from contextlib import contextmanager
from pathlib import Path

from . import keys
from .deadline import ScenarioDeadlineExceeded
from .session import Session


_DEFAULT_NAME = object()
_PROMPT_CASES = {"accept", "cancel", "empty", "tab", "history", "invalid"}
_MUTATION_CASES = {"effect", "undo", "read-only", "macro-replay"}


class CommandPathScenarioError(ValueError):
    """A command-path sidecar is missing a strict scenario expectation."""


@contextmanager
def _deadline_stage(name, stage):
    try:
        yield
    except ScenarioDeadlineExceeded as error:
        raise ScenarioDeadlineExceeded(f"{name} [{stage}]: {error}") from error


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
    cursor = case.get("expected_cursor")
    if (
        not isinstance(cursor, list)
        or len(cursor) != 2
        or any(type(value) is not int or value < 0 for value in cursor)
    ):
        raise CommandPathScenarioError(
            f"{location}.expected_cursor must be a region-relative row and column"
        )
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
        if case["mutation_case"] == "read-only":
            _nonempty_string(
                case.get("read_only_command"), f"{location}.read_only_command"
            )
        expected_bytes_source = (
            "effect_bytes"
            if case["mutation_case"] in {"effect", "macro-replay"}
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
    if session.observe_cursor(expected=tuple(expected), region=region) is not True:
        raise AssertionError(f"{region} cursor did not equal {tuple(expected)!r}")


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


def _assert_final_state(session, case, path, expected_bytes, *, save=False):
    _assert_minibuffer(session, case["expected_minibuffer"])
    for expectation in case["expected_screen"]:
        session.wait_for_region_exact_text(
            expectation["region"],
            expectation["text"],
            index=expectation.get("index", 0),
            strip_right=True,
        )
    _assert_screen(session, case["expected_screen"])
    _assert_cursor(
        session,
        case["expected_cursor"],
        case.get("expected_cursor_region", "body"),
    )
    expected_bytes = expected_bytes.encode("utf-8")
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


def _assert_effect_state(session, case):
    for expectation in case["effect_screen"]:
        session.wait_for_region_exact_text(
            expectation["region"],
            expectation["text"],
            index=expectation.get("index", 0),
            strip_right=True,
        )
    _assert_minibuffer(session, case["expected_minibuffer"])
    _assert_screen(session, case["effect_screen"])
    _assert_cursor(
        session,
        case["expected_cursor"],
        case.get("expected_cursor_region", "body"),
    )


def _run_r3(session, case, path):
    operation = case["mutation_case"]
    initial = case["initial_bytes"].encode("utf-8")
    effect = case["effect_bytes"].encode("utf-8")

    if operation == "read-only":
        _send_mx(session, case["read_only_command"])
        session.wait_for_region_text("minibuffer", case["expected_minibuffer"])
        _send_keys(session, case["command_keys"])
        _assert_final_state(session, case, path, case["expected_bytes"])
        return

    if operation == "macro-replay":
        with _deadline_stage(case["name"], "record and undo macro"):
            _send_keys(session, ["C-x", "("])
            _send_keys(session, case["command_keys"])
            session.wait_for_region_exact_text(
                "body", case["effect_screen"][0]["text"], strip_right=True
            )
            _send_keys(session, ["C-x", ")"])
            session.send(keys.ctrl("x") + keys.text("u"))
            session.wait_for_region_exact_text(
                "body", case["restore_screen"][0]["text"], strip_right=True
            )
            _save_and_assert_precondition(session, path, initial)

        replay_results = []
        for replay_index in range(2):
            with _deadline_stage(case["name"], f"replay {replay_index + 1}"):
                _send_keys(session, ["C-x", "e"])
                _assert_effect_state(session, case)
                replay_result = _save_and_assert(
                    session, path, case["expected_bytes"].encode("utf-8")
                )
            replay_results.append(replay_result)
            if replay_index == 0:
                with _deadline_stage(case["name"], "undo replay"):
                    session.send(keys.ctrl("x") + keys.text("u"))
                    session.wait_for_region_exact_text(
                        "body", case["restore_screen"][0]["text"], strip_right=True
                    )
                    _save_and_assert_precondition(session, path, initial)
        if replay_results[0] != replay_results[1]:
            raise AssertionError("second macro replay did not match the first bytes")
        _assert_effect_state(session, case)
        return

    with _deadline_stage(case["name"], "effect"):
        _send_keys(session, case["command_keys"])
        _assert_effect_state(session, case)
    expected_effect = (
        effect if operation == "undo" else case["expected_bytes"].encode("utf-8")
    )
    with _deadline_stage(case["name"], "save effect"):
        _save_and_assert(session, path, expected_effect)
    if operation == "undo":
        with _deadline_stage(case["name"], "undo and restore"):
            session.send(keys.ctrl("x") + keys.text("u"))
            _assert_final_state(
                session, case, path, case["expected_bytes"], save=True
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
