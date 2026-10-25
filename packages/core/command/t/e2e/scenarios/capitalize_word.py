"""M-c capitalizes the following word and advances point."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session

# GNU Emacs Manual, “27.7 Case Conversion Commands”:
# https://www.gnu.org/software/emacs/manual/html_node/emacs/Case.html
@scenario("editing/capitalize-word", commands=["capitalize-word", "save-buffer"])
def capitalize_word(binary):
    initial = b"ONE two three\n"
    expected = b"One two three\n"
    with tempfile.TemporaryDirectory(prefix="loom-e2e-capitalize-word-") as directory:
        path = os.path.join(directory, "capitalize.txt")
        with open(path, "wb") as handle:
            handle.write(initial)

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.send(keys.meta("c"))
            session.wait_for_region_exact_text("body", "One two three")
            session.wait_for_region_cursor("body", 3)

            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, expected)
            session.assert_file_bytes(path, expected)

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"editing/capitalize-word exited with {code}: {output!r}"
                )
