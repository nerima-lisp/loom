"""Data-driven project command path cases for strict R1 and R2 coverage."""

import os
import tempfile
from pathlib import Path

from loom_e2e.command_path_scenarios import (
    load_command_path_scenarios,
    run_command_path_scenario,
)
from loom_e2e.registry import scenario


_CASES = load_command_path_scenarios(Path(__file__).with_name("command-paths.json"))


def _scenario_function(case):
    def run(binary):
        original_tempdir = tempfile.tempdir
        tempfile.tempdir = os.path.realpath(tempfile.gettempdir())
        try:
            return run_command_path_scenario(binary, case)
        finally:
            tempfile.tempdir = original_tempdir

    return run


for _case in _CASES:
    scenario(_case["name"], commands=_case["commands"])(
        _scenario_function(_case)
    )
