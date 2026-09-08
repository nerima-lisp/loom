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
    _assert_exit_zero("--help", output, code)
    if b"Usage: loom [PATH]" not in output:
        raise AssertionError(f"--help output missing usage line: {output!r}")


@scenario("--version", commands=[])
def version_flag(binary):
    with Session(binary, ["--version"]) as session:
        output, code = session.process.wait()
    _assert_exit_zero("--version", output, code)
    if b"loom 0.1.0" not in output:
        raise AssertionError(f"--version output missing version: {output!r}")


@scenario("invalid option", commands=[])
def invalid_option(binary):
    with Session(binary, ["--definitely-invalid"]) as session:
        output, code = session.process.wait()
    _assert_exit_code("invalid option", output, code, 64)
    if b"Unknown option" not in output:
        raise AssertionError(f"invalid option output missing diagnostic: {output!r}")


@scenario("missing path", commands=[])
def missing_path(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "missing.txt")
        with Session(binary, [path]) as session:
            output, code = session.process.wait()
    _assert_exit_code("missing path", output, code, 64)
    if b"PATH does not exist" not in output:
        raise AssertionError(f"missing path output missing diagnostic: {output!r}")
