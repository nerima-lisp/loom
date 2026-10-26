"""Exercise Git commands through the PTY against temporary repositories."""

import os
import shlex
import shutil
import subprocess
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


_SOURCE = b"tracked\n"
_WAIT = 2.0
_COMMANDS = (
    "git-status",
    "git-diff",
    "git-diff-staged",
    "git-stage-file",
    "git-unstage-file",
)
_LABELS = {
    "git-status": "status",
    "git-diff": "diff",
    "git-diff-staged": "diff",
    "git-stage-file": "stage",
    "git-unstage-file": "unstage",
}


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
    session.extended_command(name, timeout=_WAIT)


def _prompted(session, name, value):
    prompt = "Git stage file: " if name == "git-stage-file" else "Git unstage file: "
    _command(session, name)
    session.wait_for_region_text("minibuffer", prompt, timeout=_WAIT)
    session.type(value)
    session.key("RET")


def _assert_alive(session):
    if session.process.has_exited():
        raise AssertionError("editor exited while handling a Git command")


def _assert_quit(session, name):
    output, code = session.quit(timeout=_WAIT)
    if code != 0:
        raise AssertionError(f"{name}: editor exited with {code}: {output!r}")


def _cached_names(directory, git="git"):
    return subprocess.run(
        [git, "-C", directory, "diff", "--cached", "--name-only"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


def _wait_message(session, message):
    session.wait_for_region_contents("minibuffer", message, timeout=_WAIT)
    session.assert_screen_text(message, match="contains", region="minibuffer")


def _assert_buffer(session, expected):
    session.assert_screen_text(
        expected, match="contains", region="body", index=None
    )


@scenario(
    "git/real-git-status-success",
    commands=["git-status"],
)
def real_git_status_success(binary):
    directory, path = _repo()
    try:
        with open(path, "ab") as handle:
            handle.write(b"working change\n")
        with Session(binary, [path]) as session:
            session.wait_ready(timeout=_WAIT)
            _command(session, "git-status")
            session.wait_for_region_contents("body", "tracked.txt", timeout=_WAIT)
            _assert_buffer(session, "tracked.txt")
            session.send(keys.ctrl("x") + b"b")
            session.wait_for_region_text(
                "minibuffer", "Switch to buffer: ", timeout=_WAIT
            )
            session.type("tracked.txt")
            session.key("RET")
            session.wait_for_region_contents("body", "tracked", timeout=_WAIT)
            _write(
                os.path.join(directory.name, "key-route-sentinel.txt"),
                b"key route refresh\n",
            )
            session.send(keys.ctrl("x") + keys.text("g"))
            session.wait_for_region_contents(
                "body", "key-route-sentinel.txt", timeout=_WAIT
            )
            _assert_buffer(session, "key-route-sentinel.txt")
            _assert_alive(session)
            _assert_quit(session, "real-git-status-success")
    finally:
        directory.cleanup()


@scenario("git/real-git-diff-success", commands=["git-diff"])
def real_git_diff_success(binary):
    directory, path = _repo()
    try:
        with open(path, "ab") as handle:
            handle.write(b"working change\n")
        with Session(binary, [path]) as session:
            session.wait_ready(timeout=_WAIT)
            _command(session, "git-diff")
            session.wait_for_region_contents("body", "+working change", timeout=_WAIT)
            _assert_buffer(session, "+working change")
            _assert_alive(session)
            _assert_quit(session, "real-git-diff-success")
    finally:
        directory.cleanup()


@scenario("git/real-git-diff-staged-success", commands=["git-diff-staged"])
def real_git_diff_staged_success(binary):
    directory, path = _repo()
    try:
        with open(path, "ab") as handle:
            handle.write(b"staged change\n")
        subprocess.run(["git", "-C", directory.name, "add", "tracked.txt"], check=True)
        with Session(binary, [path]) as session:
            session.wait_ready(timeout=_WAIT)
            _command(session, "git-diff-staged")
            session.wait_for_region_contents("body", "+staged change", timeout=_WAIT)
            _assert_buffer(session, "+staged change")
            _assert_alive(session)
            _assert_quit(session, "real-git-diff-staged-success")
    finally:
        directory.cleanup()


@scenario("git/real-git-stage-success", commands=["git-stage-file"])
def real_git_stage_success(binary):
    directory, path = _repo()
    try:
        with open(path, "ab") as handle:
            handle.write(b"working change\n")
        with Session(binary, [path]) as session:
            session.wait_ready(timeout=_WAIT)
            _prompted(session, "git-stage-file", "tracked.txt")
            _wait_message(session, "Git staged tracked.txt")
            if _cached_names(directory.name) != "tracked.txt":
                raise AssertionError("git-stage-file did not update the real index")
            _assert_alive(session)
            _assert_quit(session, "real-git-stage-success")
    finally:
        directory.cleanup()


@scenario("git/real-git-unstage-success", commands=["git-unstage-file"])
def real_git_unstage_success(binary):
    directory, path = _repo()
    try:
        with open(path, "ab") as handle:
            handle.write(b"staged change\n")
        subprocess.run(["git", "-C", directory.name, "add", "tracked.txt"], check=True)
        with Session(binary, [path]) as session:
            session.wait_ready(timeout=_WAIT)
            _prompted(session, "git-unstage-file", "tracked.txt")
            _wait_message(session, "Git unstaged tracked.txt")
            if _cached_names(directory.name):
                raise AssertionError("git-unstage-file left changes in the real index")
            _assert_alive(session)
            _assert_quit(session, "real-git-unstage-success")
    finally:
        directory.cleanup()


def _install_git_wrapper(directory, mode, marker=None):
    wrapper_dir = os.path.join(directory, ".git", "e2e-bin")
    os.makedirs(wrapper_dir)
    real_git = shutil.which("git")
    wrapper = os.path.join(wrapper_dir, "git")
    if mode == "nonzero":
        marker_test = f"[ -f {shlex.quote(marker)} ]"
        body = (
            "#!/bin/sh\n"
            f"if {marker_test}; then\n"
            f"  exec {shlex.quote(real_git)} --loom-e2e-invalid-option \"$@\"\n"
            "fi\n"
            f"exec {shlex.quote(real_git)} \"$@\"\n"
        )
    else:
        body = (
            "#!/bin/sh\n"
            f"{shlex.quote(real_git)} \"$@\"\n"
            "kill -TERM $$\n"
        )
    _write(wrapper, body.encode("utf-8"))
    os.chmod(wrapper, 0o755)
    return wrapper_dir


def _run_failure(binary, command, outcome):
    directory, path = _repo()
    if command == "git-diff":
        with open(path, "ab") as handle:
            handle.write(b"working change\n")
    elif command in ("git-diff-staged", "git-unstage-file"):
        with open(path, "ab") as handle:
            handle.write(b"staged change\n")
        subprocess.run(["git", "-C", directory.name, "add", "tracked.txt"], check=True)
    elif command == "git-stage-file":
        with open(path, "ab") as handle:
            handle.write(b"working change\n")
    index_path = os.path.join(directory.name, ".git", "index")
    with open(index_path, "rb") as handle:
        original_index = handle.read()
    marker = os.path.join(directory.name, "force-nonzero")
    original_path = os.environ.get("PATH")
    real_git = shutil.which("git", path=original_path)
    if outcome == "nonzero":
        wrapper_dir = _install_git_wrapper(directory.name, "nonzero", marker)
        os.environ["PATH"] = os.pathsep.join(
            part for part in (wrapper_dir, original_path) if part
        )
    elif outcome == "interrupted":
        wrapper_dir = _install_git_wrapper(directory.name, "interrupted")
        os.environ["PATH"] = os.pathsep.join(
            part for part in (wrapper_dir, original_path) if part
        )
    else:
        os.environ["PATH"] = ""

    label = _LABELS[command]
    try:
        with Session(binary, [path]) as session:
            session.wait_ready(timeout=_WAIT)
            if outcome == "nonzero" and command == "git-status":
                _command(session, command)
                session.wait_for_region_contents("body", "##", timeout=_WAIT)
                with open(marker, "wb") as handle:
                    handle.write(b"force failure\n")

            if command in ("git-stage-file", "git-unstage-file"):
                if outcome == "nonzero":
                    _write(marker, b"force failure\n")
                _prompted(session, command, "tracked.txt")
            else:
                if outcome == "nonzero" and command != "git-status":
                    _write(marker, b"force failure\n")
                if command == "git-status":
                    session.send(keys.ctrl("x") + keys.text("g"))
                else:
                    _command(session, command)

            if outcome == "missing":
                message = f"Git {label} error:"
            elif outcome == "interrupted":
                message = f"Git {label} terminated without an exit code"
            else:
                message = f"Git {label} exited with status"
            _wait_message(session, message)

            if outcome == "nonzero" and command == "git-status":
                _assert_buffer(session, "unknown option")
            elif outcome == "nonzero" and command in (
                "git-stage-file",
                "git-unstage-file",
            ):
                _assert_buffer(session, "tracked")
            elif outcome == "interrupted" and command == "git-status":
                _assert_buffer(session, "##")
            elif outcome == "interrupted" and command in ("git-diff", "git-diff-staged"):
                _assert_buffer(session, "diff --git")
            elif outcome == "missing":
                _assert_buffer(session, "tracked")

            session.assert_file_bytes(
                path,
                _SOURCE
                + (
                    b"working change\n"
                    if command in ("git-diff", "git-stage-file")
                    else b"staged change\n"
                    if command in ("git-diff-staged", "git-unstage-file")
                    else b""
                ),
            )
            with open(index_path, "rb") as handle:
                current_index = handle.read()
            if outcome == "interrupted" and command == "git-stage-file":
                if _cached_names(directory.name, real_git) != "tracked.txt":
                    raise AssertionError("interrupted git-stage-file did not run real Git")
            elif outcome == "interrupted" and command == "git-unstage-file":
                if _cached_names(directory.name, real_git):
                    raise AssertionError("interrupted git-unstage-file did not run real Git")
            elif current_index != original_index:
                raise AssertionError(f"{command} changed the Git index on failure")
            _assert_alive(session)
            _assert_quit(session, f"real-git-{command}-{outcome}")
    finally:
        if original_path is None:
            os.environ.pop("PATH", None)
        else:
            os.environ["PATH"] = original_path
        directory.cleanup()


def _register_failure(command, outcome):
    name = f"git/real-git-{command.removeprefix('git-')}-{outcome}"

    @scenario(name, commands=[command])
    def run(binary):
        _run_failure(binary, command, outcome)

    return run

def _assert_exact_message(session, message):
    session.wait_for_region_exact_text(
        "minibuffer", message, timeout=_WAIT
    )
    session.assert_screen_text(
        message, match="exact", region="minibuffer", strip_right=True
    )


def _cached_blob(directory, path):
    return subprocess.run(
        ["git", "-C", directory, "show", f":{path}"],
        check=True,
        capture_output=True,
    ).stdout


def _run_prompt_path(binary, command, outcome):
    directory, path = _repo()
    other_path = os.path.join(directory.name, "other.txt")
    prompt = (
        "Git stage file: "
        if command == "git-stage-file"
        else "Git unstage file: "
    )
    verb = "stage" if command == "git-stage-file" else "unstage"
    past_tense = "staged" if command == "git-stage-file" else "unstaged"
    selected_path = "other.txt" if outcome == "history" else "tracked.txt"
    main_bytes = _SOURCE + b"working change\n"

    try:
        with open(path, "ab") as handle:
            handle.write(b"working change\n")

        if outcome == "history":
            _write(other_path, b"other\n")
            if command == "git-unstage-file":
                subprocess.run(
                    ["git", "-C", directory.name, "add", "--", "tracked.txt", "other.txt"],
                    check=True,
                )
        elif command == "git-unstage-file":
            subprocess.run(
                ["git", "-C", directory.name, "add", "--", "tracked.txt"],
                check=True,
            )

        with Session(binary, [path]) as session:
            session.wait_ready(timeout=_WAIT)

            if outcome == "history":
                _prompted(session, command, selected_path)
                _assert_exact_message(
                    session, f"Git {past_tense} {selected_path}"
                )
                if command == "git-stage-file":
                    with open(other_path, "ab") as handle:
                        handle.write(b"later change\n")
                else:
                    subprocess.run(
                        ["git", "-C", directory.name, "add", "--", "other.txt"],
                        check=True,
                    )

            _command(session, command)
            session.wait_for_region_exact_text(
                "minibuffer", prompt, timeout=_WAIT
            )
            if outcome == "cancel":
                session.key("C-g")
                _assert_exact_message(session, "Quit")
            elif outcome == "empty":
                session.key("RET")
                _assert_exact_message(session, f"Git {verb} cancelled")
            else:
                if outcome == "tab":
                    session.type("track")
                    session.key("TAB")
                elif outcome == "history":
                    session.key("UP")
                else:
                    session.type(selected_path)
                session.wait_for_region_exact_text(
                    "minibuffer",
                    f"{prompt}{selected_path}",
                    timeout=_WAIT,
                )
                session.key("RET")
                _assert_exact_message(
                    session, f"Git {past_tense} {selected_path}"
                )

            session.assert_screen_text(
                "tracked", match="contains", region="body", index=None
            )
            session.assert_file_bytes(path, main_bytes)
            expected_cached = (
                selected_path
                if command == "git-stage-file" and outcome in {"accept", "tab", "history"}
                else ""
                if command == "git-stage-file"
                else "tracked.txt"
                if outcome in {"cancel", "empty", "history"}
                else ""
            )
            session.assert_external_state(
                "git diff --cached --name-only",
                _cached_names(directory.name),
                expected_cached,
            )
            if command == "git-stage-file" and outcome in {"accept", "tab"}:
                session.assert_external_state(
                    "staged tracked.txt bytes",
                    _cached_blob(directory.name, "tracked.txt"),
                    main_bytes,
                )
            elif command == "git-stage-file" and outcome == "history":
                session.assert_file_bytes(
                    other_path, b"other\nlater change\n"
                )
                session.assert_external_state(
                    "staged other.txt bytes",
                    _cached_blob(directory.name, "other.txt"),
                    b"other\nlater change\n",
                )
            elif command == "git-unstage-file" and outcome == "history":
                session.assert_file_bytes(other_path, b"other\n")

            if command == "git-unstage-file" and outcome in {
                "cancel",
                "empty",
                "history",
            }:
                session.assert_external_state(
                    "staged tracked.txt bytes",
                    _cached_blob(directory.name, "tracked.txt"),
                    main_bytes,
                )

            _assert_alive(session)
            _assert_quit(session, f"git-r2-{command}-{outcome}")
    finally:
        directory.cleanup()


def _register_prompt_path(command, outcome):
    name = f"git/r2/{command}/{outcome}"

    @scenario(name, commands=[command])
    def run(binary):
        _run_prompt_path(binary, command, outcome)

    return run


for _r2_command in ("git-stage-file", "git-unstage-file"):
    for _r2_outcome in ("accept", "cancel", "empty", "tab", "history"):
        _register_prompt_path(_r2_command, _r2_outcome)


for _command_name in _COMMANDS:
    for _outcome in ("missing", "nonzero", "interrupted"):
        _register_failure(_command_name, _outcome)
