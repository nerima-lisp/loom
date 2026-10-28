"""PTY probes for evaluation and macro commands."""

from loom_e2e.registry import scenario

from .scenario_helpers import probe_command


_COMMANDS = [
    ("eval-buffer", None),
    ("eval-expression", "Eval: "),
    ("execute-extended-command", "M-x "),
]


for _command, _expected_prompt in _COMMANDS:
    scenario(
        f"macros/{_command}",
        commands=[_command],
    )(
        (lambda command, expected_prompt: lambda binary: probe_command(
            binary, command, b"(progn)\n", expected_prompt=expected_prompt
        ))(_command, _expected_prompt)
    )

