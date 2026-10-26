import contextlib
import json
import importlib.util
import io
import os
import tempfile
import unittest
from unittest.mock import patch

from loom_e2e import registry
from loom_e2e.scenario_discovery import (
    format_scenario_listing,
    load_slice_scenarios,
    select_scenarios,
)


_SPEC = importlib.util.spec_from_file_location(
    "loom_test_scenario_discovery",
    os.path.join(os.path.dirname(__file__), "loom-test.py"),
)
cli = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(cli)


class SliceScenarioDiscoveryTests(unittest.TestCase):
    def test_nested_slice_scenario_appears_in_list_and_only(self):
        with tempfile.TemporaryDirectory() as repository_root:
            scenario_path = os.path.join(
                repository_root,
                "packages",
                "feature",
                "discovery-fixture",
                "t",
                "e2e",
                "scenarios",
                "nested",
                "fixture.py",
            )
            os.makedirs(os.path.dirname(scenario_path))
            with open(scenario_path, "w", encoding="utf-8") as handle:
                handle.write(
                    "from loom_e2e.registry import scenario\n"
                    "@scenario('slice discovery fixture', commands=['fixture-id'])\n"
                    "def fixture(_binary):\n"
                    "    pass\n"
                )

            with patch.object(registry, "_scenarios", []):
                load_slice_scenarios(repository_root)
                registered = registry.all_scenarios()

            with patch.object(registry, "_scenarios", registered):
                with patch.object(cli, "_binary_from_arguments", return_value="loom"):
                    with patch.object(
                        cli.commands,
                        "load_command_catalog",
                        return_value=[{"id": "fixture-id"}],
                    ):
                        with contextlib.redirect_stdout(io.StringIO()) as output:
                            self.assertEqual(cli.main(["--list"]), 0)
                        self.assertIn(
                            "slice discovery fixture\tcommands=fixture-id",
                            output.getvalue(),
                        )

                        selected_run = patch.object(cli, "_run_with_artifacts")
                        preflight = patch.object(cli, "_run_harness_preflight")
                        path_report = patch.object(
                            cli,
                            "_path_coverage_report",
                            return_value={"has_failures": False},
                        )
                        with selected_run as run, preflight, path_report:
                            with contextlib.redirect_stdout(io.StringIO()):
                                self.assertEqual(
                                    cli.main([
                                        "--only",
                                        "discovery fixture",
                                        "--artifacts-dir",
                                        os.path.join(repository_root, "artifacts"),
                                    ]),
                                    0,
                                )

            self.assertEqual(
                format_scenario_listing(registered),
                ["slice discovery fixture\tcommands=fixture-id"],
            )
            self.assertEqual(
                [entry[0] for entry in select_scenarios(registered, "discovery fixture")],
                ["slice discovery fixture"],
            )
            self.assertEqual(select_scenarios(registered, "missing"), [])
            self.assertEqual(run.call_args.args[0], "slice discovery fixture")


    def test_command_path_sidecar_is_registered(self):
        with tempfile.TemporaryDirectory() as repository_root:
            sidecar_path = os.path.join(
                repository_root,
                "packages",
                "feature",
                "discovery-fixture",
                "t",
                "e2e",
                "scenarios",
                "command-paths.json",
            )
            os.makedirs(os.path.dirname(sidecar_path))
            with open(sidecar_path, "w", encoding="utf-8") as handle:
                json.dump(
                    {
                        "schema_version": 1,
                        "scenarios": [
                            {
                                "name": "slice command path fixture",
                                "path_id": "r1:fixture:mx",
                                "lane": "W3-10",
                                "rule": "r1",
                                "entry": "mx",
                                "commands": ["fixture-id"],
                                "command": "fixture-id",
                                "entry_mode": "mx",
                                "initial_bytes": "fixture\n",
                                "expected_bytes": "fixture\n",
                                "expected_cursor": [0, 0],
                                "expected_minibuffer": "",
                                "expected_screen": [
                                    {"region": "body", "text": "fixture"}
                                ],
                            }
                        ],
                    },
                    handle,
                )

            with patch.object(registry, "_scenarios", []):
                load_slice_scenarios(repository_root)
                registered = registry.all_scenarios()

            self.assertEqual(
                format_scenario_listing(registered),
                ["slice command path fixture\tcommands=fixture-id"],
            )
            self.assertEqual(
                [
                    entry[0]
                    for entry in select_scenarios(
                        registered, "slice command path fixture"
                    )
                ],
                ["slice command path fixture"],
            )

    def test_sidecar_with_slice_runner_is_not_registered_twice(self):
        with tempfile.TemporaryDirectory() as repository_root:
            scenarios_directory = os.path.join(
                repository_root,
                "packages",
                "feature",
                "discovery-fixture",
                "t",
                "e2e",
                "scenarios",
            )
            os.makedirs(scenarios_directory)
            with open(
                os.path.join(scenarios_directory, "command_path_scenarios.py"),
                "w",
                encoding="utf-8",
            ) as handle:
                handle.write(
                    "from loom_e2e.registry import scenario\n"
                    "@scenario('slice-owned command path', commands=['fixture-id'])\n"
                    "def fixture(_binary):\n"
                    "    pass\n"
                )
            with open(
                os.path.join(scenarios_directory, "command-paths.json"),
                "w",
                encoding="utf-8",
            ) as handle:
                json.dump(
                    {
                        "schema_version": 1,
                        "scenarios": [
                            {
                                "name": "slice-owned command path",
                                "path_id": "r1:fixture:mx",
                                "lane": "W3-10",
                                "rule": "r1",
                                "entry": "mx",
                                "commands": ["fixture-id"],
                                "command": "fixture-id",
                                "entry_mode": "mx",
                                "initial_bytes": "fixture\n",
                                "expected_bytes": "fixture\n",
                                "expected_cursor": [0, 0],
                                "expected_minibuffer": "",
                                "expected_screen": [
                                    {"region": "body", "text": "fixture"}
                                ],
                            }
                        ],
                    },
                    handle,
                )

            with patch.object(registry, "_scenarios", []):
                load_slice_scenarios(repository_root)
                registered = registry.all_scenarios()

            self.assertEqual(
                format_scenario_listing(registered),
                ["slice-owned command path\tcommands=fixture-id"],
            )
