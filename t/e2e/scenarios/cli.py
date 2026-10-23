"""Command-line argument handling: no editor session is ever entered."""

import os
import tempfile

from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _assert_exit_zero(name, output, code):
    if code != 0:
        raise AssertionError(f"{name} exited with {code}: {output!r}")


def _assert_exit_code(name, output, code, expected):
    if code != expected:
        raise AssertionError(f"{name} exited with {code}, expected {expected}: {output!r}")


@scenario("--help", commands=[])
def help_flag(binary):
    with Session(binary, ["--help"]) as session:
        output, code = session.process.wait()
        session.observe_exit_code(code, expected=0)
        session.assert_pty_output(output, b"Usage: loom [PATH]")
    _assert_exit_zero("--help", output, code)


@scenario("--version", commands=[])
def version_flag(binary):
    with Session(binary, ["--version"]) as session:
        output, code = session.process.wait()
        session.observe_exit_code(code, expected=0)
        session.assert_pty_output(output, b"loom 0.1.0")
    _assert_exit_zero("--version", output, code)


@scenario("invalid option", commands=[])
def invalid_option(binary):
    with Session(binary, ["--definitely-invalid"]) as session:
        output, code = session.process.wait()
        session.observe_exit_code(code, expected=64)
        session.assert_pty_output(output, b"Unknown option")
    _assert_exit_code("invalid option", output, code, 64)


@scenario("missing path", commands=[])
def missing_path(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "missing.txt")
        with Session(binary, [path]) as session:
            output, code = session.process.wait()
            session.observe_exit_code(code, expected=64)
            session.assert_pty_output(output, b"PATH does not exist")
    _assert_exit_code("missing path", output, code, 64)
