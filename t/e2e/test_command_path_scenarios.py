import json
import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from loom_e2e import registry
from loom_e2e.deadline import ScenarioDeadlineExceeded
from loom_e2e.command_path_scenarios import (
    CommandPathScenarioError,
    _assert_final_state,
    _deadline_stage,
    _key_bytes,
    _r2_prompt_display,
    _run_r3,
    _resolve_path_tokens,
    load_command_path_scenarios,
    run_command_path_scenario,
)
from loom_e2e.path_generation import generate_required_paths
from loom_e2e.scenario_discovery import load_slice_scenarios


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
SCENARIO_DATA = (
    REPOSITORY_ROOT
    / "packages/core/command/t/e2e/scenarios/command-paths.json"
)
BUFFER_SCENARIO_DATA = (
    REPOSITORY_ROOT
    / "packages/core/buffer/t/e2e/scenarios/command-paths.json"
)
FILE_TREE_SCENARIO_DATA = (
    REPOSITORY_ROOT
    / "packages/feature/file-tree/t/e2e/scenarios/command-paths.json"
)
REGISTER_SCENARIO_DATA = (
    REPOSITORY_ROOT
    / "packages/feature/register/t/e2e/scenarios/command-paths.json"
)
KEYBOARD_MACRO_SCENARIO_DATA = (
    REPOSITORY_ROOT
    / "packages/feature/keyboard-macro/t/e2e/scenarios/command-paths.json"
)
BOOKMARK_SCENARIO_DATA = (
    REPOSITORY_ROOT
    / "packages/feature/bookmark/t/e2e/scenarios/command-paths.json"
)
SESSION_SCENARIO_DATA = (
    REPOSITORY_ROOT
    / "packages/feature/session/t/e2e/scenarios/command-paths.json"
)
_DEFAULT_NAME = object()


def _key(key_name, modifiers=()):
    return {
        "keymap": "global",
        "sequence": [{"key": key_name, "modifiers": list(modifiers)}],
    }


def _catalog_row(
    command_id, owner, *, name=_DEFAULT_NAME, keys=(), prompts=(), mx=True, mutates=False
):
    return {
        "id": command_id,
        "name": command_id if name is _DEFAULT_NAME else name,
        "owner": owner,
        "keymap": "global",
        "keys": list(keys),
        "group": "test",
        "mutates": mutates,
        "prompts": list(prompts),
        "needs-region": False,
        "external": [],
        "modes": ["all"],
        "mx-eligible": mx,
    }


_CORE_COMMAND_CATALOG = [
    _catalog_row(
        "comment-line",
        "feature/mode",
        keys=[_key(";", ("alt",))],
        mutates=True,
    ),
    _catalog_row(
        "indent-for-tab-command",
        "feature/mode",
        keys=[_key("tab")],
        mutates=True,
    ),
    _catalog_row("keyboard-quit", "core/command", keys=[_key("g", ("control",))]),
    _catalog_row(
        "universal-argument", "core/command", keys=[_key("u", ("control",))]
    ),
    _catalog_row(
        "execute-extended-command",
        "core/command",
        name=None,
        keys=[_key("x", ("alt",))],
        prompts=["completion"],
        mx=False,
    ),
    _catalog_row(
        "recenter-top-bottom",
        "core/buffer",
        keys=[_key("l", ("control",))],
    ),
    _catalog_row(
        "transpose-chars",
        "core/buffer",
        keys=[_key("t", ("control",))],
        mutates=True,
    ),
    _catalog_row(
        "upcase-word", "core/buffer", keys=[_key("u", ("alt",))], mutates=True
    ),
    _catalog_row(
        "downcase-word", "core/buffer", keys=[_key("l", ("alt",))], mutates=True
    ),
    _catalog_row(
        "capitalize-word", "core/buffer", keys=[_key("c", ("alt",))], mutates=True
    ),
    _catalog_row(
        "delete-char",
        "core/buffer",
        keys=[_key("d", ("control",)), _key("delete")],
        mutates=True,
    ),
    _catalog_row(
        "format-current-buffer",
        "feature/format",
        prompts=["free-string"],
        mutates=True,
    ),
]
_CORE_COMMAND_CATALOG.extend(
    _catalog_row(
        command_id,
        "core/buffer",
        keys=[_key("z", ("control",))],
        mx=False,
    )
    for command_id in {
        "forward-char",
        "goto-line",
        "load-session",
        "new-workspace",
        "save-buffer",
        "save-buffers-kill-terminal",
        "save-session",
        "split-window-below",
        "switch-workspace",
        "undo",
    }
)


class FakeScreen:
    cursor = (0, 0)

    def dump(self):
        return "fake screen"


class FakeSession:
    def __init__(self, *_args, **_kwargs):
        self.calls = []
        self.screen = FakeScreen()

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def wait_ready(self):
        self.calls.append(("wait_ready",))

    def wait_for_region_text(self, region, text, **kwargs):
        self.calls.append(("wait_text", region, text, kwargs))

    def wait_for_region_exact_text(self, region, text, **kwargs):
        self.calls.append(("wait_exact_text", region, text, kwargs))

    def wait_for_file(self, path, expected):
        self.calls.append(("wait_file", expected))

    def wait_for_region_cursor(self, region, col, index=0):
        self.calls.append(("wait_region_cursor", region, col, index))

    def quit(self):
        self.calls.append(("quit",))
        return b"", 0

    def send(self, data):
        self.calls.append(("send", data))

    def type(self, text):
        self.calls.append(("type", text))

    def key(self, *names):
        self.calls.append(("key", *names))

    def assert_screen_text(self, expected, match="exact", **kwargs):
        self.calls.append(("assert_screen", expected, match, kwargs))
        return True

    def observe_cursor(self, expected, **kwargs):
        self.calls.append(("observe_cursor", expected, kwargs))
        return True

    def assert_file_bytes(self, path, expected):
        self.calls.append(("assert_file_bytes", expected))
        return expected

    def assert_external_state(self, name, actual, expected, *, purpose="scenario"):
        self.calls.append(("assert_external_state", name, actual, expected, purpose))
        if actual != expected:
            raise AssertionError(f"{name} was {actual}, expected {expected}")
        return actual

    def observe_file_bytes(self, path, expected, *, purpose="scenario"):
        self.calls.append(("observe_file_bytes", expected, purpose))
        return expected

    def test_space_key_tokens_send_one_space(self):
        self.assertEqual(_key_bytes("SPC"), b" ")
        self.assertEqual(_key_bytes("SPACE"), b" ")

class CommandPathScenarioTests(unittest.TestCase):
    def test_r2_prompt_display_matches_right_trimmed_screen(self):
        case = {"entry_mode": "key", "prompt_open": "Register name: "}

        self.assertEqual(_r2_prompt_display(case, ""), "Register name:")
        self.assertEqual(_r2_prompt_display(case, "a"), "Register name: a")

    def test_r2_command_prompts_send_pre_keys_before_opening_the_prompt(self):
        case = {
            "name": "test/r2-pre-keys",
            "path_id": "r2:isearch-backward:prompt-1:free-string:accept",
            "lane": "W3-6",
            "rule": "r2",
            "entry": "key:C-r;prompt:1:free-string",
            "commands": ["isearch-backward"],
            "command": "isearch-backward",
            "entry_mode": "key",
            "entry_keys": ["C-r"],
            "prompt_labels": ["I-search backward: "],
            "prompt_index": 1,
            "prompt_label": "I-search backward: ",
            "prompt_kind": "free-string",
            "prompt_case": "accept",
            "input_text": "needle",
            "pre_keys": [{"key": "C-e"}],
            "initial_bytes": "needle needle\n",
            "expected_bytes": "needle needle\n",
            "expected_cursor": [0, 7],
            "expected_minibuffer": "",
            "expected_screen": [{"region": "body", "text": "needle needle"}],
        }
        sessions = []

        def session_factory(*args, **kwargs):
            session = FakeSession(*args, **kwargs)
            sessions.append(session)
            return session

        run_command_path_scenario("unused", case, session_factory=session_factory)

        calls = sessions[0].calls
        pre_key = calls.index(("send", b"\x05"))
        entry_key = calls.index(("send", b"\x12"))
        self.assertLess(pre_key, entry_key)

    def test_c_space_encodes_as_control_at(self):
        self.assertEqual(_key_bytes("C-space"), b"\x00")

    def test_deadline_error_identifies_the_command_path_stage(self):
        with self.assertRaisesRegex(
            ScenarioDeadlineExceeded, r"test/undo \[undo and restore\]: expired"
        ):
            with _deadline_stage("test/undo", "undo and restore"):
                raise ScenarioDeadlineExceeded("expired")

    def test_filesystem_expectation_precedes_final_screen_wait(self):
        case = {
            "name": "test/filesystem-before-screen",
            "expected_minibuffer": "",
            "expected_screen": [
                {
                    "region": "screen",
                    "text": "created-file.txt",
                    "match": "contains",
                }
            ],
            "expected_cursor": [0, 0],
            "expected_filesystem": [
                {"path": "created-file.txt", "kind": "file"}
            ],
        }

        class DeadlineAtScreen(FakeSession):
            def wait_for_region_text(self, region, text, **kwargs):
                super().wait_for_region_text(region, text, **kwargs)
                if region == "screen" and text == "created-file.txt":
                    raise ScenarioDeadlineExceeded("screen expired")

        with tempfile.TemporaryDirectory() as directory:
            buffer_path = Path(directory) / "buffer.txt"
            buffer_path.write_bytes(b"")
            (Path(directory) / "created-file.txt").write_bytes(b"")
            session = DeadlineAtScreen()

            with self.assertRaisesRegex(
                ScenarioDeadlineExceeded,
                r"test/filesystem-before-screen \[final state screen screen 'created-file.txt'\]: screen expired",
            ):
                _assert_final_state(
                    session,
                    case,
                    buffer_path,
                    "",
                    stage_prefix="final state",
                )

        filesystem_checks = [
            index
            for index, call in enumerate(session.calls)
            if call[0] == "assert_external_state"
            and call[1] == "filesystem/created-file.txt"
        ]
        screen_waits = [
            index
            for index, call in enumerate(session.calls)
            if call[0] == "wait_text"
            and call[1] == "screen"
            and call[2] == "created-file.txt"
        ]
        self.assertEqual(len(filesystem_checks), 1)
        self.assertEqual(len(screen_waits), 1)
        self.assertLess(filesystem_checks[0], screen_waits[0])

    def test_filesystem_mismatch_includes_the_current_screen(self):
        case = {
            "name": "test/filesystem-mismatch-screen",
            "expected_minibuffer": "",
            "expected_screen": [{"region": "body", "text": "buffer"}],
            "expected_cursor": [0, 0],
            "expected_filesystem": [{"path": "missing.txt", "kind": "file"}],
        }

        with tempfile.TemporaryDirectory() as directory:
            buffer_path = Path(directory) / "buffer.txt"
            buffer_path.write_bytes(b"")
            with self.assertRaisesRegex(AssertionError, "--- screen ---\\nfake screen"):
                _assert_final_state(FakeSession(), case, buffer_path, "")

    def test_r2_deadline_error_identifies_the_active_prompt_wait(self):
        case = next(
            case
            for case in load_command_path_scenarios(FILE_TREE_SCENARIO_DATA)
            if case["name"]
            == "command-path/r2/file-tree-create-file/free-string/accept"
        )

        class DeadlineAtPromptOpen(FakeSession):
            def wait_for_region_text(self, region, text, **kwargs):
                super().wait_for_region_text(region, text, **kwargs)
                if region == "minibuffer" and text == case["prompt_open"]:
                    raise ScenarioDeadlineExceeded("expired")

        def session_factory(*args, **kwargs):
            return DeadlineAtPromptOpen(*args, **kwargs)

        with self.assertRaises(ScenarioDeadlineExceeded) as raised:
            run_command_path_scenario(
                "unused", case, session_factory=session_factory
            )

        self.assertIn("[target prompt open]: expired", str(raised.exception))
        self.assertIn("--- screen ---\nfake screen", str(raised.exception))

    def test_r1_deadline_error_identifies_the_final_state_wait(self):
        case = next(
            case
            for case in load_command_path_scenarios(BOOKMARK_SCENARIO_DATA)
            if case["name"] == "command-path/r1/set-bookmark/key"
        )

        class DeadlineAtPrompt(FakeSession):
            def wait_for_region_exact_text(self, region, text, **kwargs):
                super().wait_for_region_exact_text(region, text, **kwargs)
                if (
                    region == "minibuffer"
                    and text == case["expected_minibuffer"].rstrip()
                ):
                    raise ScenarioDeadlineExceeded("expired")

        with self.assertRaises(ScenarioDeadlineExceeded) as raised:
            run_command_path_scenario(
                "unused", case, session_factory=lambda *_args, **_kwargs: DeadlineAtPrompt()
            )

        self.assertIn("[final state minibuffer]: expired", str(raised.exception))
        self.assertIn("--- screen ---\nfake screen", str(raised.exception))

    def test_r2_history_waits_for_the_selected_command_before_accepting(self):
        case = next(
            case
            for case in load_command_path_scenarios(SCENARIO_DATA)
            if case["name"] == "command-path/r2/history"
        )
        session = FakeSession()

        run_command_path_scenario(
            "unused", case, session_factory=lambda *_args, **_kwargs: session
        )

        history_wait = (
            "wait_exact_text",
            "minibuffer",
            case["history_expected"],
            {"strip_right": True},
        )
        up_index = session.calls.index(("key", "UP"))
        history_wait_index = session.calls.index(history_wait)
        accept_index = next(
            index
            for index, call in enumerate(session.calls)
            if index > up_index and call == ("key", "RET")
        )
        self.assertLess(up_index, history_wait_index)
        self.assertLess(history_wait_index, accept_index)

    def test_load_session_fixtures_encode_restored_text_with_a_newline(self):
        cases = load_command_path_scenarios(SESSION_SCENARIO_DATA)
        target_names = {
            "command-path/r2/load-session/free-string/accept",
            "command-path/r2/load-session/free-string/tab",
        }
        fixtures = [
            case["session_fixture"]["contents"]
            for case in cases
            if case["name"] in target_names
        ]

        self.assertEqual(len(fixtures), len(target_names))
        for contents in fixtures:
            self.assertIn("RESTORED\n", contents)
            self.assertNotIn(r"RESTORED\n", contents)

    def test_lifecycle_prompt_paths_load_from_the_custom_runner(self):
        expected_scenarios = {
            **{
                f"lifecycle/save-buffer-prompt-{prompt}": [
                    "save-buffers-kill-terminal"
                ]
                for prompt in ("accept", "cancel", "empty", "tab", "history")
            },
            **{
                f"lifecycle/abort-prompt-{prompt}": [
                    "execute-extended-command",
                    "kill-loom-abort",
                ]
                for prompt in ("accept", "cancel", "empty", "tab", "history")
            },
        }
        load_slice_scenarios(REPOSITORY_ROOT)
        registered = {
            name: commands for name, commands, _function in registry.all_scenarios()
        }

        self.assertEqual(
            {name: registered.get(name) for name in expected_scenarios},
            expected_scenarios,
        )

    def test_r3_read_only_setup_and_command_statuses_are_separate(self):
        case = next(
            case
            for case in load_command_path_scenarios(REGISTER_SCENARIO_DATA)
            if case["name"] == "command-path/r3/insert-register/read-only"
        )
        case["expected_read_only_status"] = "Buffer is read-only"
        session = FakeSession()

        run_command_path_scenario(
            "unused", case, session_factory=lambda *_args, **_kwargs: session
        )

        setup_wait = (
            "wait_exact_text",
            "minibuffer",
            case["expected_read_only_status"],
            {"strip_right": True},
        )
        final_wait = (
            "wait_exact_text",
            "minibuffer",
            case["expected_minibuffer"],
            {"strip_right": True},
        )
        self.assertIn(setup_wait, session.calls)
        self.assertIn(final_wait, session.calls)

    def test_r3_prefix_u4_waits_for_mx_prompt_before_sending_command(self):
        case = {
            "name": "test/r3-newline-prefix-u4",
            "entry": "mx",
            "command": "newline",
            "mutation_case": "prefix-u4",
            "prefix_keys": ["C-u", "4"],
            "command_keys": ["M-x", "newline", "RET"],
            "initial_bytes": "abc\n",
            "effect_bytes": "a\n\n\n\nbc\n",
            "expected_bytes": "a\n\n\n\nbc\n",
        }
        session = FakeSession()

        with (
            patch("loom_e2e.command_path_scenarios._assert_effect_state"),
            patch("loom_e2e.command_path_scenarios._save_and_assert"),
        ):
            _run_r3(session, case, Path("buffer.txt"))

        calls = session.calls
        prefix_argument = calls.index(("send", _key_bytes("C-u")))
        mx_entry = calls.index(("send", b"\x1bx"))
        prompt_open = calls.index(
            ("wait_text", "minibuffer", "M-x ", {})
        )
        command_input = calls.index(("type", "newline"))
        command_accept = calls.index(("key", "RET"), command_input)
        self.assertLess(prefix_argument, mx_entry)
        self.assertLess(mx_entry, prompt_open)
        self.assertLess(prompt_open, command_input)
        self.assertLess(command_input, command_accept)

    def test_r3_prefix_u4_keeps_inline_mx_key_sequence(self):
        case = {
            "name": "test/r3-clipboard-yank-prefix-u4",
            "entry": "mx",
            "command": "clipboard-yank",
            "mutation_case": "prefix-u4",
            "command_keys": ["C-u", "M-x", "clipboard-yank", "RET"],
            "initial_bytes": "tail",
            "effect_bytes": "tailtailtailtailtail",
            "expected_bytes": "tailtailtailtailtail",
        }
        session = FakeSession()

        with (
            patch("loom_e2e.command_path_scenarios._send_keys") as send_keys,
            patch("loom_e2e.command_path_scenarios._send_mx") as send_mx,
            patch("loom_e2e.command_path_scenarios._assert_effect_state"),
            patch("loom_e2e.command_path_scenarios._save_and_assert"),
        ):
            _run_r3(session, case, Path("buffer.txt"))

        send_keys.assert_any_call(session, case["command_keys"])
        send_mx.assert_not_called()

    def test_r2_fixture_wait_precedes_followup_keys(self):
        case = next(
            case
            for case in load_command_path_scenarios(FILE_TREE_SCENARIO_DATA)
            if case["name"]
            == "command-path/r2/file-tree-rename/free-string/cancel"
        )
        session = FakeSession()

        run_command_path_scenario(
            "unused", case, session_factory=lambda *_args, **_kwargs: session
        )

        wait_index = session.calls.index(
            ("wait_text", "screen", "rename-source.txt", {"index": 1})
        )
        first_selection_key = session.calls.index(("send", b"\x03"))
        self.assertLess(wait_index, first_selection_key)
        prompt_result = session.calls.index(
            ("wait_exact_text", "minibuffer", "Quit", {"strip_right": True})
        )
        filesystem_check = session.calls.index(
            (
                "assert_external_state",
                "filesystem/rename-source.txt",
                "file",
                "file",
                "scenario",
            )
        )
        self.assertLess(prompt_result, filesystem_check)

    def test_sidecar_covers_current_w31_catalog_paths_without_relabeling_owners(self):
        generated = generate_required_paths(_CORE_COMMAND_CATALOG)
        w31_ids = {
            path["id"] for path in generated if path["lane"] == "W3-1"
        }
        scenarios = load_command_path_scenarios(SCENARIO_DATA)
        by_path_id = {case["path_id"]: case for case in scenarios}

        self.assertEqual(len(w31_ids), 11)
        self.assertTrue(w31_ids <= by_path_id.keys())
        self.assertEqual(
            {
                by_path_id[path_id]["lane"]
                for path_id in w31_ids
            },
            {"W3-1"},
        )
        generated_by_id = {path["id"]: path for path in generated}
        self.assertTrue(by_path_id.keys() <= generated_by_id.keys())
        for path_id, case in by_path_id.items():
            with self.subTest(path_id=path_id):
                self.assertEqual(case["lane"], generated_by_id[path_id]["lane"])
                self.assertEqual(case["entry"], generated_by_id[path_id]["entry"])

    def test_sidecar_declares_all_w37a_r3_mutation_paths(self):
        generated = generate_required_paths(_CORE_COMMAND_CATALOG)
        generated_by_id = {path["id"]: path for path in generated}
        scenarios = load_command_path_scenarios(SCENARIO_DATA)
        cases_by_path_id = {case["path_id"]: case for case in scenarios}
        mutation_cases = {
            "effect",
            "undo",
            "read-only",
            "narrow",
            "split-window",
            "macro-replay",
            "prefix-u4",
        }
        expected_path_ids = {
            f"r3:{command}:{mutation_case}"
            for command in ("comment-line", "indent-for-tab-command")
            for mutation_case in mutation_cases
        }
        actual_path_ids = {
            path_id
            for path_id, case in cases_by_path_id.items()
            if case["lane"] == "W3-7a" and case["rule"] == "r3"
        }

        self.assertEqual(len(actual_path_ids), 14)
        self.assertEqual(actual_path_ids, expected_path_ids)
        for path_id in expected_path_ids:
            with self.subTest(path_id=path_id):
                case = cases_by_path_id[path_id]
                self.assertEqual(case["lane"], "W3-7a")
                self.assertEqual(case["entry"], generated_by_id[path_id]["entry"])
                self.assertEqual(case["mutation_case"], path_id.rsplit(":", 1)[1])
                command = path_id.split(":", 2)[1]
                self.assertEqual(case["command"], command)
                self.assertIn(command, case["commands"])

        self.assertEqual(
            cases_by_path_id["r3:comment-line:undo"]["expected_undo_cursor"],
            [0, 5],
        )
        self.assertEqual(
            cases_by_path_id["r3:comment-line:macro-replay"].get("prepare_keys", []),
            [],
        )
        self.assertEqual(
            cases_by_path_id["r3:comment-line:macro-replay"]["command_keys"],
            ["M-;"],
        )
        self.assertEqual(
            cases_by_path_id["r3:comment-line:macro-replay"]["expected_bytes"],
            "value #\n",
        )
        self.assertEqual(
            cases_by_path_id["r3:comment-line:macro-replay"]["expected_cursor"],
            [0, 7],
        )
        self.assertEqual(
            cases_by_path_id["r3:comment-line:macro-replay"]["effect_screen"][0][
                "text"
            ],
            "value #",
        )
        self.assertIn(
            "comment-line",
            cases_by_path_id["r3:comment-line:macro-replay"]["commands"],
        )
        self.assertEqual(
            cases_by_path_id["r3:indent-for-tab-command:undo"]["expected_undo_cursor"],
            [1, 0],
        )
        self.assertEqual(
            cases_by_path_id["r3:indent-for-tab-command:macro-replay"]["command_keys"],
            ["TAB"],
        )
        self.assertEqual(
            cases_by_path_id["r3:indent-for-tab-command:macro-replay"]["replay_prefix_keys"],
            ["C-a"],
        )
        self.assertEqual(
            cases_by_path_id["r3:indent-for-tab-command:macro-replay"]["prepare_keys"],
            ["DOWN"],
        )
        for mutation_case in {"effect", "undo", "macro-replay", "prefix-u4"}:
            case = cases_by_path_id[
                f"r3:indent-for-tab-command:{mutation_case}"
            ]
            with self.subTest(path_id=case["path_id"]):
                self.assertEqual(case["effect_screen"][0]["index"], 1)

    def test_sidecar_declares_all_prompt_results_and_exact_expectations(self):
        scenarios = load_command_path_scenarios(SCENARIO_DATA)
        prompt_cases = {
            case["prompt_case"]
            for case in scenarios
            if case["rule"] == "r2"
        }

        self.assertEqual(
            prompt_cases,
            {"accept", "cancel", "empty", "tab", "history", "invalid"},
        )
        for case in scenarios:
            with self.subTest(path_id=case["path_id"]):
                self.assertIsInstance(case["expected_minibuffer"], str)
                self.assertIn("initial_bytes", case)
                self.assertIn("expected_bytes", case)
                self.assertIsInstance(case["expected_cursor"], list)
                self.assertTrue(case["expected_screen"])

        empty_case = next(
            case for case in scenarios if case.get("prompt_case") == "empty"
        )
        self.assertEqual(empty_case["input_text"], "")
        self.assertEqual(empty_case["expected_minibuffer"], "Unknown command: ")

    def test_slice_module_registers_every_data_case(self):
        module_path = (
            REPOSITORY_ROOT
            / "packages/core/command/t/e2e/scenarios/command_path_scenarios.py"
        )
        spec = importlib.util.spec_from_file_location(
            "loom_test_command_path_scenarios", module_path
        )
        module = importlib.util.module_from_spec(spec)

        with patch.object(registry, "_scenarios", []):
            spec.loader.exec_module(module)
            registered = registry.all_scenarios()

        sidecar = load_command_path_scenarios(SCENARIO_DATA)
        self.assertEqual(len(registered), len(sidecar))
        self.assertEqual(
            {name for name, _commands, _function in registered},
            {case["name"] for case in sidecar},
        )

    def test_loader_rejects_a_missing_empty_minibuffer_expectation(self):
        valid = {
            "schema_version": 1,
            "scenarios": [
                {
                    "name": "test/empty-message",
                    "path_id": "r2:command:empty",
                    "lane": "W3-1",
                    "rule": "r2",
                    "entry": "mx",
                    "commands": ["execute-extended-command"],
                    "command": "execute-extended-command",
                    "prompt_case": "accept",
                    "input_text": "command",
                    "accepted_command": "command",
                    "initial_bytes": "a\n",
                    "expected_bytes": "a\n",
                    "expected_cursor": [0, 0],
                    "expected_screen": [{"region": "body", "text": "a"}],
                }
            ],
        }
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "scenarios.json"
            path.write_text(json.dumps(valid), encoding="utf-8")
            with self.assertRaisesRegex(
                CommandPathScenarioError, "expected_minibuffer"
            ):
                load_command_path_scenarios(path)

    def test_loader_rejects_invalid_terminal_dimensions(self):
        data = json.loads(SCENARIO_DATA.read_text(encoding="utf-8"))
        data["scenarios"][0]["columns"] = True

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "scenarios.json"
            path.write_text(json.dumps(data), encoding="utf-8")
            with self.assertRaisesRegex(
                CommandPathScenarioError,
                r"scenarios\[0\]\.columns must be a positive integer",
            ):
                load_command_path_scenarios(path)

    def test_loader_rejects_followup_fixture_keys_without_a_wait(self):
        data = json.loads(FILE_TREE_SCENARIO_DATA.read_text(encoding="utf-8"))
        case = next(
            case
            for case in data["scenarios"]
            if case["name"]
            == "command-path/r2/file-tree-rename/free-string/accept"
        )
        case.pop("fixture_wait")

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "scenarios.json"
            path.write_text(json.dumps(data), encoding="utf-8")
            with self.assertRaisesRegex(
                CommandPathScenarioError,
                "fixture_keys_after_wait requires fixture_wait",
            ):
                load_command_path_scenarios(path)

    def test_loader_rejects_r3_expected_bytes_that_disagree_with_the_outcome(self):
        data = json.loads(SCENARIO_DATA.read_text(encoding="utf-8"))
        undo_case = next(
            case
            for case in data["scenarios"]
            if case.get("mutation_case") == "undo"
        )
        undo_case["expected_bytes"] = undo_case["effect_bytes"]

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "scenarios.json"
            path.write_text(json.dumps(data), encoding="utf-8")
            with self.assertRaisesRegex(
                CommandPathScenarioError, "expected_bytes must match initial_bytes"
            ):
                load_command_path_scenarios(path)

    def test_loader_accepts_every_generated_r3_mutation_case(self):
        mutation_cases = (
            "effect",
            "undo",
            "read-only",
            "narrow",
            "split-window",
            "macro-replay",
            "prefix-u4",
        )
        effect_case = next(
            case
            for case in json.loads(
                SCENARIO_DATA.read_text(encoding="utf-8")
            )["scenarios"]
            if case.get("mutation_case") == "effect"
        )

        with tempfile.TemporaryDirectory() as directory:
            for mutation_case in mutation_cases:
                case = json.loads(json.dumps(effect_case))
                case["name"] = f"test/{mutation_case}"
                case["path_id"] = f"r3:delete-char:{mutation_case}"
                case["mutation_case"] = mutation_case
                case["entry"] = (
                    "macro" if mutation_case == "macro-replay" else effect_case["entry"]
                )
                case.pop("expected_undo_cursor", None)
                case.pop("read_only_command", None)
                case.pop("restore_screen", None)
                case.pop("replay_prefix_keys", None)

                if mutation_case == "undo":
                    case["expected_undo_cursor"] = [0, 1]
                elif mutation_case == "narrow":
                    case["prepare_commands"] = ["narrow-to-region"]
                elif mutation_case == "split-window":
                    case["prepare_commands"] = ["split-window-below"]
                elif mutation_case == "prefix-u4":
                    case["command_keys"] = ["C-u", "C-d"]
                elif mutation_case == "read-only":
                    case["read_only_command"] = "toggle-read-only"
                    case["expected_minibuffer"] = "Buffer is read-only"
                    case["effect_bytes"] = case["initial_bytes"]
                elif mutation_case == "macro-replay":
                    case["restore_screen"] = [{"region": "body", "text": "abc"}]
                    case["replay_prefix_keys"] = ["C-a"]

                expected_source = (
                    "effect_bytes"
                    if mutation_case
                    in {"effect", "narrow", "split-window", "macro-replay", "prefix-u4"}
                    else "initial_bytes"
                )
                case["expected_bytes"] = case[expected_source]
                path = Path(directory) / f"{mutation_case}.json"
                path.write_text(
                    json.dumps({"schema_version": 1, "scenarios": [case]}),
                    encoding="utf-8",
                )

                loaded = load_command_path_scenarios(path)

                with self.subTest(mutation_case=mutation_case):
                    self.assertEqual(loaded[0]["mutation_case"], mutation_case)
                    self.assertEqual(loaded[0]["expected_bytes"], case[expected_source])

    def test_r4_region_scenarios_load_and_assert_screen_and_file(self):
        scenarios = [
            {
                "name": "test/r4/region-present",
                "path_id": "r4:narrow-to-region:region-present",
                "lane": "W3-4",
                "rule": "r4",
                "entry": "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"n\",\"modifiers\":[]},{\"key\":\"n\",\"modifiers\":[]}]}",
                "commands": [
                    "forward-char",
                    "set-mark-command",
                    "forward-char",
                    "narrow-to-region",
                ],
                "command": "narrow-to-region",
                "region_case": "region-present",
                "prepare_keys": ["C-f"] * 7 + ["C-SPC"] + ["C-f"] * 6,
                "command_keys": ["C-x", "n", "n"],
                "initial_bytes": "before target after\n",
                "expected_bytes": "before target after\n",
                "expected_cursor": [0, 6],
                "expected_minibuffer": "Narrowed to the active region",
                "expected_minibuffer_match": "contains",
                "expected_screen": [{"region": "body", "text": "target"}],
            },
            {
                "name": "test/r4/region-absent",
                "path_id": "r4:narrow-to-region:region-absent",
                "lane": "W3-4",
                "rule": "r4",
                "entry": "key:{\"keymap\":\"global\",\"sequence\":[{\"key\":\"x\",\"modifiers\":[\"control\"]},{\"key\":\"n\",\"modifiers\":[]},{\"key\":\"n\",\"modifiers\":[]}]}",
                "commands": ["narrow-to-region"],
                "command": "narrow-to-region",
                "region_case": "region-absent",
                "command_keys": ["C-x", "n", "n"],
                "initial_bytes": "abc\n",
                "expected_bytes": "abc\n",
                "expected_cursor": [0, 0],
                "expected_minibuffer": "The mark is not set now, so no region is active",
                "expected_minibuffer_match": "contains",
                "expected_screen": [{"region": "body", "text": "abc"}],
            },
        ]
        sessions = []

        def session_factory(*args, **kwargs):
            session = FakeSession(*args, **kwargs)
            sessions.append(session)
            return session

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "r4.json"
            path.write_text(
                json.dumps({"schema_version": 1, "scenarios": scenarios}),
                encoding="utf-8",
            )
            loaded = load_command_path_scenarios(path)
            for case in loaded:
                run_command_path_scenario(
                    "unused", case, session_factory=session_factory
                )

        self.assertEqual(
            [case["region_case"] for case in loaded],
            ["region-present", "region-absent"],
        )
        self.assertEqual(len(sessions), len(loaded))
        for case, session in zip(loaded, sessions):
            with self.subTest(region_case=case["region_case"]):
                sent = [call[1] for call in session.calls if call[0] == "send"]
                expected_prepare_keys = (
                    ["C-f"] * 7 + ["C-SPC"] + ["C-f"] * 6
                    if case["region_case"] == "region-present"
                    else []
                )
                self.assertEqual(
                    case.get("prepare_keys", []), expected_prepare_keys
                )
                self.assertEqual(case["command_keys"], ["C-x", "n", "n"])
                keys_to_send = expected_prepare_keys + case["command_keys"]
                self.assertEqual(sent, [_key_bytes(name) for name in keys_to_send])
                self.assertIn(
                    ("assert_file_bytes", case["expected_bytes"].encode("utf-8")),
                    session.calls,
                )
                expectation = case["expected_screen"][0]
                self.assertIn(
                    (
                        "assert_screen",
                        expectation["text"],
                        "exact",
                        {
                            "region": expectation["region"],
                            "index": expectation.get("index", 0),
                            "strip_right": True,
                        },
                    ),
                    session.calls,
                )
                self.assertIn(
                    (
                        "wait_text",
                        "minibuffer",
                        case["expected_minibuffer"],
                        {},
                    ),
                    session.calls,
                )
                self.assertIn(
                    (
                        "assert_screen",
                        case["expected_minibuffer"],
                        case["expected_minibuffer_match"],
                        {"region": "minibuffer", "strip_right": True},
                    ),
                    session.calls,
                )
                self.assertIn(
                    (
                        "wait_region_cursor",
                        "body",
                        case["expected_cursor"][1],
                        case["expected_cursor"][0],
                    ),
                    session.calls,
                )
                self.assertIn(
                    (
                        "observe_cursor",
                        tuple(case["expected_cursor"]),
                        {"region": "body"},
                    ),
                    session.calls,
                )

    def test_loader_rejects_r4_without_region_case(self):
        case = {
            "name": "test/r4/missing-region-case",
            "path_id": "r4:narrow-to-region:region-present",
            "lane": "W3-4",
            "rule": "r4",
            "entry": "key",
            "commands": ["narrow-to-region"],
            "command": "narrow-to-region",
            "command_keys": ["C-x", "n", "n"],
            "initial_bytes": "abc\n",
            "expected_bytes": "abc\n",
            "expected_cursor": [0, 0],
            "expected_minibuffer": "",
            "expected_screen": [{"region": "body", "text": "abc"}],
        }
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "missing-region-case.json"
            path.write_text(
                json.dumps({"schema_version": 1, "scenarios": [case]}),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(
                CommandPathScenarioError,
                "region_case must be region-present or region-absent",
            ):
                load_command_path_scenarios(path)

    def test_accept_flow_uses_exact_body_cursor_and_saved_bytes(self):
        case = {
            "name": "test/accept",
            "path_id": "r2:execute-extended-command:accept",
            "lane": "W3-1",
            "rule": "r2",
            "commands": ["execute-extended-command", "capitalize-word", "save-buffer"],
            "command": "execute-extended-command",
            "prompt_case": "accept",
            "input_text": "capitalize-word",
            "accepted_command": "capitalize-word",
            "initial_bytes": "one two\n",
            "expected_bytes": "One two\n",
            "expected_cursor": [0, 3],
            "expected_minibuffer": "",
            "expected_screen": [{"region": "body", "text": "One two"}],
            "save_after_effect": True,
            "columns": 240,
            "rows": 30,
        }
        sessions = []
        factory_dimensions = []

        def session_factory(*args, **kwargs):
            factory_dimensions.append(kwargs)
            session = FakeSession(*args, **kwargs)
            sessions.append(session)
            return session

        run_command_path_scenario("unused", case, session_factory=session_factory)

        self.assertEqual(factory_dimensions, [{"columns": 240, "rows": 30}])
        calls = sessions[0].calls
        self.assertIn(("send", b"\x1bx"), calls)
        self.assertIn(("type", "capitalize-word"), calls)
        self.assertIn(("key", "RET"), calls)
        self.assertIn(("wait_region_cursor", "body", 3, 0), calls)
        self.assertIn(("observe_cursor", (0, 3), {"region": "body"}), calls)
        self.assertIn(("assert_file_bytes", b"One two\n"), calls)
        self.assertTrue(
            any(call[0] == "assert_screen" and call[1] == "" for call in calls)
        )

    def test_open_mx_checks_cursor_in_the_minibuffer(self):
        case = next(
            case
            for case in load_command_path_scenarios(SCENARIO_DATA)
            if case["entry_mode"] == "open-mx"
        )
        sessions = []

        def session_factory(*args, **kwargs):
            session = FakeSession(*args, **kwargs)
            sessions.append(session)
            return session

        run_command_path_scenario("unused", case, session_factory=session_factory)

        calls = sessions[0].calls
        self.assertIn(
            ("observe_cursor", (0, 4), {"region": "minibuffer"}),
            calls,
        )
        self.assertIn(("wait_region_cursor", "minibuffer", 4, 0), calls)
        self.assertLess(
            calls.index(
                ("wait_exact_text", "minibuffer", "M-x", {"strip_right": True})
            ),
            calls.index(
                (
                    "wait_exact_text",
                    "body",
                    "abc",
                    {"index": 0, "strip_right": True},
                )
            ),
        )
        cursor_check = calls.index(
            ("observe_cursor", (0, 4), {"region": "minibuffer"})
        )
        cancel_prompt = calls.index(("send", b"\x07"))
        wait_for_quit = calls.index(
            ("wait_exact_text", "minibuffer", "Quit", {"strip_right": True})
        )
        self.assertLess(cursor_check, cancel_prompt)
        self.assertLess(cancel_prompt, wait_for_quit)

    def test_r1_goto_line_mx_sends_its_numeric_followup_after_prompt_opens(self):
        case = next(
            case
            for case in load_command_path_scenarios(BUFFER_SCENARIO_DATA)
            if case["path_id"] == "r1:goto-line:mx"
        )
        session = FakeSession()

        run_command_path_scenario(
            "unused", case, session_factory=lambda *_args, **_kwargs: session
        )

        calls = session.calls
        command_input = calls.index(("type", "goto-line"))
        command_accept = calls.index(("key", "RET"), command_input)
        prompt_open = calls.index(
            ("wait_text", "minibuffer", "Go to line: ", {})
        )
        line_input = calls.index(("type", case["followup_input"]))
        line_accept = calls.index(("key", "RET"), line_input)
        self.assertLess(command_accept, prompt_open)
        self.assertLess(prompt_open, line_input)
        self.assertLess(line_input, line_accept)
        self.assertIn(("observe_cursor", (1, 0), {"region": "body"}), calls)
        self.assertIn(
            ("wait_exact_text", "minibuffer", "Moved", {"strip_right": True}),
            calls,
        )

    def test_r1_mx_without_followup_keeps_the_direct_command_flow(self):
        case = next(
            case
            for case in load_command_path_scenarios(BUFFER_SCENARIO_DATA)
            if case["path_id"] == "r1:newline:mx"
        )
        self.assertNotIn("followup_input", case)
        session = FakeSession()

        run_command_path_scenario(
            "unused", case, session_factory=lambda *_args, **_kwargs: session
        )

        self.assertIn(("type", "newline"), session.calls)
        self.assertNotIn(
            ("wait_text", "minibuffer", "Go to line: ", {}), session.calls
        )

    def test_r1_followup_input_is_only_a_positive_ascii_line_number_for_goto_line(self):
        valid_case = next(
            case
            for case in load_command_path_scenarios(BUFFER_SCENARIO_DATA)
            if case["path_id"] == "r1:goto-line:mx"
        )
        malformed = (
            ("other path", {"path_id": "r1:newline:mx"}, "only valid for"),
            ("other entry mode", {"entry_mode": "key"}, "only valid for"),
            ("other rule", {"rule": "r2"}, "only valid for R1"),
            ("zero", {"followup_input": "0"}, "positive ASCII decimal"),
            ("unicode digits", {"followup_input": "２"}, "positive ASCII decimal"),
            ("non-string", {"followup_input": 2}, "positive ASCII decimal"),
        )
        for name, updates, message in malformed:
            with self.subTest(case=name):
                case = dict(valid_case)
                case.update(updates)
                with tempfile.TemporaryDirectory() as directory:
                    scenario_path = Path(directory) / "scenarios.json"
                    scenario_path.write_text(
                        json.dumps({"schema_version": 1, "scenarios": [case]}),
                        encoding="utf-8",
                    )
                    with self.assertRaisesRegex(CommandPathScenarioError, message):
                        load_command_path_scenarios(scenario_path)

    def test_r1_cancels_a_prompt_after_asserting_its_state(self):
        case = {
            "name": "test/describe-command-prompt",
            "path_id": "r1:describe-command:key:test",
            "lane": "W3-5",
            "rule": "r1",
            "entry": "key:test",
            "commands": ["describe-command"],
            "command": "describe-command",
            "entry_mode": "key",
            "entry_keys": ["C-h", "x"],
            "initial_bytes": "abc\n",
            "expected_bytes": "abc\n",
            "expected_cursor": [0, 18],
            "expected_cursor_region": "minibuffer",
            "expected_minibuffer": "Describe command: ",
            "expected_screen": [{"region": "body", "text": "abc"}],
            "cancel_prompt_after_assert": True,
        }
        sessions = []

        def session_factory(*args, **kwargs):
            session = FakeSession(*args, **kwargs)
            sessions.append(session)
            return session

        run_command_path_scenario("unused", case, session_factory=session_factory)

        calls = sessions[0].calls
        cursor_wait = calls.index(("wait_region_cursor", "minibuffer", 18, 0))
        cursor_check = calls.index(
            ("observe_cursor", (0, 18), {"region": "minibuffer"})
        )
        cancel_prompt = calls.index(("send", b"\x07"))
        wait_for_quit = calls.index(
            ("wait_exact_text", "minibuffer", "Quit", {"strip_right": True})
        )
        self.assertLess(cursor_wait, cursor_check)
        self.assertLess(cursor_check, cancel_prompt)
        self.assertLess(cancel_prompt, wait_for_quit)
        self.assertEqual(calls[-1], ("quit",))

    def test_remaining_completion_flows_send_the_declared_terminal_keys(self):
        cases = [
            case
            for case in load_command_path_scenarios(SCENARIO_DATA)
            if case.get("prompt_case") in {"cancel", "empty", "tab", "history", "invalid"}
        ]
        for case in cases:
            with self.subTest(prompt_case=case["prompt_case"]):
                sessions = []

                def session_factory(*args, **kwargs):
                    session = FakeSession(*args, **kwargs)
                    sessions.append(session)
                    return session

                run_command_path_scenario(
                    "unused", case, session_factory=session_factory
                )
                calls = sessions[0].calls
                self.assertIn(("send", b"\x1bx"), calls)
                if case["prompt_case"] == "cancel":
                    self.assertIn(("send", b"\x07"), calls)
                elif case["prompt_case"] == "tab":
                    self.assertIn(("key", "TAB"), calls)
                    self.assertIn(("key", "RET"), calls)
                elif case["prompt_case"] == "history":
                    self.assertIn(("key", "UP"), calls)
                    self.assertGreaterEqual(
                        sum(call == ("send", b"\x1bx") for call in calls), 2
                    )
                else:
                    self.assertIn(("key", "RET"), calls)

    def test_register_tab_routes_record_the_completed_prompt_before_accept(self):
        cases = [
            case
            for case in load_command_path_scenarios(REGISTER_SCENARIO_DATA)
            if case.get("prompt_case") == "tab"
        ]
        self.assertEqual(
            {case["command"] for case in cases},
            {
                "copy-to-register",
                "insert-register",
                "jump-to-register",
                "point-to-register",
            },
        )

        for case in cases:
            with self.subTest(path_id=case["path_id"]):
                sessions = []

                def session_factory(*args, **kwargs):
                    session = FakeSession(*args, **kwargs)
                    sessions.append(session)
                    return session

                run_command_path_scenario(
                    "unused", case, session_factory=session_factory
                )

                calls = sessions[0].calls
                expected = case["prompt_open"] + case["tab_expected"]
                tab_index = calls.index(("key", "TAB"))
                wait_index = calls.index(
                    (
                        "wait_exact_text",
                        "minibuffer",
                        expected,
                        {"strip_right": True},
                    )
                )
                observation = (
                    "assert_screen",
                    expected,
                    "exact",
                    {"region": "minibuffer", "strip_right": True},
                )
                observation_index = calls.index(observation)
                accept_index = calls.index(("key", "RET"), tab_index)

                self.assertLess(tab_index, wait_index)
                self.assertLess(wait_index, observation_index)
                self.assertLess(observation_index, accept_index)

    def test_r2_uses_declared_primary_entry_for_slice_prompt(self):
        case = {
            "name": "test/copy-to-register-prompt",
            "path_id": "r2:copy-to-register:prompt-1:free-string:accept",
            "lane": "W3-10",
            "rule": "r2",
            "commands": ["copy-to-register"],
            "command": "copy-to-register",
            "entry": 'key:{"keymap":"global","sequence":[{"key":"x","modifiers":["control"]},{"key":"r","modifiers":[]},{"key":"s","modifiers":[]}]};prompt:1:free-string',
            "entry_mode": "key",
            "entry_keys": ["C-x", "r", "s"],
            "prompt_kind": "free-string",
            "prompt_open": "Store to register:",
            "prompt_case": "accept",
            "input_text": "a",
            "initial_bytes": "abc",
            "expected_bytes": "abc",
            "expected_cursor": [0, 0],
            "expected_minibuffer": "Register stored",
            "expected_screen": [{"region": "body", "text": "abc"}],
        }
        with tempfile.TemporaryDirectory() as directory:
            scenario_path = Path(directory) / "scenarios.json"
            scenario_path.write_text(
                json.dumps({"schema_version": 1, "scenarios": [case]}),
                encoding="utf-8",
            )
            case = load_command_path_scenarios(scenario_path)[0]
        sessions = []

        def session_factory(*args, **kwargs):
            session = FakeSession(*args, **kwargs)
            sessions.append(session)
            return session

        run_command_path_scenario("unused", case, session_factory=session_factory)

        calls = sessions[0].calls
        self.assertEqual(
            [call for call in calls if call[0] == "send"],
            [("send", bytes([24])), ("send", b"r"), ("send", b"s")],
        )
        self.assertNotIn(("send", bytes([27]) + b"x"), calls)
        self.assertIn(
            ("wait_text", "minibuffer", "Store to register:", {}),
            calls,
        )
        self.assertIn(("type", "a"), calls)
        self.assertIn(("key", "RET"), calls)


    def test_r2_target_prompt_history_checks_meta_p_and_meta_n(self):
        case = {
            "name": "test/copy-to-register-history",
            "path_id": "r2:copy-to-register:prompt-1:free-string:history",
            "lane": "W3-10",
            "rule": "r2",
            "commands": ["copy-to-register"],
            "command": "copy-to-register",
            "entry": "key:test;prompt:1:free-string",
            "entry_mode": "key",
            "entry_keys": ["C-x", "r", "s"],
            "prompt_kind": "free-string",
            "prompt_open": "Store to register: ",
            "prompt_case": "history",
            "input_text": "fresh",
            "history_seed_input": "a",
            "history_expected": "a",
            "history_next_expected": "fresh",
            "initial_bytes": "abc",
            "expected_bytes": "abc",
            "expected_cursor": [0, 0],
            "expected_minibuffer": "Register stored",
            "expected_screen": [{"region": "body", "text": "abc"}],
        }
        sessions = []

        def session_factory(*args, **kwargs):
            session = FakeSession(*args, **kwargs)
            sessions.append(session)
            return session

        run_command_path_scenario("unused", case, session_factory=session_factory)

        calls = sessions[0].calls
        self.assertEqual(
            [call for call in calls if call[0] == "send" and call[1] in {b"\x1bp", b"\x1bn"}],
            [
                ("send", b"\x1bp"),
                ("send", b"\x1bn"),
                ("send", b"\x1bp"),
            ],
        )
        self.assertIn(
            (
                "wait_exact_text",
                "minibuffer",
                "Store to register: a",
                {"strip_right": True},
            ),
            calls,
        )
        self.assertIn(
            (
                "wait_exact_text",
                "minibuffer",
                "Store to register: fresh",
                {"strip_right": True},
            ),
            calls,
        )

    def test_r2_target_prompt_history_can_cancel_after_navigation(self):
        case = {
            "name": "test/copy-to-register-history-cancel",
            "path_id": "r2:copy-to-register:prompt-1:free-string:history",
            "lane": "W3-10",
            "rule": "r2",
            "commands": ["copy-to-register"],
            "command": "copy-to-register",
            "entry": 'key:{"keymap":"global","sequence":[{"key":"x","modifiers":["control"]},{"key":"r","modifiers":[]},{"key":"s","modifiers":[]}]};prompt:1:free-string',
            "entry_mode": "key",
            "entry_keys": ["C-x", "r", "s"],
            "prompt_kind": "free-string",
            "prompt_open": "Store to register:",
            "prompt_case": "history",
            "input_text": "fresh",
            "history_seed_input": "a",
            "history_expected": "a",
            "history_next_expected": "fresh",
            "history_cancel": True,
            "initial_bytes": "abc",
            "expected_bytes": "abc",
            "expected_cursor": [0, 0],
            "expected_minibuffer": "Quit",
            "expected_screen": [{"region": "body", "text": "abc"}],
        }
        with tempfile.TemporaryDirectory() as directory:
            scenario_path = Path(directory) / "scenarios.json"
            scenario_path.write_text(
                json.dumps({"schema_version": 1, "scenarios": [case]}),
                encoding="utf-8",
            )
            case = load_command_path_scenarios(scenario_path)[0]
        sessions = []

        def session_factory(*args, **kwargs):
            session = FakeSession(*args, **kwargs)
            sessions.append(session)
            return session

        run_command_path_scenario("unused", case, session_factory=session_factory)

        calls = sessions[0].calls
        history_return = max(
            index for index, call in enumerate(calls) if call == ("key", "RET")
        )
        cancel_index = calls.index(("send", b"\x07"))
        self.assertLess(history_return, cancel_index)
        self.assertNotIn(("key", "RET"), calls[cancel_index + 1 :])
        self.assertIn(("type", "fresh"), calls)
        self.assertIn(
            ("wait_exact_text", "minibuffer", "Quit", {"strip_right": True}),
            calls,
        )

    def test_fixture_files_and_expected_filesystem_are_observed(self):
        case = dict(load_command_path_scenarios(SCENARIO_DATA)[0])
        case["fixture_files"] = [
            {"path": "rename-source.txt", "contents": "original\n"}
        ]
        case["expected_filesystem"] = [
            {"path": "rename-source.txt", "kind": "file"}
        ]
        case["expected_screen"] = [
            {"region": "screen", "text": "rename-source.txt", "match": "contains"}
        ]
        case["expected_minibuffer"] = "dynamic status"
        case["expected_minibuffer_match"] = "contains"
        with tempfile.TemporaryDirectory() as directory:
            scenario_path = Path(directory) / "scenarios.json"
            scenario_path.write_text(
                json.dumps({"schema_version": 1, "scenarios": [case]}),
                encoding="utf-8",
            )
            case = load_command_path_scenarios(scenario_path)[0]
        observed = {}

        def session_factory(binary, files, **kwargs):
            buffer_path = Path(files[0])
            fixture_path = buffer_path.with_name("rename-source.txt")
            observed["fixture_contents"] = fixture_path.read_text(encoding="utf-8")
            session = FakeSession(binary, files, **kwargs)
            observed["calls"] = session.calls
            return session

        run_command_path_scenario("unused", case, session_factory=session_factory)

        self.assertEqual(observed["fixture_contents"], "original\n")
        self.assertIn(
            (
                "assert_external_state",
                "filesystem/rename-source.txt",
                "file",
                "file",
                "scenario",
            ),
            observed["calls"],
        )
        self.assertIn(
            ("wait_text", "screen", "rename-source.txt", {"index": 0}),
            observed["calls"],
        )
        self.assertIn(
            (
                "assert_screen",
                "rename-source.txt",
                "contains",
                {"region": "screen", "index": 0, "strip_right": True},
            ),
            observed["calls"],
        )
        self.assertIn(
            ("wait_text", "minibuffer", "dynamic status", {}),
            observed["calls"],
        )
        self.assertIn(
            (
                "assert_screen",
                "dynamic status",
                "contains",
                {"region": "minibuffer", "strip_right": True},
            ),
            observed["calls"],
        )

    def test_scenario_directory_and_fixture_file_tokens_resolve(self):
        fixture_files = [{"path": "rename-source.txt", "contents": "original\n"}]
        resolved = _resolve_path_tokens(
            {
                "target": "$scenario_dir/renamed.txt",
                "source": "$fixture_file:rename-source.txt",
            },
            Path("/tmp/example/buffer.txt"),
            Path("/tmp/example/session.sexp"),
            fixture_files,
        )
        self.assertEqual(
            resolved["target"],
            str(Path("/tmp/example/renamed.txt").resolve(strict=False)),
        )
        self.assertEqual(
            resolved["source"],
            str(Path("/tmp/example/rename-source.txt").resolve(strict=False)),
        )

    def test_scenario_filesystem_paths_reject_directory_traversal(self):
        case = dict(load_command_path_scenarios(SCENARIO_DATA)[0])
        case["expected_filesystem"] = [{"path": "../outside", "kind": "absent"}]
        with tempfile.TemporaryDirectory() as directory:
            scenario_path = Path(directory) / "scenarios.json"
            scenario_path.write_text(
                json.dumps({"schema_version": 1, "scenarios": [case]}),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(
                CommandPathScenarioError, "filename inside the scenario directory"
            ):
                load_command_path_scenarios(scenario_path)

    def test_session_prompt_resolves_fixture_and_temporary_path_tokens(self):
        case = {
            "name": "test/load-session-prompt",
            "path_id": "r2:load-session:prompt-1:free-string:accept",
            "lane": "W3-10",
            "rule": "r2",
            "commands": ["load-session"],
            "command": "load-session",
            "entry": "mx;prompt:1:free-string",
            "entry_mode": "mx",
            "prompt_kind": "free-string",
            "prompt_open": "Load session:",
            "prompt_case": "accept",
            "input_text": "$session_file",
            "session_fixture": {
                "path": "$session_file",
                "contents": '(:buffer-path "$buffer_file")',
            },
            "initial_bytes": "before",
            "expected_bytes": "before",
            "expected_cursor": [0, 0],
            "expected_minibuffer": "Session loaded",
            "expected_screen": [{"region": "body", "text": "before"}],
        }
        with tempfile.TemporaryDirectory() as directory:
            scenario_path = Path(directory) / "scenarios.json"
            scenario_path.write_text(
                json.dumps({"schema_version": 1, "scenarios": [case]}),
                encoding="utf-8",
            )
            case = load_command_path_scenarios(scenario_path)[0]

        observed = {}

        def session_factory(binary, files, **kwargs):
            buffer_path = Path(files[0])
            session_path = buffer_path.with_name("session.sexp")
            observed["buffer_path"] = str(buffer_path)
            observed["session_path"] = str(session_path)
            observed["fixture"] = session_path.read_text(encoding="utf-8")
            session = FakeSession(binary, files, **kwargs)
            observed["calls"] = session.calls
            return session

        run_command_path_scenario("unused", case, session_factory=session_factory)

        self.assertIn(observed["buffer_path"], observed["fixture"])
        self.assertNotIn("$buffer_file", observed["fixture"])
        self.assertIn(
            (
                "type",
                str(Path(observed["session_path"]).resolve(strict=False)),
            ),
            observed["calls"],
        )

    def test_r3_undo_records_exact_changed_and_restored_bytes(self):
        case = {
            "name": "test/undo",
            "path_id": "r3:delete-char:undo",
            "lane": "W3-4",
            "rule": "r3",
            "commands": ["delete-char", "undo", "save-buffer"],
            "command": "delete-char",
            "mutation_case": "undo",
            "command_keys": ["C-d"],
            "initial_bytes": "abc\n",
            "effect_bytes": "bc\n",
            "expected_bytes": "abc\n",
            "expected_cursor": [0, 1],
            "expected_undo_cursor": [0, 0],
            "expected_minibuffer": "",
            "expected_screen": [{"region": "body", "text": "abc"}],
            "effect_screen": [{"region": "body", "text": "bc"}],
        }
        sessions = []

        def session_factory(*args, **kwargs):
            session = FakeSession(*args, **kwargs)
            sessions.append(session)
            return session

        run_command_path_scenario("unused", case, session_factory=session_factory)

        calls = sessions[0].calls
        self.assertIn(("send", b"\x04"), calls)
        self.assertIn(("send", b"\x18u"), calls)
        self.assertIn(("assert_file_bytes", b"abc\n"), calls)
        self.assertEqual(
            [call[1] for call in calls if call[0] == "observe_cursor"],
            [(0, 1), (0, 0)],
        )
        self.assertTrue(
            any(call[0] == "assert_screen" and call[1] == "bc" for call in calls)
        )
        self.assertLess(
            calls.index(("send", b"\x04")),
            calls.index(
                (
                    "wait_exact_text",
                    "body",
                    "bc",
                    {"index": 0, "strip_right": True},
                )
            ),
        )
        self.assertEqual(
            sum(
                call == ("wait_exact_text", "minibuffer", "", {"strip_right": True})
                for call in calls
            ),
            1,
        )


    def test_r3_sends_fixture_keys_before_the_declared_mutation(self):
        case = {
            "name": "test/fixture-before-mutation",
            "path_id": "r3:delete-char:effect",
            "lane": "W3-4",
            "rule": "r3",
            "commands": ["delete-char"],
            "command": "delete-char",
            "mutation_case": "effect",
            "fixture_keys": ["C-g"],
            "command_keys": ["C-d"],
            "initial_bytes": "abc\n",
            "effect_bytes": "bc\n",
            "expected_bytes": "bc\n",
            "expected_cursor": [0, 1],
            "expected_minibuffer": "",
            "expected_screen": [{"region": "body", "text": "bc"}],
            "effect_screen": [{"region": "body", "text": "bc"}],
        }
        sessions = []

        def session_factory(*args, **kwargs):
            session = FakeSession(*args, **kwargs)
            sessions.append(session)
            return session

        run_command_path_scenario("unused", case, session_factory=session_factory)

        sends = [call for call in sessions[0].calls if call[0] == "send"]
        self.assertEqual(sends[:2], [("send", b"\x07"), ("send", b"\x04")])

    def test_r3_read_only_refusal_preserves_exact_bytes(self):
        case = next(
            case
            for case in load_command_path_scenarios(SCENARIO_DATA)
            if case.get("mutation_case") == "read-only"
        )
        sessions = []

        def session_factory(*args, **kwargs):
            session = FakeSession(*args, **kwargs)
            sessions.append(session)
            return session

        run_command_path_scenario("unused", case, session_factory=session_factory)

        calls = sessions[0].calls
        self.assertIn(("type", "toggle-read-only"), calls)
        self.assertLess(
            calls.index(
                (
                    "wait_exact_text",
                    "minibuffer",
                    "Buffer is read-only",
                    {"strip_right": True},
                )
            ),
            calls.index(("send", b"\x04")),
        )
        self.assertIn(("send", b"\x04"), calls)
        self.assertIn(("assert_screen", "Buffer is read-only", "exact", {
            "region": "minibuffer", "strip_right": True,
        }), calls)
        self.assertIn(("assert_file_bytes", b"abc\n"), calls)

    def test_r3_macro_replay_saves_exact_result_after_cursor_reset(self):
        case = next(
            case
            for case in load_command_path_scenarios(SCENARIO_DATA)
            if case.get("mutation_case") == "macro-replay"
        )
        sessions = []
        self.assertEqual(case["expected_minibuffer"], "Keyboard macro defined")
        self.assertIn("move-beginning-of-line", case["commands"])
        self.assertNotIn("beginning-of-line", case["commands"])

        def session_factory(*args, **kwargs):
            session = FakeSession(*args, **kwargs)
            sessions.append(session)
            return session

        run_command_path_scenario("unused", case, session_factory=session_factory)

        calls = sessions[0].calls
        self.assertEqual(case["replay_prefix_keys"], ["C-a"])
        self.assertIn(("type", "start-kbd-macro"), calls)
        self.assertEqual(sum(call == ("send", b"\x01") for call in calls), 1)
        effect_file_assertions = [
            call[1]
            for call in calls
            if call[0] == "assert_file_bytes" and call[1] == b"bc\n"
        ]
        self.assertEqual(effect_file_assertions, [b"bc\n", b"bc\n"])
        self.assertEqual(
            [call[2] for call in calls if call[0] == "observe_file_bytes"],
            ["precondition"],
        )
        self.assertEqual(
            sum(call == ("send", b"\x18u") for call in calls),
            1,
        )
        macro_defined = ("wait_exact_text", "minibuffer", "Keyboard macro defined")
        self.assertEqual(
            sum(call[:3] == macro_defined for call in calls),
            1,
        )
        self.assertLess(
            calls.index(
                ("wait_exact_text", "minibuffer", "Keyboard macro defined", {
                    "strip_right": True,
                })
            ),
            calls.index(("send", b"\x18u")),
        )
        self.assertGreaterEqual(
            sum(
                call[:3] == ("wait_exact_text", "body", "bc")
                for call in calls
            ),
            2,
        )

    def test_r3_macro_replay_waits_for_the_declared_restore_screen_row(self):
        case = next(
            case
            for case in load_command_path_scenarios(SCENARIO_DATA)
            if case["path_id"] == "r3:indent-for-tab-command:macro-replay"
        )
        sessions = []

        def session_factory(*args, **kwargs):
            session = FakeSession(*args, **kwargs)
            sessions.append(session)
            return session

        run_command_path_scenario("unused", case, session_factory=session_factory)

        restore = case["restore_screen"][0]
        self.assertIn(
            (
                "wait_exact_text",
                restore["region"],
                restore["text"],
                {"index": restore.get("index", 0), "strip_right": True},
            ),
            sessions[0].calls,
        )

    def test_control_meta_keys_use_kitty_modifier_encoding(self):
        for name, codepoint in (("C-M-s", 115), ("C-M-%", 37), ("C-M-_", 95)):
            with self.subTest(name=name):
                self.assertEqual(
                    _key_bytes(name), f"\x1b[{codepoint};7u".encode("ascii")
                )

    def test_loader_requires_every_r2_continuation_input(self):
        case = {
            "name": "test/multi-prompt",
            "path_id": "r2:test-command:prompt-1:free-string:tab",
            "lane": "W3-6",
            "rule": "r2",
            "entry": "key:test",
            "commands": ["test-command"],
            "command": "test-command",
            "entry_mode": "key",
            "entry_keys": ["C-x"],
            "prompt_case": "tab",
            "prompt_kind": "free-string",
            "prompt_index": 1,
            "prompt_label": "Find: ",
            "prompt_labels": ["Find: ", "Replace with: "],
            "prior_prompt_inputs": [],
            "input_text": "needle",
            "initial_bytes": "needle\n",
            "expected_bytes": "needle\n",
            "expected_cursor": [0, 0],
            "expected_minibuffer": "Done",
            "expected_screen": [{"region": "body", "text": "needle"}],
        }
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "scenarios.json"
            path.write_text(
                json.dumps({"schema_version": 1, "scenarios": [case]}),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(
                CommandPathScenarioError,
                "continuation_inputs must cover prompts after prompt_index",
            ):
                load_command_path_scenarios(path)

    def test_r1_uses_declared_m_x_name_and_cleanup_keys(self):
        case = {
            "name": "test/search-occur-prompt",
            "path_id": "r1:search-occur:mx",
            "lane": "W3-6",
            "rule": "r1",
            "entry": "mx",
            "commands": ["search-occur"],
            "command": "search-occur",
            "invoke_name": "occur",
            "entry_mode": "mx",
            "initial_bytes": "abc\n",
            "expected_bytes": "abc\n",
            "expected_cursor": [0, len("List lines matching regexp: ")],
            "expected_cursor_region": "minibuffer",
            "expected_minibuffer": "List lines matching regexp: ",
            "expected_screen": [{"region": "body", "text": "abc"}],
            "cleanup_keys": ["C-g"],
        }
        with tempfile.TemporaryDirectory() as directory:
            scenario_path = Path(directory) / "scenarios.json"
            scenario_path.write_text(
                json.dumps({"schema_version": 1, "scenarios": [case]}),
                encoding="utf-8",
            )
            loaded = load_command_path_scenarios(scenario_path)[0]
        sessions = []

        def session_factory(*args, **kwargs):
            session = FakeSession(*args, **kwargs)
            sessions.append(session)
            return session

        run_command_path_scenario("unused", loaded, session_factory=session_factory)

        calls = sessions[0].calls
        self.assertIn(("type", "occur"), calls)
        self.assertNotIn(("type", "search-occur"), calls)
        cursor_check = calls.index(
            (
                "observe_cursor",
                (0, len("List lines matching regexp: ")),
                {"region": "minibuffer"},
            )
        )
        self.assertLess(cursor_check, calls.index(("send", b"\x07")))

    def test_r2_runs_the_target_prompt_then_each_continuation_prompt(self):
        case = {
            "name": "test/multi-prompt",
            "path_id": "r2:test-command:prompt-1:free-string:accept",
            "lane": "W3-6",
            "rule": "r2",
            "entry": "key:test",
            "commands": ["test-command"],
            "command": "test-command",
            "entry_mode": "key",
            "entry_keys": ["C-x"],
            "prompt_open": "Find: ",
            "prompt_case": "accept",
            "prompt_kind": "free-string",
            "prompt_index": 1,
            "prompt_label": "Find: ",
            "prompt_labels": ["Find: ", "Replace with: "],
            "prior_prompt_inputs": [],
            "continuation_inputs": ["token"],
            "input_text": "needle",
            "initial_bytes": "needle\\n",
            "expected_bytes": "needle\\n",
            "expected_cursor": [0, 0],
            "expected_minibuffer": "Done",
            "expected_screen": [{"region": "body", "text": "needle"}],
        }
        with tempfile.TemporaryDirectory() as directory:
            scenario_path = Path(directory) / "scenarios.json"
            scenario_path.write_text(
                json.dumps({"schema_version": 1, "scenarios": [case]}),
                encoding="utf-8",
            )
            loaded = load_command_path_scenarios(scenario_path)[0]
        sessions = []

        def session_factory(*args, **kwargs):
            session = FakeSession(*args, **kwargs)
            sessions.append(session)
            return session

        run_command_path_scenario("unused", loaded, session_factory=session_factory)

        calls = sessions[0].calls
        self.assertEqual(
            [call[1] for call in calls if call[0] == "type"],
            ["needle", "token"],
        )
        second_prompt = calls.index(
            ("wait_text", "minibuffer", "Replace with: ", {})
        )
        second_input = calls.index(("type", "token"))
        self.assertLess(second_prompt, second_input)

    def test_r3_runs_a_declared_prompt_command_before_effect_assertions(self):
        case = {
            "name": "test/prompted-replace",
            "path_id": "r3:replace-string:effect",
            "lane": "W3-6",
            "rule": "r3",
            "entry": "mx",
            "commands": ["replace-string", "save-buffer"],
            "command": "replace-string",
            "mutation_case": "effect",
            "entry_mode": "mx",
            "prompt_labels": ["Find: ", "Replace with: "],
            "prompt_inputs": ["needle", "token"],
            "initial_bytes": "needle\n",
            "effect_bytes": "token\n",
            "expected_bytes": "token\n",
            "expected_cursor": [0, 0],
            "expected_minibuffer": "Replaced 1 occurrence(s)",
            "expected_screen": [{"region": "body", "text": "token"}],
            "effect_screen": [{"region": "body", "text": "token"}],
        }
        sessions = []

        def session_factory(*args, **kwargs):
            session = FakeSession(*args, **kwargs)
            sessions.append(session)
            return session

        run_command_path_scenario("unused", case, session_factory=session_factory)

        calls = sessions[0].calls
        self.assertEqual(
            [call[1] for call in calls if call[0] == "type"],
            ["replace-string", "needle", "token"],
        )
        self.assertIn(("assert_file_bytes", b"token\n"), calls)

    def test_project_files_create_a_temporary_project_and_expand_expectations(self):
        case = {
            "name": "test/project-tree",
            "path_id": "r2:execute-extended-command:accept",
            "lane": "W3-6",
            "rule": "r2",
            "entry": "mx;prompt:1:completion",
            "commands": ["execute-extended-command", "find-file"],
            "command": "execute-extended-command",
            "entry_mode": "open-mx",
            "prompt_case": "accept",
            "prompt_kind": "completion",
            "input_text": "find-file",
            "accepted_command": "find-file",
            "project_files": {
                "buffer.txt": "needle\n",
                "nested/other.txt": "other\n",
            },
            "initial_bytes": "needle\n",
            "expected_bytes": "needle\n",
            "expected_cursor": [0, 0],
            "expected_minibuffer": "",
            "expected_screen": [
                {"region": "body", "text": "project {project_root}"}
            ],
        }
        with tempfile.TemporaryDirectory() as directory:
            scenarios = Path(directory) / "scenarios.json"
            invalid = dict(case)
            invalid["project_files"] = {
                **case["project_files"],
                "buffer.txt": "different\n",
            }
            scenarios.write_text(
                json.dumps({"schema_version": 1, "scenarios": [invalid]}),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(
                CommandPathScenarioError,
                "project_files.buffer.txt must match initial_bytes",
            ):
                load_command_path_scenarios(scenarios)

            invalid["project_files"] = {
                **case["project_files"],
                "../escape.txt": "outside\n",
            }
            scenarios.write_text(
                json.dumps({"schema_version": 1, "scenarios": [invalid]}),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(
                CommandPathScenarioError,
                "paths must stay inside the project",
            ):
                load_command_path_scenarios(scenarios)

            scenarios.write_text(
                json.dumps({"schema_version": 1, "scenarios": [case]}),
                encoding="utf-8",
            )
            loaded = load_command_path_scenarios(scenarios)[0]

        observed = {}

        def session_factory(binary, files, **kwargs):
            buffer_path = Path(files[0])
            observed["buffer_path"] = buffer_path
            observed["git_exists"] = (buffer_path.parent / ".git").is_dir()
            observed["other_contents"] = (
                buffer_path.parent / "nested/other.txt"
            ).read_text(encoding="utf-8")
            session = FakeSession(binary, files, **kwargs)
            observed["calls"] = session.calls
            return session

        run_command_path_scenario("unused", loaded, session_factory=session_factory)

        self.assertTrue(observed["git_exists"])
        self.assertEqual(observed["other_contents"], "other\n")
        expected_screen_text = f"project {observed['buffer_path'].parent}"
        self.assertIn(
            (
                "assert_screen",
                expected_screen_text,
                "exact",
                {"region": "body", "index": 0, "strip_right": True},
            ),
            observed["calls"],
        )


if __name__ == "__main__":
    unittest.main()
