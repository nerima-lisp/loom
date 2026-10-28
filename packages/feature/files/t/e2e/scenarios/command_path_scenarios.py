"""Run strict command-path cases owned by the files feature slice."""

import json
import os
import shlex
from pathlib import Path
from tempfile import TemporaryDirectory

from loom_e2e import keys
from loom_e2e.command_path_scenarios import (
    _assert_final_state,
    _deadline_stage,
    _send_key,
    _send_keys,
    load_command_path_scenarios,
    run_command_path_scenario,
)
from loom_e2e.registry import scenario
from loom_e2e.session import DEFAULT_TIMEOUT, Session


_ENTRY_KEYS = {
    "find-file": ["C-x", "C-f"],
    "recent-file": ["C-x", "r", "f"],
    "save-buffer": ["C-x", "C-s"],
    "write-file": ["C-x", "C-w"],
}
_PROMPT_TEXT = {
    ("find-file", 1): "Find file: ",
    ("recent-file", 1): "Recent file: ",
    ("revert-buffer", 1): "Discard local changes and revert {source_path}? (y/n): ",
    ("save-buffer", 1): "Save file: ",
    ("save-buffer", 2): "File changed on disk. Overwrite? (y/n): {source_path}",
    ("write-file", 1): "Write file: ",
}
_R2_CASES = {"accept", "cancel", "empty", "tab", "history", "invalid"}
_R3_VARIANTS = {"effect", "undo", "read-only", "narrow", "split-window", "macro-replay", "prefix-u4"}
_R3_SHARED_VARIANTS = {"effect", "undo", "read-only", "macro-replay"}
_R3_LOCAL_VARIANTS = {"narrow", "split-window", "prefix-u4"}
_R3_TARGETS = {"revert-buffer", "save-buffer"}
_SETUP_COMMANDS = {"narrow-to-region", "set-mark-command"}


def _load_files_cases(path):
    document = json.loads(path.read_text(encoding="utf-8"))
    if document.get("schema_version") != 1 or not isinstance(document.get("scenarios"), list):
        raise ValueError("files command-path declarations have an invalid top-level schema")

    custom = [
        case
        for case in document["scenarios"]
        if case.get("rule") == "r3" and case.get("mutation_case") in _R3_LOCAL_VARIANTS
    ]
    custom_ids = {case.get("path_id") for case in custom}
    shared_document = {
        **document,
        "scenarios": [case for case in document["scenarios"] if case.get("path_id") not in custom_ids],
    }
    with TemporaryDirectory(prefix="loom-e2e-files-command-path-schema-") as directory:
        shared_path = Path(directory) / path.name
        shared_path.write_text(json.dumps(shared_document), encoding="utf-8")
        shared_cases = load_command_path_scenarios(shared_path)

    validated = {case["path_id"]: case for case in shared_cases}
    for case in shared_cases:
        if case["rule"] == "r3":
            _validate_files_r3_case(case)
    for case in custom:
        _validate_files_local_r3_case(case)
        validated[case["path_id"]] = dict(case)
    declared_ids = [case.get("path_id") for case in document["scenarios"]]
    if len(validated) != len(declared_ids) or set(validated) != set(declared_ids):
        raise ValueError("files command-path declarations contain duplicate or missing IDs")
    return [validated[case["path_id"]] for case in document["scenarios"]]


def _wait_exact(session, region, expected):
    session.wait_for_region_exact_text(region, expected.rstrip(), strip_right=True)


def _entry(target, prompt_index, prompt_kind):
    if target == "revert-buffer":
        return f"mx;prompt:{prompt_index}:{prompt_kind}"
    keys = _ENTRY_KEYS[target]
    sequence = []
    for key in keys:
        if key.startswith("C-"):
            sequence.append({"key": key[2:], "modifiers": ["control"]})
        else:
            sequence.append({"key": key, "modifiers": []})
    signature = json.dumps(
        {"keymap": "global", "sequence": sequence},
        sort_keys=True,
        separators=(",", ":"),
    )
    return f"key:{signature};prompt:{prompt_index}:{prompt_kind}"


def _validate_files_prompt_case(case):
    target = case.get("target_command")
    prompt_index = case.get("prompt_index")
    prompt_kind = case.get("prompt_kind")
    if target not in {*_ENTRY_KEYS, "revert-buffer"}:
        raise ValueError(f"{case['name']} has unsupported files prompt target")
    expected_command = target if target == "revert-buffer" else "execute-extended-command"
    if case.get("command") != expected_command:
        raise ValueError(f"{case['name']} must pass the shared R2 schema")
    expected_index_kind = {
        "find-file": (1, "free-string"),
        "recent-file": (1, "completion"),
        "revert-buffer": (1, "yes-no"),
        "save-buffer": (prompt_index, "free-string" if prompt_index == 1 else "yes-no"),
        "write-file": (1, "free-string"),
    }[target]
    if (prompt_index, prompt_kind) != expected_index_kind:
        raise ValueError(f"{case['name']} has an unsupported prompt index or kind")
    if target == "save-buffer" and prompt_index not in {1, 2}:
        raise ValueError(f"{case['name']} has an unsupported save-buffer prompt")
    if case.get("entry") != _entry(target, prompt_index, prompt_kind):
        raise ValueError(f"{case['name']} entry disagrees with its prompt target")
    if case.get("prompt_text") != _PROMPT_TEXT[(target, prompt_index)]:
        raise ValueError(f"{case['name']} prompt text disagrees with its target command")
    if case.get("prompt_open") != case["prompt_text"]:
        raise ValueError(f"{case['name']} prompt-open text disagrees with its target command")
    if case.get("path_id") != (
        f"r2:{target}:prompt-{prompt_index}:{prompt_kind}:{case['prompt_case']}"
    ):
        raise ValueError(f"{case['name']} path ID disagrees with its prompt declaration")
    if case["prompt_case"] not in _R2_CASES:
        raise ValueError(f"{case['name']} has an unsupported prompt outcome")
    if target not in case["commands"]:
        raise ValueError(f"{case['name']} trace must include {target}")
    if target == "revert-buffer":
        if case.get("entry_mode") != "mx":
            raise ValueError(f"{case['name']} must enter revert-buffer through M-x")
    elif case.get("entry_mode") != "key" or case.get("entry_keys") != _ENTRY_KEYS[target]:
        raise ValueError(f"{case['name']} must enter through the target key sequence")
    if case.get("expected_file") not in {"source", "target"}:
        raise ValueError(f"{case['name']} must identify the file checked for exact bytes")
    if not isinstance(case.get("prompt_text"), str) or not case["prompt_text"]:
        raise ValueError(f"{case['name']} must declare its exact target prompt")
    if case["prompt_case"] == "history":
        if not isinstance(case.get("history_seed_input"), str):
            raise ValueError(f"{case['name']} must declare its prompt history seed")
        if not isinstance(case.get("history_expected"), str) or not case["history_expected"]:
            raise ValueError(f"{case['name']} must declare the exact recalled prompt")
    if case.get("reprompt_after_response"):
        if not isinstance(case.get("reprompt_expected"), str) or not case["reprompt_expected"]:
            raise ValueError(f"{case['name']} must declare its exact repeated prompt")
    if not isinstance(case.get("prompt_result_minibuffer"), str):
        raise ValueError(f"{case['name']} must declare its exact prompt result")


def _primary_entry(target):
    sequence = []
    for key in _ENTRY_KEYS[target]:
        if key.startswith("C-"):
            sequence.append({"key": key[2:], "modifiers": ["control"]})
        else:
            sequence.append({"key": key, "modifiers": []})
    signature = json.dumps(
        {"keymap": "global", "sequence": sequence},
        sort_keys=True,
        separators=(",", ":"),
    )
    return f"key:{signature}"


def _validate_setup_actions(case, field):
    actions = case.get(field, [])
    if not isinstance(actions, list):
        raise ValueError(f"{case['name']}.{field} must be a list")
    for index, action in enumerate(actions):
        where = f"{case['name']}.{field}[{index}]"
        if not isinstance(action, dict):
            raise ValueError(f"{where} must be an object")
        if set(action) == {"keys"}:
            if not isinstance(action["keys"], list) or not action["keys"] or any(
                not isinstance(key, str) or not key for key in action["keys"]
            ):
                raise ValueError(f"{where}.keys must be a non-empty list of key names")
        elif set(action) == {"command"}:
            if action["command"] not in _SETUP_COMMANDS:
                raise ValueError(f"{where}.command is unsupported")
        elif set(action) == {"assert_screen"}:
            expectation = action["assert_screen"]
            if not isinstance(expectation, dict) or set(expectation) - {"region", "text", "count"}:
                raise ValueError(f"{where}.assert_screen has unsupported fields")
            if expectation.get("region") not in {"body", "screen"}:
                raise ValueError(f"{where}.assert_screen.region is unsupported")
            if not isinstance(expectation.get("text"), str):
                raise ValueError(f"{where}.assert_screen.text must be a string")
            if expectation["region"] == "screen" and expectation.get("count") != 2:
                raise ValueError(f"{where}.assert_screen.count must be 2 for split windows")
            if expectation["region"] == "body" and "count" in expectation:
                raise ValueError(f"{where}.assert_screen.count is only valid for split windows")
        else:
            raise ValueError(f"{where} must declare exactly one supported action")


def _validate_files_r3_case(case):
    target = case.get("command")
    mutation = case.get("mutation_case")
    if target not in _R3_TARGETS or mutation not in _R3_VARIANTS:
        raise ValueError(f"{case.get('name')} has an unsupported files R3 route")
    if case.get("lane") != "W3-3" or case.get("path_id") != f"r3:{target}:{mutation}":
        raise ValueError(f"{case['name']} has a mismatched generated route ID or lane")
    if case.get("entry") != (
        "macro" if mutation == "macro-replay" else (_primary_entry(target) if target == "save-buffer" else "mx")
    ):
        raise ValueError(f"{case['name']} entry does not match the files command route")
    commands = case.get("commands")
    if not isinstance(commands, list) or any(not isinstance(item, str) or not item for item in commands):
        raise ValueError(f"{case['name']}.commands must contain command names")
    if target not in commands:
        raise ValueError(f"{case['name']} trace omits its target command")
    command_keys = case.get("command_keys")
    if not isinstance(command_keys, list) or not command_keys or any(
        not isinstance(key, str) or not key for key in command_keys
    ):
        raise ValueError(f"{case['name']}.command_keys must be a non-empty key sequence")

    expected_keys = {
        ("save-buffer", "effect"): ["C-x", "C-s"],
        ("save-buffer", "undo"): ["C-x", "C-s"],
        ("save-buffer", "read-only"): ["C-x", "C-s"],
        ("save-buffer", "narrow"): ["C-x", "C-s"],
        ("save-buffer", "split-window"): ["C-x", "C-s"],
        ("save-buffer", "macro-replay"): ["C-a", "X", "C-x", "C-s"],
        ("save-buffer", "prefix-u4"): ["C-u", "4", "C-x", "C-s"],
        ("revert-buffer", "effect"): ["M-x", "revert-buffer", "RET", "y", "RET"],
        ("revert-buffer", "undo"): ["M-x", "revert-buffer", "RET", "y", "RET"],
        ("revert-buffer", "read-only"): ["M-x", "revert-buffer", "RET"],
        ("revert-buffer", "narrow"): ["M-x", "revert-buffer", "RET", "y", "RET"],
        ("revert-buffer", "split-window"): ["M-x", "revert-buffer", "RET", "y", "RET"],
        ("revert-buffer", "macro-replay"): ["C-a", "M-x", "revert-buffer", "RET", "y", "RET"],
        ("revert-buffer", "prefix-u4"): ["C-u", "4", "M-x", "revert-buffer", "RET", "y", "RET"],
    }[(target, mutation)]
    if command_keys != expected_keys:
        raise ValueError(f"{case['name']} command_keys do not execute the declared route")

    effect_bytes = case.get("effect_bytes")
    initial_bytes = case.get("initial_bytes")
    if not isinstance(initial_bytes, str) or not isinstance(effect_bytes, str):
        raise ValueError(f"{case['name']} must declare exact initial and effect bytes")
    expected_source = "initial_bytes" if mutation in {"undo", "read-only"} else "effect_bytes"
    if case.get("expected_bytes") != case[expected_source]:
        raise ValueError(f"{case['name']} expected_bytes must match {expected_source}")
    if not isinstance(case.get("expected_minibuffer"), str):
        raise ValueError(f"{case['name']} must declare its exact minibuffer")
    cursor = case.get("expected_cursor")
    if not isinstance(cursor, list) or len(cursor) != 2 or any(
        type(value) is not int or value < 0 for value in cursor
    ):
        raise ValueError(f"{case['name']} must declare a non-negative cursor position")
    for field in ("expected_screen", "effect_screen"):
        values = case.get(field)
        if not isinstance(values, list) or not values:
            raise ValueError(f"{case['name']}.{field} must declare screen text")
        allowed_regions = {"screen"} if mutation == "split-window" else {"body"}
        if any(
            not isinstance(item, dict)
            or item.get("region") not in allowed_regions
            or not isinstance(item.get("text"), str)
            for item in values
        ):
            raise ValueError(f"{case['name']}.{field} has an unsupported exact screen expectation")

    if mutation == "undo" and (not isinstance(case.get("expected_undo_cursor"), list)
                                or len(case["expected_undo_cursor"]) != 2):
        raise ValueError(f"{case['name']} must declare its post-undo cursor")
    if mutation == "read-only" and case.get("read_only_command") != "toggle-read-only":
        raise ValueError(f"{case['name']} must execute toggle-read-only before its target")
    if mutation == "macro-replay":
        if not isinstance(case.get("restore_screen"), list) or not case["restore_screen"]:
            raise ValueError(f"{case['name']} must declare the exact restored screen")
        if not isinstance(case.get("replay_prefix_keys"), list) or not case["replay_prefix_keys"]:
            raise ValueError(f"{case['name']} must declare its macro replay cursor setup")
    _validate_setup_actions(case, "setup")
    _validate_setup_actions(case, "replay_setup")
    if mutation == "split-window" and case.get("expected_view_count") != 2:
        raise ValueError(f"{case['name']} must assert both split views")

    if target == "revert-buffer":
        if not isinstance(case.get("external_bytes"), str):
            raise ValueError(f"{case['name']} must declare the external file bytes")
        if mutation != "read-only" and not isinstance(case.get("revert_prompt"), str):
            raise ValueError(f"{case['name']} must declare its exact revert prompt")
        if case.get("effect_minibuffer") != "Reverted {file_path}":
            raise ValueError(f"{case['name']} must declare the exact revert result")


def _validate_files_local_r3_case(case):
    _validate_files_r3_case(case)
    if case.get("mutation_case") not in _R3_LOCAL_VARIANTS:
        raise ValueError(f"{case['name']} is not a slice-local R3 variant")
    if case["mutation_case"] == "split-window":
        if case["expected_screen"][0]["region"] != "screen":
            raise ValueError(f"{case['name']} must assert full-screen split views")
    elif any(item["region"] != "body" for item in case["expected_screen"]):
        raise ValueError(f"{case['name']} must assert exact body text")


def _expand(value, replacements):
    if isinstance(value, str):
        for marker, replacement in replacements.items():
            value = value.replace(marker, replacement)
        return value
    if isinstance(value, list):
        return [_expand(item, replacements) for item in value]
    if isinstance(value, dict):
        return {key: _expand(item, replacements) for key, item in value.items()}
    return value


def _invoke_prompt_target(session, case):
    if case["target_command"] == "revert-buffer":
        session.extended_command("revert-buffer")
    else:
        _send_keys(session, case["entry_keys"])
    _wait_exact(session, "minibuffer", case["prompt_text"])


def _seed_pathless_save_history(session, case):
    session.type(case["pre_command_text"])
    _send_keys(session, ["C-x", "C-w"])
    _wait_exact(session, "minibuffer", "Write file: ")
    session.type(case["target_path"])
    session.key("RET")
    _wait_exact(session, "minibuffer", f"Wrote {case['target_path']}")
    session.assert_file_bytes(case["target_path"], case["expected_bytes"].encode("utf-8"))

    _send_keys(session, ["C-x", "b"])
    _wait_exact(session, "minibuffer", "Switch to buffer: ")
    session.type("*scratch*")
    session.key("RET")
    _wait_exact(session, "body", case["expected_screen"][0]["text"])


def _save_pathless_buffer_for_assertion(session, case):
    _send_keys(session, ["C-x", "C-w"])
    _wait_exact(session, "minibuffer", "Write file: ")
    session.type(case["target_path"])
    session.key("RET")
    _wait_exact(session, "minibuffer", f"Wrote {case['target_path']}")


def _quit_after_discarding_buffer(session, prompt_text):
    _send_keys(session, ["C-x", "C-c"])
    _wait_exact(session, "minibuffer", prompt_text)
    session.type("d")
    session.key("RET")
    output, code = session.process.wait(timeout=DEFAULT_TIMEOUT)
    session.observe_exit_code(code, expected=0)
    return output, code


def _run_files_prompt_scenario(binary, case):
    with TemporaryDirectory(prefix="loom-e2e-files-command-path-") as directory:
        source_path = Path(directory) / "buffer.txt"
        target_path = Path(directory) / "written.txt"
        source_path.write_bytes(case["initial_bytes"].encode("utf-8"))
        replacements = {
            "{source_path}": str(source_path),
            "{source_prefix}": str(source_path)[:-4],
            "{target_path}": str(target_path),
            "{target_prefix}": str(target_path)[:-4],
        }
        runtime_case = _expand(case, replacements)
        runtime_case["target_path"] = str(target_path)
        target = runtime_case["target_command"]
        prompt_index = runtime_case["prompt_index"]
        path = source_path if runtime_case["expected_file"] == "source" else target_path
        arguments = [] if target == "save-buffer" and prompt_index == 1 else [str(source_path)]

        with Session(
            binary,
            arguments,
            rows=runtime_case.get("rows", 24),
            columns=runtime_case.get("columns", 120),
        ) as session, _deadline_stage(
            runtime_case["name"], "files prompt scenario", session=session
        ):
            session.wait_ready()
            if target == "save-buffer" and prompt_index == 1 and not (
                runtime_case["prompt_case"] == "history"
            ):
                session.type(runtime_case["pre_command_text"])
                _wait_exact(session, "body", runtime_case["expected_screen"][0]["text"])
            elif target == "revert-buffer" or (
                target == "save-buffer" and prompt_index == 2
            ):
                _send_key(session, "C-a")
                session.type("!")
                _wait_exact(session, "body", "!alpha beta")
                source_path.write_bytes(runtime_case["external_bytes"].encode("utf-8"))
                session.assert_file_bytes(source_path, runtime_case["external_bytes"].encode("utf-8"))

            if runtime_case["prompt_case"] == "history" and target == "save-buffer" and prompt_index == 1:
                _seed_pathless_save_history(session, runtime_case)
                _invoke_prompt_target(session, runtime_case)
                _send_key(session, "UP")
                _send_key(session, "UP")
                _wait_exact(session, "minibuffer", runtime_case["history_expected"])
                session.key("RET")
            elif runtime_case["prompt_case"] == "history" and runtime_case["prompt_kind"] == "yes-no":
                _invoke_prompt_target(session, runtime_case)
                session.type(runtime_case["history_seed_input"])
                session.key("RET")
                _wait_exact(session, "minibuffer", runtime_case["history_seed_result"])
                _invoke_prompt_target(session, runtime_case)
                if runtime_case["entry_mode"] == "mx":
                    _send_key(session, "UP")
                    _wait_exact(
                        session,
                        "minibuffer",
                        runtime_case["prompt_text"] + runtime_case["accepted_command"],
                    )
                _send_key(session, "UP")
                _wait_exact(session, "minibuffer", runtime_case["history_expected"])
                session.key("RET")
            else:
                _invoke_prompt_target(session, runtime_case)
                outcome = runtime_case["prompt_case"]
                if outcome == "history":
                    session.type(runtime_case["history_seed_input"])
                    session.key("RET")
                    _wait_exact(session, "minibuffer", runtime_case["history_seed_result"])
                    _invoke_prompt_target(session, runtime_case)
                    _send_key(session, "UP")
                    _wait_exact(session, "minibuffer", runtime_case["history_expected"])
                    session.key("RET")
                else:
                    if runtime_case["input_text"]:
                        session.type(runtime_case["input_text"])
                    if outcome == "tab":
                        _send_key(session, "TAB")
                        _wait_exact(session, "minibuffer", runtime_case["tab_expected"])
                    if outcome == "cancel":
                        _send_key(session, "C-g")
                    else:
                        session.key("RET")

            _wait_exact(
                session,
                "minibuffer",
                runtime_case["prompt_result_minibuffer"],
            )
            if runtime_case.get("reprompt_after_response"):
                _wait_exact(session, "minibuffer", runtime_case["reprompt_expected"])
                _send_key(session, "C-g")
                _wait_exact(session, "minibuffer", "Quit")

            if target == "save-buffer" and prompt_index == 1 and runtime_case.get(
                "verify_pathless_after_result"
            ):
                _save_pathless_buffer_for_assertion(session, runtime_case)
                path = target_path
                runtime_case["expected_minibuffer"] = f"Wrote {target_path}"

            _assert_final_state(session, runtime_case, path, runtime_case["expected_bytes"])
            if runtime_case.get("expected_target_exists") is False and target_path.exists():
                raise AssertionError(f"{runtime_case['name']} unexpectedly created {target_path}")
            if target == "save-buffer" and prompt_index == 1:
                output, code = _quit_after_discarding_buffer(
                    session, "Discard changes to *scratch*? (d/c): "
                )
            elif (target == "revert-buffer" and runtime_case["prompt_case"] != "accept") or (
                target == "save-buffer"
                and prompt_index == 2
                and runtime_case["prompt_case"] != "accept"
            ):
                output, code = _quit_after_discarding_buffer(
                    session, "Save buffer.txt? (s/d/c): "
                )
            else:
                output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"{runtime_case['name']} exited with {code}: {output!r}"
                )


def _assert_screen_expectation(session, expectation, *, name, view_count=None):
    region = expectation["region"]
    expected = expectation["text"]
    if region == "body":
        index = expectation.get("index", 0)
        session.wait_for_region_exact_text("body", expected, index=index, strip_right=True)
        if session.assert_screen_text(
            expected, region="body", index=index, strip_right=True
        ) is not True:
            raise AssertionError(f"{name} body row {index} did not match exactly")
        return

    if region != "screen" or view_count != 2:
        raise ValueError(f"{name} has an unsupported split-window screen assertion")

    def matching_rows(screen):
        return [
            index
            for index, line in enumerate(screen.lines())
            if line.rstrip() == expected
        ]

    session.wait_until(
        lambda screen: len(matching_rows(screen)) == view_count,
        what=f"{name} to show the exact text in both split views",
    )
    rows = matching_rows(session.screen)
    if len(rows) != view_count:
        raise AssertionError(
            f"{name} showed {len(rows)} exact split-view rows; expected {view_count}"
        )
    for row in rows:
        if session.assert_screen_text(
            expected, match="exact", row=row, strip_right=True
        ) is not True:
            raise AssertionError(f"{name} screen row {row} did not match exactly")


def _assert_files_r3_state(
    session,
    case,
    path,
    *,
    expected_bytes,
    screen_field="expected_screen",
    cursor=None,
    minibuffer=None,
):
    if minibuffer is not None:
        with _deadline_stage(case["name"], "exact minibuffer", session=session):
            _wait_exact(session, "minibuffer", minibuffer)
            if session.assert_screen_text(
                minibuffer.rstrip(), region="minibuffer", strip_right=True
            ) is not True:
                raise AssertionError(f"{case['name']} minibuffer did not match exactly")
    view_count = case.get("expected_view_count")
    with _deadline_stage(case["name"], "exact screen", session=session):
        for expectation in case[screen_field]:
            _assert_screen_expectation(
                session, expectation, name=case["name"], view_count=view_count
            )
    expected_cursor = case["expected_cursor"] if cursor is None else cursor
    cursor_region = case.get("expected_cursor_region", "body")
    with _deadline_stage(case["name"], "cursor position", session=session):
        session.wait_for_region_cursor(
            cursor_region, expected_cursor[1], index=expected_cursor[0]
        )
        if session.observe_cursor(
            expected=tuple(expected_cursor), region=cursor_region
        ) is not True:
            raise AssertionError(
                f"{case['name']} cursor did not match {cursor_region} {expected_cursor!r}"
            )
    expected_file = expected_bytes.encode("utf-8")
    with _deadline_stage(case["name"], "file bytes", session=session):
        session.wait_for_file(path, expected_file)
        session.assert_file_bytes(path, expected_file)


def _assert_initial_files_r3_state(session, case, path):
    initial = case["initial_bytes"]
    session.assert_file_bytes(path, initial.encode("utf-8"))
    for index, line in enumerate(initial.splitlines()):
        session.wait_for_region_exact_text("body", line, index=index, strip_right=True)
        if session.assert_screen_text(
            line, region="body", index=index, strip_right=True
        ) is not True:
            raise AssertionError(f"{case['name']} initial body row {index} did not match")
    session.wait_for_region_cursor("body", 0, index=0)
    if session.observe_cursor(expected=(0, 0), region="body") is not True:
        raise AssertionError(f"{case['name']} did not start at the declared buffer origin")


def _run_files_setup(session, case, field="setup"):
    if field == "setup" and case.get("pre_command_keys"):
        _send_keys(session, case["pre_command_keys"])
    for action in case.get(field, []):
        if "keys" in action:
            _send_keys(session, action["keys"])
        elif "command" in action:
            session.extended_command(action["command"])
        else:
            expectation = action["assert_screen"]
            _assert_screen_expectation(
                session,
                expectation,
                name=case["name"],
                view_count=expectation.get("count"),
            )


def _send_declared_revert_command(session, case):
    sequence = case["command_keys"]
    try:
        marker = sequence.index("M-x")
    except ValueError as error:
        raise ValueError(f"{case['name']} does not declare M-x revert-buffer") from error
    if sequence[marker : marker + 3] != ["M-x", "revert-buffer", "RET"]:
        raise ValueError(f"{case['name']} has an invalid revert-buffer command trace")
    if marker:
        _send_keys(session, sequence[:marker])
    session.extended_command("revert-buffer")
    response_keys = sequence[marker + 3 :]
    if response_keys:
        _wait_exact(session, "minibuffer", case["revert_prompt"])
        _send_keys(session, response_keys)
    else:
        _wait_exact(session, "minibuffer", case["effect_minibuffer"])


def _run_files_save_mutation(session, case, path):
    _run_files_setup(session, case)
    if case.get("read_only_command"):
        session.extended_command(case["read_only_command"])
        _wait_exact(session, "minibuffer", "Buffer is read-only")

    mutation = case["mutation_case"]
    if mutation == "macro-replay":
        _assert_initial_files_r3_state(session, case, path)
        _send_keys(session, ["C-x", "("])
        _send_keys(session, case["command_keys"])
        _assert_files_r3_state(
            session,
            case,
            path,
            expected_bytes=case["effect_bytes"],
            screen_field="effect_screen",
            minibuffer=case["effect_minibuffer"],
        )
        _send_keys(session, ["C-x", ")"])
        _assert_files_r3_state(
            session,
            case,
            path,
            expected_bytes=case["effect_bytes"],
            minibuffer=case["expected_minibuffer"],
        )
        _send_keys(session, ["C-x", "u"])
        _assert_files_r3_state(
            session,
            case,
            path,
            expected_bytes=case["effect_bytes"],
            screen_field="restore_screen",
            cursor=case["restore_cursor"],
        )
        _send_keys(session, ["C-x", "C-s"])
        _assert_files_r3_state(
            session,
            case,
            path,
            expected_bytes=case["initial_bytes"],
            screen_field="restore_screen",
            cursor=case["restore_cursor"],
            minibuffer=case["replay_minibuffer"],
        )
        _send_keys(session, case["replay_prefix_keys"])
        _send_keys(session, ["C-x", "e"])
        _assert_files_r3_state(
            session,
            case,
            path,
            expected_bytes=case["expected_bytes"],
            minibuffer=case["replay_minibuffer"],
        )
        return

    _send_keys(session, case["command_keys"])
    effect_minibuffer = case.get("effect_minibuffer", case["expected_minibuffer"])
    _assert_files_r3_state(
        session,
        case,
        path,
        expected_bytes=case["effect_bytes"],
        screen_field="effect_screen",
        minibuffer=effect_minibuffer,
    )
    if mutation == "undo":
        _send_keys(session, ["C-x", "u"])
        _assert_files_r3_state(
            session,
            case,
            path,
            expected_bytes=case["effect_bytes"],
            cursor=case["expected_undo_cursor"],
        )
        _send_keys(session, ["C-x", "C-s"])
        _assert_files_r3_state(
            session,
            case,
            path,
            expected_bytes=case["expected_bytes"],
            cursor=case["expected_undo_cursor"],
            minibuffer=case["expected_minibuffer"],
        )


def _run_files_revert_mutation(session, case, path):
    _assert_initial_files_r3_state(session, case, path)
    external = case["external_bytes"].encode("utf-8")
    path.write_bytes(external)
    session.assert_file_bytes(path, external)
    _run_files_setup(session, case)
    if case.get("read_only_command"):
        session.extended_command(case["read_only_command"])
        _wait_exact(session, "minibuffer", "Buffer is read-only")

    mutation = case["mutation_case"]
    if mutation == "macro-replay":
        _send_keys(session, ["C-x", "("])
        _send_declared_revert_command(session, case)
        _assert_files_r3_state(
            session,
            case,
            path,
            expected_bytes=case["effect_bytes"],
            screen_field="effect_screen",
            minibuffer=case["effect_minibuffer"],
        )
        _send_keys(session, ["C-x", ")"])
        _assert_files_r3_state(
            session,
            case,
            path,
            expected_bytes=case["effect_bytes"],
            minibuffer=case["expected_minibuffer"],
        )
        _run_files_setup(session, case, "replay_setup")
        _send_keys(session, case["replay_prefix_keys"])
        _send_keys(session, ["C-x", "e"])
        _assert_files_r3_state(
            session,
            case,
            path,
            expected_bytes=case["expected_bytes"],
            minibuffer=case["replay_minibuffer"],
        )
        return

    _send_declared_revert_command(session, case)
    effect_minibuffer = case.get("effect_minibuffer", case["expected_minibuffer"])
    _assert_files_r3_state(
        session,
        case,
        path,
        expected_bytes=case["effect_bytes"],
        screen_field="effect_screen",
        minibuffer=effect_minibuffer,
    )
    if mutation == "undo":
        _send_keys(session, case["undo_keys"])
        _assert_files_r3_state(
            session,
            case,
            path,
            expected_bytes=case["external_bytes"],
            cursor=case["expected_undo_cursor"],
        )
        _send_keys(session, case["restore_command_keys"])
        _assert_files_r3_state(
            session,
            case,
            path,
            expected_bytes=case["expected_bytes"],
            minibuffer=case["expected_minibuffer"],
        )
    elif mutation == "read-only":
        session.type(case["read_only_probe"])
        _assert_files_r3_state(
            session,
            case,
            path,
            expected_bytes=case["expected_bytes"],
            minibuffer=case["expected_minibuffer"],
        )


def _run_files_mutation_scenario(binary, case):
    with TemporaryDirectory(prefix="loom-e2e-files-command-path-") as directory:
        path = Path(directory) / "buffer.txt"
        path.write_bytes(case["initial_bytes"].encode("utf-8"))
        runtime_case = _expand(
            case, {"{file_path}": str(path.resolve(strict=False))}
        )
        with Session(
            binary,
            [str(path)],
            rows=runtime_case.get("rows", 24),
            columns=runtime_case.get("columns", 120),
        ) as session, _deadline_stage(
            runtime_case["name"], "R3 mutation flow", session=session
        ):
            with _deadline_stage(
                runtime_case["name"], "session ready", session=session
            ):
                session.wait_ready()
            if runtime_case["command"] == "save-buffer":
                with _deadline_stage(
                    runtime_case["name"], "save-buffer operations", session=session
                ):
                    _run_files_save_mutation(session, runtime_case, path)
            else:
                with _deadline_stage(
                    runtime_case["name"], "revert-buffer operations", session=session
                ):
                    _run_files_revert_mutation(session, runtime_case, path)
            with _deadline_stage(
                runtime_case["name"], "session quit", session=session
            ):
                output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"{runtime_case['name']} exited with {code}: {output!r}"
                )


def _scenario_function(case):
    def run(binary):
        if case["rule"] == "r2":
            return _run_files_prompt_scenario(binary, case)
        if case["rule"] == "r3":
            return _run_files_mutation_scenario(binary, case)

        def session_factory(binary, arguments, columns=80, rows=24):
            return Session(binary, arguments, columns=columns, rows=rows)

        return run_command_path_scenario(
            binary, case, session_factory=session_factory
        )

    return run


_CASES = _load_files_cases(Path(__file__).with_name("command-paths.json"))

for _case in _CASES:
    if _case["rule"] == "r2":
        _validate_files_prompt_case(_case)
    scenario(_case["name"], commands=_case["commands"])(_scenario_function(_case))


_SAVE_SHELL_SOURCE = b"alpha\n"
_SAVE_SHELL_FORMATTED = b"ALPHA\n"


def _save_buffer_shell_fixture(directory, outcome):
    marker_path = os.path.join(directory, "formatter-started")
    status_path = os.path.join(directory, "formatter-status")
    marker = shlex.quote(marker_path)
    status = shlex.quote(status_path)
    if outcome == "success":
        body = (
            f"printf started > {marker}\n"
            "tr '[:lower:]' '[:upper:]'\n"
            "status=$?\n"
            f"printf '%s' \"$status\" > {status}\n"
            "exit \"$status\"\n"
        )
    elif outcome == "missing":
        body = (
            f"printf started > {marker}\n"
            "loom-w3-3-save-buffer-missing-tool\n"
            "status=$?\n"
            f"printf '%s' \"$status\" > {status}\n"
            "exit \"$status\"\n"
        )
    elif outcome == "nonzero":
        body = (
            f"printf started > {marker}\n"
            "cat >/dev/null\n"
            "printf 'PARTIAL\\n'\n"
            "status=23\n"
            f"printf '%s' \"$status\" > {status}\n"
            "exit \"$status\"\n"
        )
    elif outcome == "interrupted":
        body = (
            f"printf started > {marker}\n"
            "cat >/dev/null\n"
            "/bin/sh -c 'kill -TERM $$'\n"
            "status=$?\n"
            f"printf '%s' \"$status\" > {status}\n"
            "exit \"$status\"\n"
        )
    else:
        raise ValueError(f"unsupported save-buffer shell outcome: {outcome}")

    command_path = os.path.join(directory, "formatter")
    with open(command_path, "w", encoding="utf-8") as handle:
        handle.write("#!/bin/sh\n" + body)
    os.chmod(command_path, 0o755)
    return command_path, marker_path, status_path


def _set_save_buffer_shell_command(session, command):
    session.extended_command("set-format-command")
    session.wait_for_text("Format-on-save command: ")
    session.type(command)
    session.key("RET")
    session.wait_for_text("Format-on-save command set")
    session.extended_command("format-on-save-mode")
    session.pump()


def _run_save_buffer_shell_outcome(binary, outcome, expected_status, expected_bytes):
    with TemporaryDirectory(prefix="loom-files-save-shell-") as directory:
        path = os.path.join(directory, "buffer.txt")
        with open(path, "wb") as handle:
            handle.write(_SAVE_SHELL_SOURCE)
        command_path, marker_path, status_path = _save_buffer_shell_fixture(
            directory, outcome
        )

        with Session(binary, [path]) as session:
            session.wait_ready()
            _set_save_buffer_shell_command(session, shlex.quote(command_path))
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_text(f"Wrote {path}")
            session.assert_external_state(
                f"save-buffer shell {outcome} started", Path(marker_path).read_text(), "started"
            )
            session.assert_external_state(
                f"save-buffer shell {outcome} exit status",
                Path(status_path).read_text(),
                str(expected_status),
            )
            session.assert_file_bytes(path, expected_bytes)
            output, code = session.quit()
        if code != 0:
            raise AssertionError(
                f"save-buffer shell {outcome} exited with {code}: {output!r}"
            )


@scenario(
    "files/save-buffer-shell-success",
    commands=["save-buffer", "set-format-command", "format-on-save-mode"],
)
def save_buffer_shell_success(binary):
    _run_save_buffer_shell_outcome(
        binary, "success", 0, _SAVE_SHELL_FORMATTED
    )


@scenario(
    "files/save-buffer-shell-missing",
    commands=["save-buffer", "set-format-command", "format-on-save-mode"],
)
def save_buffer_shell_missing(binary):
    _run_save_buffer_shell_outcome(binary, "missing", 127, _SAVE_SHELL_SOURCE)


@scenario(
    "files/save-buffer-shell-nonzero",
    commands=["save-buffer", "set-format-command", "format-on-save-mode"],
)
def save_buffer_shell_nonzero(binary):
    _run_save_buffer_shell_outcome(binary, "nonzero", 23, _SAVE_SHELL_SOURCE)


@scenario(
    "files/save-buffer-shell-interrupted",
    commands=["save-buffer", "set-format-command", "format-on-save-mode"],
)
def save_buffer_shell_interrupted(binary):
    _run_save_buffer_shell_outcome(binary, "interrupted", 143, _SAVE_SHELL_SOURCE)
