"""Session, bookmark, and register commands through a real PTY."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _assert_exit_zero(name, output, code):
    if code != 0:
        raise AssertionError(f"{name} exited with {code}: {output!r}")


def _wait_for_exact_line(session, region, expected, index=0):
    session.wait_until(
        lambda _screen: session.region_text(region, index).rstrip() == expected.rstrip(),
        what=f"{region} line {index} to equal {expected!r}",
    )


def _run_prompted_command(session, command, prompt, value):
    session.extended_command(command)
    _wait_for_exact_line(session, "minibuffer", prompt)
    session.type(value)
    session.send(keys.RET)


def _read_saved_session(session, path):
    session.wait_until(
        lambda _screen: os.path.isfile(path),
        what=f"session file {path!r} to be created",
    )
    with open(path, "rb") as handle:
        data = handle.read()
    if not data:
        raise AssertionError(f"session file {path!r} is empty")
    return data


@scenario("register copy and insert", commands=["copy-to-register", "insert-register"])
def register_copy_and_insert(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "register.txt")
        with open(path, "wb") as handle:
            handle.write(b"hello")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.send(keys.ctrl("x") + b"h")
            _run_prompted_command(
                session,
                "copy-to-register",
                "Copy region to register: ",
                "a",
            )
            _wait_for_exact_line(session, "minibuffer", "Copied region to register a")

            _run_prompted_command(
                session,
                "insert-register",
                "Insert register: ",
                "a",
            )
            _wait_for_exact_line(session, "body", "hellohello")
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, b"hellohello")

            output, code = session.quit()
        _assert_exit_zero("register copy and insert", output, code)


@scenario("register point and jump", commands=["point-to-register", "jump-to-register"])
def register_point_and_jump(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "position.txt")
        with open(path, "wb") as handle:
            handle.write(b"zero\npoint target\nend\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.send(keys.ctrl("n") + keys.ctrl("f") * 2)
            session.wait_for_region_cursor("body", 2, index=1)
            _run_prompted_command(
                session,
                "point-to-register",
                "Point to register: ",
                "p",
            )
            _wait_for_exact_line(session, "minibuffer", "Point stored in register p")

            session.send(keys.meta("<"))
            session.wait_for_region_cursor("body", 0, index=0)
            _run_prompted_command(
                session,
                "jump-to-register",
                "Jump to register: ",
                "p",
            )
            session.wait_for_region_cursor("body", 2, index=1)
            _wait_for_exact_line(session, "body", "point target", index=1)

            output, code = session.quit()
        _assert_exit_zero("register point and jump", output, code)


@scenario(
    "bookmarks set jump list delete",
    commands=["set-bookmark", "jump-to-bookmark", "list-bookmarks", "delete-bookmark"],
)
def bookmarks_set_jump_list_delete(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "bookmarks.txt")
        with open(path, "wb") as handle:
            handle.write(b"first\nbookmark target\nlast\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.send(keys.ctrl("n") + keys.ctrl("f") * 2)
            session.wait_for_region_cursor("body", 2, index=1)
            _run_prompted_command(
                session,
                "set-bookmark",
                "Set bookmark: ",
                "spot",
            )
            _wait_for_exact_line(session, "minibuffer", "Bookmark set: spot")

            session.send(keys.meta("<"))
            session.wait_for_region_cursor("body", 0, index=0)
            _run_prompted_command(
                session,
                "jump-to-bookmark",
                "Jump to bookmark: ",
                "spot",
            )
            session.wait_for_region_cursor("body", 2, index=1)
            _wait_for_exact_line(session, "body", "bookmark target", index=1)

            session.extended_command("list-bookmarks")
            _wait_for_exact_line(session, "minibuffer", "Bookmarks: spot")

            _run_prompted_command(
                session,
                "delete-bookmark",
                "Delete bookmark: ",
                "spot",
            )
            _wait_for_exact_line(session, "minibuffer", "Deleted bookmark: spot")
            session.extended_command("list-bookmarks")
            _wait_for_exact_line(session, "minibuffer", "No bookmarks")

            output, code = session.quit()
        _assert_exit_zero("bookmarks set jump list delete", output, code)


@scenario("session save and load", commands=["save-session", "load-session", "jump-to-bookmark"])
def session_save_and_load(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        buffer_path = os.path.join(directory, "session.txt")
        session_path = os.path.join(directory, "session.sexp")
        with open(buffer_path, "wb") as handle:
            handle.write(b"before\nrestored\n")

        with Session(binary, [buffer_path]) as session:
            session.wait_ready()
            session.send(keys.ctrl("n") + keys.ctrl("f") * 2)
            session.wait_for_region_cursor("body", 2, index=1)
            _run_prompted_command(
                session,
                "set-bookmark",
                "Set bookmark: ",
                "restore-spot",
            )
            _wait_for_exact_line(session, "minibuffer", "Bookmark set: restore-spot")

            _run_prompted_command(
                session,
                "save-session",
                "Save session to: ",
                session_path,
            )
            _wait_for_exact_line(session, "minibuffer", f"Session saved: {session_path}")
            data = _read_saved_session(session, session_path)
            for fragment in (b":LOOM-SESSION 5", b"restore-spot", b"before", b"restored"):
                if fragment not in data:
                    raise AssertionError(
                        f"session file {session_path!r} missing {fragment!r}: {data!r}"
                    )

            session.send(keys.meta("<"))
            session.type("changed ")
            _wait_for_exact_line(session, "body", "changed before")

            _run_prompted_command(
                session,
                "load-session",
                "Load session: ",
                session_path,
            )
            _wait_for_exact_line(session, "minibuffer", f"Session loaded: {session_path}")
            _wait_for_exact_line(session, "body", "before", index=0)
            _wait_for_exact_line(session, "body", "restored", index=1)
            session.wait_for_region_cursor("body", 2, index=1)

            _run_prompted_command(
                session,
                "jump-to-bookmark",
                "Jump to bookmark: ",
                "restore-spot",
            )
            session.wait_for_region_cursor("body", 2, index=1)
            _wait_for_exact_line(session, "body", "restored", index=1)

            output, code = session.quit()
        _assert_exit_zero("session save and load", output, code)
