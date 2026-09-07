"""PTY scenarios for the editing command catalogue."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _assert_exit_zero(name, output, code):
    if code != 0:
        raise AssertionError(f"{name} exited with {code}: {output!r}")


def _write(path, content):
    with open(path, "wb") as handle:
        handle.write(content)


def _save(session, path, expected):
    session.send(keys.ctrl("x") + keys.ctrl("s"))
    session.wait_for_file(path, expected)


def _close(session, name):
    output, code = session.quit()
    _assert_exit_zero(name, output, code)


def _wait_for_body(session, expected):
    session.wait_until(
        lambda screen: screen.text(session.layout.row("body")).rstrip() == expected,
        what=f"body region to equal {expected!r}",
    )


def _wait_for_body_prefix(session, expected):
    session.wait_until(
        lambda screen: screen.text(session.layout.row("body")).startswith(expected),
        what=f"body region to start with {expected!r}",
    )


@scenario(
    "editing/auto-save-current-buffer",
    commands=["auto-save-mode", "auto-save-current-buffer", "save-buffer"],
)
def auto_save_current_buffer(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "current.txt")
        sidecar = os.path.join(directory, "#current.txt#")
        _write(path, b"draft\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("auto-save-mode")
            session.wait_for_region_text("minibuffer", "Auto-save mode enabled")
            session.type("x")
            session.extended_command("auto-save-current-buffer")
            session.wait_for_file(sidecar, b"xdraft\n")
            _save(session, path, b"xdraft\n")
            _close(session, "editing/auto-save-current-buffer")


@scenario("editing/auto-save-mode", commands=["auto-save-mode"])
def auto_save_mode(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "mode.txt")
        _write(path, b"unchanged\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("auto-save-mode")
            session.wait_for_region_text("minibuffer", "Auto-save mode enabled")
            _close(session, "editing/auto-save-mode")


@scenario("editing/comment-line", commands=["comment-line", "save-buffer"])
def comment_line(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "comment.py")
        _write(path, b"value\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("comment-line")
            _wait_for_body_prefix(session, "# value")
            _save(session, path, b"# value\n")
            _close(session, "editing/comment-line")


@scenario(
    "editing/delete-backward-char",
    commands=["delete-backward-char", "save-buffer"],
)
def delete_backward_char(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "backward.txt")
        _write(path, b"abc\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.send(keys.ctrl("f") + keys.ctrl("f"))
            session.extended_command("delete-backward-char")
            _wait_for_body_prefix(session, "ac")
            _save(session, path, b"ac\n")
            _close(session, "editing/delete-backward-char")


@scenario("editing/delete-char", commands=["delete-char", "save-buffer"])
def delete_char(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "forward.txt")
        _write(path, b"abc\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("delete-char")
            _wait_for_body_prefix(session, "bc")
            _save(session, path, b"bc\n")
            _close(session, "editing/delete-char")


@scenario(
    "editing/indent-for-tab-command",
    commands=["indent-for-tab-command", "save-buffer"],
)
def indent_for_tab_command(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "indent.py")
        _write(path, b"value\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("indent-for-tab-command")
            _wait_for_body_prefix(session, "    value")
            _save(session, path, b"    value\n")
            _close(session, "editing/indent-for-tab-command")


@scenario("editing/kill-line", commands=["kill-line", "save-buffer"])
def kill_line(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "line.txt")
        _write(path, b"first\nsecond\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("kill-line")
            _save(session, path, b"\nsecond\n")
            _close(session, "editing/kill-line")


@scenario("editing/kill-region", commands=["set-mark-command", "kill-region", "save-buffer"])
def kill_region(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "region.txt")
        _write(path, b"hello-world\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("set-mark-command")
            session.send(keys.ctrl("f") * 5)
            session.extended_command("kill-region")
            _wait_for_body_prefix(session, "-world")
            _save(session, path, b"-world\n")
            _close(session, "editing/kill-region")


@scenario(
    "editing/kill-ring-save",
    commands=["set-mark-command", "kill-ring-save", "yank", "save-buffer"],
)
def kill_ring_save(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "copy.txt")
        _write(path, b"hello-world\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("set-mark-command")
            session.send(keys.ctrl("f") * 5)
            session.extended_command("kill-ring-save")
            session.extended_command("yank")
            _wait_for_body_prefix(session, "hellohello-world")
            _save(session, path, b"hellohello-world\n")
            _close(session, "editing/kill-ring-save")


@scenario("editing/kill-sexp", commands=["kill-sexp", "save-buffer"])
def kill_sexp(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "sexp.lisp")
        _write(path, b"(a b) c\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("kill-sexp")
            _wait_for_body_prefix(session, " c")
            _save(session, path, b" c\n")
            _close(session, "editing/kill-sexp")


@scenario("editing/kill-word", commands=["kill-word", "save-buffer"])
def kill_word(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "word.txt")
        _write(path, b"hello world\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("kill-word")
            _wait_for_body_prefix(session, " world")
            _save(session, path, b" world\n")
            _close(session, "editing/kill-word")


@scenario(
    "editing/mark-whole-buffer",
    commands=["mark-whole-buffer", "kill-region", "save-buffer"],
)
def mark_whole_buffer(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "whole.txt")
        _write(path, b"all text\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("mark-whole-buffer")
            session.extended_command("kill-region")
            _wait_for_body(session, "")
            _save(session, path, b"")
            _close(session, "editing/mark-whole-buffer")


@scenario("editing/newline", commands=["newline", "save-buffer"])
def newline(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "newline.txt")
        _write(path, b"abc\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.send(keys.ctrl("f"))
            session.extended_command("newline")
            _wait_for_body_prefix(session, "a")
            _save(session, path, b"a\nbc\n")
            _close(session, "editing/newline")


@scenario("editing/open-line", commands=["open-line", "save-buffer"])
def open_line(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "open-line.txt")
        _write(path, b"abc\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.send(keys.ctrl("f"))
            session.extended_command("open-line")
            session.wait_for_region_cursor("body", 1)
            _save(session, path, b"a\nbc\n")
            _close(session, "editing/open-line")


@scenario("editing/replace-string", commands=["replace-string", "save-buffer"])
def replace_string(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "replace.txt")
        _write(path, b"foo foo\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("replace-string")
            session.wait_for_text("Replace (regex): ")
            session.type("foo")
            session.send(keys.RET)
            session.wait_for_text("With: ")
            session.type("bar")
            session.send(keys.RET)
            _wait_for_body_prefix(session, "bar bar")
            _save(session, path, b"bar bar\n")
            _close(session, "editing/replace-string")


@scenario("editing/set-mark-command", commands=["set-mark-command", "kill-region", "save-buffer"])
def set_mark_command(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "mark.txt")
        _write(path, b"mark me\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("set-mark-command")
            session.send(keys.ctrl("f") * 4)
            session.extended_command("kill-region")
            _wait_for_body_prefix(session, " me")
            _save(session, path, b" me\n")
            _close(session, "editing/set-mark-command")


@scenario("editing/toggle-auto-save", commands=["toggle-auto-save", "auto-save-current-buffer", "save-buffer"])
def toggle_auto_save(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "toggle.txt")
        sidecar = os.path.join(directory, "#toggle.txt#")
        _write(path, b"draft\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("toggle-auto-save")
            session.wait_for_region_text("minibuffer", "Auto-save enabled")
            session.type("x")
            session.extended_command("auto-save-current-buffer")
            session.wait_for_file(sidecar, b"xdraft\n")
            _save(session, path, b"xdraft\n")
            _close(session, "editing/toggle-auto-save")


@scenario("editing/toggle-read-only", commands=["toggle-read-only", "save-buffer"])
def toggle_read_only(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "readonly.txt")
        _write(path, b"a\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("toggle-read-only")
            session.wait_for_region_text("minibuffer", "Buffer is read-only")
            session.type("X")
            session.extended_command("toggle-read-only")
            session.wait_for_region_text("minibuffer", "Buffer is writable")
            session.type("Y")
            _wait_for_body_prefix(session, "Ya")
            _save(session, path, b"Ya\n")
            _close(session, "editing/toggle-read-only")


@scenario("editing/undo", commands=["undo", "save-buffer"])
def undo(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "undo.txt")
        _write(path, b"a\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.type("x")
            _wait_for_body_prefix(session, "xa")
            session.send(keys.ctrl("x") + keys.ctrl("u"))
            session.send(keys.ctrl("x") + keys.ctrl("u"))
            _wait_for_body_prefix(session, "a")
            _save(session, path, b"a\n")
            _close(session, "editing/undo")


@scenario("editing/redo", commands=["undo", "redo", "save-buffer"])
def redo(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "redo.txt")
        _write(path, b"a\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.type("x")
            _wait_for_body_prefix(session, "xa")
            session.send(keys.ctrl("x") + keys.ctrl("u"))
            session.send(keys.ctrl("x") + keys.ctrl("u"))
            _wait_for_body_prefix(session, "a")
            session.send(keys.ctrl("x") + keys.ctrl("y"))
            session.send(keys.ctrl("x") + keys.ctrl("y"))
            _wait_for_body_prefix(session, "xa")
            _save(session, path, b"xa\n")
            _close(session, "editing/redo")


@scenario("editing/yank", commands=["set-mark-command", "kill-region", "yank", "save-buffer"])
def yank(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "yank.txt")
        _write(path, b"hello world\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("set-mark-command")
            session.send(keys.ctrl("f") * 5)
            session.extended_command("kill-region")
            session.extended_command("yank")
            _wait_for_body_prefix(session, "hello world")
            _save(session, path, b"hello world\n")
            _close(session, "editing/yank")


@scenario(
    "editing/yank-pop",
    commands=[
        "set-mark-command",
        "kill-ring-save",
        "beginning-of-buffer",
        "yank",
        "yank-pop",
        "save-buffer",
    ],
)
def yank_pop(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "yank-pop.txt")
        _write(path, b"one two\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("set-mark-command")
            session.send(keys.ctrl("f") * 3)
            session.extended_command("kill-ring-save")
            session.send(keys.ctrl("f"))
            session.extended_command("set-mark-command")
            session.send(keys.ctrl("f") * 3)
            session.extended_command("kill-ring-save")
            session.extended_command("beginning-of-buffer")
            session.extended_command("yank")
            session.send(keys.meta("y"))
            _wait_for_body_prefix(session, "oneone two")
            _save(session, path, b"oneone two\n")
            _close(session, "editing/yank-pop")


@scenario(
    "editing/narrow-to-region",
    commands=["set-mark-command", "narrow-to-region", "save-buffer"],
)
def narrow_to_region(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "narrow.txt")
        original = b"hidden-target-tail\n"
        _write(path, original)

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.send(keys.ctrl("f") * 7)
            session.extended_command("set-mark-command")
            session.send(keys.ctrl("f") * 6)
            session.extended_command("narrow-to-region")
            _wait_for_body(session, "target")
            _save(session, path, original)
            _close(session, "editing/narrow-to-region")


@scenario(
    "editing/widen",
    commands=["set-mark-command", "narrow-to-region", "widen", "save-buffer"],
)
def widen(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "widen.txt")
        original = b"hidden-target-tail\n"
        _write(path, original)

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.send(keys.ctrl("f") * 7)
            session.extended_command("set-mark-command")
            session.send(keys.ctrl("f") * 6)
            session.extended_command("narrow-to-region")
            _wait_for_body(session, "target")
            session.extended_command("widen")
            _wait_for_body_prefix(session, "hidden-target-tail")
            _save(session, path, original)
            _close(session, "editing/widen")


@scenario("editing/write-file", commands=["write-file"])
def write_file(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        source_path = os.path.join(directory, "source.txt")
        target_path = os.path.join(directory, "written.txt")
        _write(source_path, b"source\n")

        with Session(binary, [source_path]) as session:
            session.wait_ready()
            session.extended_command("write-file")
            session.wait_for_text("Write file: ")
            session.type(target_path)
            session.send(keys.RET)
            session.wait_for_file(target_path, b"source\n")
            _close(session, "editing/write-file")
