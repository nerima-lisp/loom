"""C-l recenters the selected window without editing the buffer."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session

# GNU Emacs Manual, “16.2 Recentering”:
# https://www.gnu.org/software/emacs/manual/html_node/emacs/Recentering.html
@scenario(
    "movement/recenter-top-bottom",
    commands=["next-line", "recenter-top-bottom", "save-buffer"],
)
def recenter_top_bottom(binary):
    lines = [f"line{index}" for index in range(15)]
    initial = ("\n".join(lines) + "\n").encode("ascii")
    with tempfile.TemporaryDirectory(prefix="loom-e2e-recenter-") as directory:
        path = os.path.join(directory, "recenter.txt")
        with open(path, "wb") as handle:
            handle.write(initial)

        with Session(binary, [path], rows=9) as session:
            session.wait_ready()
            session.send(keys.ctrl("n") * 7)
            session.wait_for_region_exact_text("body", "line7", index=6)
            session.wait_for_region_cursor("body", 0, index=6)

            session.send(keys.ctrl("l"))
            session.wait_for_region_exact_text("body", "line7", index=3)
            session.wait_for_region_cursor("body", 0, index=3)

            session.send(keys.ctrl("l"))
            session.wait_for_region_exact_text("body", "line7", index=0)
            session.wait_for_region_cursor("body", 0, index=0)

            session.send(keys.ctrl("l"))
            session.wait_for_region_exact_text("body", "line7", index=6)
            session.wait_for_region_cursor("body", 0, index=6)

            session.send(keys.ctrl("l"))
            session.wait_for_region_exact_text("body", "line7", index=3)
            session.wait_for_region_cursor("body", 0, index=3)

            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, initial)
            session.assert_file_bytes(path, initial)

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"movement/recenter-top-bottom exited with {code}: {output!r}"
                )
