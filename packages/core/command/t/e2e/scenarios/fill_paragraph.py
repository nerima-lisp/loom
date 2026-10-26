"""M-q fills the paragraph containing point to the fill column."""

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


# GNU Emacs Manual, “27.6.2 Explicit Fill Commands”, “Fill Commands”:
# https://www.gnu.org/software/emacs/manual/html_node/emacs/Fill-Commands.html
@scenario(
    "editing/fill-paragraph",
    commands=["execute-extended-command", "fill-paragraph", "next-line", "save-buffer"],
)
def fill_paragraph(binary):
    initial = (
        b"The quick brown fox jumps over the lazy dog while the editor fills "
        b"this plain paragraph.\n\n"
        b"A second paragraph contains enough ordinary words to wrap cleanly "
        b"when the default fill column is applied.\n"
    )
    expected = (
        b"The quick brown fox jumps over the lazy dog while the editor fills\n"
        b"this plain paragraph.\n\n"
        b"A second paragraph contains enough ordinary words to wrap cleanly when\n"
        b"the default fill column is applied.\n"
    )
    with tempfile.TemporaryDirectory(prefix="loom-e2e-fill-paragraph-") as directory:
        path = os.path.join(directory, "fill.txt")
        with open(path, "wb") as handle:
            handle.write(initial)

        with Session(binary, [path], columns=100) as session:
            session.wait_ready()
            session.extended_command("fill-paragraph")
            session.wait_for_region_exact_text(
                "body",
                "The quick brown fox jumps over the lazy dog while the editor fills",
                index=0,
                strip_right=True,
            )
            session.assert_screen_text(
                "The quick brown fox jumps over the lazy dog while the editor fills",
                region="body",
                index=0,
                strip_right=True,
            )
            _assert_cursor(session, (0, 0))

            session.send(keys.ctrl("n") * 3)
            session.wait_for_region_cursor("body", 0, index=3)
            session.send(keys.meta("q"))
            session.wait_for_region_exact_text(
                "body",
                "A second paragraph contains enough ordinary words to wrap cleanly when",
                index=3,
                strip_right=True,
            )
            session.assert_screen_text(
                "A second paragraph contains enough ordinary words to wrap cleanly when",
                region="body",
                index=3,
                strip_right=True,
            )
            _assert_cursor(session, (3, 0), index=3)

            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, expected)
            session.assert_file_bytes(path, expected)

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"editing/fill-paragraph exited with {code}: {output!r}"
                )
