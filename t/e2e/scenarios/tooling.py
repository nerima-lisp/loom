"""Real shell, terminal, formatter, and Git PTY scenarios."""

import os
import shlex
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
            session.key("RET")
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
            session.key("RET")
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
            session.key("RET")
            session.wait_for_text("pipe-e2e")
            output, code = session.quit()
        assert_exit_zero("pipe-command", output, code)


def _set_format(session):
    session.extended_command("set-format-command")
    session.wait_for_text("Format-on-save command: ")
    session.type("tr a-z A-Z")
    session.key("RET")
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
            session.key("RET")
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
        marker_path = os.path.join(directory, "terminal-success-marker")
        marker_bytes = b"terminal-success-marker"
        with Session(binary, [path]) as session:
            session.wait_ready(timeout=2)
            session.extended_command("terminal", timeout=2)
            session.wait_for_region_contents(
                "minibuffer", "Terminal started", timeout=2
            )
            session.assert_screen_text(
                "Terminal started", match="contains", region="minibuffer"
            )
            session.type(
                f"printf terminal-success-marker > {shlex.quote(marker_path)}; "
                "printf terminal-; printf e2e\n"
            )
            session.wait_for_text("terminal-e2e", timeout=2)
            session.assert_screen_text(
                "terminal-e2e", match="contains", region="screen"
            )
            with open(marker_path, "rb") as marker:
                actual_marker = marker.read()
            session.assert_external_state(
                "terminal shell success marker", actual_marker, marker_bytes
            )
            session.type("exit\n")
            output, code = session.quit(timeout=2)
        assert_exit_zero("terminal", output, code)


@scenario("tooling/terminal-nonzero", commands=["terminal"])
def terminal_nonzero(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = write_buffer(directory, contents=b"terminal fixture\n")
        marker_path = os.path.join(directory, "terminal-nonzero-marker")
        marker_bytes = b"23"
        with Session(binary, [path]) as session:
            session.wait_ready(timeout=2)
            session.extended_command("terminal", timeout=2)
            session.wait_for_region_contents(
                "minibuffer", "Terminal started", timeout=2
            )
            session.type(
                "sh -c 'exit 23'; status=$?; "
                f"printf %s \"$status\" > {shlex.quote(marker_path)}; "
                "printf 'terminal-exit:%s\\n' \"$status\"\n"
            )
            session.wait_for_text("terminal-exit:23", timeout=2)
            session.assert_screen_text(
                "terminal-exit:23", match="contains", region="screen"
            )
            with open(marker_path, "rb") as marker:
                actual_marker = marker.read()
            session.assert_external_state(
                "terminal shell nonzero exit", actual_marker, marker_bytes
            )
            session.type("exit\n")
            output, code = session.quit(timeout=2)
        assert_exit_zero("terminal", output, code)


@scenario("tooling/terminal-interrupted", commands=["terminal"])
def terminal_interrupted(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = write_buffer(directory, contents=b"terminal fixture\n")
        marker_path = os.path.join(directory, "terminal-interrupted-marker")
        marker_bytes = b"130"
        with Session(binary, [path]) as session:
            session.wait_ready(timeout=2)
            session.extended_command("terminal", timeout=2)
            session.wait_for_region_contents(
                "minibuffer", "Terminal started", timeout=2
            )
            session.type(
                "sh -c 'trap \"exit 130\" INT; kill -INT \"$$\"'; "
                "status=$?; "
                f"printf %s \"$status\" > {shlex.quote(marker_path)}; "
                "printf 'sigint-ok:%s\\n' \"$status\"\n"
            )
            session.wait_for_text("sigint-ok:130", timeout=2)
            session.assert_screen_text(
                "sigint-ok:130", match="contains", region="screen"
            )
            with open(marker_path, "rb") as marker:
                actual_marker = marker.read()
            session.assert_external_state(
                "terminal shell interrupted exit", actual_marker, marker_bytes
            )
            session.type("exit\n")
            output, code = session.quit(timeout=2)
        assert_exit_zero("terminal", output, code)


@scenario("tooling/terminal-stop", commands=["terminal-stop"])
def terminal_stop(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = write_buffer(directory, contents=b"terminal fixture\n")
        marker_path = os.path.join(directory, "terminal-stop-success-marker")
        marker_bytes = b"terminal-stop-success-marker"
        with Session(binary, [path]) as session:
            session.wait_ready(timeout=2)
            session.extended_command("terminal", timeout=2)
            session.wait_for_region_contents(
                "minibuffer", "Terminal started", timeout=2
            )
            session.type(
                f"printf terminal-stop-success-marker > {shlex.quote(marker_path)}; "
                "printf terminal-stop-; printf e2e\n"
            )
            session.wait_for_text("terminal-stop-e2e", timeout=2)
            session.assert_screen_text(
                "terminal-stop-e2e", match="contains", region="screen"
            )
            with open(marker_path, "rb") as marker:
                actual_marker = marker.read()
            session.assert_external_state(
                "terminal-stop shell success marker", actual_marker, marker_bytes
            )
            session.extended_command("terminal-stop", timeout=2)
            session.wait_for_region_contents(
                "minibuffer", "Terminal stopped", timeout=2
            )
            session.assert_screen_text(
                "Terminal stopped", match="contains", region="minibuffer"
            )
            session.assert_screen_text(
                "terminal-stop-e2e", match="contains", region="screen"
            )
            output, code = session.quit(timeout=2)
        assert_exit_zero("terminal-stop", output, code)


@scenario(
    "tooling/terminal-stop-nonzero",
    commands=["terminal", "terminal-stop"],
)
def terminal_stop_nonzero(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = write_buffer(directory, contents=b"terminal fixture\n")
        marker_path = os.path.join(directory, "terminal-stop-nonzero-marker")
        marker_bytes = b"23"
        ready_marker = "terminal-stop-nonzero-exit:23"
        with Session(binary, [path]) as session:
            session.wait_ready(timeout=2)
            session.extended_command("terminal", timeout=2)
            session.wait_for_region_contents(
                "minibuffer", "Terminal started", timeout=2
            )
            session.type(
                f"marker={shlex.quote(marker_path)}; "
                "sh -c 'exit 23'; status=$?; "
                "printf %s \"$status\" > \"$marker\"; "
                "printf 'terminal-stop-nonzero-exit:%s\\n' \"$status\"\n"
            )
            session.wait_for_text(ready_marker, timeout=2)
            session.assert_screen_text(
                ready_marker, match="contains", region="screen"
            )
            session.extended_command("terminal-stop", timeout=2)
            session.wait_for_region_contents(
                "minibuffer", "Terminal stopped", timeout=2
            )
            session.assert_screen_text(
                "Terminal stopped", match="contains", region="minibuffer"
            )
            session.assert_screen_text(
                ready_marker, match="contains", region="screen"
            )
            with open(marker_path, "rb") as marker:
                actual_marker = marker.read()
            session.assert_external_state(
                "terminal-stop nonzero tool status",
                actual_marker,
                marker_bytes,
            )
            output, code = session.quit(timeout=2)
        assert_exit_zero("terminal-stop", output, code)


@scenario(
    "tooling/terminal-stop-interrupted",
    commands=["terminal", "terminal-stop"],
)
def terminal_stop_interrupted(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = write_buffer(directory, contents=b"terminal fixture\n")
        marker_path = os.path.join(directory, "terminal-stop-interrupted-marker")
        marker_bytes = b"130"
        ready_marker = "terminal-stop-interrupted-exit:130"
        with Session(binary, [path]) as session:
            session.wait_ready(timeout=2)
            session.extended_command("terminal", timeout=2)
            session.wait_for_region_contents(
                "minibuffer", "Terminal started", timeout=2
            )
            session.type(
                f"marker={shlex.quote(marker_path)}; "
                "sh -c 'trap \"exit 130\" INT; kill -INT \"$$\"'; "
                "status=$?; "
                "printf %s \"$status\" > \"$marker\"; "
                "printf 'terminal-stop-interrupted-exit:%s\\n' \"$status\"\n"
            )
            session.wait_for_text(ready_marker, timeout=2)
            session.assert_screen_text(
                ready_marker, match="contains", region="screen"
            )
            session.extended_command("terminal-stop", timeout=2)
            session.wait_for_region_contents(
                "minibuffer", "Terminal stopped", timeout=2
            )
            session.assert_screen_text(
                "Terminal stopped", match="contains", region="minibuffer"
            )
            session.assert_screen_text(
                ready_marker, match="contains", region="screen"
            )
            with open(marker_path, "rb") as marker:
                actual_marker = marker.read()
            session.assert_external_state(
                "terminal-stop interrupted tool status",
                actual_marker,
                marker_bytes,
            )
            session.assert_screen_text(
                ready_marker, match="contains", region="screen"
            )
            output, code = session.quit(timeout=2)
        assert_exit_zero("terminal-stop", output, code)


@scenario("tooling/terminal-missing", commands=["terminal"])
def terminal_missing(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = write_buffer(directory, contents=b"terminal fixture\n")
        missing_shell = os.path.join(directory, "missing-shell")
        assert not os.path.exists(missing_shell)
        with Session(binary, [path], shell=missing_shell) as session:
            session.wait_ready(timeout=2)
            session.extended_command("terminal", timeout=2)
            session.wait_for_text("Terminal failed:", timeout=2)
            session.assert_screen_text(
                "Terminal failed:", match="contains", region="screen"
            )
            session.assert_external_state(
                "missing shell executable",
                os.path.exists(missing_shell),
                False,
            )
            session.assert_file_bytes(path, b"terminal fixture\n")
            output, code = session.quit(timeout=2)
        assert_exit_zero("terminal", output, code)
