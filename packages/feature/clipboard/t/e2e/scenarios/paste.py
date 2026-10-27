"""Bracketed-paste behavior through Loom's real PTY entry point."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


_PASTE_START = b"\x1b[200~"
_PASTE_END = b"\x1b[201~"


def _write(path, contents):
    with open(path, "wb") as handle:
        handle.write(contents)


def _paste(session, payload):
    session.send(_PASTE_START + payload + _PASTE_END)


def _assert_paste_mode_enabled(session):
    session.assert_pty_output(session.output_bytes, b"\x1b[?2004h")


def _assert_body_line(session, row, expected):
    session.wait_for_region_exact_text(
        "body", expected, index=row, strip_right=True
    )
    session.assert_screen_text(
        expected,
        match="exact",
        region="body",
        index=row,
        strip_right=True,
    )


def _assert_body_cursor(session, row, column):
    screen_row = session.layout.row("body", row)
    screen_column = session.layout.body_x + column
    session.wait_for_cursor(
        screen_row,
        screen_column,
        region="body",
        body_col=column,
    )
    if session.observe_cursor(expected=(row, column), region="body") is not True:
        raise AssertionError(
            f"body cursor did not reach row {row}, column {column}"
        )


def _save_and_assert(session, path, expected):
    session.send(keys.ctrl("x") + keys.ctrl("s"))
    session.wait_for_file(path, expected)
    session.assert_file_bytes(path, expected)


def _close(session, name):
    output, code = session.quit()
    session.assert_pty_output(output, b"\x1b[?2004l")
    if code != 0:
        raise AssertionError(f"{name} exited with {code}: {output!r}")


@scenario("r6/paste/move", commands=["forward-char", "save-buffer"])
def paste_move(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "move.txt")
        _write(path, b"tail\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            _assert_paste_mode_enabled(session)
            _paste(session, b"row\nx")
            _assert_body_line(session, 0, "row")
            _assert_body_line(session, 1, "xtail")

            session.send(keys.ctrl("f"))
            _assert_body_cursor(session, 1, 2)
            _save_and_assert(session, path, b"row\nxtail\n")
            _close(session, "r6/paste/move")


@scenario("r6/paste/insert", commands=["save-buffer"])
def paste_insert(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "literal.lisp")
        _write(path, b"")

        with Session(binary, [path]) as session:
            session.wait_ready()
            _assert_paste_mode_enabled(session)
            _paste(session, b"(root\n\tvalue\nend)")
            _assert_body_line(session, 0, "(root")
            _assert_body_line(session, 2, "end)")
            _assert_body_cursor(session, 2, 4)
            _save_and_assert(session, path, b"(root\n\tvalue\nend)")
            _close(session, "r6/paste/insert")


@scenario("r6/paste/delete", commands=["delete-char", "save-buffer"])
def paste_delete(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "delete.txt")
        _write(path, b"tail\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            _assert_paste_mode_enabled(session)
            _paste(session, b"head")
            _assert_body_line(session, 0, "headtail")

            session.send(keys.ctrl("d"))
            _assert_body_line(session, 0, "headail")
            _assert_body_cursor(session, 0, 4)
            _save_and_assert(session, path, b"headail\n")
            _close(session, "r6/paste/delete")


@scenario("r6/paste/undo", commands=["undo", "save-buffer"])
def paste_undo(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "undo.txt")
        _write(path, b"tail\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            _assert_paste_mode_enabled(session)
            _paste(session, b"one\ntwo\nthree")
            _assert_body_line(session, 0, "one")
            _assert_body_line(session, 1, "two")
            _assert_body_line(session, 2, "threetail")
            _assert_body_cursor(session, 2, 5)

            session.send(keys.ctrl("x") + keys.text("u"))
            _assert_body_line(session, 0, "tail")
            _assert_body_cursor(session, 0, 0)
            _save_and_assert(session, path, b"tail\n")
            _close(session, "r6/paste/undo")


@scenario("r6/paste/save", commands=["save-buffer"])
def paste_save(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "save.txt")
        _write(path, b"")

        with Session(binary, [path]) as session:
            session.wait_ready()
            _assert_paste_mode_enabled(session)
            _paste(session, b"saved\nexact")
            _assert_body_line(session, 0, "saved")
            _assert_body_line(session, 1, "exact")
            _assert_body_cursor(session, 1, 5)
            _save_and_assert(session, path, b"saved\nexact")
            _close(session, "r6/paste/save")


@scenario("r6/paste/separate-undo", commands=["undo", "save-buffer"])
def paste_separate_undo(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "separate-undo.txt")
        _write(path, b"base\n")

        with Session(binary, [path]) as session:
            stage = "wait-ready"
            try:
                session.wait_ready()
                stage = "check paste mode"
                _assert_paste_mode_enabled(session)
                stage = "send first paste"
                _paste(session, b"first")
                stage = "observe first paste"
                _assert_body_line(session, 0, "firstbase")
                stage = "check first paste cursor"
                _assert_body_cursor(session, 0, 5)

                stage = "send second paste"
                _paste(session, b"second")
                stage = "observe second paste"
                _assert_body_line(session, 0, "firstsecondbase")
                stage = "check second paste cursor"
                _assert_body_cursor(session, 0, 11)

                stage = "send first undo"
                session.send(keys.ctrl("x") + keys.text("u"))
                stage = "observe first undo"
                _assert_body_line(session, 0, "firstbase")
                stage = "check first undo cursor"
                _assert_body_cursor(session, 0, 5)

                stage = "send second undo"
                session.send(keys.ctrl("x") + keys.text("u"))
                stage = "observe second undo"
                _assert_body_line(session, 0, "base")
                stage = "check second undo cursor"
                _assert_body_cursor(session, 0, 0)
                stage = "save restored text"
                _save_and_assert(session, path, b"base\n")
                stage = "close terminal"
                _close(session, "r6/paste/separate-undo")
            except Exception as condition:
                raise AssertionError(
                    f"r6/paste/separate-undo failed during {stage}: {condition}\n"
                    f"cursor={session.screen.cursor}\n"
                    f"{session.screen.dump()}"
                ) from condition
