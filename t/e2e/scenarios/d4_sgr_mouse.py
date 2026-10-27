"""SGR mouse click behavior through Loom's real PTY entry point."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


@scenario("clipboard-mouse/d4-sgr-mouse", commands=["forward-char"])
def sgr_mouse_click_moves_point(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "mouse.txt")
        with open(path, "wb") as handle:
            handle.write(b"first\nsecond\nthird\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            mouse_click = b"\x1b[<0;3;2M"
            session.send(mouse_click + keys.ctrl("f"))
            expected = (1, 3)
            no_click_after_fence = (0, 1)

            try:
                session.wait_until(
                    lambda _screen: session.region_cursor("body", 1)
                    in (expected, no_click_after_fence)
                    or session.process.has_exited(),
                    timeout=1,
                    what="C-f after the SGR mouse bytes to reach the point",
                )
            except TimeoutError:
                pass

            if session.process.has_exited():
                raise AssertionError(
                    "SGR mouse event terminated loom "
                    f"(TYPE-ERROR={b'TYPE-ERROR' in session.output_bytes}): "
                    f"{session.output_bytes!r}"
                )

            if session.observe_cursor(
                expected=expected,
                region="body",
                index=1,
                purpose="SGR click followed by C-f moves point",
                sample=mouse_click,
            ) is not True:
                raise AssertionError(
                    f"D4: SGR click bytes {mouse_click!r} followed by C-f did not "
                    f"move point to {expected!r}; "
                    f"actual={session.region_cursor('body', 1)!r}, "
                    f"PTY output={session.output_bytes!r}"
                )

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"SGR mouse scenario exited with {code}: {output!r}"
                )
