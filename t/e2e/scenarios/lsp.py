"""PTY scenarios using the real nixd language server."""

import os
import shutil
import subprocess
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session

from .scenario_helpers import assert_exit_zero, write_buffer


def _nixd_command():
    command = shutil.which("nixd")
    if command:
        return command
    return subprocess.check_output(
        ["nix", "eval", "--raw", "nixpkgs#nixd"], text=True
    ).strip()


def _fixture():
    directory = tempfile.TemporaryDirectory(prefix="loom-e2e-lsp-")
    with open(os.path.join(directory.name, "flake.nix"), "wb") as handle:
        handle.write(b"{}\n")
    with open(os.path.join(directory.name, ".loom-lsp"), "w", encoding="utf-8") as handle:
        handle.write(_nixd_command() + "\n")
    path = write_buffer(
        directory.name,
        "main.nix",
        b"let\n  value = 1;\nin\n  value\n",
    )
    return directory, path


def _start(session):
    session.extended_command("lsp-start")
    session.wait_for_text("LSP command [RET for")
    session.send(keys.RET)
    session.wait_for_text("LSP started.")


def _run_lsp_command(binary, command, expected):
    directory, path = _fixture()
    try:
        with Session(binary, [path]) as session:
            session.wait_ready()
            _start(session)
            if command not in ("lsp-diagnostics", "lsp-stop"):
                session.extended_command("lsp-diagnostics")
                session.wait_for_text("LSP diagnostics refreshed.")
                session.extended_command("switch-to-buffer")
                session.wait_for_text("Switch to buffer: ")
                session.type("main.nix")
                session.send(keys.RET)
                session.wait_for_text("let")
            session.extended_command(command)
            session.wait_for_text(expected)
            output, code = session.quit()
        assert_exit_zero(command, output, code)
    finally:
        directory.cleanup()


@scenario("lsp/start", commands=["lsp-start"])
def lsp_start(binary):
    directory, path = _fixture()
    try:
        with Session(binary, [path]) as session:
            session.wait_ready()
            _start(session)
            output, code = session.quit()
        assert_exit_zero("lsp-start", output, code)
    finally:
        directory.cleanup()


@scenario("lsp/stop", commands=["lsp-stop"])
def lsp_stop(binary):
    directory, path = _fixture()
    try:
        with Session(binary, [path]) as session:
            session.wait_ready()
            _start(session)
            session.extended_command("lsp-stop")
            session.wait_for_text("LSP stopped.")
            output, code = session.quit()
        assert_exit_zero("lsp-stop", output, code)
    finally:
        directory.cleanup()


@scenario("lsp/diagnostics", commands=["lsp-diagnostics"])
def lsp_diagnostics(binary):
    _run_lsp_command(binary, "lsp-diagnostics", "LSP diagnostics refreshed.")


@scenario("lsp/completion", commands=["lsp-completion-at-point"])
def lsp_completion(binary):
    _run_lsp_command(binary, "lsp-completion-at-point", "No completions")


@scenario("lsp/find-definition", commands=["lsp-find-definition"])
def lsp_find_definition(binary):
    _run_lsp_command(binary, "lsp-find-definition", "No definition found")


@scenario("lsp/pop-definition", commands=["lsp-pop-definition"])
def lsp_pop_definition(binary):
    _run_lsp_command(binary, "lsp-pop-definition", "No jump to return from")
