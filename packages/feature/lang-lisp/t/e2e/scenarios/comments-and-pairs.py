"""Exercise Lisp comments and parenthesis completion through a PTY."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


@scenario(
    "lang-lisp/comment-pair-completion",
    commands=[
        "comment-line",
        "keyboard-quit",
        "move-beginning-of-line",
        "move-end-of-line",
        "next-line",
        "save-buffer",
        "set-mark-command",
    ],
)
def lisp_comment_and_pair_completion(binary):
    for mode, extension in (("Common Lisp", "lisp"), ("Emacs Lisp", "el")):
        initial = b"hello\nworld\n"
        commented = b"; hello\n; world\n"
        completed = b"; hello\n; world\n(x)\n"

        with tempfile.TemporaryDirectory(prefix="loom-e2e-lang-lisp-") as directory:
            path = os.path.join(directory, "comments." + extension)
            with open(path, "wb") as handle:
                handle.write(initial)

            with Session(binary, [path]) as session:
                session.wait_ready()
                session.wait_for_region_exact_text("body", "hello\nworld")
                session.wait_for_region_cursor("body", 0)

                session.send(
                    keys.ctrl("a")
                    + b"\x00"
                    + keys.ctrl("n")
                    + keys.ctrl("e")
                    + keys.meta(";")
                )
                session.wait_for_region_exact_text("body", "; hello\n; world")
                session.wait_for_region_cursor("body", 7, index=1)
                if session.observe_cursor(
                    expected=(1, 7), region="body", index=1
                ) is not True:
                    raise AssertionError(f"{mode}: point after M-; was not (1, 7)")

                session.send(keys.ctrl("x") + keys.ctrl("s"))
                session.wait_for_file(path, commented)
                session.assert_file_bytes(path, commented)

                session.send(keys.ctrl("g"))
                session.send(keys.ctrl("n"))
                session.wait_for_region_cursor("body", 0, index=2)
                session.send(b"(")
                session.wait_for_region_exact_text("body", "; hello\n; world\n()")
                session.wait_for_region_cursor("body", 1, index=2)
                if session.observe_cursor(
                    expected=(2, 1), region="body", index=2
                ) is not True:
                    raise AssertionError(f"{mode}: point after paired opener was not (2, 1)")

                session.send(b"x")
                session.wait_for_region_exact_text("body", "; hello\n; world\n(x)")
                session.wait_for_region_cursor("body", 2, index=2)
                session.send(b")")
                session.wait_for_region_exact_text("body", "; hello\n; world\n(x)")
                session.wait_for_region_cursor("body", 3, index=2)
                if session.observe_cursor(
                    expected=(2, 3), region="body", index=2
                ) is not True:
                    raise AssertionError(f"{mode}: point after skipped closer was not (2, 3)")

                session.send(keys.ctrl("x") + keys.ctrl("s"))
                session.wait_for_file(path, completed)
                session.assert_file_bytes(path, completed)
                output, code = session.quit()

            if code != 0:
                raise AssertionError(
                    f"lang-lisp/comment-pair-completion ({mode}) exited "
                    f"with {code}: {output!r}"
                )
