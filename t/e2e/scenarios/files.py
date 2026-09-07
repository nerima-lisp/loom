"""PTY scenarios for file, buffer, and project commands."""

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


def _wait_for_body_text(session, substring, timeout=10.0):
    session.wait_until(
        lambda _screen: any(
            substring in session.region_text("body", index)
            for index in range(session.layout.body_height)
        ),
        timeout,
        f"body to contain {substring!r}",
    )


def _assert_body_text(session, index, expected):
    actual = session.region_text("body", index).rstrip()
    if actual != expected:
        raise AssertionError(
            f"body row {index} expected {expected!r}, got {actual!r}"
        )


def _wait_for_body_row(session, index, expected, timeout=10.0):
    session.wait_until(
        lambda _screen: session.region_text("body", index).rstrip() == expected,
        timeout,
        f"body row {index} to equal {expected!r}",
    )


@scenario(
    "file and buffer commands",
    commands=[
        "find-file",
        "write-file",
        "save-buffer",
        "recent-file",
        "switch-to-buffer",
        "kill-buffer",
        "save-buffers-kill-terminal",
    ],
)
def file_and_buffer_commands(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-files-", dir="/tmp") as directory:
        directory = os.path.realpath(directory)
        alpha_path = os.path.join(directory, "alpha.txt")
        beta_path = os.path.join(directory, "beta.txt")
        copy_path = os.path.join(directory, "copy.txt")
        _write(alpha_path, b"alpha\n")
        _write(beta_path, b"beta\n")

        with Session(binary, [alpha_path]) as session:
            session.wait_ready()
            if session.home_dir == os.path.expanduser("~"):
                raise AssertionError("Session did not isolate HOME")
            _assert_body_text(session, 0, "alpha")
            session.wait_for_region_text("mode-line", "Ln 1, Col 1")

            session.send(keys.ctrl("x") + keys.ctrl("f"))
            session.wait_for_region_text("minibuffer", "Find file: ")
            session.type(beta_path)
            session.send(keys.RET)
            _wait_for_body_text(session, "beta")
            _assert_body_text(session, 0, "beta")

            session.send(keys.ctrl("x") + keys.ctrl("w"))
            session.wait_for_region_text("minibuffer", "Write file: ")
            session.type(copy_path)
            session.send(keys.RET)
            session.wait_for_file(copy_path, b"beta\n")
            _assert_body_text(session, 0, "beta")

            session.type("!")
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(copy_path, b"!beta\n")
            _assert_body_text(session, 0, "!beta")

            session.send(keys.ctrl("x") + b"rf")
            session.wait_for_region_text("minibuffer", "Recent file: ")
            session.type(beta_path)
            session.send(keys.RET)
            _wait_for_body_row(session, 0, "beta")
            _assert_body_text(session, 0, "beta")

            session.send(keys.ctrl("x") + b"b")
            session.wait_for_region_text("minibuffer", "Switch to buffer: ")
            session.type("copy.txt")
            session.send(keys.RET)
            _wait_for_body_row(session, 0, "!beta")
            _assert_body_text(session, 0, "!beta")
            session.wait_for_region_text("mode-line", "Ln 1, Col 2")

            session.send(keys.ctrl("x") + b"k")
            session.wait_for_region_text("minibuffer", "Kill buffer: ")
            session.type("copy.txt")
            session.send(keys.RET)
            session.wait_for_region_text("minibuffer", "Killed copy.txt")
            _wait_for_body_row(session, 0, "beta")
            _assert_body_text(session, 0, "beta")

            session.send(keys.ctrl("x") + b"b")
            session.wait_for_region_text("minibuffer", "Switch to buffer: ")
            session.type("copy.txt")
            session.send(keys.RET)
            session.wait_for_region_text("minibuffer", "No such buffer: copy.txt")
            _assert_body_text(session, 0, "beta")

            output, code = session.quit()
        _assert_exit_zero("file and buffer commands", output, code)


@scenario("open line", commands=["open-line", "save-buffer", "save-buffers-kill-terminal"])
def open_line(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-open-line-", dir="/tmp") as directory:
        path = os.path.join(os.path.realpath(directory), "lines.txt")
        _write(path, b"alpha\nomega\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            _assert_body_text(session, 0, "alpha")

            session.send(keys.ctrl("o"))
            session.wait_for_region_text("body", "alpha", index=1)
            session.wait_for_region_text("body", "omega", index=2)
            _assert_body_text(session, 0, "")
            session.wait_for_region_cursor("body", 0)
            session.wait_for_region_text("mode-line", "Ln 1, Col 1")

            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, b"\nalpha\nomega\n")
            _assert_body_text(session, 1, "alpha")

            output, code = session.quit()
        _assert_exit_zero("open line", output, code)


@scenario(
    "project file commands",
    commands=["project-root", "project-find-file", "project-search", "save-buffers-kill-terminal"],
)
def project_file_commands(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-project-") as directory:
        root = os.path.realpath(directory)
        source_directory = os.path.join(root, "src")
        ignored_directory = os.path.join(root, "target")
        os.mkdir(source_directory)
        os.mkdir(ignored_directory)
        _write(os.path.join(root, "flake.nix"), b"{}\n")
        source_path = os.path.join(source_directory, "main.py")
        other_path = os.path.join(source_directory, "other.py")
        ignored_path = os.path.join(ignored_directory, "generated.py")
        _write(source_path, b"needle\nmain\n")
        _write(other_path, b"other\n")
        _write(ignored_path, b"needle\nignored\n")

        with Session(binary, [source_path]) as session:
            session.wait_ready()
            session.send(keys.ctrl("x") + b"pr")
            session.wait_for_region_text("minibuffer", "Project root: ")
            if root not in session.region_text("minibuffer"):
                raise AssertionError(
                    f"project root message omitted {root!r}: "
                    f"{session.region_text('minibuffer')!r}"
                )

            session.send(keys.ctrl("x") + b"pf")
            session.wait_for_region_text("minibuffer", "Project file: ")
            session.type("src/other.py")
            session.send(keys.RET)
            _wait_for_body_text(session, "other")
            _assert_body_text(session, 0, "other")
            session.wait_for_region_text("mode-line", "Ln 1, Col 1")

            session.send(keys.ctrl("x") + b"ps")
            session.wait_for_region_text("minibuffer", "Project search: ")
            session.type("needle")
            session.send(keys.RET)
            session.wait_for_region_text("minibuffer", "Matches:")
            message = session.region_text("minibuffer")
            if "src/main.py:1" not in message:
                raise AssertionError(f"project search omitted source match: {message!r}")
            if "generated.py" in message:
                raise AssertionError(f"project search included ignored file: {message!r}")
            _assert_body_text(session, 0, "other")
            with open(other_path, "rb") as handle:
                unchanged = handle.read()
            if unchanged != b"other\n":
                raise AssertionError("project-find-file changed the visited file")

            output, code = session.quit()
        _assert_exit_zero("project file commands", output, code)


@scenario("help command", commands=["help", "save-buffers-kill-terminal"])
def help_command(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-help-", dir="/tmp") as directory:
        path = os.path.join(os.path.realpath(directory), "help.txt")
        _write(path, b"help body\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            _assert_body_text(session, 0, "help body")
            session.extended_command("help")
            session.wait_for_region_text("minibuffer", "Help: M-x Command")
            session.wait_for_region_text("body", "help body")
            session.wait_for_region_text("mode-line", "Ln 1, Col 1")

            output, code = session.quit()
        _assert_exit_zero("help command", output, code)
