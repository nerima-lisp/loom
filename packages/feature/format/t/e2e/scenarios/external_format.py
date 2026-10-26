"""Exercise formatter commands through the PTY with real temporary inputs."""

import os
import shlex
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


_SOURCE = b"1+1\n"
_FORMATTED = b"1 + 1\n"
_INVALID_NIX = b"{ broken = ; }\n"


def _write(path, content):
    with open(path, "wb") as handle:
        handle.write(content)


def _write_script(path, content):
    _write(path, content.encode("utf-8"))
    os.chmod(path, 0o755)
    return path


def _read_text(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def _format_prompt(session, command):
    session.extended_command("format-current-buffer")
    session.wait_for_text("Format command: ")
    session.type(command)
    session.key("RET")


def _assert_exit_zero(session, name):
    output, code = session.quit()
    if session.observe_exit_code(code, 0) is not True:
        raise AssertionError(f"{name}: loom exited with {code}: {output!r}")


def _write_nixfmt_wrapper(directory, marker):
    path = os.path.join(directory, "nixfmt-wrapper")
    _write_script(
        path,
        "#!/bin/sh\n"
        "nixfmt\n"
        "status=$?\n"
        f"printf '%s' \"$status\" > {shlex.quote(marker)}\n"
        "exit \"$status\"\n",
    )
    return path


def _assert_formatter_error(session, path, original, marker, name, predicate, expected):
    session.wait_for_text("Formatter exited with code ")
    marker_code = int(_read_text(marker))
    if session.observe_external_state(name, predicate(marker_code), expected) is not True:
        raise AssertionError(f"{name}: unexpected formatter exit code {marker_code}")
    session.assert_screen_text(
        f"Formatter exited with code {marker_code}",
        match="contains",
        region="screen",
    )
    session.assert_screen_text(
        original.decode("utf-8").rstrip("\n"),
        match="contains",
        region="body",
        index=None,
    )
    session.assert_file_bytes(path, original)


@scenario(
    "format/real-nixfmt-success",
    commands=["format-current-buffer"],
)
def real_nixfmt_success(binary):
    with tempfile.TemporaryDirectory(prefix="loom-format-e2e-") as directory:
        path = os.path.join(directory, "expression.nix")
        marker = os.path.join(directory, "formatter-exit")
        _write(path, _SOURCE)
        command = _write_nixfmt_wrapper(directory, marker)

        with Session(binary, [path]) as session:
            session.wait_ready()
            _format_prompt(session, command)
            session.wait_for_text("Buffer formatted successfully")
            session.assert_screen_text(
                "1 + 1", match="contains", region="body", index=None
            )
            session.assert_external_state(
                "nixfmt-exit-code", _read_text(marker), "0"
            )
            session.assert_file_bytes(path, _SOURCE)
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, _FORMATTED)
            session.assert_file_bytes(path, _FORMATTED)
            _assert_exit_zero(session, "real-nixfmt-success")


@scenario(
    "format/real-nixfmt-nonzero",
    commands=["format-current-buffer"],
)
def real_nixfmt_nonzero(binary):
    with tempfile.TemporaryDirectory(prefix="loom-format-e2e-") as directory:
        path = os.path.join(directory, "invalid.nix")
        marker = os.path.join(directory, "formatter-exit")
        _write(path, _INVALID_NIX)
        command = _write_nixfmt_wrapper(directory, marker)

        with Session(binary, [path]) as session:
            session.wait_ready()
            _format_prompt(session, command)
            _assert_formatter_error(
                session,
                path,
                _INVALID_NIX,
                marker,
                "nixfmt-nonzero-exit",
                lambda code: code != 0,
                True,
            )
            _assert_exit_zero(session, "real-nixfmt-nonzero")


@scenario(
    "format/missing-formatter",
    commands=["format-current-buffer"],
)
def missing_formatter(binary):
    with tempfile.TemporaryDirectory(prefix="loom-format-e2e-") as directory:
        path = os.path.join(directory, "expression.nix")
        marker = os.path.join(directory, "formatter-exit")
        _write(path, _SOURCE)
        command = _write_script(
            os.path.join(directory, "missing-formatter-wrapper"),
            "#!/bin/sh\n"
            "cat >/dev/null\n"
            "loom-w3-11-format-command-that-does-not-exist\n"
            "status=$?\n"
            f"printf '%s' \"$status\" > {shlex.quote(marker)}\n"
            "exit \"$status\"\n",
        )

        with Session(binary, [path]) as session:
            session.wait_ready()
            _format_prompt(session, command)
            session.wait_for_file(marker, b"127", timeout=2.0)
            session.assert_external_state(
                "missing-formatter-exit-code", _read_text(marker), "127"
            )
            session.wait_for_text("Formatter exited with code 127")
            session.assert_screen_text(
                "Formatter exited with code 127", match="contains", region="screen"
            )
            session.assert_screen_text(
                "1+1", match="contains", region="body", index=None
            )
            session.assert_file_bytes(path, _SOURCE)
            _assert_exit_zero(session, "missing-formatter")


@scenario(
    "format/interrupted-formatter",
    commands=["format-current-buffer"],
)
def interrupted_formatter(binary):
    with tempfile.TemporaryDirectory(prefix="loom-format-e2e-") as directory:
        path = os.path.join(directory, "expression.nix")
        _write(path, _SOURCE)
        command = "cat >/dev/null; kill -TERM $$"

        with Session(binary, [path]) as session:
            session.wait_ready()
            _format_prompt(session, command)
            session.wait_for_text("Formatter exited with code 143")
            session.assert_screen_text(
                "Formatter exited with code 143", match="contains", region="screen"
            )
            session.assert_screen_text(
                "1+1", match="contains", region="body", index=None
            )
            session.assert_file_bytes(path, _SOURCE)
            _assert_exit_zero(session, "interrupted-formatter")


def _set_format_prompt(session, command):
    session.extended_command("set-format-command")
    session.wait_for_text("Format-on-save command: ")
    session.type(command)
    session.key("RET")


@scenario(
    "format/format-on-save-real-nixfmt",
    commands=["format-on-save-mode", "set-format-command"],
)
def format_on_save_real_nixfmt(binary):
    with tempfile.TemporaryDirectory(prefix="loom-format-e2e-") as directory:
        path = os.path.join(directory, "expression.nix")
        _write(path, _SOURCE)

        with Session(binary, [path]) as session:
            session.wait_ready()
            _set_format_prompt(session, "nixfmt")
            session.wait_for_text("Format-on-save command set")
            session.assert_screen_text(
                "Format-on-save command set", match="contains", region="screen"
            )
            session.extended_command("format-on-save-mode")
            session.pump()
            session.assert_screen_text(
                "1+1", match="contains", region="body", index=None
            )
            session.send(keys.ctrl("e") + keys.text(" "))
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, _FORMATTED)
            session.assert_file_bytes(path, _FORMATTED)
            session.extended_command("format-on-save-mode")
            _assert_exit_zero(session, "format-on-save-real-nixfmt")
