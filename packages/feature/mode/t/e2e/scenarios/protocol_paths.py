"""PTY coverage for the major-mode editing and completion protocols."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _write(path, contents):
    with open(path, "wb") as handle:
        handle.write(contents)


def _save(session, path, expected):
    session.send(keys.ctrl("x") + keys.ctrl("s"))
    session.wait_for_file(path, expected)
    session.assert_file_bytes(path, expected)


def _close(session, name):
    output, code = session.quit()
    if code != 0:
        raise AssertionError(f"{name} exited with {code}: {output!r}")


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


def _indent_key(session, index=1):
    session.key("TAB")
    _assert_body(session, "    value", index)


def _comment_mx(session, index=0):
    session.extended_command("comment-line")
    _assert_body(session, "# value", index)


def _comment_key(session):
    session.send(keys.meta(";"))


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
            _indent_key(session)
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
    "mode/indent-undo",
    commands=["set-major-mode", "indent-for-tab-command", "undo", "save-buffer"],
)
def indent_undo(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-mode-indent-undo-") as directory:
        original = b"    root\nvalue\n"
        path = _python_path(directory, "indent.py", original)
        with Session(binary, [path]) as session:
            session.wait_ready()
            _select_python_mode(session)
            session.key("DOWN")
            _indent_key(session)
            session.send(keys.ctrl("x") + keys.text("u"))
            _assert_body(session, "value", 1)
            _save(session, path, original)
            _close(session, "mode/indent-undo")


@scenario(
    "mode/indent-read-only",
    commands=["set-major-mode", "toggle-read-only", "indent-for-tab-command"],
)
def indent_read_only(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-mode-indent-read-only-") as directory:
        original = b"    root\nvalue\n"
        path = _python_path(directory, "indent.py", original)
        with Session(binary, [path]) as session:
            session.wait_ready()
            _select_python_mode(session)
            session.key("DOWN")
            session.extended_command("toggle-read-only")
            session.wait_for_region_text("minibuffer", "Buffer is read-only")
            session.key("TAB")
            _assert_body(session, "value", 1)
            session.assert_file_bytes(path, original)
            _close(session, "mode/indent-read-only")


@scenario(
    "mode/indent-narrow",
    commands=[
        "set-major-mode",
        "set-mark-command",
        "narrow-to-region",
        "indent-for-tab-command",
        "widen",
        "save-buffer",
    ],
)
def indent_narrow(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-mode-indent-narrow-") as directory:
        original = b"before\n    root\nvalue\nafter\n"
        expected = b"before\n    root\n    value\nafter\n"
        path = _python_path(directory, "indent.py", original)
        with Session(binary, [path]) as session:
            session.wait_ready()
            _select_python_mode(session)
            session.send(keys.ctrl("f") * len("before\n    root\n"))
            session.extended_command("set-mark-command")
            session.send(keys.ctrl("f") * len("value"))
            session.extended_command("narrow-to-region")
            _indent_key(session, 0)
            session.extended_command("widen")
            _save(session, path, expected)
            _close(session, "mode/indent-narrow")


@scenario(
    "mode/indent-split-window",
    commands=[
        "set-major-mode",
        "split-window-below",
        "indent-for-tab-command",
        "save-buffer",
    ],
)
def indent_split_window(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-mode-indent-split-") as directory:
        path = _python_path(directory, "indent.py", b"    root\nvalue\n")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _select_python_mode(session)
            session.extended_command("split-window-below")
            lower_window = session.layout.body_height // 2 + 1
            session.key("DOWN")
            session.key("TAB")
            _assert_body(session, "    value", 1)
            _assert_body(session, "    value", lower_window + 1)
            _save(session, path, b"    root\n    value\n")
            _close(session, "mode/indent-split-window")


@scenario(
    "mode/indent-macro",
    commands=[
        "set-major-mode",
        "start-kbd-macro",
        "indent-for-tab-command",
        "end-kbd-macro",
        "call-last-kbd-macro",
        "save-buffer",
    ],
)
def indent_macro(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-mode-indent-macro-") as directory:
        expected = b"root\n    value\n    value\n"
        path = _python_path(directory, "indent.py", b"root\nvalue\nvalue\n")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _select_python_mode(session)
            session.key("DOWN")
            session.send(keys.ctrl("x") + b"(" + session.profile.key("TAB"))
            session.send(keys.ctrl("x") + b")")
            session.key("DOWN")
            session.send(keys.ctrl("x") + b"e")
            _assert_body(session, "    value", 1)
            _assert_body(session, "    value", 2)
            _save(session, path, expected)
            _close(session, "mode/indent-macro")


@scenario(
    "mode/indent-prefix",
    commands=[
        "set-major-mode",
        "universal-argument",
        "indent-for-tab-command",
        "save-buffer",
    ],
)
def indent_prefix(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-mode-indent-prefix-") as directory:
        path = _python_path(directory, "indent.py", b"    root\nvalue\n")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _select_python_mode(session)
            session.key("DOWN")
            session.send(keys.ctrl("u"))
            session.type("4")
            _indent_key(session)
            _save(session, path, b"    root\n    value\n")
            _close(session, "mode/indent-prefix")


@scenario(
    "mode/comment-line-key",
    commands=["set-major-mode", "comment-line", "save-buffer"],
)
def comment_line_key(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-mode-comment-key-") as directory:
        path = _python_path(directory, "comment.py", b"value\n")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _select_python_mode(session)
            _comment_key(session)
            _assert_body(session, "value #")
            _save(session, path, b"value #\n")
            _close(session, "mode/comment-line-key")


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
            _comment_mx(session)
            _save(session, path, b"# value\n")
            _close(session, "mode/comment-line-mx")


@scenario(
    "mode/comment-line-undo",
    commands=["set-major-mode", "comment-line", "undo", "save-buffer"],
)
def comment_line_undo(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-mode-comment-undo-") as directory:
        original = b"value\n"
        path = _python_path(directory, "comment.py", original)
        with Session(binary, [path]) as session:
            session.wait_ready()
            _select_python_mode(session)
            _comment_key(session)
            _assert_body(session, "value #")
            session.send(keys.ctrl("x") + keys.text("u"))
            _assert_body(session, "value")
            _save(session, path, original)
            _close(session, "mode/comment-line-undo")


@scenario(
    "mode/comment-line-read-only",
    commands=["set-major-mode", "toggle-read-only", "comment-line"],
)
def comment_line_read_only(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-mode-comment-read-only-") as directory:
        original = b"value\n"
        path = _python_path(directory, "comment.py", original)
        with Session(binary, [path]) as session:
            session.wait_ready()
            _select_python_mode(session)
            session.extended_command("toggle-read-only")
            session.wait_for_region_text("minibuffer", "Buffer is read-only")
            _comment_key(session)
            _assert_body(session, "value")
            session.assert_file_bytes(path, original)
            _close(session, "mode/comment-line-read-only")


@scenario(
    "mode/comment-line-narrow",
    commands=[
        "set-major-mode",
        "set-mark-command",
        "narrow-to-region",
        "comment-line",
        "widen",
        "save-buffer",
    ],
)
def comment_line_narrow(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-mode-comment-narrow-") as directory:
        original = b"before\nvalue\nafter\n"
        expected = b"before\n# value\nafter\n"
        path = _python_path(directory, "comment.py", original)
        with Session(binary, [path]) as session:
            session.wait_ready()
            session.send(
                keys.meta("x")
                + b"set-major-mode\rPython\r"
                + keys.ctrl("f") * len("before\n")
                + keys.ctrl("@")
                + keys.ctrl("f") * len("value")
                + keys.ctrl("x")
                + b"nn"
                + keys.meta(";")
                + keys.ctrl("x")
                + b"nw"
            )
            _save(session, path, expected)
            _close(session, "mode/comment-line-narrow")


@scenario(
    "mode/comment-line-split-window",
    commands=[
        "set-major-mode",
        "split-window-below",
        "comment-line",
        "save-buffer",
    ],
)
def comment_line_split_window(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-mode-comment-split-") as directory:
        path = _python_path(directory, "comment.py", b"root\nvalue\n")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _select_python_mode(session)
            session.extended_command("split-window-below")
            lower_window = session.layout.body_height // 2 + 1
            session.key("DOWN")
            _comment_key(session)
            _assert_body(session, "value #", 1)
            _assert_body(session, "value #", lower_window + 1)
            _save(session, path, b"root\nvalue #\n")
            _close(session, "mode/comment-line-split-window")


@scenario(
    "mode/comment-line-macro",
    commands=[
        "set-major-mode",
        "start-kbd-macro",
        "comment-line",
        "end-kbd-macro",
        "call-last-kbd-macro",
        "save-buffer",
    ],
)
def comment_line_macro(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-mode-comment-macro-") as directory:
        path = _python_path(directory, "comment.py", b"value\nvalue\n")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _select_python_mode(session)
            session.send(keys.ctrl("x") + b"(" + keys.meta(";"))
            session.send(keys.ctrl("x") + b")")
            session.key("DOWN")
            session.send(keys.ctrl("x") + b"e")
            _assert_body(session, "value #")
            _assert_body(session, "value #", 1)
            _save(session, path, b"value #\nvalue #\n")
            _close(session, "mode/comment-line-macro")


@scenario(
    "mode/comment-line-prefix",
    commands=[
        "set-major-mode",
        "universal-argument",
        "comment-line",
        "save-buffer",
    ],
)
def comment_line_prefix(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-mode-comment-prefix-") as directory:
        path = _python_path(directory, "comment.py", b"value\n")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _select_python_mode(session)
            session.send(keys.ctrl("u"))
            session.type("4")
            _comment_key(session)
            _assert_body(session, "value #")
            _save(session, path, b"value #\n")
            _close(session, "mode/comment-line-prefix")


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
            _major_mode_prompt(session)
            session.key("UP")
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
