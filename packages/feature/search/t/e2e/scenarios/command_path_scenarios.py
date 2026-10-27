"""Data-driven search command paths with exact prompt and mutation outcomes."""

from pathlib import Path

from loom_e2e.command_path_scenarios import (
    load_command_path_scenarios,
    run_command_path_scenario,
)
from loom_e2e.registry import scenario


# GNU Emacs behavior references:
# https://www.gnu.org/software/emacs/manual/html_node/emacs/Incremental-Search.html
# https://www.gnu.org/software/emacs/manual/html_node/emacs/Query-Replace.html
# https://www.gnu.org/software/emacs/manual/html_node/emacs/Regexp-Replace.html
# https://www.gnu.org/software/emacs/manual/html_node/emacs/Search.html
# https://www.gnu.org/software/emacs/manual/html_node/emacs/Compilation-Mode.html
_CASES = load_command_path_scenarios(Path(__file__).with_name("command-paths.json"))


def _scenario_function(case):
    def run(binary):
        return run_command_path_scenario(binary, case)

    return run


for _case in _CASES:
    scenario(_case["name"], commands=_case["commands"])(
        _scenario_function(_case)
    )
