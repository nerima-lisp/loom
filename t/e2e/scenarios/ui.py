"""PTY scenarios for UI and lifecycle commands."""

from loom_e2e.registry import scenario

from .scenario_helpers import probe_command


_COMMANDS = [
    "keyboard-quit",
    "help",
    "save-buffers-kill-terminal",
    "execute-extended-command",
    "toggle-truncate-lines",
]


for _command in _COMMANDS:
    scenario(
        f"ui/{_command}",
        commands=[_command],
    )(
        (lambda command: lambda binary: probe_command(
            binary, command, b"ui probe\n"
        ))(_command)
    )

