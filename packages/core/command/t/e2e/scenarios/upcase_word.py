"""M-u uppercases the following word and advances point."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session

# GNU Emacs Manual, “27.7 Case Conversion Commands”:
# https://www.gnu.org/software/emacs/manual/html_node/emacs/Case.html
@scenario("editing/upcase-word", commands=["upcase-word", "save-buffer"])
def upcase_word(binary):
    initial = b"one two three\n"
    expected = b"ONE two three\n"
    with tempfile.TemporaryDirectory(prefix="loom-e2e-upcase-word-") as directory:
        path = os.path.join(directory, "upcase.txt")
        with open(path, "wb") as handle:
            handle.write(initial)

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.send(keys.meta("u"))
            session.wait_for_region_exact_text("body", "ONE two three")
            session.wait_for_region_cursor("body", 3)

            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, expected)
            session.assert_file_bytes(path, expected)

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"editing/upcase-word exited with {code}: {output!r}"
                )
