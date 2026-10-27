"""Run buffer command paths with cleanup for intentionally modified buffers."""

from pathlib import Path

from loom_e2e import keys
from loom_e2e.command_path_scenarios import (
    load_command_path_scenarios,
    run_command_path_scenario,
)
from loom_e2e.registry import scenario
from loom_e2e.session import DEFAULT_TIMEOUT, Session


_CASES = load_command_path_scenarios(Path(__file__).with_name("command-paths.json"))
_MODIFIED_BUFFER_CLEANUP = {
    "command-path/r2/kill-buffer/prompt-2/cancel": "cancel",
    "command-path/r2/kill-buffer/prompt-2/empty": "empty",
    "command-path/r2/kill-buffer/prompt-2/history": "history",
}


class _BufferScenarioSession(Session):
    def __init__(
        self,
        *args,
        cleanup_kind=None,
        history_prompt_label=None,
        history_intermediate_expected=None,
        **kwargs,
    ):
        self.cleanup_kind = cleanup_kind
        self.history_prompt_label = history_prompt_label
        self.history_intermediate_expected = history_intermediate_expected
        super().__init__(*args, **kwargs)

    def key(self, *names):
        result = super().key(*names)
        if names == ("UP",) and self.history_intermediate_expected is not None:
            self.wait_for_region_exact_text(
                "minibuffer",
                self.history_prompt_label + self.history_intermediate_expected,
                strip_right=True,
            )
            self.history_intermediate_expected = None
        return result

    def _discard_modified_buffer(self):
        if self.cleanup_kind == "empty":
            self.send(keys.ctrl("g"))
            self.wait_for_region_exact_text("minibuffer", "Quit", strip_right=True)

        self.send(keys.ctrl("x") + keys.text("k"))
        self.wait_for_region_text("minibuffer", "Kill buffer: ")
        self.type("buffer.txt")
        self.key("RET")
        self.wait_for_region_text("minibuffer", "Save buffer.txt? (s/d/c): ")
        self.type("d")
        self.key("RET")
        self.wait_for_region_exact_text(
            "minibuffer", "Killed buffer.txt", strip_right=True
        )

    def quit(self, timeout=DEFAULT_TIMEOUT):
        if self.cleanup_kind is not None:
            self._discard_modified_buffer()
        return super().quit(timeout=timeout)


def _scenario_function(case):
    def run(binary):
        cleanup_kind = _MODIFIED_BUFFER_CLEANUP.get(case["name"])

        def session_factory(binary, arguments, columns=80, rows=24):
            return _BufferScenarioSession(
                binary,
                arguments,
                columns=columns,
                rows=rows,
                cleanup_kind=cleanup_kind,
                history_prompt_label=case.get("prompt_label"),
                history_intermediate_expected=case.get(
                    "history_intermediate_expected"
                ),
            )

        return run_command_path_scenario(
            binary, case, session_factory=session_factory
        )

    return run


for _case in _CASES:
    scenario(_case["name"], commands=_case["commands"])(
        _scenario_function(_case)
    )
