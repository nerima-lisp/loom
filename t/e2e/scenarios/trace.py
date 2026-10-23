"""Verify real command dispatches are written to the JSONL trace."""

import json
import os
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
        with open(path, "wb") as handle:
            handle.write(b"abc\ndef\n")

        with Session(binary, [path]) as session:
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

        trace_rows = [
            json.loads(line)
            for line in session.trace_bytes.decode("utf-8").splitlines()
        ]
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
        events = [(event["command"], event["route"]) for event in trace_rows]
        session.observe_external_state("command trace", events, expected)
        pids = {event["pid"] for event in trace_rows}
        sequences = [event["seq"] for event in trace_rows]
        if events != expected or len(pids) != 1 or sequences != list(
            range(1, len(expected) + 1)
        ):
            raise AssertionError(f"unexpected command trace: {trace_rows!r}")
