"""M-^ joins the current line to the previous line."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _assert_cursor(session, expected, index=0):
    if session.observe_cursor(
        expected=expected, region="body", index=index
    ) is not True:
        raise AssertionError(
            f"cursor at body row {index} did not match {expected!r}"
        )


# GNU Emacs Manual, “Indentation Commands”:
# https://www.gnu.org/software/emacs/manual/html_node/emacs/Indentation-Commands.html
@scenario(
    "editing/delete-indentation",
    commands=["execute-extended-command", "delete-indentation", "next-line", "save-buffer"],
)
def delete_indentation(binary):
    initial = b"alpha\n  beta\n    gamma\n"
    expected = b"alpha beta gamma\n"
    with tempfile.TemporaryDirectory(prefix="loom-e2e-delete-indentation-") as directory:
        path = os.path.join(directory, "join.txt")
        with open(path, "wb") as handle:
            handle.write(initial)

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.send(keys.ctrl("n"))
            session.extended_command("delete-indentation")
            session.wait_for_region_exact_text(
                "body", "alpha beta", index=0, strip_right=True
            )
            session.assert_screen_text(
                "alpha beta", region="body", index=0, strip_right=True
            )
            _assert_cursor(session, (0, 5))

            session.send(keys.ctrl("n"))
            session.wait_for_region_cursor("body", 5, index=1)
            session.send(keys.meta("^"))
            session.wait_for_region_exact_text(
                "body", "alpha beta gamma", index=0, strip_right=True
            )
            session.assert_screen_text(
                "alpha beta gamma", region="body", index=0, strip_right=True
            )
            _assert_cursor(session, (0, 10))

            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, expected)
            session.assert_file_bytes(path, expected)

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"editing/delete-indentation exited with {code}: {output!r}"
                )
