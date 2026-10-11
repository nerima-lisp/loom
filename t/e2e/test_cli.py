import contextlib
import importlib.util
import io
import os
import unittest
from unittest.mock import call, patch

from loom_e2e import registry


_SPEC = importlib.util.spec_from_file_location(
    "loom_test_cli", os.path.join(os.path.dirname(__file__), "loom-test.py")
)
cli = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(cli)


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
            cli.commands, "parse_command_names",
            return_value=["forward-char", "backward-char"],
        ))
        self.contexts.enter_context(patch.object(registry, "_scenarios", self.registered))
        self.binary = self.contexts.enter_context(patch.object(
            cli, "_binary_from_arguments", return_value="loom",
        ))
        self.preflight = self.contexts.enter_context(patch.object(cli, "_run_deadline_preflight"))
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
        self.binary.assert_not_called()

    def test_unknown_selected_command_fails(self):
        self.registered[0][1].append("unknown-command")
        self.assertEqual(cli.main(["--only", "forward"]), 1)
        self.assertIn("unknown-command", self.stdout.getvalue())

    def test_empty_catalogue_fails(self):
        self.catalogue.return_value = []
        with self.assertRaisesRegex(SystemExit, "command-spec catalogue is empty"):
            cli.main(["--list"])

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


if __name__ == "__main__":
    unittest.main()
