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


def _write_nixfmt_wrapper(directory, marker, name="nixfmt-wrapper"):
    path = os.path.join(directory, name)
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


def _assert_formatted(session):
    session.wait_for_text("Buffer formatted successfully")
    session.assert_screen_text(
        "Buffer formatted successfully", match="contains", region="minibuffer"
    )
    session.assert_screen_text(
        "1 + 1", match="contains", region="body", index=None
    )


def _save_formatted(session, path):
    session.send(keys.ctrl("x") + keys.ctrl("s"))
    session.wait_for_file(path, _FORMATTED)
    session.assert_file_bytes(path, _FORMATTED)


def _configure_nixfmt(session):
    _set_format_prompt(session, "nixfmt")
    session.wait_for_text("Format-on-save command set")
    session.assert_screen_text(
        "Format-on-save command set", match="contains", region="minibuffer"
    )


def _enable_format_on_save_and_save(session, path):
    session.extended_command("format-on-save-mode")
    session.pump()
    session.send(keys.ctrl("e") + keys.text(" "))
    session.send(keys.ctrl("x") + keys.ctrl("s"))
    session.wait_for_file(path, _FORMATTED)
    session.assert_file_bytes(path, _FORMATTED)


@scenario(
    "format/format-current-buffer-prompt-accept",
    commands=["format-current-buffer"],
)
def format_current_buffer_prompt_accept(binary):
    with tempfile.TemporaryDirectory(prefix="loom-format-r2-") as directory:
        path = os.path.join(directory, "expression.nix")
        _write(path, _SOURCE)

        with Session(binary, [path]) as session:
            session.wait_ready()
            _format_prompt(session, "nixfmt")
            _assert_formatted(session)
            session.assert_file_bytes(path, _SOURCE)
            _save_formatted(session, path)
            _assert_exit_zero(session, "format-current-buffer-prompt-accept")


@scenario(
    "format/format-current-buffer-prompt-cancel",
    commands=["format-current-buffer"],
)
def format_current_buffer_prompt_cancel(binary):
    with tempfile.TemporaryDirectory(prefix="loom-format-r2-") as directory:
        path = os.path.join(directory, "expression.nix")
        _write(path, _SOURCE)

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("format-current-buffer")
            session.wait_for_region_text("minibuffer", "Format command: ")
            session.send(keys.ctrl("g"))
            session.wait_for_region_absent_text("minibuffer", "Format command: ")
            session.assert_screen_text(
                "1+1", match="contains", region="body", index=None
            )
            session.assert_file_bytes(path, _SOURCE)
            _assert_exit_zero(session, "format-current-buffer-prompt-cancel")


@scenario(
    "format/format-current-buffer-prompt-empty",
    commands=["format-current-buffer"],
)
def format_current_buffer_prompt_empty(binary):
    with tempfile.TemporaryDirectory(prefix="loom-format-r2-") as directory:
        path = os.path.join(directory, "expression.nix")
        _write(path, _SOURCE)

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("format-current-buffer")
            session.wait_for_region_text("minibuffer", "Format command: ")
            session.key("RET")
            session.wait_for_region_exact_text(
                "minibuffer", "Format command cancelled", strip_right=True
            )
            session.assert_screen_text(
                "Format command cancelled", match="contains", region="minibuffer"
            )
            session.assert_screen_text(
                "1+1", match="contains", region="body", index=None
            )
            session.assert_file_bytes(path, _SOURCE)
            _assert_exit_zero(session, "format-current-buffer-prompt-empty")


@scenario(
    "format/format-current-buffer-prompt-tab",
    commands=["format-current-buffer"],
)
def format_current_buffer_prompt_tab(binary):
    with tempfile.TemporaryDirectory(prefix="loom-format-r2-") as directory:
        path = os.path.join(directory, "expression.nix")
        _write(path, _SOURCE)

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("format-current-buffer")
            session.wait_for_region_text("minibuffer", "Format command: ")
            session.type("nixfmt")
            session.key("TAB")
            session.wait_for_region_exact_text(
                "minibuffer", "Format command: nixfmt", strip_right=True
            )
            session.assert_screen_text(
                "Format command: nixfmt",
                match="exact",
                region="minibuffer",
                strip_right=True,
            )
            session.key("RET")
            _assert_formatted(session)
            session.assert_file_bytes(path, _SOURCE)
            _save_formatted(session, path)
            _assert_exit_zero(session, "format-current-buffer-prompt-tab")


@scenario(
    "format/format-current-buffer-prompt-history",
    commands=["format-current-buffer"],
)
def format_current_buffer_prompt_history(binary):
    with tempfile.TemporaryDirectory(prefix="loom-format-r2-") as directory:
        path = os.path.join(directory, "expression.nix")
        marker = os.path.join(directory, "formatter-exit")
        _write(path, _SOURCE)
        _write_nixfmt_wrapper(directory, marker, name="format-current-buffer")
        original_path = os.environ.get("PATH")
        os.environ["PATH"] = os.pathsep.join(
            part for part in (directory, original_path) if part
        )

        try:
            with Session(binary, [path]) as session:
                session.wait_ready()
                session.extended_command("format-current-buffer")
                session.wait_for_region_text("minibuffer", "Format command: ")
                session.key("UP")
                session.wait_for_region_exact_text(
                    "minibuffer",
                    "Format command: format-current-buffer",
                    strip_right=True,
                )
                session.assert_screen_text(
                    "Format command: format-current-buffer",
                    match="exact",
                    region="minibuffer",
                    strip_right=True,
                )
                session.key("RET")
                _assert_formatted(session)
                session.assert_external_state(
                    "history-formatter-exit-code", _read_text(marker), "0"
                )
                session.assert_file_bytes(path, _SOURCE)
                _save_formatted(session, path)
                _assert_exit_zero(session, "format-current-buffer-prompt-history")
        finally:
            if original_path is None:
                os.environ.pop("PATH", None)
            else:
                os.environ["PATH"] = original_path


@scenario("format/set-format-command-prompt-accept", commands=["set-format-command"])
def set_format_command_prompt_accept(binary):
    with tempfile.TemporaryDirectory(prefix="loom-format-r2-") as directory:
        path = os.path.join(directory, "expression.nix")
        _write(path, _SOURCE)

        with Session(binary, [path]) as session:
            session.wait_ready()
            _configure_nixfmt(session)
            session.assert_file_bytes(path, _SOURCE)
            _enable_format_on_save_and_save(session, path)
            _assert_exit_zero(session, "set-format-command-prompt-accept")


@scenario("format/set-format-command-prompt-cancel", commands=["set-format-command"])
def set_format_command_prompt_cancel(binary):
    with tempfile.TemporaryDirectory(prefix="loom-format-r2-") as directory:
        path = os.path.join(directory, "expression.nix")
        _write(path, _SOURCE)

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("set-format-command")
            session.wait_for_region_text("minibuffer", "Format-on-save command: ")
            session.send(keys.ctrl("g"))
            session.wait_for_region_absent_text(
                "minibuffer", "Format-on-save command: "
            )
            session.assert_file_bytes(path, _SOURCE)
            session.extended_command("format-on-save-mode")
            session.wait_for_region_text(
                "minibuffer", "Set a format command before enabling format-on-save"
            )
            session.assert_screen_text(
                "Set a format command before enabling format-on-save",
                match="contains",
                region="minibuffer",
            )
            session.assert_file_bytes(path, _SOURCE)
            _assert_exit_zero(session, "set-format-command-prompt-cancel")


@scenario("format/set-format-command-prompt-empty", commands=["set-format-command"])
def set_format_command_prompt_empty(binary):
    with tempfile.TemporaryDirectory(prefix="loom-format-r2-") as directory:
        path = os.path.join(directory, "expression.nix")
        _write(path, _SOURCE)

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("set-format-command")
            session.wait_for_region_text("minibuffer", "Format-on-save command: ")
            session.key("RET")
            session.wait_for_region_exact_text(
                "minibuffer",
                "Format-on-save command error: The format command must not be empty",
                strip_right=True,
            )
            session.assert_file_bytes(path, _SOURCE)
            session.extended_command("format-on-save-mode")
            session.wait_for_region_text(
                "minibuffer", "Set a format command before enabling format-on-save"
            )
            session.assert_screen_text(
                "Set a format command before enabling format-on-save",
                match="contains",
                region="minibuffer",
            )
            session.assert_file_bytes(path, _SOURCE)
            _assert_exit_zero(session, "set-format-command-prompt-empty")


@scenario("format/set-format-command-prompt-tab", commands=["set-format-command"])
def set_format_command_prompt_tab(binary):
    with tempfile.TemporaryDirectory(prefix="loom-format-r2-") as directory:
        path = os.path.join(directory, "expression.nix")
        _write(path, _SOURCE)

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("set-format-command")
            session.wait_for_region_text(
                "minibuffer", "Format-on-save command: "
            )
            session.type("nixfmt")
            session.key("TAB")
            session.wait_for_region_exact_text(
                "minibuffer", "Format-on-save command: nixfmt", strip_right=True
            )
            session.assert_screen_text(
                "Format-on-save command: nixfmt",
                match="exact",
                region="minibuffer",
                strip_right=True,
            )
            session.key("RET")
            session.wait_for_region_text("minibuffer", "Format-on-save command set")
            session.assert_file_bytes(path, _SOURCE)
            _enable_format_on_save_and_save(session, path)
            _assert_exit_zero(session, "set-format-command-prompt-tab")


@scenario("format/set-format-command-prompt-history", commands=["set-format-command"])
def set_format_command_prompt_history(binary):
    with tempfile.TemporaryDirectory(prefix="loom-format-r2-") as directory:
        path = os.path.join(directory, "expression.nix")
        marker = os.path.join(directory, "formatter-exit")
        _write(path, _SOURCE)
        _write_nixfmt_wrapper(directory, marker, name="set-format-command")
        original_path = os.environ.get("PATH")
        os.environ["PATH"] = os.pathsep.join(
            part for part in (directory, original_path) if part
        )

        try:
            with Session(binary, [path]) as session:
                session.wait_ready()
                session.extended_command("set-format-command")
                session.wait_for_region_text(
                    "minibuffer", "Format-on-save command: "
                )
                session.key("UP")
                session.wait_for_region_exact_text(
                    "minibuffer",
                    "Format-on-save command: set-format-command",
                    strip_right=True,
                )
                session.assert_screen_text(
                    "Format-on-save command: set-format-command",
                    match="exact",
                    region="minibuffer",
                    strip_right=True,
                )
                session.key("RET")
                session.wait_for_region_text(
                    "minibuffer", "Format-on-save command set"
                )
                _enable_format_on_save_and_save(session, path)
                session.assert_external_state(
                    "history-format-on-save-exit-code", _read_text(marker), "0"
                )
                _assert_exit_zero(session, "set-format-command-prompt-history")
        finally:
            if original_path is None:
                os.environ.pop("PATH", None)
            else:
                os.environ["PATH"] = original_path


@scenario(
    "format/format-current-buffer-read-only",
    commands=["toggle-read-only", "format-current-buffer"],
)
def format_current_buffer_read_only(binary):
    with tempfile.TemporaryDirectory(prefix="loom-format-r3-") as directory:
        path = os.path.join(directory, "expression.nix")
        _write(path, _SOURCE)

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("toggle-read-only")
            session.wait_for_region_text("minibuffer", "Buffer is read-only")
            _format_prompt(session, "nixfmt")
            session.wait_for_region_exact_text(
                "minibuffer",
                "Format command error: Buffer expression.nix is read-only",
                strip_right=True,
            )
            session.assert_screen_text(
                "1+1", match="contains", region="body", index=None
            )
            session.assert_file_bytes(path, _SOURCE)
            _assert_exit_zero(session, "format-current-buffer-read-only")


@scenario(
    "format/format-current-buffer-narrow",
    commands=["set-mark-command", "narrow-to-region", "format-current-buffer"],
)
def format_current_buffer_narrow(binary):
    source = b"{ a=1;\n  b=2;\n}\n"
    with tempfile.TemporaryDirectory(prefix="loom-format-r3-") as directory:
        path = os.path.join(directory, "expression.nix")
        _write(path, source)

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.send(keys.ctrl("n"))
            session.extended_command("set-mark-command")
            session.send(keys.ctrl("e"))
            session.extended_command("narrow-to-region")
            session.wait_for_region_exact_text("body", "  b=2;", index=0)
            session.assert_screen_text(
                "  b=2;", match="exact", region="body", index=0, strip_right=True
            )
            _format_prompt(session, "nixfmt")
            session.wait_for_region_text(
                "minibuffer",
                "Format command error: format-buffer-with-command does not",
            )
            session.assert_screen_text(
                "Format command error: format-buffer-with-command does not",
                match="contains",
                region="minibuffer",
            )
            session.assert_file_bytes(path, source)
            _assert_exit_zero(session, "format-current-buffer-narrow")


@scenario(
    "format/format-current-buffer-split-window",
    commands=["split-window-below", "format-current-buffer", "save-buffer"],
)
def format_current_buffer_split_window(binary):
    with tempfile.TemporaryDirectory(prefix="loom-format-r3-") as directory:
        path = os.path.join(directory, "expression.nix")
        _write(path, _SOURCE)

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.send(keys.ctrl("x") + keys.text("2"))
            session.wait_for_text("1+1")
            _format_prompt(session, "nixfmt")
            _assert_formatted(session)
            if session.region_contents("body").count("1 + 1") != 2:
                raise AssertionError("formatted text is not visible in both windows")
            _save_formatted(session, path)
            _assert_exit_zero(session, "format-current-buffer-split-window")


@scenario(
    "format/format-current-buffer-prefix-u4",
    commands=["format-current-buffer", "save-buffer"],
)
def format_current_buffer_prefix_u4(binary):
    with tempfile.TemporaryDirectory(prefix="loom-format-r3-") as directory:
        path = os.path.join(directory, "expression.nix")
        _write(path, _SOURCE)

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.send(keys.ctrl("u") + keys.text("4"))
            _format_prompt(session, "nixfmt")
            _assert_formatted(session)
            _save_formatted(session, path)
            _assert_exit_zero(session, "format-current-buffer-prefix-u4")


def _assert_point_zero(session, scenario_name):
    if session.observe_cursor(expected=(0, 0), region="body") is not True:
        raise AssertionError(
            f"{scenario_name}: cursor was {session.region_cursor('body')!r}, expected (0, 0)"
        )


@scenario(
    "format/format-current-buffer-effect",
    commands=["format-current-buffer", "save-buffer"],
)
def format_current_buffer_effect(binary):
    with tempfile.TemporaryDirectory(prefix="loom-format-r3-") as directory:
        path = os.path.join(directory, "expression.nix")
        _write(path, _SOURCE)

        with Session(binary, [path]) as session:
            session.wait_ready()
            _format_prompt(session, "nixfmt")
            _assert_formatted(session)
            session.assert_screen_text(
                "1 + 1", match="exact", region="body", index=0, strip_right=True
            )
            _assert_point_zero(session, "format-current-buffer-effect")
            _save_formatted(session, path)
            _assert_exit_zero(session, "format-current-buffer-effect")


@scenario(
    "format/format-current-buffer-undo",
    commands=["format-current-buffer", "undo", "save-buffer"],
)
def format_current_buffer_undo(binary):
    with tempfile.TemporaryDirectory(prefix="loom-format-r3-") as directory:
        path = os.path.join(directory, "expression.nix")
        _write(path, _SOURCE)

        with Session(binary, [path]) as session:
            session.wait_ready()
            _format_prompt(session, "nixfmt")
            _assert_formatted(session)
            session.assert_screen_text(
                "1 + 1", match="exact", region="body", index=0, strip_right=True
            )
            _assert_point_zero(session, "format-current-buffer-undo")
            _save_formatted(session, path)

            session.send(keys.ctrl("x") + keys.text("u"))
            session.wait_for_region_exact_text("body", "1+1", index=0)
            session.assert_screen_text(
                "1+1", match="exact", region="body", index=0, strip_right=True
            )
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, _SOURCE)
            session.assert_file_bytes(path, _SOURCE)
            _assert_exit_zero(session, "format-current-buffer-undo")
