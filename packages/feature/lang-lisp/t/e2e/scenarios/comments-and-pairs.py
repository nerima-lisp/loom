"""Exercise Lisp comments and parenthesis completion through a PTY."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _comment_lisp_region(binary, mode, extension):
    initial = b"hello\nworld\n"
    commented = b"; hello\n; world\n"

    with tempfile.TemporaryDirectory(prefix="loom-e2e-lang-lisp-") as directory:
        path = os.path.join(directory, "comments." + extension)
        with open(path, "wb") as handle:
            handle.write(initial)

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.wait_for_region_exact_text("body", "hello", timeout=2.0)
            session.wait_for_region_exact_text(
                "body", "world", index=1, timeout=2.0
            )
            session.wait_for_region_cursor("body", 0, timeout=2.0)
            session.send(
                keys.ctrl("a")
                + b"\x00"
                + keys.ctrl("n")
                + keys.ctrl("e")
                + keys.meta(";")
            )
            session.wait_for_region_exact_text("body", "; hello", timeout=2.0)
            session.wait_for_region_exact_text(
                "body", "; world", index=1, timeout=2.0
            )
            session.assert_screen_text(
                "; hello", region="body", index=0, strip_right=True
            )
            session.assert_screen_text(
                "; world", region="body", index=1, strip_right=True
            )
            session.wait_for_region_cursor("body", 7, index=1, timeout=2.0)
            if session.observe_cursor(
                expected=(1, 7), region="body", index=1
            ) is not True:
                raise AssertionError(f"{mode}: point after M-; was not (1, 7)")

            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, commented, timeout=2.0)
            session.assert_file_bytes(path, commented)
            output, code = session.quit()

        if code != 0:
            raise AssertionError(
                f"lang-lisp/comment-dwim ({mode}) exited with {code}: {output!r}"
            )


def _skip_lisp_closer(binary, mode, extension):
    initial = b"tail\n"
    completed = b"(x)tail\n"

    with tempfile.TemporaryDirectory(prefix="loom-e2e-lang-lisp-") as directory:
        path = os.path.join(directory, "pairs." + extension)
        with open(path, "wb") as handle:
            handle.write(initial)

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.wait_for_region_exact_text("body", "tail")
            session.wait_for_region_cursor("body", 0)
            session.send(b"(")
            session.wait_for_region_exact_text("body", "()tail")
            session.wait_for_region_cursor("body", 1)
            session.send(b"x")
            session.wait_for_region_exact_text("body", "(x)tail")
            session.wait_for_region_cursor("body", 2)
            session.send(b")")
            session.wait_for_region_exact_text("body", "(x)tail")
            session.wait_for_region_cursor("body", 3)
            if session.observe_cursor(expected=(0, 3), region="body") is not True:
                raise AssertionError(f"{mode}: point after skipped closer was not (0, 3)")

            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, completed)
            session.assert_file_bytes(path, completed)
            output, code = session.quit()

        if code != 0:
            raise AssertionError(
                f"lang-lisp/pair-skip ({mode}) exited with {code}: {output!r}"
            )


@scenario(
    "lang-lisp/comment-dwim-cl",
    commands=[
        "comment-line",
        "move-beginning-of-line",
        "move-end-of-line",
        "next-line",
        "save-buffer",
        "set-mark-command",
    ],
)
def common_lisp_comment_dwim(binary):
    _comment_lisp_region(binary, "Common Lisp", "lisp")


@scenario(
    "lang-lisp/comment-dwim-el",
    commands=[
        "comment-line",
        "move-beginning-of-line",
        "move-end-of-line",
        "next-line",
        "save-buffer",
        "set-mark-command",
    ],
)
def emacs_lisp_comment_dwim(binary):
    _comment_lisp_region(binary, "Emacs Lisp", "el")


@scenario(
    "lang-lisp/pair-skip-cl",
    commands=["save-buffer"],
)
def common_lisp_pair_skip(binary):
    _skip_lisp_closer(binary, "Common Lisp", "lisp")


@scenario(
    "lang-lisp/pair-skip-el",
    commands=["save-buffer"],
)
def emacs_lisp_pair_skip(binary):
    _skip_lisp_closer(binary, "Emacs Lisp", "el")
