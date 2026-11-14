"""Fixed buffer-menu paths: window reuse, quit targets, marks, and stopped x."""

import tempfile
from pathlib import Path

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


# Eleven rows split into an upper window on rows 0-4 (mode line 4) and a lower
# window on rows 5-9 (mode line 9); row 10 is the minibuffer.
_ROWS = 11
_UPPER_MODE_LINE = 4
_LOWER_MODE_LINE = 9
_LOWER_FIRST = 5


def _write(path, content):
    Path(path).write_bytes(content)


def _assert_body(session, index, text, match="contains"):
    if match == "exact":
        session.wait_for_region_exact_text("body", text, index=index)
    else:
        session.wait_for_region_text("body", text, index=index)
    session.assert_screen_text(
        text, match=match, region="body", index=index, strip_right=True
    )


def _assert_row(session, row, text):
    session.wait_for_row_text(row, text)
    session.assert_screen_text(text, match="contains", row=row)


def _assert_cursor(session, row, column):
    session.wait_for_region_cursor("body", column, index=row)
    if session.observe_cursor(expected=(row, column), region="body") is not True:
        raise AssertionError(
            f"body cursor was {session.region_cursor('body')!r}; "
            f"expected {(row, column)!r}"
        )


def _quit(session, discard_prompt=None):
    if discard_prompt is None:
        output, code = session.quit()
    else:
        session.send(keys.ctrl("x") + keys.ctrl("c"))
        session.wait_for_region_text("minibuffer", discard_prompt)
        session.type("d")
        session.key("RET")
        output, code = session.process.wait()
        session.observe_exit_code(code, expected=0)
    if code != 0:
        raise AssertionError(f"loom exited with {code}: {output!r}")


@scenario(
    "buffer-menu/one-window-split-quit",
    commands=["list-buffers", "buffer-menu-quit"],
)
def one_window_split_quit(binary):
    with tempfile.TemporaryDirectory(prefix="loom-buffer-menu-") as directory:
        path = Path(directory) / "buffer.txt"
        _write(path, b"abc\n")
        with Session(binary, [str(path)], rows=_ROWS) as session:
            session.wait_ready()
            session.send(keys.ctrl("e"))
            session.wait_for_region_cursor("body", 3, index=0)

            session.send(keys.ctrl("x") + keys.ctrl("b"))
            _assert_body(session, _LOWER_FIRST + 2, "*Buffer List*")
            _assert_body(session, _LOWER_FIRST, "  .   buffer.txt")
            _assert_row(session, _LOWER_MODE_LINE, "*Buffer List*")
            _assert_body(session, 0, "abc", match="exact")
            _assert_cursor(session, 0, 3)

            session.send(keys.ctrl("x") + b"o")
            session.wait_for_region_cursor("body", 0, index=_LOWER_FIRST)
            session.send(b"q")
            _assert_body(session, _LOWER_FIRST, "", match="exact")
            session.assert_screen_text(
                "*Buffer List*", match="not_contains", region="screen"
            )
            _assert_body(session, 0, "abc", match="exact")
            _assert_cursor(session, 0, 3)
            _quit(session)


@scenario(
    "buffer-menu/two-window-reuse-quit",
    commands=["list-buffers", "buffer-menu-quit"],
)
def two_window_reuse_quit(binary):
    with tempfile.TemporaryDirectory(prefix="loom-buffer-menu-") as directory:
        path = Path(directory) / "buffer.txt"
        _write(path, b"abc\n")
        with Session(binary, [str(path)], rows=_ROWS) as session:
            session.wait_ready()
            # C-x 2 selects the new lower window; show *Messages* in the upper one.
            session.send(keys.ctrl("x") + b"2")
            session.wait_for_region_cursor("body", 0, index=_LOWER_FIRST)
            session.send(keys.ctrl("x") + b"o")
            session.wait_for_region_cursor("body", 0, index=0)
            session.send(keys.ctrl("x") + b"b")
            session.wait_for_region_text("minibuffer", "Switch to buffer: ")
            session.type("*Messages*")
            session.key("RET")
            session.wait_for_row_text(_UPPER_MODE_LINE, " *Messages* ")
            session.send(keys.ctrl("x") + b"o")
            session.wait_for_region_cursor("body", 0, index=_LOWER_FIRST)

            session.send(keys.ctrl("x") + keys.ctrl("b"))
            _assert_row(session, _UPPER_MODE_LINE, "*Buffer List*")
            _assert_body(session, 0, "  .   buffer.txt")
            _assert_body(session, _LOWER_FIRST, "abc", match="exact")
            _assert_row(session, _LOWER_MODE_LINE, " buffer.txt ")
            _assert_cursor(session, _LOWER_FIRST, 0)

            session.send(keys.ctrl("x") + b"o")
            session.wait_for_region_cursor("body", 0, index=0)
            session.send(b"q")
            _assert_row(session, _UPPER_MODE_LINE, " *Messages* ")
            session.assert_screen_text(
                "*Buffer List*", match="not_contains", row=_UPPER_MODE_LINE
            )
            _assert_body(session, _LOWER_FIRST, "abc", match="exact")
            _assert_row(session, _LOWER_MODE_LINE, " buffer.txt ")
            _quit(session)


@scenario(
    "buffer-menu/mark-replacement",
    commands=["list-buffers", "buffer-menu-delete", "buffer-menu-save"],
)
def mark_replacement(binary):
    with tempfile.TemporaryDirectory(prefix="loom-buffer-menu-") as directory:
        path = Path(directory) / "buffer.txt"
        _write(path, b"abc\n")
        with Session(binary, [str(path)], rows=_ROWS) as session:
            session.wait_ready()
            session.send(keys.ctrl("x") + keys.ctrl("b"))
            _assert_body(session, _LOWER_FIRST, "  .   buffer.txt")
            _assert_cursor(session, 0, 0)
            session.send(keys.ctrl("x") + b"o")
            session.wait_for_region_cursor("body", 0, index=_LOWER_FIRST)

            session.send(b"d")
            _assert_body(session, _LOWER_FIRST, "D .   buffer.txt")
            _assert_cursor(session, _LOWER_FIRST + 1, 0)
            session.send(b"p")
            session.wait_for_region_cursor("body", 0, index=_LOWER_FIRST)
            session.send(b"s")
            _assert_body(session, _LOWER_FIRST, "S .   buffer.txt")
            session.assert_screen_text(
                "D ", match="not_contains", region="body", index=_LOWER_FIRST
            )
            _assert_cursor(session, _LOWER_FIRST + 1, 0)
            _quit(session)


@scenario(
    "buffer-menu/execute-stops-on-cancelled-save",
    commands=[
        "list-buffers",
        "buffer-menu-save",
        "buffer-menu-delete",
        "buffer-menu-execute",
    ],
)
def execute_stops_on_cancelled_save(binary):
    with tempfile.TemporaryDirectory(prefix="loom-buffer-menu-") as directory:
        path = Path(directory) / "buffer.txt"
        other = Path(directory) / "other.txt"
        _write(path, b"abc\n")
        _write(other, b"other\n")
        with Session(binary, [str(path)], rows=_ROWS) as session:
            session.wait_ready()
            session.type("!")
            session.wait_for_region_exact_text("body", "!abc", index=0)
            _write(path, b"external\n")
            session.send(keys.ctrl("x") + keys.ctrl("f"))
            session.wait_for_region_text("minibuffer", "Find file: ")
            session.type(str(other))
            session.key("RET")
            session.wait_for_region_exact_text("body", "other", index=0)

            session.send(keys.ctrl("x") + keys.ctrl("b"))
            _assert_body(session, _LOWER_FIRST + 3, "*Buffer List*")
            _assert_body(session, _LOWER_FIRST, "    * buffer.txt")
            _assert_body(session, _LOWER_FIRST + 2, "  .   other.txt")
            session.send(keys.ctrl("x") + b"o")
            session.wait_for_region_cursor("body", 0, index=_LOWER_FIRST)

            session.send(b"s")
            _assert_body(session, _LOWER_FIRST, "S   * buffer.txt")
            session.wait_for_region_cursor("body", 0, index=_LOWER_FIRST + 1)
            session.send(b"n")
            session.wait_for_region_cursor("body", 0, index=_LOWER_FIRST + 2)
            session.send(b"d")
            _assert_body(session, _LOWER_FIRST + 2, "D .   other.txt")

            session.send(b"x")
            session.wait_for_region_text(
                "minibuffer", "File changed on disk. Overwrite? (y/n): "
            )
            session.send(keys.ctrl("g"))
            session.wait_for_region_exact_text("minibuffer", "Quit")
            session.assert_screen_text(
                "Quit", region="minibuffer", strip_right=True
            )
            _assert_body(session, _LOWER_FIRST, "S   * buffer.txt")
            _assert_body(session, _LOWER_FIRST + 2, "D .   other.txt")
            session.assert_file_bytes(path, b"external\n")
            session.assert_file_bytes(other, b"other\n")
            _quit(session, discard_prompt="Save buffer.txt? (s/d/c): ")
