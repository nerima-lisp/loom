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
    _deadline_stage,
    _key_bytes,
    _send_keys,
    load_command_path_scenarios,
    run_command_path_scenario,
)
from loom_e2e.path_generation import generate_required_paths


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
SCENARIO_DATA = (
    REPOSITORY_ROOT
    / "packages/core/command/t/e2e/scenarios/command-paths.json"
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


class FakeSession:
    def __init__(self, *_args, **_kwargs):
        self.calls = []

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

    def observe_file_bytes(self, path, expected, *, purpose="scenario"):
        self.calls.append(("observe_file_bytes", expected, purpose))
        return expected


class CommandPathScenarioTests(unittest.TestCase):
    def test_extended_command_sequence_waits_and_types_command(self):
        session = FakeSession()

        _send_keys(session, ["M-x", "comment-line", "RET"])

        self.assertEqual(
            session.calls,
            [
                ("send", _key_bytes("M-x")),
                ("wait_text", "minibuffer", "M-x ", {}),
                ("type", "comment-line"),
                ("key", "RET"),
            ],
        )

    def test_c_space_encodes_as_control_at(self):
        self.assertEqual(_key_bytes("C-space"), b"\x00")

    def test_deadline_error_identifies_the_command_path_stage(self):
        with self.assertRaisesRegex(
            ScenarioDeadlineExceeded, r"test/undo \[undo and restore\]: expired"
        ):
            with _deadline_stage("test/undo", "undo and restore"):
                raise ScenarioDeadlineExceeded("expired")

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
            ["M-x", "comment-line", "RET"],
        )
        self.assertEqual(
            cases_by_path_id["r3:comment-line:macro-replay"]["expected_bytes"],
            "# value\n",
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
            ["M-x", "indent-for-tab-command", "RET"],
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
        }
        sessions = []

        def session_factory(*args, **kwargs):
            session = FakeSession(*args, **kwargs)
            sessions.append(session)
            return session

        run_command_path_scenario("unused", case, session_factory=session_factory)

        calls = sessions[0].calls
        self.assertIn(("send", b"\x1bx"), calls)
        self.assertIn(("type", "capitalize-word"), calls)
        self.assertIn(("key", "RET"), calls)
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
            calls.index(("wait_text", "minibuffer", "Buffer is read-only", {})),
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


if __name__ == "__main__":
    unittest.main()
