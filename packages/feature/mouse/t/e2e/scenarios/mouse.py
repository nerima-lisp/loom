"""Exercise SGR mouse behavior through Loom's real PTY entry point."""

import json
import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _sgr(button, column, row, final="M"):
    return f"\x1b[<{button};{column + 1};{row + 1}{final}".encode("ascii")


def _left_click(column, row):
    return _sgr(0, column, row) + _sgr(0, column, row, final="m")


def _left_drag(start_column, start_row, end_column, end_row):
    return (
        _sgr(0, start_column, start_row)
        + _sgr(32, end_column, end_row)
        + _sgr(0, end_column, end_row, final="m")
    )


def _run_case(binary, name, files, initial_file, exercise):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-mouse-") as directory:
        paths = {}
        for filename, contents in files.items():
            path = os.path.join(directory, filename)
            with open(path, "wb") as handle:
                handle.write(contents)
            paths[filename] = path

        with Session(binary, [paths[initial_file]]) as session:
            session.wait_ready(timeout=5)
            exercise(session, paths)
            output, code = session.quit()

        if code != 0:
            raise AssertionError(f"r6/mouse/{name} exited with {code}: {output!r}")
        trace = [
            json.loads(line)
            for line in session.trace_bytes.decode("utf-8").splitlines()
        ]
        if not any(
            event.get("command") == "mouse-event"
            and event.get("route") == "mouse"
            for event in trace
        ):
            raise AssertionError(f"r6/mouse/{name} did not trace a mouse route: {trace!r}")


def _assert_cursor(session, row, column):
    session.wait_for_region_cursor("body", column, index=row, timeout=5)
    if session.observe_cursor(
        expected=(row, column), region="body", index=row
    ) is not True:
        raise AssertionError(
            f"mouse point was {session.region_cursor('body', row)!r}, "
            f"expected {(row, column)!r}"
        )


def _move(session, _paths):
    session.send(_left_click(2, 1))
    _assert_cursor(session, 1, 2)
    session.assert_screen_text("beta", match="contains", region="body", index=1)


@scenario("r6/mouse")
def r6_mouse(binary):
    _run_case(
        binary,
        "move",
        {"mouse.txt": b"alpha\nbeta\n"},
        "mouse.txt",
        _move,
    )


def _insert(session, paths):
    session.send(_left_click(2, 0))
    _assert_cursor(session, 0, 2)
    session.send(b"X")
    session.wait_for_region_exact_text("body", "abXcd", timeout=5)
    session.send(keys.ctrl("x") + keys.ctrl("s"))
    session.wait_for_file(paths["mouse.txt"], b"abXcd\n", timeout=5)
    session.assert_file_bytes(paths["mouse.txt"], b"abXcd\n")


@scenario("r6/mouse/insert", commands=["save-buffer"])
def r6_mouse_insert(binary):
    _run_case(binary, "insert", {"mouse.txt": b"abcd\n"}, "mouse.txt", _insert)


def _delete(session, paths):
    session.send(_left_click(1, 0))
    _assert_cursor(session, 0, 1)
    session.extended_command("delete-char")
    session.wait_for_region_exact_text("body", "acd", timeout=5)
    session.send(keys.ctrl("x") + keys.ctrl("s"))
    session.wait_for_file(paths["mouse.txt"], b"acd\n", timeout=5)
    session.assert_file_bytes(paths["mouse.txt"], b"acd\n")


@scenario("r6/mouse/delete", commands=["delete-char", "save-buffer"])
def r6_mouse_delete(binary):
    _run_case(binary, "delete", {"mouse.txt": b"abcd\n"}, "mouse.txt", _delete)


def _undo(session, paths):
    session.send(_left_click(2, 0))
    _assert_cursor(session, 0, 2)
    session.send(b"X")
    session.wait_for_region_exact_text("body", "abXcd", timeout=5)
    session.send(keys.ctrl("x") + keys.text("u"))
    session.wait_for_region_exact_text("body", "abcd", timeout=5)
    session.send(keys.ctrl("x") + keys.ctrl("s"))
    session.wait_for_file(paths["mouse.txt"], b"abcd\n", timeout=5)
    session.assert_file_bytes(paths["mouse.txt"], b"abcd\n")


@scenario("r6/mouse/undo", commands=["undo", "save-buffer"])
def r6_mouse_undo(binary):
    _run_case(binary, "undo", {"mouse.txt": b"abcd\n"}, "mouse.txt", _undo)


def _save(session, paths):
    session.send(_left_click(2, 0))
    _assert_cursor(session, 0, 2)
    session.send(b"X")
    session.wait_for_region_exact_text("body", "abXcd", timeout=5)
    session.send(keys.ctrl("x") + keys.ctrl("s"))
    session.wait_for_file(paths["mouse.txt"], b"abXcd\n", timeout=5)
    session.assert_file_bytes(paths["mouse.txt"], b"abXcd\n")


@scenario("r6/mouse/save", commands=["save-buffer"])
def r6_mouse_save(binary):
    _run_case(binary, "save", {"mouse.txt": b"abcd\n"}, "mouse.txt", _save)


def _window_selection(session, _paths):
    session.extended_command("split-window-below")
    session.wait_for_region_exact_text("body", "line-00", index=0, timeout=5)
    session.send(_left_click(2, 2))
    session.send(_left_click(2, 15))
    session.wait_for_cursor(15, 2, timeout=5)
    if session.observe_cursor(expected=(15, 2)) is not True:
        raise AssertionError(f"mouse did not select the lower window: {session.screen.cursor!r}")


@scenario("r6/mouse/window-selection", commands=["split-window-below"])
def r6_mouse_window_selection(binary):
    lines = "".join(f"line-{index:02d}\n" for index in range(40)).encode("ascii")
    _run_case(
        binary,
        "window-selection",
        {"mouse.txt": lines},
        "mouse.txt",
        _window_selection,
    )


def _wheel(session, _paths):
    session.wait_for_region_exact_text("body", "line-00", index=0, timeout=5)
    session.send(_sgr(65, 2, 0))
    session.wait_for_region_exact_text("body", "line-22", index=0, timeout=5)
    session.assert_screen_text("line-22", match="contains", region="body", index=0)


@scenario("r6/mouse/wheel")
def r6_mouse_wheel(binary):
    lines = "".join(f"line-{index:02d}\n" for index in range(60)).encode("ascii")
    _run_case(
        binary,
        "wheel",
        {"mouse.txt": lines},
        "mouse.txt",
        _wheel,
    )


def _drag(session, paths):
    session.send(_left_drag(1, 0, 4, 0))
    session.send(keys.ctrl("w"))
    session.wait_for_region_exact_text("body", "aef", timeout=5)
    session.send(keys.ctrl("x") + keys.ctrl("s"))
    session.wait_for_file(paths["mouse.txt"], b"aef\n", timeout=5)
    session.assert_file_bytes(paths["mouse.txt"], b"aef\n")


@scenario("r6/mouse/drag", commands=["kill-region", "save-buffer"])
def r6_mouse_drag(binary):
    _run_case(binary, "drag", {"mouse.txt": b"abcdef\n"}, "mouse.txt", _drag)


def _file_tree_open(session, paths):
    session.extended_command("toggle-file-tree")
    session.wait_for_text("b-target.txt", timeout=5)
    session.send(_left_click(2, 1))
    session.wait_for_region_exact_text("body", "TARGET-CONTENT", timeout=5)
    session.send(b"!")
    session.send(keys.ctrl("x") + keys.ctrl("s"))
    session.wait_for_file(
        paths["b-target.txt"], b"!TARGET-CONTENT\n", timeout=5
    )
    session.assert_file_bytes(paths["b-target.txt"], b"!TARGET-CONTENT\n")


@scenario("r6/mouse/file-tree-open", commands=["toggle-file-tree", "save-buffer"])
def r6_mouse_file_tree_open(binary):
    _run_case(
        binary,
        "file-tree-open",
        {
            "a-start.txt": b"START-CONTENT\n",
            "b-target.txt": b"TARGET-CONTENT\n",
        },
        "a-start.txt",
        _file_tree_open,
    )
