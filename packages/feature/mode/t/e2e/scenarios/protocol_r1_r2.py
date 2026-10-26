"""PTY coverage for the major-mode command entry and prompt routes."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _write(path, contents):
    with open(path, "wb") as handle:
        handle.write(contents)


def _python_path(directory, name, contents):
    path = os.path.join(directory, name)
    _write(path, contents)
    return path


def _assert_body(session, expected, index=0):
    session.wait_for_region_text("body", expected, index=index)
    session.assert_screen_text(
        expected, match="contains", region="body", index=index
    )


def _select_python_mode(session):
    session.extended_command("set-major-mode")
    session.wait_for_region_text("minibuffer", "Major mode: ")
    session.type("Python")
    session.key("RET")
    session.wait_for_region_text("minibuffer", "Mode: Python")


def _save(session, path, expected):
    session.send(keys.ctrl("x") + keys.ctrl("s"))
    session.wait_for_file(path, expected)
    session.assert_file_bytes(path, expected)


def _close(session, name):
    output, code = session.quit()
    if code != 0:
        raise AssertionError(f"{name} exited with {code}: {output!r}")


@scenario(
    "mode/indent-key",
    commands=["set-major-mode", "indent-for-tab-command", "save-buffer"],
)
def indent_key(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-mode-indent-key-") as directory:
        path = _python_path(directory, "indent.py", b"    root\nvalue\n")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _select_python_mode(session)
            session.key("DOWN")
            session.key("TAB")
            _assert_body(session, "    value", 1)
            _save(session, path, b"    root\n    value\n")
            _close(session, "mode/indent-key")


@scenario(
    "mode/indent-mx",
    commands=["set-major-mode", "indent-for-tab-command", "save-buffer"],
)
def indent_mx(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-mode-indent-mx-") as directory:
        path = _python_path(directory, "indent.py", b"    root\nvalue\n")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _select_python_mode(session)
            session.key("DOWN")
            session.extended_command("indent-for-tab-command")
            _assert_body(session, "    value", 1)
            _save(session, path, b"    root\n    value\n")
            _close(session, "mode/indent-mx")


@scenario(
    "mode/comment-line-mx",
    commands=["set-major-mode", "comment-line", "save-buffer"],
)
def comment_line_mx(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-mode-comment-mx-") as directory:
        path = _python_path(directory, "comment.py", b"value\n")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _select_python_mode(session)
            session.extended_command("comment-line")
            _assert_body(session, "# value")
            _save(session, path, b"# value\n")
            _close(session, "mode/comment-line-mx")


def _major_mode_prompt(session):
    session.extended_command("set-major-mode")
    session.wait_for_region_text("minibuffer", "Major mode: ")


@scenario("mode/set-major-mode-cancel", commands=["set-major-mode"])
def set_major_mode_cancel(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-mode-prompt-cancel-") as directory:
        path = os.path.join(directory, "buffer.txt")
        _write(path, b"")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _major_mode_prompt(session)
            session.send(keys.ctrl("g"))
            session.wait_for_region_text("minibuffer", "Quit")
            session.assert_screen_text(
                "Quit", match="contains", region="minibuffer"
            )
            _close(session, "mode/set-major-mode-cancel")


@scenario("mode/set-major-mode-empty", commands=["set-major-mode"])
def set_major_mode_empty(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-mode-prompt-empty-") as directory:
        path = os.path.join(directory, "buffer.txt")
        _write(path, b"")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _major_mode_prompt(session)
            session.key("RET")
            session.wait_for_region_text("minibuffer", "Unknown major mode:")
            session.assert_screen_text(
                "Unknown major mode:", match="contains", region="minibuffer"
            )
            _close(session, "mode/set-major-mode-empty")


@scenario("mode/set-major-mode-tab", commands=["set-major-mode"])
def set_major_mode_tab(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-mode-prompt-tab-") as directory:
        path = os.path.join(directory, "buffer.txt")
        _write(path, b"")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _major_mode_prompt(session)
            session.type("Pyth")
            session.key("TAB")
            session.key("RET")
            session.wait_for_region_text("minibuffer", "Mode: Python")
            session.assert_screen_text(
                "Mode: Python", match="contains", region="minibuffer"
            )
            _close(session, "mode/set-major-mode-tab")


@scenario("mode/set-major-mode-history", commands=["set-major-mode"])
def set_major_mode_history(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-mode-prompt-history-") as directory:
        path = os.path.join(directory, "buffer.txt")
        _write(path, b"")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _major_mode_prompt(session)
            session.type("Python")
            session.key("RET")
            session.wait_for_region_text("minibuffer", "Mode: Python")
            _major_mode_prompt(session)
            session.key("UP", "UP")
            session.key("RET")
            session.wait_for_region_text("minibuffer", "Mode: Python")
            session.assert_screen_text(
                "Mode: Python", match="contains", region="minibuffer"
            )
            _close(session, "mode/set-major-mode-history")


@scenario("mode/set-major-mode-invalid", commands=["set-major-mode"])
def set_major_mode_invalid(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-mode-prompt-invalid-") as directory:
        path = os.path.join(directory, "buffer.txt")
        _write(path, b"")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _major_mode_prompt(session)
            session.type("not-a-mode")
            session.key("RET")
            session.wait_for_region_text("minibuffer", "Unknown major mode: not-a-mode")
            session.assert_screen_text(
                "Unknown major mode: not-a-mode",
                match="contains",
                region="minibuffer",
            )
            _close(session, "mode/set-major-mode-invalid")


@scenario(
    "mode/toggle-truncate-lines-mx",
    commands=["toggle-truncate-lines"],
)
def toggle_truncate_lines_mx(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-mode-truncate-lines-") as directory:
        path = os.path.join(directory, "buffer.txt")
        _write(path, b"")
        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("toggle-truncate-lines")
            session.wait_for_region_text("minibuffer", "Truncate long lines")
            session.assert_screen_text(
                "Truncate long lines", match="contains", region="minibuffer"
            )
            _close(session, "mode/toggle-truncate-lines-mx")
