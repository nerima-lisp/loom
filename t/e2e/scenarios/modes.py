"""Major-mode selection and mode-specific TAB indentation."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _assert_exit_zero(name, output, code):
    if code != 0:
        raise AssertionError(f"{name} exited with {code}: {output!r}")


@scenario(
    "major mode editing",
    commands=["execute-extended-command", "set-major-mode", "indent-for-tab-command", "save-buffer"],
)
def major_mode_editing(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "notes.txt")
        with open(path, "wb") as handle:
            handle.write(b"value\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("set-major-mode")
            session.wait_for_region_text("minibuffer", "Major mode: ")
            session.type("Python")
            session.send(keys.RET)
            session.send(keys.TAB)
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, b"    value\n")

            output, code = session.quit()
        _assert_exit_zero("major mode editing", output, code)
