"""C-t transposes the characters around point."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session

# GNU Emacs Manual, “18.2 Transposing Text”:
# https://www.gnu.org/software/emacs/manual/html_node/emacs/Transpose.html
@scenario(
    "editing/transpose-chars",
    commands=["forward-char", "transpose-chars", "save-buffer"],
)
def transpose_chars(binary):
    initial = b"abcd\n"
    expected = b"bacd\n"
    with tempfile.TemporaryDirectory(prefix="loom-e2e-transpose-") as directory:
        path = os.path.join(directory, "transpose.txt")
        with open(path, "wb") as handle:
            handle.write(initial)

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.send(keys.ctrl("f"))
            session.wait_for_region_cursor("body", 1)

            session.send(keys.ctrl("t"))
            session.wait_for_region_exact_text("body", "bacd")
            session.wait_for_region_cursor("body", 2)

            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, expected)
            session.assert_file_bytes(path, expected)

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"editing/transpose-chars exited with {code}: {output!r}"
                )
