import json
import tempfile
import unittest
from pathlib import Path

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
            "entry": 'key:{"keymap":"global","sequence":["C-x","C-s"]}',
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
        trace_route="key",
        trace_name="trace.jsonl",
        observation_class="effect-verified",
        trace_entry=None,
    ):
        scenario_dir = self.artifacts_dir / "files-save-buffer"
        scenario_dir.mkdir(exist_ok=True)
        result = {
            "scenario": self.ledger["scenario"],
            "binary_realpath": self.binary_realpath,
            "declared_commands": list(self.ledger["commands"]),
            "observation_class": observation_class,
            "observations": observations,
            "artifacts": {"trace": trace_name},
        }
        if status is not None:
            result["status"] = status
        (scenario_dir / "result.json").write_text(
            json.dumps(result), encoding="utf-8"
        )
        if trace_entry is None:
            trace_entry = self.required["entry"].split(";prompt:", 1)[0]
        with (scenario_dir / "trace.jsonl").open("w", encoding="utf-8") as handle:
            for command in trace_commands:
                handle.write(
                    json.dumps(
                        {"command": command, "route": trace_route, "entry": trace_entry}
                    )
                    + "\n"
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
            "purpose": "scenario",
            **overrides,
        }

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

    def test_trace_from_the_wrong_entry_route_does_not_satisfy_path(self):
        self._write_scenario(
            [self._matching_observation()], trace_route="mx"
        )
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "no-trace")
        self.assertEqual(report["paths"][0]["missing_commands"], ["save-buffer"])

    def test_key_route_without_the_encoded_sequence_is_not_pass(self):
        self._write_scenario(
            [self._matching_observation()], trace_entry="key"
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

    def test_ledger_key_sequence_must_match_generated_path(self):
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
                    "actual": "file saved",
                    "expected": "saved",
                    "passed": True,
                    "sequence": 0,
                    "trace_lines": 2,
                    "purpose": "scenario",
                    "match": "contains",
                }
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


if __name__ == "__main__":
    unittest.main()
