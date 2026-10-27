"""A single undo restores a contiguous self-insert group."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


@scenario("editing/undo-one-group", commands=["undo", "save-buffer"])
def undo_one_group(binary):
    initial = b"a\n"
    with tempfile.TemporaryDirectory(prefix="loom-e2e-undo-") as directory:
        path = os.path.join(directory, "undo.txt")
        with open(path, "wb") as handle:
            handle.write(initial)

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.type("xy")
            session.wait_for_region_exact_text("body", "xya")
            session.wait_for_region_cursor("body", 2)

            trace_count = session.command_trace_count()
            session.send(keys.ctrl("x") + keys.text("u"))
            session.wait_for_command_completion(
                "undo", route="key", after=trace_count
            )
            session.wait_for_region_exact_text("body", "a")
            session.assert_screen_text(
                "a", region="body", strip_right=True
            )
            session.wait_for_region_cursor("body", 0)

            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, initial)
            session.assert_file_bytes(path, initial)

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"editing/undo-one-group exited with {code}: {output!r}"
                )
