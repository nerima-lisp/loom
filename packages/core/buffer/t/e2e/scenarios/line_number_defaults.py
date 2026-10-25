"""Check which major modes enable the line-number gutter by default."""

import os
import re
import tempfile

from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _assert_body_text_and_cursor(session, mode):
    session.wait_for_region_text("body", "alpha", index=0)
    session.wait_for_region_text("body", "beta", index=1)
    session.wait_for_region_cursor("body", 0, index=0)
    if session.observe_cursor(
        expected=(0, 0),
        sample=f"{mode} body cursor",
        region="body",
    ) is not True:
        raise AssertionError(
            f"{mode} body cursor was {session.region_cursor('body')!r}, expected (0, 0)"
        )


def _set_major_mode(session, mode):
    session.extended_command("set-major-mode")
    session.wait_for_region_text("minibuffer", "Major mode: ")
    session.type(mode)
    session.key("RET")
    session.wait_for_region_text("minibuffer", f"Mode: {mode}")


def _assert_line_number(session, index, expected):
    body_x = session.layout.body_x
    row = session.layout.row("body", index)
    gutter = session.screen.text(row)[:body_x]
    number_tokens = re.findall(r"\d+", gutter)
    if not number_tokens or number_tokens[-1] != str(expected):
        raise AssertionError(
            f"line-number gutter at body row {index} was {gutter!r}, "
            f"expected line number {expected}"
        )


@scenario(
    "fr-d02/default-line-numbers",
    commands=["execute-extended-command", "set-major-mode"],
)
def fr_d02_default_line_numbers(binary):
    with tempfile.TemporaryDirectory(prefix="loom-fr-d02-") as directory:
        path = os.path.join(directory, "notes.py")
        with open(path, "w", encoding="utf-8") as handle:
            handle.write("alpha\nbeta\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            _assert_body_text_and_cursor(session, "Python")
            session.wait_for_region_text("mode-line", "Python")

            body_x = session.layout.body_x
            if body_x <= 0:
                raise AssertionError(
                    f"Python mode did not create a line-number gutter: body_x={body_x}"
                )
            _assert_line_number(session, 0, 1)
            _assert_line_number(session, 1, 2)

            for mode in ("Markdown", "Org", "Text", "Fundamental"):
                _set_major_mode(session, mode)
                _assert_body_text_and_cursor(session, mode)
                if session.layout.body_x != 0:
                    raise AssertionError(
                        f"{mode} mode should start the body at the screen origin; "
                        f"body_x={session.layout.body_x}"
                    )
