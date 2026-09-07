"""Startup into the editor loop, and scratch-HOME isolation."""

import os
import tempfile

from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _assert_exit_zero(name, output, code):
    if code != 0:
        raise AssertionError(f"{name} exited with {code}: {output!r}")


@scenario("startup without path", commands=["save-buffers-kill-terminal"])
def startup_without_path(binary):
    real_home = os.path.expanduser("~")
    real_loom_dir = os.path.join(real_home, ".loom")
    existed_before = os.path.isdir(real_loom_dir)

    with Session(binary, []) as session:
        if session.home_dir == real_home:
            raise AssertionError("scratch HOME was not isolated from the real HOME")
        session.wait_ready()
        output, code = session.quit()
    _assert_exit_zero("startup without path", output, code)

    if os.path.isdir(real_loom_dir) != existed_before:
        raise AssertionError(
            f"the real {real_loom_dir} changed existence during a scratch-HOME run"
        )


@scenario("startup directory", commands=["save-buffers-kill-terminal"])
def startup_directory(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        with Session(binary, [directory]) as session:
            session.wait_ready()
            output, code = session.quit()
    _assert_exit_zero("startup directory", output, code)
