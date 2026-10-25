"""PTY scenarios for UI and lifecycle commands."""

import tempfile

from loom_e2e.registry import scenario
from loom_e2e.session import DEFAULT_TIMEOUT, Session

from .scenario_helpers import assert_exit_zero, probe_command, write_buffer


_COMMANDS = [
    "keyboard-quit",
    "help",
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


@scenario(
    "ui/save-buffers-kill-terminal",
    commands=["save-buffers-kill-terminal"],
)
def save_buffers_kill_terminal(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = write_buffer(directory, contents=b"ui probe\n")
        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("save-buffers-kill-terminal")
            output, code = session.process.wait(timeout=DEFAULT_TIMEOUT)
            session.observe_exit_code(code, expected=0)
        assert_exit_zero("save-buffers-kill-terminal", output, code)

