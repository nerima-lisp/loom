import os
import re
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _populate(directory):
    for index in range(200):
        with open(os.path.join(directory, f"wp3-{index:03d}.txt"), "wb") as handle:
            handle.write(f"WP3 content {index:03d}\n".encode())


def _open_tree(session):
    session.wait_ready()
    session.send(keys.ctrl("x") + keys.text("d"))
    _assert_sidebar_row(session, 0, "wp3-000.txt")


def _assert_sidebar_row(session, row, label):
    session.wait_until(
        lambda _screen: label in session.screen.lines()[row][:24],
        what=f"file-tree row {row} to contain {label}",
    )
    session.assert_screen_text(label, match="contains", row=row)


def _selected_row(session, label):
    return next(
        (
            row
            for row, line in enumerate(session.screen.lines()[:session.rows - 1])
            if label in line[:24]
            and session.screen.cell_attrs(row, 2)["reverse"]
        ),
        None,
    )


def _assert_selected(session, label, expected_row=None):
    session.wait_until(
        lambda _screen: _selected_row(session, label) is not None,
        what=f"selected file-tree entry {label} to be visible",
    )
    row = _selected_row(session, label) if expected_row is None else expected_row
    session.assert_screen_text(label, match="contains", row=row)
    session.assert_cell_attrs(row, 2, {"reverse": True})


def _quit(session):
    output, code = session.quit()
    if code != 0:
        raise AssertionError(f"file-tree scroll exited with {code}: {output!r}")


@scenario("file-tree/wp3-scroll/down", commands=["toggle-file-tree", "file-tree-select-next"])
def scroll_down(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-wp3-") as directory:
        _populate(directory)
        with Session(binary, [directory]) as session:
            _open_tree(session)
            height = session.rows - 1
            for index in range(200):
                session.send(keys.ctrl("c") + keys.text("n"))
                expected_row = height - 1 if index == 199 else min(index, height - 2)
                _assert_selected(session, f"wp3-{index:03d}.txt", expected_row)
            _quit(session)


@scenario("file-tree/wp3-scroll/up", commands=["toggle-file-tree", "file-tree-select-next", "file-tree-select-previous"])
def scroll_up(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-wp3-") as directory:
        _populate(directory)
        with Session(binary, [directory]) as session:
            _open_tree(session)
            session.send((keys.ctrl("c") + keys.text("n")) * 200)
            _assert_selected(session, "wp3-199.txt", session.rows - 2)
            initial_top = 200 - (session.rows - 1)
            for index in range(198, -1, -1):
                session.send(keys.ctrl("c") + keys.text("p"))
                expected_row = min(index, max(1, index - initial_top))
                _assert_selected(session, f"wp3-{index:03d}.txt", expected_row)
            _quit(session)


@scenario("file-tree/wp3-scroll/click", commands=["toggle-file-tree", "file-tree-select-next"])
def scroll_click(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-wp3-") as directory:
        _populate(directory)
        with Session(binary, [directory]) as session:
            _open_tree(session)
            session.send((keys.ctrl("c") + keys.text("n")) * 80)
            _assert_selected(session, "wp3-079.txt")
            row = session.rows * 3 // 4
            label = session.screen.text(row)[:24].strip()
            match = re.fullmatch(r"wp3-(\d{3})\.txt", label)
            if match is None:
                raise AssertionError(f"lower sidebar row has no file: {label!r}")
            session.send(f"\x1b[<0;3;{row + 1}M".encode())
            session.wait_for_region_text("body", f"WP3 content {match[1]}")
            session.assert_screen_text(
                f"WP3 content {match[1]}", match="contains", region="body"
            )
            _quit(session)


@scenario("file-tree/wp3-scroll/resize", commands=["toggle-file-tree", "file-tree-select-next", "file-tree-open-selected"])
def scroll_resize(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-wp3-") as directory:
        _populate(directory)
        with Session(binary, [directory], rows=32) as session:
            _open_tree(session)
            session.send((keys.ctrl("c") + keys.text("n")) * 200)
            _assert_selected(session, "wp3-199.txt", 30)
            session.send(b"\x1b[<64;3;10M")
            _assert_sidebar_row(session, 0, "wp3-166.txt")
            session.send(keys.ctrl("c") + keys.text("o"))
            session.wait_for_region_text("body", "WP3 content 199")
            session.assert_screen_text("WP3 content 199", match="contains", region="body")
            _assert_sidebar_row(session, 0, "wp3-166.txt")
            session.resize(80, 12)
            _assert_sidebar_row(session, 0, "wp3-166.txt")
            session.resize(80, 42)
            _assert_sidebar_row(session, 0, "wp3-159.txt")
            _assert_selected(session, "wp3-199.txt", 40)
            _quit(session)


@scenario("file-tree/wp3-scroll/wheel", commands=["toggle-file-tree", "file-tree-select-next", "file-tree-open-selected"])
def scroll_wheel(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-wp3-") as directory:
        _populate(directory)
        with Session(binary, [directory]) as session:
            _open_tree(session)
            session.send(keys.ctrl("c") + keys.text("n"))
            _assert_selected(session, "wp3-000.txt", 0)
            session.send(b"\x1b[<65;3;10M")
            _assert_sidebar_row(session, 0, "wp3-003.txt")
            session.send(keys.ctrl("c") + keys.text("o"))
            session.wait_for_region_text("body", "WP3 content 000")
            session.assert_screen_text("WP3 content 000", match="contains", region="body")
            _assert_sidebar_row(session, 0, "wp3-003.txt")
            session.send(b"\x1b[<64;3;10M")
            _assert_selected(session, "wp3-000.txt", 0)
            _assert_sidebar_row(session, 0, "wp3-000.txt")
            _quit(session)
