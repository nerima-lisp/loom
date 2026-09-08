"""PTY probes for evaluation and macro commands."""

from loom_e2e.registry import scenario

from .scenario_helpers import probe_command


_COMMANDS = [
    "eval-buffer",
    "eval-expression",
    "execute-extended-command",
]


for _command in _COMMANDS:
    scenario(
        f"macros/{_command}",
        commands=[_command],
    )(
        (lambda command: lambda binary: probe_command(
            binary, command, b"(progn)\n"
        ))(_command)
    )

