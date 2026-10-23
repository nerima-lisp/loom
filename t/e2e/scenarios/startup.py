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
        session.assert_external_state(
            "scratch HOME differs from real HOME",
            session.home_dir != real_home,
            True,
        )
        session.observe_external_state(
            "real .loom directory existed before scenario", existed_before
        )
        session.wait_ready()
        output, code = session.quit()
        session.assert_external_state(
            "real .loom directory existence after scenario",
            os.path.isdir(real_loom_dir),
            existed_before,
        )
    _assert_exit_zero("startup without path", output, code)


@scenario("startup directory", commands=["save-buffers-kill-terminal"])
def startup_directory(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        with Session(binary, [directory]) as session:
            session.wait_ready()
            output, code = session.quit()
    _assert_exit_zero("startup directory", output, code)
