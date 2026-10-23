"""Edit, save, and exit: also proves the pyte screen reconstruction, since a
byte-substring assertion alone can't tell a live grid from a stale one."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session
from .scenario_helpers import write_buffer


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

            # Screen coordinates start at column 0 because there is no gutter.
            session.wait_for_region_cursor("body", 1)
            row0 = session.region_text("body")
            session.assert_screen_text(
                row0,
                "ax",
                match="starts_with",
                region="body",
                row=0,
            )

            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, b"ax\n")

            output, code = session.quit()
        _assert_exit_zero("edit/save/exit", output, code)


@scenario("ansi-wide-full")
def ansi_wide_full(binary):
    lines = ["あX", "😀X", "あ X", "😀 X", "A X"]
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = write_buffer(directory, contents=("\n".join(lines) + "\n").encode())
        with Session(binary, [path]) as session:
            session.wait_ready()
            for index, expected in enumerate(lines):
                session.wait_for_region_exact_text(
                    "body", expected, index=index, strip_right=True
                )
            output, code = session.quit()
        _assert_exit_zero("ansi-wide-full", output, code)


@scenario("ansi-wide-diff")
def ansi_wide_diff(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = write_buffer(directory, contents=b"AX\n")
        with Session(binary, [path]) as session:
            session.wait_ready()
            row = session.layout.row("body")

            def expect_line(expected, column):
                session.wait_for_row_and_cursor(row, expected, column)

            expect_line("AX", 0)
            for glyph in ("あ", "😀"):
                session.send(keys.ctrl("d"))
                expect_line("X", 0)
                session.type(glyph)
                expect_line(glyph + "X", 2)
                session.type(" ")
                expect_line(glyph + " X", 3)
                session.send(b"\x7f")
                expect_line(glyph + "X", 2)
                session.send(keys.ctrl("a") + keys.ctrl("d"))
                expect_line("X", 0)
                session.type("A")
                expect_line("AX", 1)
                session.send(keys.ctrl("a"))
                expect_line("AX", 0)
            session.send(keys.ctrl("e"))
            session.type("!")
            expect_line("AX!", 3)
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, b"AX!\n")
            output, code = session.quit()
        _assert_exit_zero("ansi-wide-diff", output, code)
