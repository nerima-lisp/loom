"""Exercise standard terminal navigation keys through a PTY session."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _assert_cursor(session, col, index=0):
    expected = (session.layout.row("body", index), col)
    if session.observe_cursor(expected=expected) is not True:
        raise AssertionError(f"body cursor did not reach {expected!r}")


def _navigation_file(directory, lines):
    path = os.path.join(directory, "navigation.txt")
    with open(path, "wb") as handle:
        handle.write(("\n".join(lines) + "\n").encode("ascii"))
    return path


@scenario(
    "movement/terminal-navigation-arrows",
    commands=[
        "backward-char",
        "forward-char",
        "next-line",
        "previous-line",
    ],
)
def terminal_navigation_arrows(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _navigation_file(
            directory, ["abcdef"] + [f"line{index}" for index in range(1, 30)]
        )
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

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"movement/terminal-navigation-arrows exited with {code}: {output!r}"
                )


@scenario(
    "movement/terminal-navigation-home-end",
    commands=[
        "backward-char",
        "forward-char",
        "move-beginning-of-line",
        "move-end-of-line",
    ],
)
def terminal_navigation_home_end(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _navigation_file(
            directory, ["abcdef"] + [f"line{index}" for index in range(1, 30)]
        )
        with Session(binary, [path], rows=8) as session:
            session.wait_ready()
            session.wait_for_region_cursor("body", 0, index=0)

            for home in (b"\x1b[H", b"\x1b[1~", b"\x1b[7~", b"\x1bOH"):
                session.send(b"\x1b[C" + home)
                session.wait_for_region_cursor("body", 0, index=0)
                _assert_cursor(session, 0)

            for end in (b"\x1b[F", b"\x1b[4~", b"\x1b[8~", b"\x1bOF"):
                session.send(b"\x1b[D" + end)
                session.wait_for_region_cursor("body", 6, index=0)
                _assert_cursor(session, 6)

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"movement/terminal-navigation-home-end exited with {code}: {output!r}"
                )


@scenario(
    "movement/terminal-navigation-delete",
    commands=["delete-char", "save-buffer"],
)
def terminal_navigation_delete(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _navigation_file(directory, ["abc"])
        with Session(binary, [path], rows=8) as session:
            session.wait_ready()
            session.wait_for_region_cursor("body", 0, index=0)
            _assert_cursor(session, 0)
            session.send(b"\x1b[3~")
            session.wait_for_region_text_prefix("body", "bc")
            session.assert_screen_text("bc", match="starts_with", region="body")
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, b"bc\n")
            session.assert_file_bytes(path, b"bc\n")

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"movement/terminal-navigation-delete exited with {code}: {output!r}"
                )


@scenario(
    "movement/terminal-navigation-page",
    commands=["next-line", "scroll-down-command", "scroll-up-command", "save-buffer"],
)
def terminal_navigation_page(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        lines = [f"line{index}" for index in range(20)]
        initial = ("\n".join(lines) + "\n").encode("ascii")
        path = _navigation_file(directory, lines)
        session = Session(binary, [path], rows=8)
        try:
            with session:
                session.wait_ready()
                session.wait_for_region_cursor("body", 0, index=0)

                session.send(b"\x1b[B" * 14)
                session.wait_for_region_text("body", "line9")
                session.send(b"\x1b[6~")
                session.wait_for_region_text("body", "line14", index=1)
                session.assert_screen_text(
                    "line14", match="contains", region="body", index=1
                )
                session.send(b"\x1b[5~")
                session.wait_for_region_text("body", "line9")
                session.assert_screen_text(
                    "line9", match="starts_with", region="body"
                )
                session.send(keys.ctrl("x") + keys.ctrl("s"))
                session.wait_for_file(path, initial)
                session.assert_file_bytes(path, initial)

                output, code = session.quit()
                if code != 0:
                    raise AssertionError(
                        f"movement/terminal-navigation-page exited with {code}: {output!r}"
                    )
        except TimeoutError:
            print("movement/terminal-navigation-page body screen on timeout:")
            print(session.region_contents("body"))
            trace_tail = session.trace_bytes.decode(
                "utf-8", errors="replace"
            ).splitlines()[-8:]
            print("movement/terminal-navigation-page trace tail on timeout:")
            print("\n".join(trace_tail))
            raise
