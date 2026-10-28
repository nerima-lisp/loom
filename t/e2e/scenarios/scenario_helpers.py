"""Shared PTY scenario helpers."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.session import Session


def assert_exit_zero(name, output, code):
    if code != 0:
        raise AssertionError(f"{name} exited with {code}: {output!r}")


def write_buffer(directory, name="buffer.txt", contents=b"alpha beta\ngamma\n"):
    path = os.path.join(directory, name)
    with open(path, "wb") as handle:
        handle.write(contents)
    return path


def probe_command(
    binary, command, contents=b"alpha beta\ngamma\n", expected_prompt=None
):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = write_buffer(directory, contents=contents)
        with Session(binary, [path]) as session:
            session.wait_ready()
            initial_lines = contents.splitlines()
            if initial_lines:
                first_line = initial_lines[0].decode("utf-8")
                if first_line:
                    session.wait_for_region_text("body", first_line)
            session.extended_command(command)
            if expected_prompt is not None:
                session.wait_for_region_text("minibuffer", expected_prompt)
            session.send(keys.ctrl("g"))
            output, code = session.quit()
        assert_exit_zero(command, output, code)


def probe_commands(binary, commands, contents=b"alpha beta\ngamma\n"):
    for command in commands:
        probe_command(binary, command, contents)

