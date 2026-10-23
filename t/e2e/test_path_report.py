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
        self.repo_root.mkdir()
        self.artifacts_dir.mkdir()
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
            "entry": "key",
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
    ):
        scenario_dir = self.artifacts_dir / "files-save-buffer"
        scenario_dir.mkdir(exist_ok=True)
        result = {
            "scenario": self.ledger["scenario"],
            "observations": observations,
            "artifacts": {"trace": "trace.jsonl"},
        }
        if status is not None:
            result["status"] = status
        (scenario_dir / "result.json").write_text(
            json.dumps(result), encoding="utf-8"
        )
        with (scenario_dir / "trace.jsonl").open("w", encoding="utf-8") as handle:
            for command in trace_commands:
                handle.write(
                    json.dumps({"command": command, "route": trace_route}) + "\n"
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
            selected_scenarios,
        )

    def _matching_observation(self, **overrides):
        return {
            "type": "file_bytes",
            "actual": {"encoding": "base64", "data": "bmV3", "length": 3},
            "expected": {"encoding": "base64", "data": "bmV3", "length": 3},
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
            [{"type": "exit_code", "actual": 0, "expected": 0, "passed": True}]
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

    def test_mx_entry_uses_mx_trace_route(self):
        self.required["entry"] = "mx"
        self.ledger["entry"] = "mx"
        self._write_scenario([self._matching_observation()], trace_route="mx")
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "pass")

    def test_mx_prompt_entry_suffix_requires_mx_route(self):
        self.required["entry"] = "mx;prompt:2:completion"
        self.ledger["entry"] = "mx"
        self._write_scenario([self._matching_observation()], trace_route="mx")
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "pass")

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

    def test_matching_observation_passes_without_trusting_passed_flag(self):
        self._write_scenario([self._matching_observation(passed=False)])
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "pass")
        self.assertFalse(report["has_failures"])

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
                },
                {"type": "exit_code", "actual": 0, "expected": 0},
            ]
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
                }
            ]
        )
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "pass")

    def test_match_mode_and_rollups_are_reflected_in_report(self):
        self.required["commands"] = ["save-buffer", "undo"]
        self.required["observe"] = ["screen_text"]
        self._write_scenario(
            [
                {
                    "type": "screen_text",
                    "actual": "file saved",
                    "expected": "saved",
                    "match": "contains",
                }
            ],
            trace_commands=("save-buffer", "undo"),
        )
        self.ledger["commands"] = ["save-buffer", "undo"]
        self.ledger["observe"] = ["screen_text"]
        report = self._report(ledger=self.ledger)
        self.assertEqual(report["paths"][0]["status"], "pass")
        self.assertEqual(report["by_rule"]["r1"]["pass"], 1)
        self.assertEqual(report["by_lane"]["W3-3"]["total"], 1)
        self.assertIn("1 pass", render_summary(report))
        destination = self.root / "reports" / "coverage.json"
        write_report(report, destination)
        self.assertEqual(json.loads(destination.read_text(encoding="utf-8")), report)


if __name__ == "__main__":
    unittest.main()
