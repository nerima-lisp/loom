"""Self-check public PTY harness APIs against the real loom executable."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


@scenario(
    "harness resize and typed observations",
    commands=["forward-char", "backward-char", "newline", "save-buffer"],
)
def harness_resize_and_observations(binary):
    initial = b"alpha\nbeta\n"
    with tempfile.TemporaryDirectory(prefix="loom-e2e-harness-") as directory:
        path = os.path.join(directory, "buffer.txt")
        with open(path, "wb") as handle:
            handle.write(initial)

        with Session(binary, [path], columns=80, rows=8) as session:
            session.wait_ready()
            session.wait_for_region_text("mode-line", "Ln 1, Col 1")
            session.assert_file_bytes(path, initial)

            mode_line = session.screen.find("Ln 1, Col 1")
            session.assert_external_state(
                "mode line text found on screen", mode_line is not None, True
            )
            session.assert_cell_attrs(*mode_line, expected={"reverse": True})

            session.resize(columns=80, rows=12)
            session.assert_external_state(
                "pyte dimensions",
                (session.screen.columns, session.screen.rows),
                (80, 12),
                purpose="precondition",
            )
            session.assert_external_state(
                "layout dimensions",
                (session.layout.columns, session.layout.rows),
                (80, 12),
                purpose="precondition",
            )
            session.send(keys.ctrl("f"))
            session.wait_for_region_text("mode-line", "Ln 1, Col 2")
            resized_mode_line = session.screen.find("Ln 1, Col 2")
            session.assert_screen_text(
                "Ln 1, Col 2", match="contains", region="mode-line"
            )
            if (
                resized_mode_line is None
                or resized_mode_line[0] != session.layout.mode_line_row
            ):
                raise AssertionError("mode line did not render at the resized row")
            session.assert_cell_attrs(
                *resized_mode_line, expected={"reverse": True}
            )
            session.send(keys.ctrl("b"))
            session.wait_for_region_text("mode-line", "Ln 1, Col 1")
            session.key("RET")
            session.wait_for_region_cursor("body", 0, index=1)
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, b"\nalpha\nbeta\n")
            output, code = session.quit()
            session.assert_pty_output(output, b"\x1b[", match="contains")
            if code != 0:
                raise AssertionError(f"harness self-test exited with {code}: {output!r}")
