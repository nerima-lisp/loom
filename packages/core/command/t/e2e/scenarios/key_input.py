"""Exercise CR-to-RET mapping and input recovery in a PTY session."""

import os
import tempfile

from loom_e2e.registry import scenario
from loom_e2e import keys
from loom_e2e.session import Session


@scenario(
    "command/cr-ret-unknown-escape-mouse-survival",
    commands=["newline"],
)
def cr_ret_unknown_escape_mouse_survival(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "key-input.txt")
        with open(path, "wb") as handle:
            handle.write(b"first\nsecond\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.wait_for_region_text("body", "first")
            session.wait_for_region_cursor("body", 0)

            session.send(b"\r")
            session.wait_for_region_cursor("body", 0, index=1)
            session.assert_screen_text(
                expected="",
                region="body",
                index=0,
                strip_right=True,
            )

            session.send(b"\x1b[99z")
            session.type("escape-ok")
            session.wait_for_text("escape-ok")

            mouse_row = session.layout.row("body") + 1
            session.send(f"\x1b[<0;1;{mouse_row}M".encode("ascii"))
            session.type("mouse-ok")
            session.wait_for_text("mouse-ok")

            if session.process.has_exited():
                raise AssertionError("editor exited after an input event")
            session.send(keys.ctrl("x") + keys.ctrl("c"))
            session.wait_for_text("Save key-input.txt? (s/d/c): ")
            session.type("d")
            session.key("RET")
            output, code = session.process.wait(timeout=10)
            if code != 0:
                raise AssertionError(
                    f"command/cr-ret-unknown-escape-mouse-survival exited "
                    f"with {code}: {output!r}"
                )
