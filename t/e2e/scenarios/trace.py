"""Verify real command dispatches are written to the JSONL trace."""

import json
import os
import shlex
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


@scenario(
    "runtime/command-trace",
    commands=[
        "execute-extended-command",
        "forward-char",
        "backward-char",
        "save-buffers-kill-terminal",
    ],
)
def command_trace(binary):
    with tempfile.TemporaryDirectory(prefix="loom-trace-") as directory:
        path = os.path.join(directory, "notes.txt")
        trace_path = os.path.join(directory, "commands.jsonl")
        wrapper_path = os.path.join(directory, "loom-with-trace")
        with open(path, "wb") as handle:
            handle.write(b"abc\n")
        with open(wrapper_path, "w", encoding="utf-8") as handle:
            handle.write("#!/bin/sh\n")
            handle.write(
                f"export LOOM_TRACE_COMMANDS={shlex.quote(trace_path)}\n"
            )
            handle.write(
                f"exec {shlex.quote(os.path.abspath(binary))} \"$@\"\n"
            )
        os.chmod(wrapper_path, 0o700)

        with Session(wrapper_path, [path]) as session:
            session.wait_ready()
            session.send(keys.ctrl("f"))
            session.wait_for_region_cursor("body", 1)
            session.extended_command("backward-char")
            session.wait_for_region_cursor("body", 0)
            output, code = session.quit()

        if code != 0:
            raise AssertionError(
                f"command trace session exited with {code}: {output!r}"
            )

        with open(trace_path, encoding="utf-8") as handle:
            events = [json.loads(line) for line in handle]
        expected = [
            {"command": "forward-char", "route": "key", "seq": 1},
            {"command": "execute-extended-command", "route": "key", "seq": 2},
            {"command": "backward-char", "route": "mx", "seq": 3},
            {"command": "save-buffers-kill-terminal", "route": "key", "seq": 4},
        ]
        if events != expected:
            raise AssertionError(f"unexpected command trace: {events!r}")
