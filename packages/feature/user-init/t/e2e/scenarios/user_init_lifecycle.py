"""Exercise startup options and init diagnostics through the real PTY editor."""

import os
import shlex
import subprocess
import tempfile
from pathlib import Path

from loom_e2e import keys
from loom_e2e.deadline import scenario_deadline
from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _write_wrapper(directory, name, body):
    wrapper = Path(directory) / name
    wrapper.write_text("#!/bin/sh\n" + body, encoding="utf-8")
    wrapper.chmod(0o755)
    return os.fspath(wrapper)


def _write(path, contents):
    Path(path).write_bytes(contents)


def _write_text(path, contents):
    Path(path).write_text(contents, encoding="utf-8")


def _lisp_string(value):
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def _write_editor_wrapper(directory, binary, init_file):
    return _write_wrapper(
        directory,
        "loom-editor.sh",
        f"export LOOM_INIT_FILE={shlex.quote(os.fspath(init_file))}\n"
        f"exec {shlex.quote(os.fspath(binary))} \"$@\"\n",
    )


def _assert_exit_zero(name, output, code):
    if code != 0:
        raise AssertionError(f"{name} exited with {code}: {output!r}")


def _git(directory, *arguments):
    env = os.environ.copy()
    env.update(
        {
            "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_TERMINAL_PROMPT": "0",
            "HOME": os.fspath(directory),
        }
    )
    result = subprocess.run(
        ["git", "-C", os.fspath(directory), *arguments],
        check=True,
        capture_output=True,
        text=True,
        timeout=1,
        env=env,
    )
    return result.stdout.strip()


def _init_git_repo(directory, commits):
    _git(directory, "init", "--quiet")
    _git(directory, "config", "user.name", "loom E2E")
    _git(directory, "config", "user.email", "loom-e2e@example.invalid")
    for message, contents in commits:
        _write(os.path.join(directory, "state.txt"), contents)
        _git(directory, "add", "state.txt")
        _git(directory, "commit", "--quiet", "-m", message)


def _save_and_exit_editor(session, file_path=None, expected_bytes=None):
    trace_count = session.command_trace_count()
    session.send(keys.ctrl("x") + keys.ctrl("s"))
    session.wait_for_command_completion(
        "save-buffer", route="key", after=trace_count, timeout=1
    )
    if file_path is not None:
        session.wait_for_file(file_path, expected_bytes, timeout=1)
        session.assert_file_bytes(file_path, expected_bytes)
    trace_count = session.command_trace_count()
    session.send(keys.ctrl("x") + keys.ctrl("c"))
    session.wait_for_command_completion(
        "save-buffers-kill-terminal", route="key", after=trace_count, timeout=1
    )


def _rebase_todo_after_save_edit(initial_todo):
    return b"# E2E save observation\n" + initial_todo


def _wait_editor_parent(session, name):
    output, code = session.process.wait(timeout=2)
    session.observe_exit_code(code, expected=0)
    _assert_exit_zero(name, output, code)


def _assert_refusal(session, expected_reason):
    output, code = session.process.wait(timeout=2)
    session.observe_exit_code(code, expected=1)
    if code != 1:
        raise AssertionError(f"terminal refusal exited with {code}: {output!r}")
    rendered = output.decode("utf-8", errors="replace")
    if expected_reason not in rendered:
        raise AssertionError(
            f"terminal refusal did not display {expected_reason!r}: {rendered!r}"
        )


@scenario(
    "user-init --no-init skips configured file",
    commands=["save-buffers-kill-terminal"],
)
def no_init_skips_configured_file(binary):
    with scenario_deadline(seconds=5, cleanup_seconds=1):
        with tempfile.TemporaryDirectory(prefix="loom-e2e-user-init-") as directory:
            marker = os.path.join(directory, "loaded")
            init_file = os.path.join(directory, "init.lisp")
            _write_text(
                init_file,
                "(with-open-file (stream "
                + _lisp_string(marker)
                + ' :direction :output) (write-string "loaded" stream))\n',
            )
            path = os.path.join(directory, "buffer.txt")
            _write(path, b"edit remains available\n")
            wrapper = _write_editor_wrapper(directory, binary, init_file)

            with Session(wrapper, ["--no-init", path]) as session:
                session.wait_ready(timeout=2)
                session.assert_external_state(
                    "configured init marker remains absent",
                    os.path.exists(marker),
                    False,
                )
                output, code = session.quit(timeout=2)

            session.assert_external_state(
                "configured init marker remains absent after exit",
                os.path.exists(marker),
                False,
            )
            _assert_exit_zero("user-init --no-init", output, code)


@scenario(
    "user-init error reports and editor continues",
    commands=[
        "save-buffer",
        "switch-to-buffer",
        "save-buffers-kill-terminal",
    ],
)
def init_error_is_reported_and_editor_continues(binary):
    with scenario_deadline(seconds=5, cleanup_seconds=1):
        with tempfile.TemporaryDirectory(prefix="loom-e2e-user-init-") as directory:
            init_file = os.path.join(directory, "init.lisp")
            _write_text(init_file, '(error "user-init-sentinel")\n')
            path = os.path.join(directory, "buffer.txt")
            _write(path, b"seed\n")
            wrapper = _write_editor_wrapper(directory, binary, init_file)

            with Session(wrapper, [path]) as session:
                session.wait_for_region_text(
                    "minibuffer", "user-init-sentinel", timeout=2
                )
                session.assert_screen_text(
                    "user-init-sentinel",
                    match="contains",
                    region="minibuffer",
                )
                session.assert_external_state(
                    "editor remains alive after init error",
                    not session.process.has_exited(),
                    True,
                )

                session.send(keys.ctrl("g"))
                session.send(keys.ctrl("a"))
                session.type("edited ")
                session.send(keys.ctrl("x") + keys.ctrl("s"))
                expected_bytes = b"edited seed\n"
                session.wait_for_file(path, expected_bytes, timeout=2)
                session.assert_file_bytes(path, expected_bytes)

                session.send(keys.ctrl("x") + b"b")
                session.wait_for_region_text(
                    "minibuffer", "Switch to buffer: ", timeout=2
                )
                session.type("*Messages*")
                session.key("RET")
                session.wait_for_region_text(
                    "body", "user-init-sentinel", timeout=2
                )
                session.assert_screen_text(
                    "user-init-sentinel",
                    match="contains",
                    region="body",
                )
                output, code = session.quit(timeout=2)

            _assert_exit_zero("user-init error continuation", output, code)


@scenario(
    "user-init R7 git commit",
    commands=["save-buffer", "save-buffers-kill-terminal"],
)
def git_commit_uses_editor_contract(binary):
    with scenario_deadline(seconds=5, cleanup_seconds=1):
        with tempfile.TemporaryDirectory(prefix="loom-e2e-user-init-") as directory:
            repo = Path(directory) / "repo"
            repo.mkdir()
            _init_git_repo(os.fspath(repo), [("baseline", b"before\n")])
            _write(repo / "state.txt", b"after\n")
            _git(os.fspath(repo), "add", "state.txt")
            editor = _write_wrapper(
                directory,
                "git-editor.sh",
                f"exec {shlex.quote(os.fspath(binary))} \"$@\"\n",
            )
            launcher = _write_wrapper(
                directory,
                "git-commit.sh",
                f"cd {shlex.quote(os.fspath(repo))}\n"
                "unset GIT_EDITOR\n"
                f"export EDITOR={shlex.quote(shlex.quote(editor))}\n"
                "exec git commit --quiet\n",
            )

            with Session(launcher) as session:
                session.wait_ready(timeout=1.5)
                session.wait_for_region_text(
                    "body", "Please enter", index=1, timeout=1
                )
                edit_message_path = repo / ".git" / "COMMIT_EDITMSG"
                initial_edit_message = edit_message_path.read_bytes()
                session.type("R7 commit subject\n")
                _save_and_exit_editor(
                    session,
                    os.fspath(edit_message_path),
                    b"R7 commit subject\n" + initial_edit_message,
                )
                _wait_editor_parent(session, "git commit editor")
                actual_subject = _git(
                    os.fspath(repo), "log", "-1", "--format=%s"
                )
                session.assert_external_state(
                    "git commit subject", actual_subject, "R7 commit subject"
                )


@scenario(
    "user-init R7 git rebase -i",
    commands=["save-buffer", "save-buffers-kill-terminal"],
)
def interactive_rebase_uses_editor_contract(binary):
    with scenario_deadline(seconds=5, cleanup_seconds=1):
        with tempfile.TemporaryDirectory(prefix="loom-e2e-user-init-") as directory:
            repo = Path(directory) / "repo"
            repo.mkdir()
            _init_git_repo(
                os.fspath(repo),
                [("first", b"first\n"), ("second", b"second\n")],
            )
            editor = _write_wrapper(
                directory,
                "sequence-editor.sh",
                f"exec {shlex.quote(os.fspath(binary))} \"$@\"\n",
            )
            launcher = _write_wrapper(
                directory,
                "git-rebase.sh",
                f"cd {shlex.quote(os.fspath(repo))}\n"
                "unset GIT_SEQUENCE_EDITOR GIT_EDITOR\n"
                f"export EDITOR={shlex.quote(shlex.quote(editor))}\n"
                "exec git rebase -i --root --quiet\n",
            )
            expected_history = "first\nsecond"

            with Session(launcher) as session:
                session.wait_ready(timeout=1.5)
                session.wait_for_region_text("body", "pick", timeout=1)
                todo_path = repo / ".git" / "rebase-merge" / "git-rebase-todo"
                initial_todo = todo_path.read_bytes()
                session.type("# E2E save observation\n")
                _save_and_exit_editor(
                    session,
                    os.fspath(todo_path),
                    _rebase_todo_after_save_edit(initial_todo),
                )
                _wait_editor_parent(session, "git rebase -i editor")
                actual_history = _git(
                    os.fspath(repo), "log", "--reverse", "--format=%s"
                )
                session.assert_external_state(
                    "rebase commit history", actual_history, expected_history
                )
                status = _git(os.fspath(repo), "status", "--porcelain")
                session.assert_external_state(
                    "working tree after rebase", status, ""
                )


@scenario(
    "user-init R7 crontab-style editor",
    commands=["save-buffer", "save-buffers-kill-terminal"],
)
def crontab_style_uses_editor_contract(binary):
    with scenario_deadline(seconds=5, cleanup_seconds=1):
        with tempfile.TemporaryDirectory(prefix="loom-e2e-user-init-") as directory:
            cron_file = Path(directory) / "crontab"
            initial = b"0 * * * * /bin/true\n"
            appended = b"0 * * * * /bin/true\n5 * * * * /bin/true\n"
            cron_file.write_bytes(initial)
            stub_directory = Path(directory) / "bin"
            stub_directory.mkdir()
            _write_wrapper(
                stub_directory,
                "crontab",
                'exec "$EDITOR" "$LOOM_CRONTAB_FILE"\n',
            )
            editor = _write_wrapper(
                directory,
                "cron-editor.sh",
                f"exec {shlex.quote(os.fspath(binary))} \"$@\"\n",
            )
            launcher = _write_wrapper(
                directory,
                "crontab-style.sh",
                f"export PATH={shlex.quote(os.fspath(stub_directory))}:$PATH\n"
                f"export EDITOR={shlex.quote(editor)}\n"
                f"export LOOM_CRONTAB_FILE={shlex.quote(os.fspath(cron_file))}\n"
                "exec crontab -e\n",
            )

            with Session(launcher) as session:
                session.wait_ready(timeout=1.5)
                session.wait_for_text("0 * * * * /bin/true", timeout=1)
                session.send(keys.ctrl("e"))
                session.key("RET")
                session.type("5 * * * * /bin/true")
                _save_and_exit_editor(
                    session,
                    os.fspath(cron_file),
                    appended,
                )
                _wait_editor_parent(session, "crontab-style editor")
                session.assert_file_bytes(os.fspath(cron_file), appended)


@scenario(
    "user-init R7 xargs non-tty stdin",
    commands=["save-buffer", "save-buffers-kill-terminal"],
)
def xargs_non_tty_stdin_uses_controlling_tty(binary):
    with scenario_deadline(seconds=5, cleanup_seconds=1):
        with tempfile.TemporaryDirectory(prefix="loom-e2e-user-init-") as directory:
            path = Path(directory) / "xargs.txt"
            initial = b"xargs editor input\n"
            expected = b"edited xargs editor input\n"
            path.write_bytes(initial)
            launcher = _write_wrapper(
                directory,
                "xargs-editor.sh",
                f"export EDITOR={shlex.quote(os.fspath(binary))}\n"
                f"printf '%s\\n' {shlex.quote(os.fspath(path))} "
                '| xargs "$EDITOR"\n',
            )

            with Session(launcher) as session:
                session.wait_ready(timeout=1.5)
                session.send(keys.ctrl("a"))
                session.type("edited ")
                session.send(keys.ctrl("x") + keys.ctrl("s"))
                session.wait_for_file(os.fspath(path), expected, timeout=1.5)
                session.assert_file_bytes(os.fspath(path), expected)
                _save_and_exit_editor(session)
                _wait_editor_parent(session, "xargs non-tty stdin editor")


@scenario(
    "user-init R7 +N FILE",
    commands=["save-buffer", "save-buffers-kill-terminal"],
)
def plus_n_file_opens_requested_line(binary):
    with scenario_deadline(seconds=5, cleanup_seconds=1):
        with tempfile.TemporaryDirectory(prefix="loom-e2e-user-init-") as directory:
            path = Path(directory) / "numbered.txt"
            original = b"one\ntwo\nthree\nfour\n"
            expected = b"one\nedited two\nthree\nfour\n"
            path.write_bytes(original)

            with Session(binary, ["+2", os.fspath(path)]) as session:
                session.wait_ready(timeout=1.5)
                session.wait_for_region_cursor("body", 0, index=1, timeout=1.5)
                session.assert_screen_text(
                    "two", match="contains", region="body", index=1
                )
                session.type("edited ")
                session.send(keys.ctrl("x") + keys.ctrl("s"))
                session.wait_for_file(os.fspath(path), expected, timeout=1.5)
                output, code = session.quit(timeout=1.5)
                session.assert_file_bytes(os.fspath(path), expected)
                _assert_exit_zero("+N FILE", output, code)


@scenario(
    "user-init R7 new file",
    commands=["save-buffer", "save-buffers-kill-terminal"],
)
def new_file_is_created_on_save(binary):
    with scenario_deadline(seconds=5, cleanup_seconds=1):
        with tempfile.TemporaryDirectory(prefix="loom-e2e-user-init-") as directory:
            path = Path(directory) / "missing-parent" / "nested" / "new-file.txt"
            expected = b"created by $EDITOR\n"

            with Session(binary, [os.fspath(path)]) as session:
                session.wait_ready(timeout=1.5)
                try:
                    session.assert_screen_text(
                        "",
                        match="exact",
                        region="body",
                        index=0,
                        strip_right=True,
                        purpose="precondition",
                    )
                except AssertionError as error:
                    raise AssertionError(
                        f"{error}; actual body={session.region_contents('body')!r}; "
                        f"screen:\n{session.screen.dump()}"
                    ) from error
                session.assert_external_state(
                    "new file and parent directories do not exist before save",
                    path.exists() or path.parent.exists(),
                    False,
                )
                session.type(expected.decode("ascii"))
                session.send(keys.ctrl("x") + keys.ctrl("s"))
                session.wait_for_region_text(
                    "minibuffer",
                    "Parent directory does not exist. Create it? (y/n):",
                    timeout=1.5,
                )
                session.type("y")
                session.send(keys.key("RET"))
                session.wait_for_file(os.fspath(path), expected, timeout=1.5)
                session.assert_external_state(
                    "parent directories are created after confirmation",
                    path.parent.is_dir(),
                    True,
                )
                session.assert_file_bytes(os.fspath(path), expected)
                output, code = session.quit(timeout=1.5)
                _assert_exit_zero("new file with missing parent directories", output, code)


@scenario(
    "user-init R7 interruption",
    commands=["keyboard-quit", "save-buffers-kill-terminal"],
)
def keyboard_quit_interrupts_without_exiting(binary):
    with scenario_deadline(seconds=5, cleanup_seconds=1):
        with tempfile.TemporaryDirectory(prefix="loom-e2e-user-init-") as directory:
            path = Path(directory) / "interrupt.txt"
            original = b"unchanged\n"
            path.write_bytes(original)

            with Session(binary, [os.fspath(path)]) as session:
                session.wait_ready(timeout=1.5)
                session.send(keys.ctrl("g"))
                session.wait_for_region_text("minibuffer", "Quit", timeout=1.5)
                session.assert_external_state(
                    "editor remains active after keyboard-quit",
                    not session.process.has_exited(),
                    True,
                )
                session.assert_file_bytes(os.fspath(path), original)
                output, code = session.quit(timeout=1.5)
                _assert_exit_zero("keyboard-quit interruption", output, code)


@scenario("user-init TERM=dumb refusal", commands=[])
def dumb_term_is_refused(binary):
    with scenario_deadline(seconds=5, cleanup_seconds=1):
        with tempfile.TemporaryDirectory(prefix="loom-e2e-user-init-") as directory:
            path = Path(directory) / "buffer.txt"
            path.write_bytes(b"unchanged\n")
            profile = keys.TerminalProfile(
                "dumb", "dumb", keys.DEFAULT_PROFILE.key_sequences
            )

            with Session(binary, [os.fspath(path)], profile=profile) as session:
                _assert_refusal(session, "dumb")


@scenario("user-init unset TERM refusal", commands=[])
def unset_term_is_refused(binary):
    with scenario_deadline(seconds=5, cleanup_seconds=1):
        with tempfile.TemporaryDirectory(prefix="loom-e2e-user-init-") as directory:
            path = Path(directory) / "buffer.txt"
            path.write_bytes(b"unchanged\n")
            launcher = _write_wrapper(
                directory,
                "unset-term.sh",
                "unset TERM\n"
                f"exec {shlex.quote(os.fspath(binary))} \"$@\"\n",
            )

            with Session(launcher, [os.fspath(path)]) as session:
                _assert_refusal(session, "TERM")


@scenario(
    "user-init non-tty stdin uses /dev/tty",
    commands=["save-buffer", "save-buffers-kill-terminal"],
)
def non_tty_stdin_uses_controlling_tty(binary):
    with scenario_deadline(seconds=5, cleanup_seconds=1):
        with tempfile.TemporaryDirectory(prefix="loom-e2e-user-init-") as directory:
            path = Path(directory) / "stdin.txt"
            path.write_bytes(b"stdin\n")
            expected = b"edited stdin\n"
            launcher = _write_wrapper(
                directory,
                "stdin-redirection.sh",
                f"exec {shlex.quote(os.fspath(binary))} \"$@\" </dev/null\n",
            )

            with Session(launcher, [os.fspath(path)]) as session:
                session.wait_ready(timeout=1.5)
                session.send(keys.ctrl("a"))
                session.type("edited ")
                session.send(keys.ctrl("x") + keys.ctrl("s"))
                session.wait_for_file(os.fspath(path), expected, timeout=1.5)
                session.assert_file_bytes(os.fspath(path), expected)
                output, code = session.quit(timeout=1.5)
                _assert_exit_zero("non-TTY stdin", output, code)


@scenario(
    "user-init non-tty stdout uses /dev/tty",
    commands=["save-buffer", "save-buffers-kill-terminal"],
)
def non_tty_stdout_uses_controlling_tty(binary):
    with scenario_deadline(seconds=5, cleanup_seconds=1):
        with tempfile.TemporaryDirectory(prefix="loom-e2e-user-init-") as directory:
            path = Path(directory) / "stdout.txt"
            path.write_bytes(b"stdout\n")
            expected = b"edited stdout\n"
            launcher = _write_wrapper(
                directory,
                "stdout-redirection.sh",
                f"exec {shlex.quote(os.fspath(binary))} \"$@\" >/dev/null\n",
            )

            with Session(launcher, [os.fspath(path)]) as session:
                session.wait_ready(timeout=1.5)
                session.send(keys.ctrl("a"))
                session.type("edited ")
                session.send(keys.ctrl("x") + keys.ctrl("s"))
                session.wait_for_file(os.fspath(path), expected, timeout=1.5)
                session.assert_file_bytes(os.fspath(path), expected)
                output, code = session.quit(timeout=1.5)
                _assert_exit_zero("non-TTY stdout", output, code)
