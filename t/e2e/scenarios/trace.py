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
        "start-kbd-macro",
        "kill-line",
        "end-kbd-macro",
        "next-line",
        "call-last-kbd-macro",
        "universal-argument",
        "previous-line",
        "save-buffer",
        "save-buffers-kill-terminal",
    ],
)
def command_trace(binary):
    with tempfile.TemporaryDirectory(prefix="loom-trace-") as directory:
        path = os.path.join(directory, "notes.txt")
        trace_path = os.path.join(directory, "commands.jsonl")
        wrapper_path = os.path.join(directory, "loom-with-trace")
        with open(path, "wb") as handle:
            handle.write(b"abc\ndef\n")
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
            session.send(keys.ctrl("x") + b"(")
            session.send(keys.ctrl("k"))
            session.send(keys.ctrl("x") + b")")
            session.send(keys.ctrl("n"))
            session.send(keys.ctrl("x") + b"e")
            session.send(keys.ctrl("u"))
            session.send(keys.ctrl("p"))
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            output, code = session.quit()

        if code != 0:
            raise AssertionError(
                f"command trace session exited with {code}: {output!r}"
            )

        with open(trace_path, encoding="utf-8") as handle:
            events = [json.loads(line) for line in handle]
        expected = [
            ("forward-char", "key"),
            ("execute-extended-command", "key"),
            ("backward-char", "mx"),
            ("start-kbd-macro", "key"),
            ("kill-line", "key"),
            ("end-kbd-macro", "key"),
            ("next-line", "key"),
            ("call-last-kbd-macro", "key"),
            ("kill-line", "macro"),
            ("universal-argument", "key"),
            ("previous-line", "key"),
            ("save-buffer", "key"),
            ("save-buffers-kill-terminal", "key"),
        ]
        actual = [(event["command"], event["route"]) for event in events]
        pids = {event["pid"] for event in events}
        sequences = [event["seq"] for event in events]
        if actual != expected or len(pids) != 1 or sequences != list(
            range(1, len(expected) + 1)
        ):
            raise AssertionError(f"unexpected command trace: {events!r}")
