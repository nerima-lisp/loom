"""Run buffer-menu command paths, discarding a buffer the case leaves modified."""

from pathlib import Path

from loom_e2e import keys
from loom_e2e.command_path_scenarios import (
    load_command_path_scenarios,
    run_command_path_scenario,
)
from loom_e2e.registry import scenario
from loom_e2e.session import DEFAULT_TIMEOUT, Session


_CASES = load_command_path_scenarios(Path(__file__).with_name("command-paths.json"))
# These R2 cases end with buffer.txt still modified, so C-x C-c asks about it.
_MODIFIED_AT_QUIT = {
    "command-path/r2/buffer-menu-execute/prompt-1/cancel",
    "command-path/r2/buffer-menu-execute/prompt-1/empty",
    "command-path/r2/buffer-menu-execute/prompt-1/history",
}


class _DiscardOnQuitSession(Session):
    def quit(self, timeout=DEFAULT_TIMEOUT):
        self.send(keys.ctrl("x") + keys.ctrl("c"))
        self.wait_for_region_text("minibuffer", "Save buffer.txt? (s/d/c): ")
        self.type("d")
        self.key("RET")
        output, code = self.process.wait(timeout=timeout)
        self.observe_exit_code(code, expected=0)
        return output, code


def _scenario_function(case):
    def run(binary):
        factory = (
            _DiscardOnQuitSession if case["name"] in _MODIFIED_AT_QUIT else Session
        )
        return run_command_path_scenario(binary, case, session_factory=factory)

    return run


for _case in _CASES:
    scenario(_case["name"], commands=_case["commands"])(_scenario_function(_case))
