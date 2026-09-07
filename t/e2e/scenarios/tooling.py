"""Real shell, terminal, formatter, and Git PTY scenarios."""

import os
import subprocess
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session

from .scenario_helpers import assert_exit_zero, write_buffer


def _git_repo():
    directory = tempfile.TemporaryDirectory(prefix="loom-e2e-git-")
    subprocess.run(["git", "init", "-q", directory.name], check=True)
    subprocess.run(
        ["git", "-C", directory.name, "config", "user.email", "e2e@example.invalid"],
        check=True,
    )
    subprocess.run(
        ["git", "-C", directory.name, "config", "user.name", "E2E"],
        check=True,
    )
    path = write_buffer(directory.name, "tracked.txt", b"tracked\n")
    subprocess.run(["git", "-C", directory.name, "add", "tracked.txt"], check=True)
    subprocess.run(
        ["git", "-C", directory.name, "commit", "-q", "-m", "initial"],
        check=True,
    )
    return directory, path


@scenario("tooling/git-status", commands=["git-status"])
def git_status(binary):
    directory, path = _git_repo()
    try:
        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("git-status")
            session.wait_for_text("##")
            output, code = session.quit()
        assert_exit_zero("git-status", output, code)
    finally:
        directory.cleanup()


@scenario("tooling/git-diff", commands=["git-diff"])
def git_diff(binary):
    directory, path = _git_repo()
    try:
        with open(path, "ab") as handle:
            handle.write(b"working tree\n")
        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("git-diff")
            session.wait_for_text("diff --git")
            output, code = session.quit()
        assert_exit_zero("git-diff", output, code)
    finally:
        directory.cleanup()


@scenario("tooling/git-stage-file", commands=["git-stage-file"])
def git_stage_file(binary):
    directory, path = _git_repo()
    try:
        with open(path, "ab") as handle:
            handle.write(b"unstaged\n")
        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("git-stage-file")
            session.wait_for_text("Git stage file: ")
            session.type("tracked.txt")
            session.send(keys.RET)
            session.wait_for_text("Git staged")
            output, code = session.quit()
        assert_exit_zero("git-stage-file", output, code)
        staged = subprocess.run(
            ["git", "-C", directory.name, "diff", "--cached", "--name-only"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
        if "tracked.txt" not in staged:
            raise AssertionError(f"git stage did not update the index: {staged!r}")
    finally:
        directory.cleanup()


@scenario("tooling/git-diff-staged", commands=["git-diff-staged"])
def git_diff_staged(binary):
    directory, path = _git_repo()
    try:
        with open(path, "ab") as handle:
            handle.write(b"staged\n")
        subprocess.run(["git", "-C", directory.name, "add", "tracked.txt"], check=True)
        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("git-diff-staged")
            session.wait_for_text("diff --git")
            output, code = session.quit()
        assert_exit_zero("git-diff-staged", output, code)
    finally:
        directory.cleanup()


@scenario("tooling/git-unstage-file", commands=["git-unstage-file"])
def git_unstage_file(binary):
    directory, path = _git_repo()
    try:
        with open(path, "ab") as handle:
            handle.write(b"staged\n")
        subprocess.run(["git", "-C", directory.name, "add", "tracked.txt"], check=True)
        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("git-unstage-file")
            session.wait_for_text("Git unstage file: ")
            session.type("tracked.txt")
            session.send(keys.RET)
            session.wait_for_text("Git unstaged")
            output, code = session.quit()
        assert_exit_zero("git-unstage-file", output, code)
        staged = subprocess.run(
            ["git", "-C", directory.name, "diff", "--cached", "--name-only"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
        if staged.strip():
            raise AssertionError(f"git unstage left index changes: {staged!r}")
    finally:
        directory.cleanup()


@scenario("tooling/pipe-command", commands=["pipe-command"])
def pipe_command(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = write_buffer(directory, contents=b"pipe input\n")
        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("pipe-command")
            session.wait_for_text("Pipe command: ")
            session.type("printf pipe-e2e")
            session.send(keys.RET)
            session.wait_for_text("pipe-e2e")
            output, code = session.quit()
        assert_exit_zero("pipe-command", output, code)


def _set_format(session):
    session.extended_command("set-format-command")
    session.wait_for_text("Format-on-save command: ")
    session.type("tr a-z A-Z")
    session.send(keys.RET)
    session.wait_for_text("Format-on-save command set")


@scenario("tooling/set-format-command", commands=["set-format-command"])
def set_format_command(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = write_buffer(directory, contents=b"lower\n")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _set_format(session)
            output, code = session.quit()
        assert_exit_zero("set-format-command", output, code)


@scenario("tooling/format-current-buffer", commands=["format-current-buffer"])
def format_current_buffer(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = write_buffer(directory, contents=b"lower\n")
        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("format-current-buffer")
            session.wait_for_text("Format command: ")
            session.type("tr a-z A-Z")
            session.send(keys.RET)
            session.wait_for_text("Buffer formatted successfully")
            session.wait_for_text("LOWER")
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, b"LOWER\n")
            output, code = session.quit()
        assert_exit_zero("format-current-buffer", output, code)


@scenario("tooling/format-on-save-mode", commands=["format-on-save-mode"])
def format_on_save_mode(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = write_buffer(directory, contents=b"lower\n")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _set_format(session)
            session.extended_command("format-on-save-mode")
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, b"LOWER\n")
            output, code = session.quit()
        assert_exit_zero("format-on-save-mode", output, code)


@scenario("tooling/terminal", commands=["terminal"])
def terminal(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = write_buffer(directory, contents=b"terminal fixture\n")
        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("terminal")
            session.type("printf terminal-e2e\n")
            session.wait_for_text("terminal-e2e")
            session.type("exit\n")
            output, code = session.quit()
        assert_exit_zero("terminal", output, code)


@scenario("tooling/terminal-stop", commands=["terminal-stop"])
def terminal_stop(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = write_buffer(directory, contents=b"terminal fixture\n")
        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("terminal")
            session.extended_command("terminal-stop")
            session.wait_for_text("Terminal stopped")
            output, code = session.quit()
        assert_exit_zero("terminal-stop", output, code)
