import json
import tempfile
import unittest
from pathlib import Path

from loom_e2e.path_generation import LANE_REGISTRY
from loom_e2e.path_report import build_report, render_summary, write_report


class PathReportTests(unittest.TestCase):
    def setUp(self):
        self._temporary = tempfile.TemporaryDirectory()
        self.root = Path(self._temporary.name)
        self.repo_root = self.root / "repo"
        self.artifacts_dir = self.root / "artifacts"
        self.binary_path = self.root / "loom"
        self.repo_root.mkdir()
        self.artifacts_dir.mkdir()
        self.binary_path.write_text("test binary", encoding="utf-8")
        self.binary_realpath = str(self.binary_path.resolve())
        self.required = {
            "id": "r1/save-buffer/key",
            "commands": ["save-buffer"],
            "rule": "r1",
            "lane": "W3-3",
            "entry": "mx",
            "observe": ["file_bytes"],
        }
        self.ledger = {
            **self.required,
            "scenario": "files/save-buffer",
            "entry": self.required["entry"],
            "state": "edited buffer",
            "outcome": "saved buffer",
            "observe": ["file_bytes"],
        }

    def tearDown(self):
        self._temporary.cleanup()

    def _write_scenario(
        self,
        observations,
        trace_commands=("save-buffer",),
        status="passed",
        trace_route="mx",
        trace_name="trace.jsonl",
        observation_class="effect-verified",
        trace_entry=None,
        events=(),
    ):
        scenario_dir = self.artifacts_dir / "files-save-buffer"
        scenario_dir.mkdir(exist_ok=True)
        result = {
            "scenario": self.ledger["scenario"],
            "binary_realpath": self.binary_realpath,
            "declared_commands": list(self.ledger["commands"]),
            "events": list(events),
            "observation_class": observation_class,
            "observations": observations,
            "artifacts": {"trace": trace_name},
        }
        if status is not None:
            result["status"] = status
        (scenario_dir / "result.json").write_text(
            json.dumps(result), encoding="utf-8"
        )
        with (scenario_dir / "trace.jsonl").open("w", encoding="utf-8") as handle:
            for sequence, command in enumerate(trace_commands, start=1):
                trace = {
                    "command": command,
                    "route": trace_route,
                    "seq": sequence,
                    "pid": 1234,
                }
                if trace_entry is not None:
                    trace["entry"] = trace_entry
                handle.write(
                    json.dumps(trace) + "\n"
                )

    def _report(
        self, ledger=None, exclusions=(), required=None, selected_scenarios=None
    ):
        return build_report(
            [required or self.required],
            [] if ledger is None else [ledger],
            list(exclusions),
            self.artifacts_dir,
            self.repo_root,
            self.binary_realpath,
            selected_scenarios,
        )

    def _matching_observation(self, **overrides):
        return {
            "type": "file_bytes",
            "actual": {"encoding": "base64", "data": "bmV3", "length": 3},
            "expected": {"encoding": "base64", "data": "bmV3", "length": 3},
            "passed": True,
            "sequence": 0,
            "trace_lines": 1,
            "timeline_sequence": 1,
            "purpose": "scenario",
            **overrides,
        }

    def _configure_path(
        self,
        *,
        path_id,
        commands,
        rule,
        lane,
        entry,
        state,
        outcome,
        observe,
        scenario,
    ):
        self.required = {
            "id": path_id,
            "commands": commands,
            "rule": rule,
            "lane": lane,
            "entry": entry,
            "state": state,
            "outcome": outcome,
            "observe": observe,
        }
        self.ledger = {**self.required, "scenario": scenario}

    def test_generated_path_missing_from_ledger_is_reported(self):
        report = self._report()
        self.assertEqual(report["paths"][0]["status"], "not-in-ledger")
        self.assertTrue(report["has_failures"])
        self.assertEqual(report["missing_paths"][0]["id"], self.required["id"])

    def test_missing_result_is_not_pass(self):
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "no-result")
        self.assertTrue(report["has_failures"])

    def test_unselected_scenario_does_not_use_stale_result_artifact(self):
        self._write_scenario([self._matching_observation()])
        report = self._report(ledger=self.ledger, selected_scenarios=set())
        self.assertEqual(report["paths"][0]["status"], "no-result")
        self.assertEqual(
            report["paths"][0]["reason"],
            "ledger scenario was not selected for this run",
        )

    def test_exit_code_only_result_is_not_pass(self):
        self._write_scenario(
            [{"type": "exit_code", "actual": 0, "expected": 0, "passed": True}],
            observation_class="exit-code-only",
        )
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "no-observation")
        self.assertTrue(report["has_failures"])

    def test_trace_without_every_target_command_is_not_pass(self):
        self._write_scenario(
            [self._matching_observation()], trace_commands=("other-command",)
        )
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "no-trace")
        self.assertEqual(report["paths"][0]["missing_commands"], ["save-buffer"])

    def _use_event_target(self, target):
        self.required["commands"] = []
        self.required["event_targets"] = [target]
        self.ledger["commands"] = []

    def test_declared_event_target_precedes_effect_observation(self):
        self._use_event_target("text_input")
        self._write_scenario(
            [self._matching_observation()],
            trace_commands=(),
            events=[
                {"timeline_sequence": 0, "type": "text_input", "text": "漢"}
            ],
        )

        report = self._report(ledger=self.ledger)

        self.assertEqual(report["paths"][0]["status"], "pass")

    def test_terminal_resize_target_precedes_effect_observation(self):
        self._use_event_target("terminal_resize")
        self._write_scenario(
            [self._matching_observation()],
            trace_commands=(),
            events=[
                {
                    "timeline_sequence": 0,
                    "type": "terminal_resize",
                    "columns": 20,
                    "rows": 12,
                }
            ],
        )

        report = self._report(ledger=self.ledger)

        self.assertEqual(report["paths"][0]["status"], "pass")
        self.assertEqual(
            report["paths"][0]["event_targets"], ["terminal_resize"]
        )

    def test_declared_event_target_without_event_is_not_pass(self):
        self._use_event_target("text_input")
        self._write_scenario(
            [self._matching_observation()], trace_commands=(), events=()
        )

        report = self._report(ledger=self.ledger)

        self.assertEqual(report["paths"][0]["status"], "no-trace")
        self.assertEqual(report["paths"][0]["missing_events"], ["text_input"])

    def test_event_after_effect_observation_does_not_satisfy_target(self):
        self._use_event_target("terminal_resize")
        self._write_scenario(
            [self._matching_observation(timeline_sequence=1)],
            trace_commands=(),
            events=[
                {
                    "timeline_sequence": 2,
                    "type": "terminal_resize",
                    "columns": 20,
                    "rows": 12,
                }
            ],
        )

        report = self._report(ledger=self.ledger)

        self.assertEqual(report["paths"][0]["status"], "no-trace")
        self.assertEqual(
            report["paths"][0]["missing_events"], ["terminal_resize"]
        )

    def test_event_evidence_does_not_bypass_effect_mismatch(self):
        self._use_event_target("text_input")
        self._write_scenario(
            [self._matching_observation(actual="wrong")],
            trace_commands=(),
            events=[
                {"timeline_sequence": 0, "type": "text_input", "text": "漢"}
            ],
        )

        report = self._report(ledger=self.ledger)

        self.assertEqual(report["paths"][0]["status"], "mismatch")

    def test_newline_path_matches_newline_and_indent_trace_command(self):
        self.required["commands"] = ["newline"]
        self.ledger["commands"] = ["newline"]
        self._write_scenario(
            [self._matching_observation()],
            trace_commands=("newline-and-indent", "save-buffer"),
            trace_route="mx",
        )
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "pass")

    def test_comment_line_path_matches_mode_comment_dwim_key_trace(self):
        self.required["commands"] = ["comment-line"]
        self.ledger["commands"] = ["comment-line"]
        self.required["entry"] = "key: M-;"
        self.ledger["entry"] = "key: M-;"
        trace_entry = (
            'key:{"keymap":"nix","sequence":'
            '[{"key":";","modifiers":["alt"]}]}'
        )
        self._write_scenario(
            [self._matching_observation()],
            trace_commands=("mode/comment-dwim",),
            trace_route="key",
            trace_entry=trace_entry,
        )
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "pass")

    def test_language_ret_trace_matches_newline_and_indent_without_mode(self):
        self.required["commands"] = ["newline"]
        self.ledger["commands"] = ["newline"]
        self.required["entry"] = "key: RET"
        self.ledger["entry"] = "key: RET"
        trace_entry = (
            'key:{"keymap":"global","sequence":'
            '[{"key":"enter","modifiers":[]}]} '
        ).strip()
        self._write_scenario(
            [self._matching_observation()],
            trace_commands=("newline-and-indent",),
            trace_route="key",
            trace_entry=trace_entry,
        )

        report = self._report(ledger=self.ledger)

        self.assertEqual(report["paths"][0]["status"], "pass")

    def test_trace_from_the_wrong_entry_route_does_not_satisfy_path(self):
        self._write_scenario(
            [self._matching_observation()], trace_route="key"
        )
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "no-trace")
        self.assertEqual(report["paths"][0]["missing_commands"], ["save-buffer"])

    def test_key_route_without_the_encoded_sequence_is_not_pass(self):
        self.required["entry"] = (
            'key:{"keymap":"global","sequence":["C-x","C-s"]}'
        )
        self.ledger["entry"] = self.required["entry"]
        self._write_scenario(
            [self._matching_observation()], trace_route="key"
        )
        report = self._report(ledger=self.ledger)
        path = report["paths"][0]
        self.assertEqual(path["status"], "no-trace")
        self.assertEqual(path["missing_commands"], [])
        self.assertEqual(
            path["missing_entry"], self.required["entry"].split(";prompt:", 1)[0]
        )

    def test_trace_must_precede_the_effect_observation(self):
        self._write_scenario([self._matching_observation(trace_lines=0)])
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "no-trace")

    def test_every_target_command_must_precede_the_same_effect_observation(self):
        self.required["commands"] = ["save-buffer", "undo"]
        self.ledger["commands"] = ["save-buffer", "undo"]
        self._write_scenario(
            [self._matching_observation(trace_lines=1)],
            trace_commands=("save-buffer", "undo"),
        )
        report = self._report(ledger=self.ledger)
        path = report["paths"][0]
        self.assertEqual(path["status"], "no-trace")
        self.assertEqual(path["missing_commands"], ["undo"])

    def test_each_target_command_needs_an_effect_in_its_own_window(self):
        self.required["commands"] = ["save-buffer", "undo"]
        self.ledger["commands"] = ["save-buffer", "undo"]
        self._write_scenario(
            [self._matching_observation(trace_lines=2)],
            trace_commands=("save-buffer", "undo"),
        )
        report = self._report(ledger=self.ledger)
        path = report["paths"][0]
        self.assertEqual(path["status"], "no-observation")
        self.assertEqual(path["missing_effect_commands"], ["save-buffer"])

    def test_each_target_command_can_be_covered_by_its_own_effect_window(self):
        self.required["commands"] = ["save-buffer", "undo"]
        self.ledger["commands"] = ["save-buffer", "undo"]
        self._write_scenario(
            [
                self._matching_observation(trace_lines=1),
                self._matching_observation(trace_lines=2),
            ],
            trace_commands=("save-buffer", "undo"),
        )
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "pass")

    def test_declared_commands_must_include_the_path_target(self):
        self._write_scenario([self._matching_observation()])
        result_path = next(self.artifacts_dir.rglob("result.json"))
        result = json.loads(result_path.read_text(encoding="utf-8"))
        result["declared_commands"] = []
        result_path.write_text(json.dumps(result), encoding="utf-8")
        report = self._report(ledger=self.ledger)
        path = report["paths"][0]
        self.assertEqual(path["status"], "mismatch")
        self.assertEqual(path["missing_declared_commands"], ["save-buffer"])

    def test_result_must_name_the_expected_binary(self):
        self._write_scenario([self._matching_observation()])
        result_path = next(self.artifacts_dir.rglob("result.json"))
        result = json.loads(result_path.read_text(encoding="utf-8"))
        result["binary_realpath"] = str(self.root / "other-loom")
        result_path.write_text(json.dumps(result), encoding="utf-8")
        report = self._report(ledger=self.ledger)
        self.assertEqual(
            report["paths"][0]["reason"],
            "scenario result used a different binary",
        )

    def test_trace_from_another_scenario_is_not_used(self):
        other_scenario = self.artifacts_dir / "other-scenario"
        other_scenario.mkdir()
        (other_scenario / "trace.jsonl").write_text(
            json.dumps({"command": "save-buffer", "route": "key"}) + "\n",
            encoding="utf-8",
        )
        self._write_scenario(
            [self._matching_observation()],
            trace_name="../other-scenario/trace.jsonl",
        )
        report = self._report(ledger=self.ledger)
        path = report["paths"][0]
        self.assertEqual(path["status"], "no-trace")
        self.assertIn("escapes the result scenario directory", path["reason"])

    def test_duplicate_trace_members_are_not_accepted(self):
        self._write_scenario([self._matching_observation()])
        trace_path = next(self.artifacts_dir.rglob("trace.jsonl"))
        trace_path.write_text(
            '{"command":"save-buffer","route":"mx","route":"key"}\n',
            encoding="utf-8",
        )
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "no-trace")

    def test_mx_entry_uses_mx_trace_route(self):
        self.required["entry"] = "mx"
        self.ledger["entry"] = "mx"
        self._write_scenario([self._matching_observation()], trace_route="mx")
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "pass")

    def test_mx_prompt_entry_suffix_requires_mx_route(self):
        self.required["entry"] = "mx;prompt:2:completion"
        self.ledger["entry"] = "mx;prompt:2:completion"
        self._write_scenario([self._matching_observation()], trace_route="mx")
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "pass")

    def test_trace_uses_current_command_route_sequence_pid_shape(self):
        self._write_scenario([self._matching_observation()])
        trace_path = next(self.artifacts_dir.rglob("trace.jsonl"))
        trace = json.loads(trace_path.read_text(encoding="utf-8"))
        self.assertTrue({"command", "route", "seq", "pid"} <= set(trace))
        self.assertLessEqual(
            set(trace) - {"command", "route", "seq", "pid"}, {"entry"}
        )
        self.assertEqual(
            trace,
            {"command": "save-buffer", "route": "mx", "seq": 1, "pid": 1234},
        )
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "pass")

    def test_trace_accepts_optional_entry_field(self):
        self._write_scenario(
            [self._matching_observation()], trace_entry="mx"
        )
        trace_path = next(self.artifacts_dir.rglob("trace.jsonl"))
        trace = json.loads(trace_path.read_text(encoding="utf-8"))
        self.assertEqual(trace["entry"], "mx")
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "pass")

    def test_key_trace_entry_identity_verifies_generated_key_sequence(self):
        key_entry = (
            'key:{"keymap":"global","sequence":'
            '[{"key":"x","modifiers":["control"]},'
            '{"key":"s","modifiers":["control"]}]}'
        )
        self.required["entry"] = key_entry
        self.ledger["entry"] = key_entry
        self._write_scenario(
            [self._matching_observation()],
            trace_route="key",
            trace_entry=key_entry,
        )
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "pass")

    def test_language_key_labels_match_serialized_sequences_without_mode(self):
        cases = (
            (
                "key: RET",
                'key:{"keymap":"markdown","sequence":[{"key":"enter","modifiers":[]}]}',
            ),
            (
                "key:RET",
                'key:{"keymap":"org","sequence":[{"key":"enter","modifiers":[]}]}',
            ),
            (
                "key: TAB",
                'key:{"keymap":"markdown","sequence":[{"key":"tab","modifiers":[]}]}',
            ),
            (
                "key: C-M-backslash",
                'key:{"keymap":"org","sequence":[{"key":"\\\\","modifiers":["alt","control"]}]}',
            ),
            (
                "key: C-M-backslash",
                'key:{"keymap":"nix","sequence":[{"key":"control-backslash","modifiers":["alt"]}]}',
            ),
            (
                "key: M-;",
                'key:{"keymap":"markdown","sequence":[{"key":";","modifiers":["alt"]}]}',
            ),
        )
        for entry, trace_entry in cases:
            with self.subTest(entry=entry):
                self.required["commands"] = {
                    "key: RET": ["newline"],
                    "key:RET": ["newline"],
                    "key: TAB": ["indent-for-tab-command"],
                    "key: C-M-backslash": ["indent-for-tab-command"],
                    "key: M-;": ["comment-line"],
                }[entry]
                self.ledger["commands"] = self.required["commands"]
                self.required["entry"] = entry
                self.ledger["entry"] = entry
                self._write_scenario(
                    [self._matching_observation()],
                    trace_commands=self.required["commands"],
                    trace_route="key",
                    trace_entry=trace_entry,
                )
                report = self._report(ledger=self.ledger)
                self.assertEqual(report["paths"][0]["status"], "pass")

    def test_current_trace_shape_without_entry_cannot_verify_key_sequence(self):
        key_entry = (
            'key:{"keymap":"global","sequence":'
            '[{"key":"x","modifiers":["control"]},'
            '{"key":"s","modifiers":["control"]}]}'
        )
        self.required["entry"] = key_entry
        self.ledger["entry"] = key_entry
        self._write_scenario(
            [self._matching_observation()],
            trace_route="key",
        )
        report = self._report(ledger=self.ledger)
        path = report["paths"][0]
        self.assertEqual(path["status"], "no-trace")
        self.assertIn("identify the generated key sequence", path["reason"])

    def test_ledger_key_sequence_must_match_generated_path(self):
        self.required["entry"] = (
            'key:{"keymap":"global","sequence":["C-x","C-s"]}'
        )
        self._write_scenario([self._matching_observation()])
        self.ledger["entry"] = (
            'key:{"keymap":"global","sequence":["C-x","C-a"]}'
        )
        report = self._report(ledger=self.ledger)
        path = report["paths"][0]
        self.assertEqual(path["status"], "mismatch")
        self.assertEqual(
            path["reason"], "generated path and ledger entry do not match"
        )

    def test_duplicate_result_members_are_not_accepted(self):
        self._write_scenario([self._matching_observation()])
        result_path = next(self.artifacts_dir.rglob("result.json"))
        result = {
            "scenario": self.ledger["scenario"],
            "binary_realpath": self.binary_realpath,
            "declared_commands": ["save-buffer"],
            "observation_class": "effect-verified",
            "observations": [self._matching_observation()],
            "artifacts": {"trace": "trace.jsonl"},
        }
        serialized = json.dumps(result)
        result_path.write_text(
            serialized[:-1] + ',"status":"failed","status":"passed"}\n',
            encoding="utf-8",
        )
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "no-result")

    def test_mismatching_observation_is_not_pass_even_if_passed_flag_says_true(self):
        self._write_scenario(
            [
                self._matching_observation(
                    actual={"encoding": "base64", "data": "b2xk", "length": 3},
                    passed=True,
                )
            ]
        )
        report = self._report(ledger=self.ledger)
        path = report["paths"][0]
        self.assertEqual(path["status"], "mismatch")
        self.assertEqual(path["mismatches"][0]["actual"]["data"], "b2xk")

    def test_missing_actual_does_not_match_a_null_expectation(self):
        self.required["observe"] = ["external_state"]
        self.ledger["observe"] = ["external_state"]
        self._write_scenario([{"type": "external_state", "expected": None}])
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "mismatch")

    def test_scenario_without_passed_status_fails_closed(self):
        self._write_scenario([self._matching_observation()], status=None)
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "mismatch")

    def test_observation_type_must_match_generated_and_ledger_requirements(self):
        self.required["observe"] = ["screen_text"]
        self.ledger["observe"] = ["file_bytes"]
        self._write_scenario(
            [
                {
                    "type": "screen_text",
                    "actual": "saved",
                    "expected": "saved",
                    "passed": True,
                    "sequence": 0,
                    "trace_lines": 1,
                    "purpose": "scenario",
                }
            ]
        )
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "no-observation")

    def test_save_screen_text_alone_does_not_verify_declared_file_bytes_effect(self):
        self.required["entry"] = (
            'key:{"keymap":"global","sequence":["C-x","C-s"]}'
        )
        self.ledger["entry"] = self.required["entry"]
        self.required["observe"] = ["screen_text"]
        self.ledger["observe"] = ["file_bytes"]
        self._write_scenario(
            [
                {
                    "type": "file_bytes",
                    "actual": {"encoding": "base64", "data": "YmV0YQ==", "length": 4},
                    "expected": {"encoding": "base64", "data": "YmV0YQ==", "length": 4},
                    "passed": True,
                    "sequence": 0,
                    "trace_lines": 1,
                    "purpose": "precondition",
                    "target": "file.txt",
                },
                {
                    "type": "screen_text",
                    "actual": "!beta",
                    "expected": "!beta",
                    "passed": True,
                    "sequence": 1,
                    "trace_lines": 1,
                    "purpose": "scenario",
                    "match": "contains",
                    "region": "body",
                },
            ],
            trace_route="key",
        )
        report = self._report(ledger=self.ledger)
        path = report["paths"][0]
        self.assertEqual(path["status"], "no-observation")
        self.assertIn("non-precondition", path["reason"])

    def test_ledger_effect_type_can_override_generic_generated_observation(self):
        self.required["observe"] = ["screen_text"]
        self.ledger["observe"] = ["file_bytes"]
        self._write_scenario([self._matching_observation()])
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "pass")

    def test_effect_after_an_unrelated_command_remains_in_target_window(self):
        self.required["observe"] = ["screen_text"]
        self.ledger["observe"] = ["screen_text"]
        self._write_scenario(
            [
                {
                    "type": "screen_text",
                    "actual": "saved",
                    "expected": "saved",
                    "passed": True,
                    "sequence": 0,
                    "trace_lines": 2,
                    "purpose": "scenario",
                    "match": "contains",
                    "region": "body",
                }
            ],
            trace_commands=("save-buffer", "other-command"),
        )
        report = self._report(ledger=self.ledger)
        path = report["paths"][0]
        self.assertEqual(path["status"], "pass")
        self.assertFalse(report["has_failures"])

    def test_empty_ledger_observation_requirement_cannot_pass(self):
        self.ledger["observe"] = []
        self._write_scenario([self._matching_observation()])
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "no-observation")

    def test_effect_unverified_classification_prevents_pass(self):
        self._write_scenario(
            [self._matching_observation(passed=False)],
            observation_class="effect-unverified",
        )
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "no-observation")
        self.assertTrue(report["has_failures"])

    def test_pty_output_is_a_verified_effect_observation(self):
        self.required["observe"] = ["pty_output"]
        self.ledger["observe"] = ["pty_output"]
        self._write_scenario(
            [
                self._matching_observation(
                    type="pty_output",
                    actual="saved",
                    expected="saved",
                    match="contains",
                )
            ]
        )
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "pass")
        self.assertEqual(
            report["scenario_observation_classes"]["effect-verified"], 1
        )

    def test_valid_exclusion_is_excluded_without_artifacts(self):
        (self.repo_root / "evidence.txt").write_text("reason\n", encoding="utf-8")
        report = self._report(
            exclusions=[
                {"id": self.required["id"], "reason": "not applicable", "evidence": "evidence.txt:1"}
            ]
        )
        self.assertEqual(report["paths"][0]["status"], "excluded")
        self.assertFalse(report["paths"][0]["failed"])
        self.assertFalse(report["has_failures"])

    def test_nonexistent_exclusion_evidence_fails_and_does_not_hide_path(self):
        self._write_scenario([self._matching_observation()])
        report = self._report(
            ledger=self.ledger,
            exclusions=[
                {"id": self.required["id"], "reason": "not applicable", "evidence": "missing.txt:1"}
            ],
        )
        path = report["paths"][0]
        self.assertEqual(path["status"], "pass")
        self.assertTrue(path["failed"])
        self.assertIn("invalid exclusion evidence", path["failure_reasons"][0])
        self.assertEqual(report["missing_paths"][0]["id"], self.required["id"])
        self.assertTrue(report["has_failures"])

    def test_precondition_effect_and_exit_code_do_not_satisfy_observation_gate(self):
        self._write_scenario(
            [
                {
                    "type": "screen_text",
                    "actual": "ready",
                    "expected": "ready",
                    "purpose": "precondition",
                    "sequence": 0,
                    "trace_lines": 0,
                },
                {
                    "type": "exit_code",
                    "actual": 0,
                    "expected": 0,
                    "sequence": 1,
                    "trace_lines": 0,
                    "purpose": "scenario",
                },
            ],
            observation_class="exit-code-only",
        )
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "no-observation")

    def test_commandless_r6_signal_paths_pass_with_matching_external_state(self):
        cases = (
            (
                "r6:signal:sigterm",
                "SIGTERM",
                "process exits and recovers state",
            ),
            (
                "r6:signal:sighup",
                "SIGHUP",
                "process exits and recovers state",
            ),
            (
                "r6:signal:sigtstp-cont",
                "SIGTSTP then SIGCONT",
                "terminal suspends and resumes",
            ),
        )
        for path_id, entry, outcome in cases:
            with self.subTest(path_id=path_id):
                self._configure_path(
                    path_id=path_id,
                    commands=[],
                    rule="r6",
                    lane="W3-2",
                    entry=entry,
                    state="running-process",
                    outcome=outcome,
                    observe=["external_state"],
                    scenario=f"lifecycle/{path_id.replace(':', '-')}",
                )
                self._write_scenario(
                    [
                        {
                            "type": "external_state",
                            "actual": "recovered",
                            "expected": "recovered",
                            "passed": True,
                            "purpose": "scenario",
                        }
                    ],
                    trace_commands=(),
                )

                report = self._report(ledger=self.ledger)

                self.assertEqual(report["paths"][0]["status"], "pass")
                self.assertFalse(report["paths"][0]["failed"])

    def test_commandless_r6_route_passes_when_all_declared_effects_match(self):
        self._configure_path(
            path_id="r6:resize",
            commands=[],
            rule="r6",
            lane="W3-4",
            entry="terminal-resize",
            state="resized-terminal",
            outcome="screen redraws",
            observe=["screen_text", "cursor"],
            scenario="lifecycle/resize",
        )
        self._write_scenario(
            [
                {
                    "type": "screen_text",
                    "actual": "redrawn frame",
                    "expected": "redrawn frame",
                    "passed": True,
                    "purpose": "scenario",
                },
                {
                    "type": "cursor",
                    "actual": [0, 0],
                    "expected": [0, 0],
                    "passed": True,
                    "purpose": "scenario",
                },
            ],
            trace_commands=(),
        )

        report = self._report(ledger=self.ledger)

        self.assertEqual(report["paths"][0]["status"], "pass")
        self.assertFalse(report["has_failures"])

    def test_commandless_r6_route_requires_observations_for_all_declared_effects(self):
        self._configure_path(
            path_id="r6:resize",
            commands=[],
            rule="r6",
            lane="W3-4",
            entry="terminal-resize",
            state="resized-terminal",
            outcome="screen redraws",
            observe=["screen_text", "cursor"],
            scenario="lifecycle/resize",
        )
        self._write_scenario(
            [
                {
                    "type": "screen_text",
                    "actual": "redrawn frame",
                    "expected": "redrawn frame",
                    "passed": True,
                    "purpose": "scenario",
                }
            ],
            trace_commands=(),
        )

        report = self._report(ledger=self.ledger)

        self.assertEqual(report["paths"][0]["status"], "no-observation")

    def test_commandless_r6_signal_path_rejects_precondition_only_observations(self):
        self._configure_path(
            path_id="r6:signal:sigterm",
            commands=[],
            rule="r6",
            lane="W3-2",
            entry="SIGTERM",
            state="running-process",
            outcome="process exits and recovers state",
            observe=["external_state"],
            scenario="lifecycle/sigterm-recovery",
        )
        self._write_scenario(
            [
                {
                    "type": "external_state",
                    "actual": "recovered",
                    "expected": "recovered",
                    "passed": True,
                    "purpose": "precondition",
                }
            ],
            trace_commands=(),
            observation_class="none",
        )

        report = self._report(ledger=self.ledger)

        self.assertEqual(report["paths"][0]["status"], "no-observation")

    def test_commandless_r6_signal_path_rejects_empty_observations(self):
        self._configure_path(
            path_id="r6:signal:sigterm",
            commands=[],
            rule="r6",
            lane="W3-2",
            entry="SIGTERM",
            state="running-process",
            outcome="process exits and recovers state",
            observe=["external_state"],
            scenario="lifecycle/sigterm-recovery",
        )
        self._write_scenario(
            [],
            trace_commands=(),
            observation_class="none",
        )

        report = self._report(ledger=self.ledger)

        self.assertEqual(report["paths"][0]["status"], "no-observation")

    def test_commandless_r6_signal_path_requires_an_expected_value(self):
        self._configure_path(
            path_id="r6:signal:sigterm",
            commands=[],
            rule="r6",
            lane="W3-2",
            entry="SIGTERM",
            state="running-process",
            outcome="process exits and recovers state",
            observe=["external_state"],
            scenario="lifecycle/sigterm-recovery",
        )
        self._write_scenario(
            [
                {
                    "type": "external_state",
                    "actual": "recovered",
                    "passed": True,
                    "purpose": "scenario",
                }
            ],
            trace_commands=(),
            observation_class="effect-unverified",
        )

        report = self._report(ledger=self.ledger)

        self.assertEqual(report["paths"][0]["status"], "no-observation")

    def test_commandless_r6_signal_path_rejects_mismatched_observation(self):
        self._configure_path(
            path_id="r6:signal:sigterm",
            commands=[],
            rule="r6",
            lane="W3-2",
            entry="SIGTERM",
            state="running-process",
            outcome="process exits and recovers state",
            observe=["external_state"],
            scenario="lifecycle/sigterm-recovery",
        )
        self._write_scenario(
            [
                {
                    "type": "external_state",
                    "actual": "not-recovered",
                    "expected": "recovered",
                    "passed": True,
                    "purpose": "scenario",
                }
            ],
            trace_commands=(),
        )

        report = self._report(ledger=self.ledger)

        self.assertEqual(report["paths"][0]["status"], "mismatch")

    def test_commandless_r6_signal_path_rejects_failed_scenario(self):
        self._configure_path(
            path_id="r6:signal:sigterm",
            commands=[],
            rule="r6",
            lane="W3-2",
            entry="SIGTERM",
            state="running-process",
            outcome="process exits and recovers state",
            observe=["external_state"],
            scenario="lifecycle/sigterm-recovery",
        )
        self._write_scenario(
            [
                {
                    "type": "external_state",
                    "actual": "recovered",
                    "expected": "recovered",
                    "passed": True,
                    "purpose": "scenario",
                }
            ],
            trace_commands=(),
            status="failed",
        )

        report = self._report(ledger=self.ledger)

        self.assertEqual(report["paths"][0]["status"], "mismatch")

    def test_unrelated_commandless_path_still_requires_trace(self):
        self._configure_path(
            path_id="r7:plus-n",
            commands=[],
            rule="r7",
            lane="W3-2",
            entry="+N FILE",
            state="$EDITOR invocation",
            outcome="line argument opens the requested line",
            observe=["external_state"],
            scenario="startup/plus-n",
        )
        self._write_scenario(
            [
                {
                    "type": "external_state",
                    "actual": "opened",
                    "expected": "opened",
                    "passed": True,
                    "purpose": "scenario",
                }
            ],
            trace_commands=(),
        )

        report = self._report(ledger=self.ledger)

        self.assertEqual(report["paths"][0]["status"], "no-trace")

    def test_cell_attributes_compare_expected_subset(self):
        self.required["observe"] = ["cell_attrs"]
        self.ledger["observe"] = ["cell_attrs"]
        self._write_scenario(
            [
                {
                    "type": "cell_attrs",
                    "actual": {"data": "X", "reverse": True, "bold": False},
                    "expected": {"reverse": True},
                    "passed": True,
                    "sequence": 0,
                    "trace_lines": 1,
                    "purpose": "scenario",
                }
            ]
        )
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "pass")

    def test_match_mode_and_rollups_are_reflected_in_report(self):
        self.required["commands"] = ["save-buffer", "undo"]
        self.ledger["commands"] = ["save-buffer", "undo"]
        self.required["observe"] = ["screen_text"]
        self.ledger["observe"] = ["screen_text"]
        self._write_scenario(
            [
                {
                    "type": "screen_text",
                    "actual": "saved",
                    "expected": "saved",
                    "passed": True,
                    "sequence": 0,
                    "trace_lines": 1,
                    "purpose": "scenario",
                    "match": "contains",
                },
                {
                    "type": "screen_text",
                    "actual": "file saved",
                    "expected": "saved",
                    "passed": True,
                    "sequence": 1,
                    "trace_lines": 2,
                    "purpose": "scenario",
                    "match": "contains",
                },
            ],
            trace_commands=("save-buffer", "undo"),
        )
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "pass")
        self.assertEqual(report["by_rule"]["r1"]["pass"], 1)
        self.assertEqual(report["by_lane"]["W3-3"]["total"], 1)
        self.assertEqual(
            report["scenario_observation_classes"]["effect-verified"], 1
        )
        self.assertIn("1 pass", render_summary(report))
        self.assertIn("effect-verified: 1", render_summary(report))
        destination = self.root / "reports" / "coverage.json"
        write_report(report, destination)
        self.assertEqual(json.loads(destination.read_text(encoding="utf-8")), report)

    def test_by_lane_includes_zero_count_registered_lanes(self):
        report = self._report(ledger=self.ledger)
        lanes = set(LANE_REGISTRY.values())

        self.assertEqual(set(report["by_lane"]), lanes)
        for lane in lanes - {self.required["lane"]}:
            counts = report["by_lane"][lane]
            self.assertEqual(
                {key: counts[key] for key in ("pass", "excluded", "failures", "total")},
                {"pass": 0, "excluded": 0, "failures": 0, "total": 0},
            )

        summary = report["summary"]
        self.assertEqual(summary.count("By lane:"), 1)
        lane_rows = [line for line in summary.splitlines() if line.startswith("  W3-")]
        expected_rows = [
            f"  {lane}: pass={counts['pass']} excluded={counts['excluded']} "
            f"failures={counts['failures']} total={counts['total']}"
            for lane, counts in report["by_lane"].items()
        ]
        self.assertEqual(lane_rows, expected_rows)
        self.assertEqual(len(lane_rows), len(lanes))


if __name__ == "__main__":
    unittest.main()
