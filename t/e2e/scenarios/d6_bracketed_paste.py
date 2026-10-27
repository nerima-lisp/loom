"""Bracketed-paste behavior through Loom's real PTY entry point."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


@scenario(
    "clipboard-mouse/d6-bracketed-paste-tab",
    commands=["save-buffer", "save-buffers-kill-terminal"],
)
def bracketed_paste_preserves_tab(binary):
    original = b"tail\n"
    expected = b"left\trighttail\n"
    paste = b"\x1b[200~left\tright\x1b[201~"
    enable = b"\x1b[?2004h"

    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "paste.txt")
        with open(path, "wb") as handle:
            handle.write(original)

        with Session(binary, [path]) as session:
            session.wait_ready()
            startup_output = session.output_bytes
            bracket_mode_enabled = session.observe_pty_output(
                startup_output,
                enable,
                match="contains",
                purpose="bracketed-paste mode enabled before raw paste input",
            )
            session.send(paste)

            session.send(keys.ctrl("x") + keys.ctrl("s"))
            try:
                session.wait_for_file(path, expected, timeout=1)
            except TimeoutError:
                pass

            actual = session.observe_file_bytes(path, expected)
            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"bracketed-paste scenario exited with {code}: {output!r}"
                )

            bracket_mode_disabled = session.observe_pty_output(
                session.output_bytes,
                b"\x1b[?2004l",
                match="contains",
                purpose="bracketed-paste mode disabled on exit",
            )

            if actual != expected:
                raise AssertionError(
                    "D6: bracketed paste did not preserve TAB as a literal byte; "
                    f"saved bytes={actual!r}, expected={expected!r}, "
                    f"CSI ?2004h={bracket_mode_enabled!r}, "
                    f"CSI ?2004l={bracket_mode_disabled!r}"
                )

            if bracket_mode_enabled is not True:
                raise AssertionError(
                    "D6: PTY output omitted CSI ?2004h before raw paste bytes "
                    f"{paste!r}; startup output was {startup_output!r}"
                )

            if bracket_mode_disabled is not True:
                raise AssertionError(
                    "D6: PTY output omitted CSI ?2004l on exit: "
                    f"{session.output_bytes!r}"
                )
