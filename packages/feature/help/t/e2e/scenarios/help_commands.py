"""Exercise help commands through the PTY interface."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


@scenario(
    "help/describe-commands",
    commands=[
        "help",
        "describe-bindings",
        "describe-command",
        "describe-key",
        "describe-mode",
        "switch-to-buffer",
    ],
)
def describe_commands(binary):
    # GNU Emacs documents help keys and commands here:
    # https://www.gnu.org/software/emacs/manual/html_node/emacs/Help-Summary.html
    # C-h k key descriptions are documented here:
    # https://www.gnu.org/software/emacs/manual/html_node/emacs/Key-Help.html
    with tempfile.TemporaryDirectory(
        prefix="loom-e2e-help-", dir="/tmp"
    ) as directory:
        start_path = os.path.join(directory, "start.py")
        with open(start_path, "wb") as handle:
            handle.write(b"print('help')\n")

        with Session(binary, [start_path]) as session:
            session.wait_ready()

            session.send(b"\x1bOP")
            session.wait_for_text("Help:")
            session.assert_screen_text("Help:", match="contains", region="body")

            session.send(keys.ctrl("x") + b"b")
            session.wait_for_region_text("minibuffer", "Switch to buffer: ")
            session.type("start.py")
            session.key("RET")
            session.wait_for_region_text("body", "print('help')")

            session.send(keys.ctrl("h") + b"m")
            session.wait_for_text("Mode: Python")

            session.send(keys.ctrl("h") + b"b")
            session.wait_for_text("Global bindings")

            session.send(keys.ctrl("h") + b"k")
            session.wait_for_region_text("minibuffer", "Describe key: ")
            session.type("C-h")
            session.key("RET")
            session.wait_for_text("C-h is a prefix key.")

            session.send(keys.ctrl("h") + b"x")
            session.wait_for_region_text("minibuffer", "Describe command: ")
            session.type("forward-char")
            session.key("RET")
            session.wait_for_text("forward-char (forward-char)")

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"help/describe-commands exited with {code}: {output!r}"
                )
