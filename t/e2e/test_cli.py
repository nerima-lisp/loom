import contextlib
import importlib.util
import io
import os
import json
import tempfile
import unittest
from unittest.mock import call, patch

from loom_e2e import commands, registry


_SPEC = importlib.util.spec_from_file_location(
    "loom_test_cli", os.path.join(os.path.dirname(__file__), "loom-test.py")
)
cli = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(cli)


def _catalog_entry(command_id, name):
    return {
        "id": command_id,
        "name": name,
        "owner": "feature/test",
        "keymap": "global",
        "mx-eligible": name is not None,
    }


class CommandCatalogTests(unittest.TestCase):
    def test_catalog_is_read_from_the_runtime_session(self):
        payload = [_catalog_entry("forward-char", "forward-char")]
        with patch.object(commands, "Session") as session_type:
            session = session_type.return_value.__enter__.return_value
            session.process.wait.return_value = (
                json.dumps(payload).encode("utf-8"),
                0,
            )
            self.assertEqual(commands.load_command_catalog("loom"), payload)
        session_type.assert_called_once_with("loom", ["--dump-catalog"])

    def _load_payload(self, payload):
        with patch.object(commands, "Session") as session_type:
            session = session_type.return_value.__enter__.return_value
            session.process.wait.return_value = (
                json.dumps(payload).encode("utf-8"),
                0,
            )
            return commands.load_command_catalog("loom")

    def test_catalog_accepts_null_name_with_canonical_id(self):
        payload = [_catalog_entry("execute-extended-command", None)]
        self.assertEqual(self._load_payload(payload), payload)

    def test_catalog_accepts_id_different_from_name(self):
        payload = [_catalog_entry("forward-char", "legacy-forward")]
        self.assertEqual(self._load_payload(payload), payload)
        self.assertEqual(commands.catalog_command_ids(payload), {"forward-char"})

    def test_catalog_rejects_missing_id(self):
        payload = [_catalog_entry("forward-char", "forward-char")]
        del payload[0]["id"]
        with self.assertRaisesRegex(RuntimeError, "invalid command ID"):
            self._load_payload(payload)

    def test_catalog_rejects_duplicate_ids(self):
        payload = [
            _catalog_entry("forward-char", "forward-char"),
            _catalog_entry("forward-char", "next-command"),
        ]
        with self.assertRaisesRegex(RuntimeError, "duplicate command ID"):
            self._load_payload(payload)


class CoverageCliTests(unittest.TestCase):
    def setUp(self):
        self.contexts = contextlib.ExitStack()
        self.addCleanup(self.contexts.close)
        self.forward = lambda binary: None
        self.backward = lambda binary: None
        self.registered = [
            ("forward", ["forward-char"], self.forward),
            ("backward", ["backward-char"], self.backward),
        ]
        self.catalogue = self.contexts.enter_context(patch.object(
            cli.commands, "load_command_catalog",
            return_value=[
                _catalog_entry("forward-char", "forward-char"),
                _catalog_entry("backward-char", "backward-char"),
            ],
        ))
        self.contexts.enter_context(patch.object(registry, "_scenarios", self.registered))
        self.binary = self.contexts.enter_context(patch.object(
            cli, "_binary_from_arguments", return_value="loom",
        ))
        self.preflight = self.contexts.enter_context(patch.object(cli, "_run_harness_preflight"))
        self.path_report = self.contexts.enter_context(patch.object(
            cli, "_path_coverage_report", return_value={"has_failures": False},
        ))
        self.run = self.contexts.enter_context(patch.object(cli, "run_scenario"))
        self.stdout = self.contexts.enter_context(contextlib.redirect_stdout(io.StringIO()))
        self.stderr = self.contexts.enter_context(contextlib.redirect_stderr(io.StringIO()))

    def test_partial_run_reports_only_selected_commands(self):
        self.assertEqual(cli.main(["--only", "forward"]), 0)
        self.assertIn("commands covered: 1 / 2", self.stdout.getvalue())
        self.assertIn("uncovered commands: backward-char", self.stdout.getvalue())
        self.run.assert_called_once_with(self.forward, "loom")
        self.preflight.assert_called_once_with()

    def test_partial_run_cannot_claim_full_coverage(self):
        self.assertEqual(cli.main([
            "--only", "forward", "--require-full-coverage",
        ]), 1)
        self.run.assert_called_once_with(self.forward, "loom")
        self.preflight.assert_called_once_with()

    def test_full_run_reports_full_coverage(self):
        self.assertEqual(cli.main([]), 0)
        self.assertIn("commands covered: 2 / 2", self.stdout.getvalue())
        self.assertEqual(self.run.call_args_list, [
            call(self.forward, "loom"), call(self.backward, "loom"),
        ])
        self.preflight.assert_called_once_with()

    def test_list_reports_registered_coverage_without_running(self):
        self.assertEqual(cli.main(["--list"]), 0)
        self.assertIn("commands covered: 2 / 2", self.stdout.getvalue())
        self.run.assert_not_called()
        self.preflight.assert_not_called()
        self.catalogue.assert_called_once_with("loom")

    def test_unknown_selected_command_fails(self):
        self.registered[0][1].append("unknown-command")
        self.assertEqual(cli.main(["--only", "forward"]), 1)
        self.assertIn("unknown-command", self.stdout.getvalue())

    def test_coverage_matches_null_name_by_canonical_id(self):
        selected = [
            ("execute", ["execute-extended-command"], self.forward),
        ]
        result = cli._coverage_report(
            selected,
            [_catalog_entry("execute-extended-command", None)],
        )
        self.assertEqual(result, ([], []))
        self.assertIn("commands covered: 1 / 1", self.stdout.getvalue())

    def test_coverage_matches_id_when_name_differs(self):
        selected = [("forward", ["forward-char"], self.forward)]
        result = cli._coverage_report(
            selected,
            [_catalog_entry("forward-char", "legacy-forward")],
        )
        self.assertEqual(result, ([], []))
        self.assertIn("commands covered: 1 / 1", self.stdout.getvalue())

    def test_coverage_rejects_missing_and_duplicate_ids(self):
        missing_id = _catalog_entry("forward-char", "forward-char")
        del missing_id["id"]
        duplicate_ids = [
            _catalog_entry("forward-char", "forward-char"),
            _catalog_entry("forward-char", "next-command"),
        ]
        for catalog, message in (
            ([missing_id], "invalid command ID"),
            (duplicate_ids, "duplicate command ID"),
        ):
            with self.subTest(message=message):
                with self.assertRaisesRegex(RuntimeError, message):
                    cli._coverage_report([], catalog)

    def test_empty_catalogue_fails(self):
        self.catalogue.return_value = []
        with self.assertRaisesRegex(SystemExit, "command-spec catalogue is empty"):
            cli.main(["--list"])

    def test_path_coverage_flag_fails_on_report_gaps(self):
        with patch.object(
            cli,
            "_path_coverage_report",
            return_value={"has_failures": True},
        ):
            self.assertEqual(cli.main(["--only", "forward", "--require-path-coverage"]), 1)

    def test_report_mode_does_not_fail_on_path_gaps(self):
        with patch.object(
            cli,
            "_path_coverage_report",
            return_value={"has_failures": True},
        ):
            self.assertEqual(cli.main(["--only", "forward"]), 0)

    def test_partial_run_limits_path_report_to_selected_scenarios(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(cli.main([
                "--only", "forward", "--artifacts-dir", directory,
            ]), 0)
        self.assertEqual(
            self.path_report.call_args.kwargs["selected_scenarios"],
            {"forward"},
        )
        self.assertEqual(
            self.path_report.call_args.args[2], os.path.realpath("loom")
        )

    def test_unmatched_filter_runs_nothing(self):
        with self.assertRaisesRegex(SystemExit, "matched no scenario"):
            cli.main(["--only", "missing"])
        self.preflight.assert_not_called()
        self.run.assert_not_called()

    def test_failed_selected_scenario_fails_with_full_coverage(self):
        self.run.side_effect = AssertionError("scenario failed")
        self.assertEqual(cli.main([]), 1)
        self.assertIn("0 passed, 2 failed, 2 total", self.stdout.getvalue())
        self.assertIn("scenario failed", self.stderr.getvalue())

    def test_unexpected_scenario_exceptions_are_counted_as_failures(self):
        for error_type in (ValueError, KeyError, TypeError, RuntimeError):
            with self.subTest(error_type=error_type.__name__):
                self.run.reset_mock()
                self.run.side_effect = error_type("scenario failed")
                self.assertEqual(cli.main(["--only", "forward"]), 1)
                self.assertIn("0 passed, 1 failed, 1 total", self.stdout.getvalue())
                self.assertIn("scenario failed", self.stderr.getvalue())

    def test_artifacts_dir_saves_per_scenario_files(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(cli.main([
                "--only", "forward", "--artifacts-dir", directory,
            ]), 0)
            scenario_dirs = [
                os.path.join(directory, name)
                for name in os.listdir(directory)
                if os.path.isdir(os.path.join(directory, name))
            ]
            self.assertEqual(len(scenario_dirs), 1)
            with open(os.path.join(scenario_dirs[0], "trace.jsonl"), "rb") as handle:
                self.assertEqual(handle.read(), b"")
            with open(os.path.join(scenario_dirs[0], "output.pty"), "rb") as handle:
                self.assertEqual(handle.read(), b"")
            with open(os.path.join(scenario_dirs[0], "result.json"), encoding="utf-8") as handle:
                result = json.load(handle)
            self.assertEqual(result["scenario"], "forward")
            self.assertEqual(result["status"], "passed")
            self.assertEqual(result["binary_realpath"], os.path.realpath("loom"))
            self.assertEqual(result["declared_commands"], ["forward-char"])

    def test_default_artifact_directories_are_printed_and_retained(self):
        self.assertEqual(cli.main(["--only", "forward"]), 0)
        self.assertEqual(cli.main(["--only", "forward"]), 0)
        paths = [
            line.removeprefix("scenario artifacts: ")
            for line in self.stdout.getvalue().splitlines()
            if line.startswith("scenario artifacts: ")
        ]
        self.assertEqual(len(paths), 2)
        self.assertNotEqual(paths[0], paths[1])
        for path in paths:
            self.assertTrue(os.path.isdir(path))
            result_files = [
                os.path.join(root, filename)
                for root, _dirs, files in os.walk(path)
                for filename in files
                if filename == "result.json"
            ]
            self.assertEqual(len(result_files), 1)

    def test_benchmark_mode_reports_over_target_without_failing(self):
        def startup(binary):
            return {"startup_to_first_screen_seconds": 0.4}

        def redraw(binary):
            return {"input_to_redraw_p95_milliseconds": 60.0}

        def large_file_open(binary):
            return {
                "open_100000_lines_5mb_seconds": 1.2,
                "input": {"lines": 100_000, "bytes": 5_000_000},
            }

        self.run.side_effect = lambda function, binary: function(binary)
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(
                cli,
                "benchmark_scenarios",
                return_value={
                    "startup": startup,
                    "redraw": redraw,
                    "large-file-open": large_file_open,
                },
            ):
                self.assertEqual(cli.main([
                    "--benchmarks", "--artifacts-dir", directory,
                ]), 0)
            self.assertIn("over target", self.stdout.getvalue())
            self.assertEqual(
                self.run.call_args_list,
                [
                    call(startup, "loom"),
                    call(redraw, "loom"),
                    call(large_file_open, "loom"),
                ],
            )
            with open(os.path.join(directory, "benchmarks.json"), encoding="utf-8") as handle:
                report = json.load(handle)
            self.assertEqual(report["measurements"], {
                "startup_to_first_screen_seconds": 0.4,
                "open_100000_lines_5mb_seconds": 1.2,
                "input_to_redraw_p95_milliseconds": 60.0,
            })
            self.assertEqual(report["input"], {"lines": 100_000, "bytes": 5_000_000})
            self.assertFalse(any(report["within_targets"].values()))

    def test_benchmark_gate_fails_when_targets_are_missed(self):
        scenarios = {
            "startup": lambda _binary: {
                "startup_to_first_screen_seconds": 0.4,
            },
            "redraw": lambda _binary: {
                "input_to_redraw_p95_milliseconds": 60.0,
            },
            "large-file-open": lambda _binary: {
                "open_100000_lines_5mb_seconds": 1.2,
                "input": {"lines": 100_000, "bytes": 5_000_000},
            },
        }
        self.run.side_effect = lambda function, binary: function(binary)
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(cli, "benchmark_scenarios", return_value=scenarios):
                self.assertEqual(cli.main([
                    "--benchmark-gate", "--artifacts-dir", directory,
                ]), 1)
        self.assertIn("FAIL PTY performance gate", self.stderr.getvalue())
        self.assertIn("open_100000_lines_5mb", self.stderr.getvalue())
        self.assertIn("input_to_redraw_p95", self.stderr.getvalue())

    def test_benchmark_gate_passes_when_targets_are_met(self):
        scenarios = {
            "startup": lambda _binary: {
                "startup_to_first_screen_seconds": 0.2,
            },
            "redraw": lambda _binary: {
                "input_to_redraw_p95_milliseconds": 10.0,
            },
            "large-file-open": lambda _binary: {
                "open_100000_lines_5mb_seconds": 0.8,
                "input": {"lines": 100_000, "bytes": 5_000_000},
            },
        }
        self.run.side_effect = lambda function, binary: function(binary)
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(cli, "benchmark_scenarios", return_value=scenarios):
                self.assertEqual(cli.main([
                    "--benchmark-gate", "--artifacts-dir", directory,
                ]), 0)
        self.assertNotIn("FAIL PTY performance gate", self.stderr.getvalue())

    def test_benchmark_gate_fails_with_elapsed_value_when_open_expires(self):
        scenarios = {
            "startup": lambda _binary: {
                "startup_to_first_screen_seconds": 0.2,
            },
            "redraw": lambda _binary: {
                "input_to_redraw_p95_milliseconds": 10.0,
            },
            "large-file-open": lambda _binary: {
                "open_100000_lines_5mb_seconds": 5.0,
                "samples": [5.0],
                "first_row_observed": False,
                "completed_samples": [False],
                "completed": False,
                "input": {"lines": 100_000, "bytes": 5_000_000},
            },
        }
        self.run.side_effect = lambda function, binary: function(binary)
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(cli, "benchmark_scenarios", return_value=scenarios):
                self.assertEqual(cli.main([
                    "--benchmark-gate", "--artifacts-dir", directory,
                ]), 1)
        self.assertIn(
            "over target; first row not observed by execution deadline",
            self.stdout.getvalue(),
        )
        self.assertIn("samples=[5.0]", self.stdout.getvalue())
        self.assertIn("FAIL PTY performance gate", self.stderr.getvalue())

    def test_benchmark_mode_prints_timed_out_open_sample(self):
        def trial(value, first_row_observed):
            return lambda _binary: {
                "open_100000_lines_5mb_seconds": value,
                "samples": [value],
                "first_row_observed": first_row_observed,
                "input": {"lines": 100_000, "bytes": 5_000_000},
                "eof_samples": [],
            }

        self.run.side_effect = lambda function, binary: function(binary)
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(
                cli,
                "benchmark_scenarios",
                return_value={
                    "large-file-open-trial-1": trial(0.8, True),
                    "large-file-open-trial-2": trial(3.5, False),
                    "large-file-open-trial-3": trial(0.9, True),
                },
            ):
                self.assertEqual(cli.main([
                    "--benchmarks", "--artifacts-dir", directory,
                ]), 0)

        self.assertIn(
            "open_100000_lines_5mb_seconds: 0.900 (target 1; over target; "
            "first row not observed by execution deadline; "
            "samples=[0.8, 3.5, 0.9])",
            self.stdout.getvalue(),
        )

    def test_benchmark_mode_reports_failed_scenarios_as_missing_metrics(self):
        def startup(binary):
            return {"startup_to_first_screen_seconds": 0.2}

        def redraw(binary):
            return {"input_to_redraw_p95_milliseconds": 20.0}

        def large_file_open(binary):
            raise TimeoutError("scenario execution deadline expired")

        self.run.side_effect = lambda function, binary: function(binary)
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(
                cli,
                "benchmark_scenarios",
                return_value={
                    "startup": startup,
                    "redraw": redraw,
                    "large-file-open": large_file_open,
                },
            ):
                self.assertEqual(cli.main([
                    "--benchmarks", "--artifacts-dir", directory,
                ]), 0)

            self.assertIn(
                "open_100000_lines_5mb_seconds: missing (target 1)",
                self.stdout.getvalue(),
            )
            self.assertIn("large-file-open", self.stderr.getvalue())
            with open(
                os.path.join(directory, "benchmarks.json"), encoding="utf-8"
            ) as handle:
                report = json.load(handle)
            self.assertIn(
                "open_100000_lines_5mb_seconds", report["missing_metrics"]
            )
            self.assertEqual(report["scenario_errors"], ["large-file-open"])


if __name__ == "__main__":
    unittest.main()
