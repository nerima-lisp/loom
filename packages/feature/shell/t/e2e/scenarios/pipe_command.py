"""PTY coverage for the real pipe-command shell process."""

import os
import re
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


_SOURCE = b"shell-source-sentinel\n"
_BUFFER_NAME = "shell-source.txt"


def _write_buffer(directory, name, contents):
    path = os.path.join(directory, name)
    with open(path, "wb") as handle:
        handle.write(contents)
    return path


def _assert_exit_zero(name, output, code):
    if code != 0:
        raise AssertionError(f"{name} exited with {code}: {output!r}")


def _source_fixture():
    directory = tempfile.TemporaryDirectory(
        prefix="w3-11-shell-", dir="/tmp"
    )
    path = _write_buffer(directory.name, _BUFFER_NAME, _SOURCE)
    return directory, path


def _pipe_prompt(session, *, route="key"):
    if route == "key":
        session.send(keys.meta("!"))
        session.wait_for_region_text("minibuffer", "Pipe command: ")
    else:
        session.extended_command("pipe-command")
        session.wait_for_region_text("minibuffer", "Pipe command: ")


def _pipe(session, command, *, route="key"):
    _pipe_prompt(session, route=route)
    session.type(command)
    session.key("RET")


def _assert_alive(session):
    if session.process.has_exited():
        raise AssertionError("editor exited while handling pipe-command")


def _assert_source_unchanged(session, path):
    session.send(keys.ctrl("x") + b"b")
    session.wait_for_region_text("minibuffer", "Switch to buffer: ")
    session.type(_BUFFER_NAME)
    session.key("RET")
    session.wait_for_text("shell-source-sentinel")
    session.assert_screen_text(
        "shell-source-sentinel", match="contains", region="body", index=None
    )
    session.assert_file_bytes(path, _SOURCE)


def _result_text(session):
    return session.region_contents("body")


def _assert_result_text(session, expected):
    session.assert_screen_text(
        expected, match="contains", region="body", index=None
    )


def _result_exit_code(session):
    match = re.search(r"Exit code:\s*(\d+)", _result_text(session))
    if match is None:
        raise AssertionError(f"pipe-command result has no exit code: {_result_text(session)!r}")
    return int(match.group(1))


def _assert_exit_message(session, code):
    message = f"Pipe command exited with code {code}"
    session.wait_for_region_text("minibuffer", message)
    session.assert_screen_text(message, match="contains", region="minibuffer")


@scenario("shell/pipe-command-key", commands=["pipe-command"])
def pipe_command_key(binary):
    directory, path = _source_fixture()
    try:
        result_path = os.path.join(directory.name, "shell-success.txt")
        command = (
            "/bin/sh -c 'printf shell-key-file > shell-success.txt; "
            "printf shell-key-output'"
        )
        with Session(binary, [path]) as session:
            session.wait_ready()
            _pipe(session, command)
            session.wait_for_text("shell-key-output")
            session.wait_for_region_text(
                "minibuffer", "Pipe command finished successfully"
            )
            _assert_result_text(session, "shell-key-output")
            session.assert_screen_text(
                "Pipe command finished successfully",
                match="contains",
                region="minibuffer",
            )
            with open(result_path, "rb") as handle:
                session.assert_external_state(
                    "pipe-command shell output file", handle.read(), b"shell-key-file"
                )
            _assert_alive(session)
            _assert_source_unchanged(session, path)
            output, code = session.quit()
        _assert_exit_zero("pipe-command key", output, code)
    finally:
        directory.cleanup()


@scenario("shell/pipe-command-mx", commands=["pipe-command"])
def pipe_command_mx(binary):
    directory, path = _source_fixture()
    try:
        with Session(binary, [path]) as session:
            session.wait_ready()
            _pipe(session, "/bin/sh -c 'printf shell-mx-output'", route="mx")
            session.wait_for_text("shell-mx-output")
            session.wait_for_region_text(
                "minibuffer", "Pipe command finished successfully"
            )
            _assert_result_text(session, "shell-mx-output")
            session.assert_screen_text(
                "Pipe command finished successfully",
                match="contains",
                region="minibuffer",
            )
            _assert_alive(session)
            _assert_source_unchanged(session, path)
            output, code = session.quit()
        _assert_exit_zero("pipe-command M-x", output, code)
    finally:
        directory.cleanup()


@scenario("shell/pipe-command-prompt-cancel", commands=["pipe-command"])
def pipe_command_prompt_cancel(binary):
    directory, path = _source_fixture()
    try:
        with Session(binary, [path]) as session:
            session.wait_ready()
            _pipe_prompt(session)
            session.send(keys.ctrl("g"))
            session.wait_for_text("shell-source-sentinel")
            session.assert_screen_text(
                "shell-source-sentinel", match="contains", region="body", index=None
            )
            _assert_alive(session)
            _assert_source_unchanged(session, path)
            output, code = session.quit()
        _assert_exit_zero("pipe-command prompt cancel", output, code)
    finally:
        directory.cleanup()


@scenario("shell/pipe-command-prompt-empty", commands=["pipe-command"])
def pipe_command_prompt_empty(binary):
    directory, path = _source_fixture()
    try:
        with Session(binary, [path]) as session:
            session.wait_ready()
            _pipe_prompt(session)
            session.key("RET")
            session.wait_for_region_text("minibuffer", "Pipe command cancelled")
            session.assert_screen_text(
                "Pipe command cancelled", match="contains", region="minibuffer"
            )
            _assert_alive(session)
            _assert_source_unchanged(session, path)
            output, code = session.quit()
        _assert_exit_zero("pipe-command empty prompt", output, code)
    finally:
        directory.cleanup()


@scenario("shell/pipe-command-prompt-tab", commands=["pipe-command"])
def pipe_command_prompt_tab(binary):
    directory, path = _source_fixture()
    try:
        with Session(binary, [path]) as session:
            session.wait_ready()
            _pipe_prompt(session)
            session.type("true")
            session.key("TAB")
            session.wait_for_region_text("minibuffer", "Pipe command: true")
            session.assert_screen_text(
                "Pipe command: true", match="contains", region="minibuffer"
            )
            session.key("RET")
            session.wait_for_text("Exit code: 0")
            _assert_result_text(session, "$ true")
            _assert_result_text(session, "Exit code: 0")
            _assert_alive(session)
            _assert_source_unchanged(session, path)
            output, code = session.quit()
        _assert_exit_zero("pipe-command prompt tab", output, code)
    finally:
        directory.cleanup()


@scenario("shell/pipe-command-prompt-history", commands=["pipe-command"])
def pipe_command_prompt_history(binary):
    directory, path = _source_fixture()
    try:
        with Session(binary, [path]) as session:
            session.wait_ready()
            _pipe(session, "/bin/sh -c 'printf shell-history-output'")
            session.wait_for_text("shell-history-output")
            session.wait_for_region_text(
                "minibuffer", "Pipe command finished successfully"
            )
            session.send(keys.meta("!"))
            session.wait_for_region_text("minibuffer", "Pipe command: ")
            session.key("UP")
            session.wait_for_region_text("minibuffer", "shell-history-output")
            session.assert_screen_text(
                "shell-history-output", match="contains", region="minibuffer"
            )
            session.key("RET")
            session.wait_for_text("shell-history-output")
            session.wait_for_region_text(
                "minibuffer", "Pipe command finished successfully"
            )
            _assert_result_text(session, "shell-history-output")
            _assert_alive(session)
            _assert_source_unchanged(session, path)
            output, code = session.quit()
        _assert_exit_zero("pipe-command prompt history", output, code)
    finally:
        directory.cleanup()


@scenario("shell/pipe-command-r5-missing", commands=["pipe-command"])
def pipe_command_r5_missing(binary):
    directory, path = _source_fixture()
    try:
        with Session(binary, [path]) as session:
            session.wait_ready()
            _pipe(session, "./w3-11-shell-missing-tool")
            missing_error_fragments = (
                "not found",
                "No such file or directory",
            )
            session.wait_until(
                lambda _screen: any(
                    fragment in _result_text(session)
                    for fragment in missing_error_fragments
                ),
                what="the shell's missing executable diagnostic",
            )
            missing_error = next(
                fragment
                for fragment in missing_error_fragments
                if fragment in _result_text(session)
            )
            _assert_exit_message(session, 127)
            _assert_result_text(session, missing_error)
            session.assert_external_state(
                "pipe-command exit code", _result_exit_code(session), 127
            )
            _assert_alive(session)
            _assert_source_unchanged(session, path)
            output, code = session.quit()
        _assert_exit_zero("pipe-command missing tool", output, code)
    finally:
        directory.cleanup()


@scenario("shell/pipe-command-r5-nonzero", commands=["pipe-command"])
def pipe_command_r5_nonzero(binary):
    directory, path = _source_fixture()
    try:
        with Session(binary, [path]) as session:
            session.wait_ready()
            _pipe(
                session,
                "/bin/sh -c 'printf shell-nonzero-output; "
                "printf shell-nonzero-error >&2; exit 23'",
            )
            session.wait_for_text("shell-nonzero-error")
            _assert_exit_message(session, 23)
            _assert_result_text(session, "shell-nonzero-output")
            _assert_result_text(session, "shell-nonzero-error")
            session.assert_external_state(
                "pipe-command exit code", _result_exit_code(session), 23
            )
            _assert_alive(session)
            _assert_source_unchanged(session, path)
            output, code = session.quit()
        _assert_exit_zero("pipe-command nonzero status", output, code)
    finally:
        directory.cleanup()


@scenario("shell/pipe-command-r5-interrupted", commands=["pipe-command"])
def pipe_command_r5_interrupted(binary):
    directory, path = _source_fixture()
    try:
        with Session(binary, [path]) as session:
            session.wait_ready()
            _pipe(session, "exec /bin/sh -c 'kill -KILL $$'")
            session.wait_for_text("Exit code: 137")
            _assert_exit_message(session, 137)
            _assert_result_text(session, "Exit code: 137")
            session.assert_external_state(
                "pipe-command exit code", _result_exit_code(session), 137
            )
            _assert_alive(session)
            _assert_source_unchanged(session, path)
            output, code = session.quit()
        _assert_exit_zero("pipe-command interrupted child", output, code)
    finally:
        directory.cleanup()
