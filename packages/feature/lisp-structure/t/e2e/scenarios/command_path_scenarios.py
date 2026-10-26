"""Data-driven R1 command-path cases for S-expression commands."""

from pathlib import Path

from loom_e2e.command_path_scenarios import (
    load_command_path_scenarios,
    run_command_path_scenario,
)
from loom_e2e.registry import scenario
from loom_e2e.results import UNSET
from loom_e2e.session import Session


_CASES = load_command_path_scenarios(Path(__file__).with_name("command-paths.json"))
_CURSOR_MOTION_COMMANDS = {
    "backward-sexp",
    "backward-up-list",
    "down-list",
    "forward-sexp",
}


class _CursorSettledSession(Session):
    def observe_cursor(
        self,
        expected=UNSET,
        *,
        purpose="scenario",
        sample=UNSET,
        region=None,
        index=0,
    ):
        if expected is not UNSET and region is not None:
            self.wait_for_region_cursor(region, expected[1], index=expected[0])
        return super().observe_cursor(
            expected=expected,
            purpose=purpose,
            sample=sample,
            region=region,
            index=index,
        )


def _scenario_function(case):
    def run(binary):
        session_factory = (
            _CursorSettledSession
            if case["command"] in _CURSOR_MOTION_COMMANDS
            else Session
        )
        return run_command_path_scenario(
            binary, case, session_factory=session_factory
        )

    return run


for _case in _CASES:
    scenario(_case["name"], commands=_case["commands"])(
        _scenario_function(_case)
    )
