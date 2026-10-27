"""Load strict command-path examples and run their shared PTY flows."""

import json
import tempfile
from contextlib import ExitStack, contextmanager, nullcontext
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
        if expectation.get("region") not in {"body", "minibuffer", "screen"}:
            raise CommandPathScenarioError(
                f"{where}.region must be body, minibuffer, or screen"
            )
        if (
            not isinstance(expectation.get("match", "exact"), str)
            or expectation.get("match", "exact") not in {"exact", "contains"}
        ):
            raise CommandPathScenarioError(
                f"{where}.match must be exact or contains"
            )
        if not isinstance(expectation.get("text"), str):
            raise CommandPathScenarioError(f"{where}.text must be a string")
        if expectation.get("match", "exact") not in {"exact", "contains"}:
            raise CommandPathScenarioError(
                f"{where}.match must be exact or contains"
            )
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


def _validate_r1_followup_input(case, location):
    if (
        case.get("path_id") != "r1:goto-line:mx"
        or case.get("command") != "goto-line"
        or case.get("commands") != ["execute-extended-command", "goto-line"]
        or case.get("entry") != "mx"
        or case.get("entry_mode") != "mx"
    ):
        raise CommandPathScenarioError(
            f"{location}.followup_input is only valid for r1:goto-line:mx"
        )
    value = case["followup_input"]
    if (
        not isinstance(value, str)
        or not value.isascii()
        or not value.isdigit()
        or not any(digit != "0" for digit in value)
    ):
        raise CommandPathScenarioError(
            f"{location}.followup_input must be a positive ASCII decimal line number"
        )


def _validate_case(case, index):
    location = f"scenarios[{index}]"
    if not isinstance(case, dict):
        raise CommandPathScenarioError(f"{location} must be an object")
    for dimension in ("columns", "rows"):
        value = case.get(dimension)
        if dimension in case and (
            isinstance(value, bool) or not isinstance(value, int) or value <= 0
        ):
            raise CommandPathScenarioError(
                f"{location}.{dimension} must be a positive integer"
            )
    for field in ("name", "path_id", "lane", "rule", "command", "entry"):
        _nonempty_string(case.get(field), f"{location}.{field}")
    if case["rule"] not in {"r1", "r2", "r3"}:
        raise CommandPathScenarioError(f"{location}.rule must be r1, r2, or r3")
    if "followup_input" in case and case["rule"] != "r1":
        raise CommandPathScenarioError(
            f"{location}.followup_input is only valid for R1 M-x goto-line"
        )
    if not isinstance(case.get("commands"), list) or not case["commands"]:
        raise CommandPathScenarioError(f"{location}.commands must be non-empty")
    for command_index, command in enumerate(case["commands"]):
        _nonempty_string(command, f"{location}.commands[{command_index}]")
    for field in ("initial_bytes", "expected_bytes", "expected_minibuffer"):
        if not isinstance(case.get(field), str):
            raise CommandPathScenarioError(f"{location}.{field} must be a string")
    _validate_cursor(case.get("expected_cursor"), f"{location}.expected_cursor")
    minibuffer_match = case.get("expected_minibuffer_match", "exact")
    if not isinstance(minibuffer_match, str) or minibuffer_match not in {
        "exact",
        "contains",
    }:
        raise CommandPathScenarioError(
            f"{location}.expected_minibuffer_match must be exact or contains"
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
        if "followup_input" in case:
            _validate_r1_followup_input(case, location)
        if "cancel_prompt_after_assert" in case and not isinstance(
            case["cancel_prompt_after_assert"], bool
        ):
            raise CommandPathScenarioError(
                f"{location}.cancel_prompt_after_assert must be a boolean"
            )
        if case["entry_mode"] == "key":
            _validate_key_list(case.get("entry_keys"), f"{location}.entry_keys")
        _validate_key_actions(case.get("pre_keys", []), f"{location}.pre_keys")
    elif case["rule"] == "r2":
        entry_mode = case.get(
            "entry_mode",
            "open-mx" if case["command"] == "execute-extended-command" else None,
        )
        if entry_mode not in {"key", "mx", "open-mx"}:
            raise CommandPathScenarioError(
                f"{location}.entry_mode must be key, mx, or open-mx"
            )
        if entry_mode == "key":
            _validate_key_list(case.get("entry_keys"), f"{location}.entry_keys")
            prompt_open = case.get("prompt_open")
            if not isinstance(prompt_open, str) or not prompt_open.strip():
                raise CommandPathScenarioError(
                    f"{location}.prompt_open must be non-empty text"
                )
        elif entry_mode == "mx":
            if case["command"] == "execute-extended-command":
                raise CommandPathScenarioError(
                    f"{location}.entry_mode mx cannot target execute-extended-command"
                )
            if not case["entry"].startswith("mx;prompt:"):
                raise CommandPathScenarioError(
                    f"{location}.entry must be the generated M-x prompt entry"
                )
            prompt_open = case.get("prompt_open")
            if not isinstance(prompt_open, str) or not prompt_open.strip():
                raise CommandPathScenarioError(
                    f"{location}.prompt_open must be non-empty text"
                )
        elif case["command"] != "execute-extended-command":
            raise CommandPathScenarioError(
                f"{location}.entry_mode open-mx requires execute-extended-command"
            )

        if case.get("prompt_case") not in _PROMPT_CASES:
            raise CommandPathScenarioError(
                f"{location}.prompt_case is not a supported completion case"
            )
        if not isinstance(case.get("input_text"), str):
            raise CommandPathScenarioError(f"{location}.input_text must be a string")
        prompt_kind = case.get(
            "prompt_kind",
            "completion" if entry_mode == "open-mx" else None,
        )
        if prompt_kind not in {"free-string", "completion", "yes-no", "numeric"}:
            raise CommandPathScenarioError(
                f"{location}.prompt_kind is not a supported prompt kind"
            )
        if "accepted_command" in case:
            _nonempty_string(case["accepted_command"], f"{location}.accepted_command")
        if (
            entry_mode == "open-mx"
            and case["prompt_case"] in {"accept", "tab", "history"}
            and not case.get("accepted_command")
        ):
            raise CommandPathScenarioError(
                f"{location}.accepted_command is required for accepted completion"
            )
        if case["prompt_case"] == "tab":
            _nonempty_string(case.get("tab_expected"), f"{location}.tab_expected")
        if case["prompt_case"] == "history":
            history_value_field = (
                "history_seed_command"
                if entry_mode == "open-mx"
                else "history_seed_input"
            )
            _nonempty_string(
                case.get(history_value_field),
                f"{location}.{history_value_field}",
            )
            _nonempty_string(
                case.get("history_expected"), f"{location}.history_expected"
            )
            if entry_mode != "open-mx" and not isinstance(
                case.get("history_next_expected"), str
            ):
                raise CommandPathScenarioError(
                    f"{location}.history_next_expected must be text for target prompts"
                )
            if "history_cancel" in case and type(case["history_cancel"]) is not bool:
                raise CommandPathScenarioError(
                    f"{location}.history_cancel must be a boolean"
                )
        elif "history_cancel" in case:
            raise CommandPathScenarioError(
                f"{location}.history_cancel is only valid for history prompts"
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
            if "expected_read_only_status" in case:
                _nonempty_string(
                    case["expected_read_only_status"],
                    f"{location}.expected_read_only_status",
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

    if "fixture_keys" in case:
        _validate_key_list(case["fixture_keys"], f"{location}.fixture_keys")
    if "fixture_wait" in case:
        if case["rule"] != "r2":
            raise CommandPathScenarioError(
                f"{location}.fixture_wait is only valid for R2 scenarios"
            )
        fixture_wait = case["fixture_wait"]
        if not isinstance(fixture_wait, dict):
            raise CommandPathScenarioError(f"{location}.fixture_wait must be an object")
        _validate_screen_expectations([fixture_wait], f"{location}.fixture_wait")
        _nonempty_string(fixture_wait["text"], f"{location}.fixture_wait.text")
    if "fixture_keys_after_wait" in case:
        if "fixture_wait" not in case:
            raise CommandPathScenarioError(
                f"{location}.fixture_keys_after_wait requires fixture_wait"
            )
        _validate_key_list(
            case["fixture_keys_after_wait"],
            f"{location}.fixture_keys_after_wait",
        )

    if "fixture_files" in case:
        fixture_files = case["fixture_files"]
        if not isinstance(fixture_files, list):
            raise CommandPathScenarioError(f"{location}.fixture_files must be a list")
        fixture_names = set()
        for fixture_index, fixture in enumerate(fixture_files):
            where = f"{location}.fixture_files[{fixture_index}]"
            if not isinstance(fixture, dict):
                raise CommandPathScenarioError(f"{where} must be an object")
            fixture_name = _scenario_filename(fixture.get("path"), f"{where}.path")
            if fixture_name in {"buffer.txt", "session.sexp"}:
                raise CommandPathScenarioError(
                    f"{where}.path is reserved by the scenario runner"
                )
            if fixture_name in fixture_names:
                raise CommandPathScenarioError(
                    f"{location}.fixture_files contains duplicate paths"
                )
            fixture_names.add(fixture_name)
            if not isinstance(fixture.get("contents"), str):
                raise CommandPathScenarioError(f"{where}.contents must be a string")

    if "expected_filesystem" in case:
        expected_filesystem = case["expected_filesystem"]
        if not isinstance(expected_filesystem, list) or not expected_filesystem:
            raise CommandPathScenarioError(
                f"{location}.expected_filesystem must be a non-empty list"
            )
        expected_paths = set()
        for expected_index, expectation in enumerate(expected_filesystem):
            where = f"{location}.expected_filesystem[{expected_index}]"
            if not isinstance(expectation, dict):
                raise CommandPathScenarioError(f"{where} must be an object")
            expected_name = _scenario_filename(
                expectation.get("path"), f"{where}.path"
            )
            if expected_name in expected_paths:
                raise CommandPathScenarioError(
                    f"{location}.expected_filesystem contains duplicate paths"
                )
            expected_paths.add(expected_name)
            if not isinstance(expectation.get("kind"), str) or expectation.get(
                "kind"
            ) not in {"file", "directory", "absent"}:
                raise CommandPathScenarioError(
                    f"{where}.kind must be file, directory, or absent"
                )

    session_fixture = case.get("session_fixture")
    if session_fixture is not None and (
        not isinstance(session_fixture, dict)
        or session_fixture.get("path") != "$session_file"
        or not isinstance(session_fixture.get("contents"), str)
    ):
        raise CommandPathScenarioError(
            f"{location}.session_fixture must define the temporary session path and text"
        )

    if case["expected_bytes"] != case["initial_bytes"] and case["rule"] != "r3":
        if case.get("save_after_effect") is not True:
            raise CommandPathScenarioError(
                f"{location} must save changed bytes before asserting them"
            )
    return dict(case)


def _scenario_filename(value, location):
    _nonempty_string(value, location)
    if (
        value in {".", ".."}
        or "/" in value
        or "\\" in value
        or "\x00" in value
    ):
        raise CommandPathScenarioError(
            f"{location} must be a filename inside the scenario directory"
        )
    return value


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
    if name == "C-/":
        return b"\x1b[47;5u"
    if name == "C-M-_":
        return b"\x1b[95;7u"
    if name == "C-space":
        return keys.ctrl("@")
    if name in {"SPC", "SPACE"}:
        return keys.text(" ")
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


def _assert_minibuffer(session, expected, match="exact"):
    expected = expected.rstrip()
    if match == "contains":
        session.wait_for_region_text("minibuffer", expected)
    else:
        session.wait_for_region_exact_text(
            "minibuffer", expected, strip_right=True
        )
    session.assert_screen_text(
        expected, match=match, region="minibuffer", strip_right=True
    )


def _assert_screen(session, expectations):
    for expectation in expectations:
        session.assert_screen_text(
            expectation["text"],
            match=expectation.get("match", "exact"),
            region=expectation["region"],
            index=expectation.get("index", 0),
            strip_right=True,
        )


def _assert_cursor(session, expected, region):
    expected = tuple(expected)
    session.wait_for_region_cursor(region, expected[1], index=expected[0])
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

    scenario_dir = path.parent.resolve()
    for expectation in case.get("expected_filesystem", []):
        with stage(f"filesystem {expectation['path']}"):
            target = (scenario_dir / expectation["path"]).resolve()
            try:
                target.relative_to(scenario_dir)
            except ValueError as error:
                raise CommandPathScenarioError(
                    f"{case['name']}.expected_filesystem.path escaped its scenario directory"
                ) from error
            if target.is_file():
                actual = "file"
            elif target.is_dir():
                actual = "directory"
            elif target.exists() or target.is_symlink():
                actual = "other"
            else:
                actual = "absent"
            try:
                session.assert_external_state(
                    f"filesystem/{expectation['path']}",
                    actual,
                    expectation["kind"],
                )
            except AssertionError as error:
                screen = session.screen.dump() if session.screen is not None else ""
                raise AssertionError(f"{error}\n--- screen ---\n{screen}") from error

    if check_minibuffer:
        with stage("minibuffer"):
            _assert_minibuffer(
                session,
                case["expected_minibuffer"],
                case.get("expected_minibuffer_match", "exact"),
            )
    for expectation in case["expected_screen"]:
        with stage(
            f"screen {expectation['region']} {expectation['text']!r}"
        ):
            if expectation.get("match", "exact") == "contains":
                session.wait_for_region_text(
                    expectation["region"],
                    expectation["text"],
                    index=expectation.get("index", 0),
                )
            else:
                session.wait_for_region_exact_text(
                    expectation["region"],
                    expectation["text"],
                    index=expectation.get("index", 0),
                    strip_right=True,
                )
    with stage("screen assertions"):
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
    if "followup_input" in case:
        with _deadline_stage(case["name"], "follow-up input", session=session):
            session.wait_for_region_text("minibuffer", "Go to line: ")
            session.type(case["followup_input"])
            session.key("RET")
    _assert_final_state(
        session,
        case,
        path,
        case["expected_bytes"],
        save=case.get("save_after_effect", False),
        stage_prefix="final state",
    )
    if entry_mode == "open-mx" or case.get("cancel_prompt_after_assert", False):
        _send_key(session, "C-g")
        session.wait_for_region_exact_text(
            "minibuffer", "Quit", strip_right=True
        )


def _open_r2_prompt(session, case):
    entry_mode = case.get(
        "entry_mode",
        "open-mx" if case["command"] == "execute-extended-command" else None,
    )
    if entry_mode == "key":
        _send_keys(session, case["entry_keys"])
    elif entry_mode == "mx":
        _send_mx(session, case["command"])
    else:
        session.send(keys.meta("x"))
        session.wait_for_region_text("minibuffer", "M-x ")

    if entry_mode != "open-mx":
        session.wait_for_region_text("minibuffer", case["prompt_open"])


def _r2_prompt_display(case, value):
    if case.get("entry_mode") in {None, "open-mx"}:
        return value
    return (case["prompt_open"] + value).rstrip()


def _run_r2(session, case, path):
    prompt_case = case["prompt_case"]
    entry_mode = case.get(
        "entry_mode",
        "open-mx" if case["command"] == "execute-extended-command" else None,
    )

    def stage(label):
        return _deadline_stage(case["name"], label, session=session)

    if case.get("fixture_keys"):
        with stage("fixture keys"):
            _send_keys(session, case["fixture_keys"])
    if case.get("fixture_wait"):
        fixture_wait = case["fixture_wait"]
        with stage("fixture wait"):
            session.wait_for_region_text(
                fixture_wait["region"],
                fixture_wait["text"],
                index=fixture_wait.get("index", 0),
            )
    if case.get("fixture_keys_after_wait"):
        with stage("fixture keys after wait"):
            _send_keys(session, case["fixture_keys_after_wait"])
    if prompt_case == "history":
        if entry_mode == "open-mx":
            with stage("history seed command"):
                _send_mx(session, case["history_seed_command"])
        else:
            with stage("history seed prompt open"):
                _open_r2_prompt(session, case)
            with stage("history seed input"):
                session.type(case["history_seed_input"])
            with stage("history seed accept (RET)"):
                session.key("RET")

    with stage("target prompt open"):
        _open_r2_prompt(session, case)
    if prompt_case == "history":
        with stage("history target input"):
            session.type(case["input_text"])
            if case["input_text"]:
                session.wait_for_region_text("minibuffer", case["input_text"])
        if entry_mode == "open-mx":
            with stage("history previous (UP)"):
                session.key("UP")
                session.wait_for_region_exact_text(
                    "minibuffer", case["history_expected"], strip_right=True
                )
        else:
            with stage("history previous (M-p)"):
                session.send(keys.meta("p"))
                session.wait_for_region_exact_text(
                    "minibuffer",
                    _r2_prompt_display(case, case["history_expected"]),
                    strip_right=True,
                )
        if entry_mode != "open-mx":
            with stage("history next (M-n)"):
                session.send(keys.meta("n"))
                session.wait_for_region_exact_text(
                    "minibuffer",
                    _r2_prompt_display(case, case["history_next_expected"]),
                    strip_right=True,
                )
            with stage("history previous (M-p)"):
                session.send(keys.meta("p"))
                session.wait_for_region_exact_text(
                    "minibuffer",
                    _r2_prompt_display(case, case["history_expected"]),
                    strip_right=True,
                )
    else:
        with stage("target prompt input"):
            session.type(case["input_text"])
            if case["input_text"]:
                session.wait_for_region_text("minibuffer", case["input_text"])
        if prompt_case == "tab":
            with stage("TAB completion"):
                session.key("TAB")
                session.wait_for_region_exact_text(
                    "minibuffer",
                    _r2_prompt_display(case, case["tab_expected"]),
                    strip_right=True,
                )
                if case["command"] in {
                    "copy-to-register",
                    "insert-register",
                    "jump-to-register",
                    "point-to-register",
                }:
                    session.assert_screen_text(
                        _r2_prompt_display(case, case["tab_expected"]),
                        region="minibuffer",
                        strip_right=True,
                    )
    if prompt_case == "cancel" or (
        prompt_case == "history" and case.get("history_cancel", False)
    ):
        with stage("prompt cancel (C-g)"):
            _send_key(session, "C-g")
    else:
        with stage("prompt accept (RET)"):
            session.key("RET")

    with stage("prompt result"):
        _assert_minibuffer(
            session,
            case["expected_minibuffer"],
            case.get("expected_minibuffer_match", "exact"),
        )
    _assert_final_state(
        session,
        case,
        path,
        case["expected_bytes"],
        save=case.get("save_after_effect", False),
        stage_prefix="final state",
        check_minibuffer=False,
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
    if case.get("fixture_keys"):
        _send_keys(session, case["fixture_keys"])

    if "pre_command_keys" in case:
        _send_keys(session, case["pre_command_keys"])

    if "major_mode" in case:
        _select_major_mode(session, case["major_mode"])
    _send_keys(session, case.get("prepare_keys", []))
    for command in case.get("prepare_commands", []):
        _send_mx(session, command)
    _send_keys(session, case.get("post_setup_keys", []))

    if operation == "read-only":
        _send_mx(session, case["read_only_command"])
        session.wait_for_region_exact_text(
            "minibuffer",
            case.get("expected_read_only_status", case["expected_minibuffer"]),
            strip_right=True,
        )
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


def _resolve_path_tokens(value, buffer_path, session_path, fixture_files=()):
    if isinstance(value, str):
        resolved = (
            value.replace(
                "$buffer_file", str(Path(buffer_path).resolve(strict=False))
            )
            .replace(
                "$session_file", str(Path(session_path).resolve(strict=False))
            )
            .replace(
                "$scenario_dir",
                str(Path(buffer_path).parent.resolve(strict=False)),
            )
        )
        for fixture in fixture_files:
            fixture_name = fixture["path"]
            resolved = resolved.replace(
                f"$fixture_file:{fixture_name}",
                str(
                    buffer_path.with_name(fixture_name).resolve(strict=False)
                ),
            )
        return resolved
    if isinstance(value, list):
        return [
            _resolve_path_tokens(item, buffer_path, session_path, fixture_files)
            for item in value
        ]
    if isinstance(value, dict):
        return {
            key: _resolve_path_tokens(item, buffer_path, session_path, fixture_files)
            for key, item in value.items()
        }
    return value


def run_command_path_scenario(binary, case, *, session_factory=Session):
    """Execute one strict R1, R2, or R3 example against a loom binary."""
    initial = case["initial_bytes"].encode("utf-8")
    with tempfile.TemporaryDirectory(prefix="loom-e2e-command-path-") as directory:
        path = Path(directory) / "buffer.txt"
        session_path = path.with_name("session.sexp")
        path.write_bytes(initial)
        case = _resolve_path_tokens(
            case, path, session_path, case.get("fixture_files", [])
        )
        for fixture in case.get("fixture_files", []):
            (Path(directory) / fixture["path"]).write_text(
                fixture["contents"], encoding="utf-8"
            )
        fixture = case.get("session_fixture")
        if fixture is not None:
            fixture_path = Path(fixture["path"])
            if fixture_path != session_path.resolve(strict=False):
                raise CommandPathScenarioError(
                    f"{case['name']}.session_fixture.path must resolve inside its scenario directory"
                )
            session_path.write_text(fixture["contents"], encoding="utf-8")

        with ExitStack() as stack:
            session_context = session_factory(
                binary,
                [str(path)],
                columns=case.get("columns", 80),
                rows=case.get("rows", 24),
            )
            if case["rule"] == "r2":
                with _deadline_stage(case["name"], "session startup"):
                    session = stack.enter_context(session_context)
                with _deadline_stage(case["name"], "session ready", session=session):
                    session.wait_ready()
            else:
                session = stack.enter_context(session_context)
                session.wait_ready()
            if case["rule"] == "r1":
                _run_r1(session, case, path)
            elif case["rule"] == "r2":
                _run_r2(session, case, path)
            else:
                _run_r3(session, case, path)
            if case["rule"] == "r2":
                with _deadline_stage(case["name"], "session quit", session=session):
                    output, code = session.quit()
            else:
                output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"{case['name']} exited with {code}: {output!r}"
                )
