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
    session.wait_for_region_text("screen", "wp3-000.txt", index=0)


def _selected_row(session, label):
    return next(
        (
            row
            for row in range(session.rows - 1)
            if label in session.screen.text(row)[:24]
            and session.screen.cell_attrs(row, 2)["reverse"]
        ),
        None,
    )


def _assert_selected(session, label):
    session.wait_until(
        lambda _screen: _selected_row(session, label) is not None,
        what=f"selected file-tree entry {label} to be visible",
    )
    row = _selected_row(session, label)
    session.assert_screen_text(label, match="contains", region="screen", index=row)
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
            for index in range(200):
                session.send(keys.ctrl("c") + keys.text("n"))
                _assert_selected(session, f"wp3-{index:03d}.txt")
            _quit(session)


@scenario("file-tree/wp3-scroll/up", commands=["toggle-file-tree", "file-tree-select-next", "file-tree-select-previous"])
def scroll_up(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-wp3-") as directory:
        _populate(directory)
        with Session(binary, [directory]) as session:
            _open_tree(session)
            session.send((keys.ctrl("c") + keys.text("n")) * 200)
            _assert_selected(session, "wp3-199.txt")
            for index in range(198, -1, -1):
                session.send(keys.ctrl("c") + keys.text("p"))
                _assert_selected(session, f"wp3-{index:03d}.txt")
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


@scenario("file-tree/wp3-scroll/resize", commands=["toggle-file-tree", "file-tree-select-next"])
def scroll_resize(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-wp3-") as directory:
        _populate(directory)
        with Session(binary, [directory], rows=32) as session:
            _open_tree(session)
            session.send((keys.ctrl("c") + keys.text("n")) * 200)
            _assert_selected(session, "wp3-199.txt")
            session.resize(80, 12)
            _assert_selected(session, "wp3-199.txt")
            session.assert_screen_text(
                "wp3-189.txt", match="contains", region="screen", index=0
            )
            _quit(session)


@scenario("file-tree/wp3-scroll/wheel", commands=["toggle-file-tree", "file-tree-select-next"])
def scroll_wheel(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-wp3-") as directory:
        _populate(directory)
        with Session(binary, [directory]) as session:
            _open_tree(session)
            session.send(keys.ctrl("c") + keys.text("n"))
            _assert_selected(session, "wp3-000.txt")
            session.send(b"\x1b[<65;3;10M")
            session.wait_for_region_text("screen", "wp3-003.txt", index=0)
            session.assert_screen_text(
                "wp3-003.txt", match="contains", region="screen", index=0
            )
            session.send(b"\x1b[<64;3;10M")
            _assert_selected(session, "wp3-000.txt")
            session.assert_screen_text(
                "wp3-000.txt", match="contains", region="screen", index=0
            )
            _quit(session)
