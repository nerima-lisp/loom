"""Exercise standard terminal navigation keys through a PTY session."""

import os
import tempfile

from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _assert_cursor(session, col, index=0):
    expected = (session.layout.row("body", index), col)
    if session.observe_cursor(expected=expected) is not True:
        raise AssertionError(f"body cursor did not reach {expected!r}")


@scenario(
    "movement/terminal-navigation-keys",
    commands=[
        "backward-char",
        "delete-char",
        "forward-char",
        "move-beginning-of-line",
        "move-end-of-line",
        "next-line",
        "previous-line",
        "scroll-down-command",
        "scroll-up-command",
    ],
)
def terminal_navigation_keys(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "navigation.txt")
        lines = ["abcdef"] + [f"line{index}" for index in range(1, 30)]
        with open(path, "wb") as handle:
            handle.write(("\n".join(lines) + "\n").encode("ascii"))

        with Session(binary, [path], rows=8) as session:
            session.wait_ready()
            session.wait_for_region_cursor("body", 0, index=0)

            session.send(b"\x1b[C")
            session.wait_for_region_cursor("body", 1, index=0)
            _assert_cursor(session, 1)
            session.send(b"\x1b[B")
            session.wait_for_region_cursor("body", 1, index=1)
            _assert_cursor(session, 1, index=1)
            session.send(b"\x1b[D")
            session.wait_for_region_cursor("body", 0, index=1)
            _assert_cursor(session, 0, index=1)
            session.send(b"\x1b[A")
            session.wait_for_region_cursor("body", 0, index=0)
            _assert_cursor(session, 0)

            for home in (b"\x1b[H", b"\x1b[1~", b"\x1b[7~", b"\x1bOH"):
                session.send(b"\x1b[C" + home)
                session.wait_for_region_cursor("body", 0, index=0)
                _assert_cursor(session, 0)

            for end in (b"\x1b[F", b"\x1b[4~", b"\x1b[8~", b"\x1bOF"):
                session.send(b"\x1b[D" + end)
                session.wait_for_region_cursor("body", 6, index=0)
                _assert_cursor(session, 6)

            session.send(b"\x1b[H")
            session.wait_for_region_cursor("body", 0, index=0)
            _assert_cursor(session, 0)

            session.send(b"\x1b[3~")
            session.wait_for_region_text_prefix("body", "bcdef")
            session.assert_screen_text(
                "bcdef", match="starts_with", region="body"
            )

            session.send(b"\x1b[6~")
            page_row = session.layout.body_height
            page_line = f"line{page_row}"
            session.wait_for_region_text("body", page_line, index=1)
            session.assert_screen_text(
                page_line, match="contains", region="body", index=1
            )
            session.send(b"\x1b[5~")
            session.wait_for_region_text("body", "bcdef")
            session.assert_screen_text(
                "bcdef", match="starts_with", region="body"
            )

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"movement/terminal-navigation-keys exited with {code}: {output!r}"
                )
