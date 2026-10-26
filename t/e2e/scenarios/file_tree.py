"""Exercise the file-tree commands through a real PTY and filesystem."""

import os
import tempfile
from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _assert_exit_zero(name, output, code):
    if code != 0:
        raise AssertionError(f"{name} exited with {code}: {output!r}")


def _wait_for_path(session, path, predicate, description):
    session.wait_for_external_state(
        description, lambda: bool(predicate(path)), True
    )


def _run_command(session, name):
    session.extended_command(name)
    session.wait_for_region_cursor("body", 0)


def _wait_for_region_text(session, region, expected, index=0):
    session.wait_for_region_text(region, expected, index=index)
    session.observe_screen_text(
        expected=expected,
        match="contains",
        region=region,
        index=index,
    )


def _show_file_tree(session, first_entry):
    session.extended_command("toggle-file-tree")
    session.wait_for_region_text("screen", first_entry)
    session.wait_for_region_cursor("body", 0)


@scenario("file-tree toggle", commands=["toggle-file-tree"])
def file_tree_toggle(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        marker = os.path.join(directory, "toggle-marker.txt")
        with open(marker, "wb") as handle:
            handle.write(b"marker\n")

        with Session(binary, [directory]) as session:
            session.wait_ready()
            session.send(keys.ctrl("x") + keys.text("d"))
            session.wait_for_region_text("screen", "toggle-marker.txt")
            session.wait_for_region_cursor("body", 0)

            session.send(keys.ctrl("x") + keys.text("d"))
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
            _wait_for_region_text(session, "screen", "child.txt", index=1)

            _run_command(session, "file-tree-select-next")
            _run_command(session, "file-tree-open-selected")
            session.wait_for_region_text("body", "child content")

            _run_command(session, "file-tree-select-previous")
            _run_command(session, "file-tree-open-selected")
            session.wait_for_region_absent_text("screen", "child.txt", index=1)

            output, code = session.quit()
        _assert_exit_zero("file-tree navigation", output, code)


@scenario(
    "file-tree create file",
    commands=["file-tree-create-file"],
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
            session.key("RET")
            _wait_for_path(
                session, created_file, os.path.isfile, "created file",
            )
            _wait_for_region_text(
                session, "screen", "created.txt", index=0,
            )

            output, code = session.quit()
        _assert_exit_zero("file-tree create file", output, code)


@scenario("file-tree create directory", commands=["file-tree-create-directory"])
def file_tree_create_directory(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        seed = os.path.join(directory, "seed.txt")
        with open(seed, "wb") as handle:
            handle.write(b"seed\n")

        with Session(binary, [directory]) as session:
            session.wait_ready()
            _show_file_tree(session, "seed.txt")

            created_directory = os.path.join(directory, "created-dir")
            session.extended_command("file-tree-create-directory")
            session.wait_for_region_text("minibuffer", "Create directory: ")
            session.type(created_directory)
            session.key("RET")
            _wait_for_path(
                session, created_directory, os.path.isdir, "created directory",
            )
            _wait_for_region_text(
                session, "screen", "created-dir", index=0,
            )

            output, code = session.quit()
        _assert_exit_zero("file-tree create directory", output, code)


@scenario("file-tree rename", commands=["file-tree-rename"])
def file_tree_rename(binary):
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
            session.key("RET")
            _wait_for_path(
                session, old_path, lambda path: not os.path.exists(path),
                "old path to disappear",
            )
            _wait_for_path(
                session, new_path, os.path.isfile, "renamed file",
            )
            _wait_for_region_text(session, "screen", "renamed.txt")

            output, code = session.quit()
        _assert_exit_zero("file-tree rename", output, code)


@scenario("file-tree delete", commands=["file-tree-delete"])
def file_tree_delete(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        deleted_path = os.path.join(directory, "delete-me.txt")
        with open(deleted_path, "wb") as handle:
            handle.write(b"delete me\n")

        with Session(binary, [directory]) as session:
            session.wait_ready()
            _show_file_tree(session, "delete-me.txt")
            _run_command(session, "file-tree-select-next")
            _run_command(session, "file-tree-delete")
            _wait_for_path(
                session, deleted_path, lambda path: not os.path.exists(path),
                "deleted path to disappear",
            )
            session.wait_for_region_absent_text("screen", "delete-me.txt")

            output, code = session.quit()
        _assert_exit_zero("file-tree delete", output, code)
