"""Edit, save, and exit: also proves the pyte screen reconstruction, since a
byte-substring assertion alone can't tell a live grid from a stale one."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _assert_exit_zero(name, output, code):
    if code != 0:
        raise AssertionError(f"{name} exited with {code}: {output!r}")


@scenario("edit/save/exit", commands=["save-buffer", "save-buffers-kill-terminal"])
def edit_save_exit(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "notes.txt")
        with open(path, "wb") as handle:
            handle.write(b"x\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.type("a")

            # loom draws no line-number gutter (grep -rn "gutter\\|line-number"
            # src/ packages/ turns up no gutter feature): the buffer's first
            # column is screen column 0, so inserting "a" before "x" puts the
            # cursor at column 1 on row 0.
            session.wait_for_cursor(0, 1)
            row0 = session.screen.text(0)
            if not row0.startswith("ax"):
                raise AssertionError(
                    f"row 0 after typing 'a' should start with 'ax', got {row0[:10]!r}"
                )

            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, b"ax\n")

            output, code = session.quit()
        _assert_exit_zero("edit/save/exit", output, code)
