"""Exercise kill-ring region and local clipboard paths through a real PTY."""

import base64
import contextlib
import json
import os
import shlex
import tempfile
from pathlib import Path

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


_INITIAL = b"alpha beta\n"
_OUTCOMES = ("success", "missing", "nonzero", "interrupted")
_REGION_COMMANDS = {"kill-region", "kill-ring-save"}
_KILL_TEXT = {
    "backward-kill-word": b"beta",
    "kill-line": b"alpha beta",
    "kill-region": b"alpha beta",
    "kill-ring-save": b"alpha beta",
    "kill-word": b"alpha",
}
_BODY_TEXT = {
    "backward-kill-word": "alpha",
    "kill-line": "",
    "kill-region": "",
    "kill-ring-save": "alpha beta",
    "kill-word": " beta",
}
_SAVED_BYTES = {
    "backward-kill-word": b"alpha \n",
    "kill-line": b"\n",
    "kill-region": b"\n",
    "kill-ring-save": _INITIAL,
    "kill-word": b" beta\n",
}


@contextlib.contextmanager
def _clipboard_path(path):
    previous = os.environ.get("PATH")
    os.environ["PATH"] = str(path)
    try:
        yield
    finally:
        if previous is None:
            os.environ.pop("PATH", None)
        else:
            os.environ["PATH"] = previous


def _write_fake_tool(bin_dir, command, outcome, result_path):
    script_path = bin_dir / command
    script_path.write_text(
        "\n".join(
            (
                "#!/bin/sh",
                "payload=",
                "IFS= read -r payload || :",
                f"printf '{{\"status\":\"{outcome}\",\"payload\":\"%s\"}}' \"$payload\" > {shlex.quote(str(result_path))}",
                "if [ \"" + outcome + "\" = nonzero ]; then exit 23; fi",
                "if [ \"" + outcome + "\" = interrupted ]; then kill -TERM \"$$\"; fi",
            )
        )
        + "\n",
        encoding="utf-8",
    )
    script_path.chmod(0o755)


def _result(result_path):
    if not result_path.exists():
        return {"status": "missing", "payload": ""}
    return json.loads(result_path.read_text(encoding="utf-8"))


def _invoke_primary_key(session, command):
    sequence = {
        "backward-kill-word": b"\x1b\x7f",
        "kill-line": keys.ctrl("k"),
        "kill-region": keys.ctrl("w"),
        "kill-ring-save": keys.meta("w"),
        "kill-word": keys.meta("d"),
    }[command]
    session.send(sequence)


def _select_whole_line(session):
    session.send(keys.ctrl("a") + keys.ctrl("@") + keys.ctrl("e"))


def _wait_body(session, expected):
    session.wait_for_region_exact_text("body", expected, strip_right=True)
    session.assert_screen_text(
        expected, region="body", strip_right=True
    )


def _save(session, path, expected):
    session.send(keys.ctrl("x") + keys.ctrl("s"))
    session.wait_for_file(path, expected)
    session.assert_file_bytes(path, expected)


def _wait_for_terminal_clipboard_write(session, text):
    encoded = base64.b64encode(text).decode("ascii")
    sequence = f"\x1b]52;c;{encoded}\x07".encode("ascii")
    session.wait_until(
        lambda _screen: sequence in session.output_bytes,
        timeout=2,
        what="the terminal clipboard write sequence",
    )
    session.assert_pty_output(session.output_bytes, sequence)


def _run_kill_command(binary, command, outcome):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-kill-ring-r5-") as directory:
        root = Path(directory)
        bin_dir = root / "bin"
        bin_dir.mkdir()
        path = root / "buffer.txt"
        path.write_bytes(_INITIAL)
        result_path = root / "clipboard-result.json"
        if outcome != "missing":
            _write_fake_tool(bin_dir, "pbcopy", outcome, result_path)

        with _clipboard_path(bin_dir), Session(binary, [str(path)]) as session:
            session.wait_ready()
            if command in _REGION_COMMANDS:
                _select_whole_line(session)
            elif command == "backward-kill-word":
                session.send(keys.ctrl("e"))

            _invoke_primary_key(session, command)
            _wait_body(session, _BODY_TEXT[command])
            _wait_for_terminal_clipboard_write(session, _KILL_TEXT[command])
            _save(session, path, _SAVED_BYTES[command])
            session.assert_external_state(
                "local clipboard command result",
                _result(result_path),
                {
                    "status": outcome,
                    "payload": _KILL_TEXT[command].decode("utf-8")
                    if outcome != "missing"
                    else "",
                },
            )


def _register_r5(command, outcome):
    name = f"r5/clipboard/{command}/{outcome}"

    @scenario(name, commands=[command, "save-buffer"])
    def run(binary):
        _run_kill_command(binary, command, outcome)

    return run


for _command in sorted(_KILL_TEXT):
    for _outcome in _OUTCOMES:
        globals()[f"r5_{_command}_{_outcome}"] = _register_r5(
            _command, _outcome
        )


def _run_r4(binary, command, region_present):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-kill-ring-r4-") as directory:
        root = Path(directory)
        bin_dir = root / "bin"
        bin_dir.mkdir()
        path = root / "buffer.txt"
        path.write_bytes(_INITIAL)
        result_path = root / "clipboard-result.json"
        if region_present:
            _write_fake_tool(bin_dir, "pbcopy", "success", result_path)

        with _clipboard_path(bin_dir), Session(binary, [str(path)]) as session:
            session.wait_ready()
            if region_present:
                _select_whole_line(session)

            _invoke_primary_key(session, command)
            if not region_present:
                session.wait_for_region_exact_text(
                    "minibuffer",
                    "The mark is not set now, so no region is active",
                )
                session.assert_screen_text(
                    "The mark is not set now, so no region is active",
                    region="minibuffer",
                    strip_right=True,
                )
                _wait_body(session, "alpha beta")
                session.assert_file_bytes(path, _INITIAL)
                return

            expected_body = "" if command == "kill-region" else "alpha beta"
            _wait_body(session, expected_body)
            if command == "kill-ring-save":
                _wait_for_terminal_clipboard_write(session, b"alpha beta")
            expected_bytes = b"\n" if command == "kill-region" else _INITIAL
            _save(session, path, expected_bytes)
            if command == "kill-ring-save":
                session.assert_external_state(
                    "local clipboard contains the copied region",
                    _result(result_path),
                    {"status": "success", "payload": "alpha beta"},
                )


@scenario(
    "kill-ring/r4/kill-region/region-present",
    commands=["kill-region", "save-buffer"],
)
def r4_kill_region_region_present(binary):
    _run_r4(binary, "kill-region", True)


@scenario(
    "kill-ring/r4/kill-region/region-absent",
    commands=["kill-region"],
)
def r4_kill_region_region_absent(binary):
    _run_r4(binary, "kill-region", False)


@scenario(
    "kill-ring/r4/kill-ring-save/region-present",
    commands=["kill-ring-save", "save-buffer"],
)
def r4_kill_ring_save_region_present(binary):
    _run_r4(binary, "kill-ring-save", True)


@scenario(
    "kill-ring/r4/kill-ring-save/region-absent",
    commands=["kill-ring-save"],
)
def r4_kill_ring_save_region_absent(binary):
    _run_r4(binary, "kill-ring-save", False)
