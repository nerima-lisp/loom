"""Exercise Git commands through the PTY against temporary repositories."""

import os
import shlex
import shutil
import subprocess
import tempfile

from loom_e2e.registry import scenario
from loom_e2e.session import Session


_SOURCE = b"tracked\n"


def _write(path, contents):
    with open(path, "wb") as handle:
        handle.write(contents)


def _repo():
    directory = tempfile.TemporaryDirectory(prefix="loom-git-e2e-")
    subprocess.run(["git", "init", "-q", directory.name], check=True)
    subprocess.run(
        ["git", "-C", directory.name, "config", "user.email", "e2e@example.invalid"],
        check=True,
    )
    subprocess.run(
        ["git", "-C", directory.name, "config", "user.name", "E2E"],
        check=True,
    )
    path = os.path.join(directory.name, "tracked.txt")
    _write(path, _SOURCE)
    subprocess.run(["git", "-C", directory.name, "add", "tracked.txt"], check=True)
    subprocess.run(
        ["git", "-C", directory.name, "commit", "-q", "-m", "initial"],
        check=True,
    )
    return directory, path


def _command(session, name):
    session.extended_command(name)


def _prompted(session, name, prompt, value):
    _command(session, name)
    session.wait_for_text(prompt)
    session.type(value)
    session.key("RET")


def _assert_alive(session):
    if session.process.has_exited():
        raise AssertionError("editor exited while handling a Git command")


def _assert_quit(session, name):
    output, code = session.quit()
    if code != 0:
        raise AssertionError(f"{name}: editor exited with {code}: {output!r}")


def _cached_names(directory):
    return subprocess.run(
        ["git", "-C", directory, "diff", "--cached", "--name-only"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


@scenario(
    "git/real-git-success",
    commands=[
        "git-status",
        "git-diff",
        "git-stage-file",
        "git-diff-staged",
        "git-unstage-file",
    ],
)
def real_git_success(binary):
    directory, path = _repo()
    try:
        with open(path, "ab") as handle:
            handle.write(b"working change\n")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _command(session, "git-status")
            session.wait_for_region_contents("body", "tracked.txt")
            session.assert_screen_text(
                "tracked.txt", match="contains", region="body", index=None
            )

            _command(session, "git-diff")
            session.wait_for_region_contents("body", "working change")
            session.assert_screen_text(
                "working change", match="contains", region="body", index=None
            )

            _prompted(session, "git-stage-file", "Git stage file: ", "tracked.txt")
            session.wait_for_text("Git staged tracked.txt")
            if _cached_names(directory.name) != "tracked.txt":
                raise AssertionError("git-stage-file did not update the real index")

            _command(session, "git-diff-staged")
            session.wait_for_region_contents("body", "working change")
            session.assert_screen_text(
                "working change", match="contains", region="body", index=None
            )

            _prompted(session, "git-unstage-file", "Git unstage file: ", "tracked.txt")
            session.wait_for_text("Git unstaged tracked.txt")
            if _cached_names(directory.name):
                raise AssertionError("git-unstage-file left changes in the real index")
            _assert_alive(session)
            _assert_quit(session, "real-git-success")
    finally:
        directory.cleanup()


@scenario("git/real-git-missing-executable", commands=["git-status"])
def real_git_missing_executable(binary):
    directory, path = _repo()
    index_path = os.path.join(directory.name, ".git", "index")
    with open(index_path, "rb") as handle:
        original_index = handle.read()
    original_path = os.environ.get("PATH")
    try:
        os.environ["PATH"] = ""
        try:
            with Session(binary, [path]) as session:
                session.wait_ready()
                _command(session, "git-status")
                session.wait_for_text("Git status error:")
                session.assert_screen_text(
                    "Git status error:", match="contains", region="minibuffer"
                )
                session.assert_screen_text(
                    "tracked", match="contains", region="body", index=None
                )
                session.assert_file_bytes(path, _SOURCE)
                with open(index_path, "rb") as handle:
                    session.assert_external_state(
                        "Git index after missing executable", handle.read(), original_index
                    )
                _assert_alive(session)
                _assert_quit(session, "real-git-missing-executable")
        finally:
            if original_path is None:
                os.environ.pop("PATH", None)
            else:
                os.environ["PATH"] = original_path
    finally:
        directory.cleanup()


@scenario("git/real-git-nonzero-preserves-result", commands=["git-status"])
def real_git_nonzero_preserves_result(binary):
    directory, path = _repo()
    index_path = os.path.join(directory.name, ".git", "index")
    with open(index_path, "rb") as handle:
        original_index = handle.read()
    marker = os.path.join(directory.name, "fail-git-status")
    wrapper_dir = os.path.join(directory.name, "bin")
    os.makedirs(wrapper_dir)
    real_git = shutil.which("git")
    wrapper = os.path.join(wrapper_dir, "git")
    _write(
        wrapper,
        (
            "#!/bin/sh\n"
            "/bin/cat >/dev/null\n"
            f"if [ -e {shlex.quote(marker)} ]; then\n"
            f"  exec {shlex.quote(real_git)} \"$@\" --loom-e2e-invalid-option\n"
            "fi\n"
            f"exec {shlex.quote(real_git)} \"$@\"\n"
        ).encode("utf-8"),
    )
    os.chmod(wrapper, 0o755)
    original_path = os.environ.get("PATH")
    try:
        os.environ["PATH"] = os.pathsep.join(
            part for part in (wrapper_dir, original_path) if part
        )
        with open(path, "ab") as handle:
            handle.write(b"pending change\n")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _command(session, "git-status")
            session.wait_for_region_contents("body", "pending change")
            session.assert_screen_text(
                "pending change", match="contains", region="body", index=None
            )

            with open(marker, "wb") as handle:
                handle.write(b"fail\n")
            _command(session, "git-status")
            session.wait_for_region_contents(
                "minibuffer", "Git status exited with status"
            )
            session.assert_screen_text(
                "Git status exited with status", match="contains", region="minibuffer"
            )
            session.assert_screen_text(
                "pending change", match="contains", region="body", index=None
            )
            session.assert_file_bytes(path, _SOURCE + b"pending change\n")
            with open(index_path, "rb") as handle:
                session.assert_external_state(
                    "Git index after nonzero status", handle.read(), original_index
                )
            _assert_alive(session)
            _assert_quit(session, "real-git-nonzero-preserves-result")
    finally:
        if original_path is None:
            os.environ.pop("PATH", None)
        else:
            os.environ["PATH"] = original_path
        directory.cleanup()


@scenario("git/real-git-interrupted", commands=["git-status"])
def real_git_interrupted(binary):
    directory, path = _repo()
    index_path = os.path.join(directory.name, ".git", "index")
    with open(index_path, "rb") as handle:
        original_index = handle.read()
    wrapper_dir = os.path.join(directory.name, "bin")
    os.makedirs(wrapper_dir)
    real_git = shutil.which("git")
    wrapper = os.path.join(wrapper_dir, "git")
    _write(
        wrapper,
        (
            "#!/bin/sh\n"
            "/bin/cat >/dev/null\n"
            f"{shlex.quote(real_git)} \"$@\"\n"
            "kill -TERM $$\n"
        ).encode("utf-8"),
    )
    os.chmod(wrapper, 0o755)
    original_path = os.environ.get("PATH")
    try:
        os.environ["PATH"] = os.pathsep.join(
            part for part in (wrapper_dir, original_path) if part
        )
        try:
            with Session(binary, [path]) as session:
                session.wait_ready()
                _command(session, "git-status")
                session.wait_for_region_contents(
                    "minibuffer", "Git status exited with status 143"
                )
                session.assert_screen_text(
                    "Git status exited with status 143",
                    match="contains",
                    region="minibuffer",
                )
                session.assert_screen_text(
                    "##", match="contains", region="body", index=None
                )
                session.assert_file_bytes(path, _SOURCE)
                with open(index_path, "rb") as handle:
                    session.assert_external_state(
                        "Git index after interruption", handle.read(), original_index
                    )
                _assert_alive(session)
                _assert_quit(session, "real-git-interrupted")
        finally:
            if original_path is None:
                os.environ.pop("PATH", None)
            else:
                os.environ["PATH"] = original_path
    finally:
        directory.cleanup()
