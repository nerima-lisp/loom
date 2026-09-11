"""Keyboard macros and the numeric prefix argument."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _assert_exit_zero(name, output, code):
    if code != 0:
        raise AssertionError(f"{name} exited with {code}: {output!r}")


@scenario(
    "keyboard macro",
    commands=["start-kbd-macro", "end-kbd-macro", "call-last-kbd-macro", "save-buffer"],
)
def keyboard_macro(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "macro.txt")
        with open(path, "wb") as handle:
            handle.write(b"\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.send(keys.ctrl("x") + b"(")
            session.type("a")
            session.send(keys.ctrl("x") + b")")
            session.send(keys.ctrl("x") + b"e")
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, b"aa\n")

            output, code = session.quit()
        _assert_exit_zero("keyboard macro", output, code)


@scenario("numeric prefix", commands=["universal-argument", "save-buffer"])
def numeric_prefix(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "prefix.txt")
        with open(path, "wb") as handle:
            handle.write(b"\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.send(keys.ctrl("u"))
            session.type("2a")
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, b"aa\n")

            output, code = session.quit()
        _assert_exit_zero("numeric prefix", output, code)
