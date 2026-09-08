"""Exercise the file-tree commands through a real PTY and filesystem."""

import os
import tempfile
import time

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _assert_exit_zero(name, output, code):
    if code != 0:
        raise AssertionError(f"{name} exited with {code}: {output!r}")


def _wait_for_path(session, path, predicate, description):
    session.wait_until(
        lambda _screen: predicate(path),
        what=f"{description} {path}",
    )


def _run_command(session, name):
    session.extended_command(name)
    session.wait_for_region_cursor("body", 24)


def _wait_for_region_after_refresh(session, region, expected, index=0):
    deadline = time.monotonic() + 10.0
    while True:
        if expected in session.region_text(region, index):
            return
        session.send(keys.ctrl("x") + keys.ctrl("t"))
        session.send(keys.ctrl("x") + keys.ctrl("t"))
        session.pump()
        if time.monotonic() >= deadline:
            raise TimeoutError(
                f"timed out waiting for {expected!r} in {region} region"
            )


def _show_file_tree(session, first_entry):
    session.extended_command("toggle-file-tree")
    session.wait_for_region_text("body", first_entry)
    session.wait_for_region_cursor("body", 24)


@scenario("file-tree toggle", commands=["toggle-file-tree"])
def file_tree_toggle(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        marker = os.path.join(directory, "toggle-marker.txt")
        with open(marker, "wb") as handle:
            handle.write(b"marker\n")

        with Session(binary, [directory]) as session:
            session.wait_ready()
            session.send(keys.ctrl("x") + keys.ctrl("t"))
            session.wait_for_region_text("body", "toggle-marker.txt")
            session.wait_for_region_cursor("body", 24)

            session.send(keys.ctrl("x") + keys.ctrl("t"))
            session.wait_for_region_cursor("body", 0)

            output, code = session.quit()
        _assert_exit_zero("file-tree toggle", output, code)


@scenario(
    "file-tree navigation",
    commands=[
        "toggle-file-tree",
        "file-tree-select-next",
        "file-tree-select-previous",
        "file-tree-open-selected",
    ],
)
def file_tree_navigation(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        nested = os.path.join(directory, "nested")
        os.mkdir(nested)
        child = os.path.join(nested, "child.txt")
        with open(child, "wb") as handle:
            handle.write(b"child content\n")
        with open(os.path.join(directory, "open.txt"), "wb") as handle:
            handle.write(b"other content\n")

        with Session(binary, [directory]) as session:
            session.wait_ready()
            _show_file_tree(session, "nested")

            _run_command(session, "file-tree-select-next")
            _run_command(session, "file-tree-open-selected")
            _wait_for_region_after_refresh(session, "body", "child.txt", index=1)

            _run_command(session, "file-tree-select-next")
            _run_command(session, "file-tree-open-selected")
            session.wait_for_region_text("body", "child content")

            _run_command(session, "file-tree-select-previous")
            _run_command(session, "file-tree-open-selected")
            session.wait_until(
                lambda _screen: "child.txt" not in session.region_text("body", 1),
                what="the nested directory to collapse",
            )

            output, code = session.quit()
        _assert_exit_zero("file-tree navigation", output, code)


@scenario(
    "file-tree create",
    commands=["file-tree-create-file", "file-tree-create-directory"],
)
def file_tree_create(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        seed = os.path.join(directory, "seed.txt")
        with open(seed, "wb") as handle:
            handle.write(b"seed\n")

        with Session(binary, [directory]) as session:
            session.wait_ready()
            _show_file_tree(session, "seed.txt")

            created_file = os.path.join(directory, "created.txt")
            session.extended_command("file-tree-create-file")
            session.wait_for_region_text("minibuffer", "Create file: ")
            session.type(created_file)
            session.send(keys.RET)
            _wait_for_path(
                session, created_file, os.path.isfile, "created file",
            )
            _wait_for_region_after_refresh(
                session, "body", "created.txt", index=0,
            )

            created_directory = os.path.join(directory, "created-dir")
            session.extended_command("file-tree-create-directory")
            session.wait_for_region_text("minibuffer", "Create directory: ")
            session.type(created_directory)
            session.send(keys.RET)
            _wait_for_path(
                session, created_directory, os.path.isdir, "created directory",
            )
            _wait_for_region_after_refresh(
                session, "body", "created-dir", index=0,
            )

            output, code = session.quit()
        _assert_exit_zero("file-tree create", output, code)


@scenario("file-tree rename/delete", commands=["file-tree-rename", "file-tree-delete"])
def file_tree_rename_delete(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        old_path = os.path.join(directory, "old.txt")
        with open(old_path, "wb") as handle:
            handle.write(b"old\n")

        with Session(binary, [directory]) as session:
            session.wait_ready()
            _show_file_tree(session, "old.txt")
            _run_command(session, "file-tree-select-next")

            new_path = os.path.join(directory, "renamed.txt")
            session.extended_command("file-tree-rename")
            session.wait_for_region_text("minibuffer", "Rename ")
            session.type(new_path)
            session.send(keys.RET)
            _wait_for_path(
                session, old_path, lambda path: not os.path.exists(path),
                "old path to disappear",
            )
            _wait_for_path(
                session, new_path, os.path.isfile, "renamed file",
            )
            _wait_for_region_after_refresh(session, "body", "renamed.txt")

            _run_command(session, "file-tree-select-next")
            _run_command(session, "file-tree-delete")
            _wait_for_path(
                session, new_path, lambda path: not os.path.exists(path),
                "deleted path to disappear",
            )

            output, code = session.quit()
        _assert_exit_zero("file-tree rename/delete", output, code)
