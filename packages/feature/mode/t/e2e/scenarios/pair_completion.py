"""Exercise pair completion through the interactive major-mode command."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


@scenario(
    "mode/pair-completion",
    commands=["set-major-mode", "save-buffer"],
)
def pair_completion(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-pair-completion-") as directory:
        path = os.path.join(directory, "buffer.txt")
        with open(path, "wb") as handle:
            handle.write(b"")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("set-major-mode")
            session.wait_for_region_text("minibuffer", "Major mode: ")
            session.type("Common Lisp")
            session.key("RET")
            session.wait_for_region_text("minibuffer", "Mode: Common Lisp")
            session.assert_screen_text(
                "Mode: Common Lisp", match="contains", region="minibuffer"
            )

            session.type("(")
            session.wait_for_region_exact_text("body", "()")
            session.wait_for_region_cursor("body", 1)

            session.type(")")
            session.wait_for_region_exact_text("body", "()")
            session.wait_for_region_cursor("body", 2)

            session.send(keys.ctrl("x") + keys.ctrl("s"))
            expected = b"()"
            session.wait_for_file(path, expected)
            session.assert_file_bytes(path, expected)

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"mode/pair-completion exited with {code}: {output!r}"
                )
