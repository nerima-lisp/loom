"""Exercise file-buffer reuse and names through the PTY interface."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


@scenario(
    "find-file buffer reuse and names",
    commands=["find-file", "save-buffer", "switch-to-buffer", "save-buffers-kill-terminal"],
)
def find_file_buffer_reuse_and_names(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-file-buffers-", dir="/tmp") as directory:
        root = os.path.realpath(directory)
        left_directory = os.path.join(root, "left")
        right_directory = os.path.join(root, "right")
        os.mkdir(left_directory)
        os.mkdir(right_directory)
        left_path = os.path.join(left_directory, "same.txt")
        right_path = os.path.join(right_directory, "same.txt")
        with open(left_path, "wb") as handle:
            handle.write(b"left\n")
        with open(right_path, "wb") as handle:
            handle.write(b"right\n")

        with Session(binary, [left_path]) as session:
            session.wait_ready()
            session.assert_screen_text("left", match="exact", region="body", index=0, strip_right=True)

            session.type("!")
            session.send(keys.ctrl("x") + keys.ctrl("f"))
            session.wait_for_region_text("minibuffer", "Find file: ")
            session.type(left_path)
            session.key("RET")
            session.wait_for_region_exact_text("body", "!left", index=0, strip_right=True)

            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(left_path, b"!left\n")
            session.assert_file_bytes(right_path, b"right\n")

            session.send(keys.ctrl("x") + keys.ctrl("f"))
            session.wait_for_region_text("minibuffer", "Find file: ")
            session.type(right_path)
            session.key("RET")
            session.wait_for_region_exact_text("body", "right", index=0, strip_right=True)

            session.send(keys.ctrl("x") + b"b")
            session.wait_for_region_text("minibuffer", "Switch to buffer: ")
            session.type("same.txt<right>")
            session.key("RET")
            session.wait_for_region_exact_text("body", "right", index=0, strip_right=True)

            session.send(keys.ctrl("x") + b"b")
            session.wait_for_region_text("minibuffer", "Switch to buffer: ")
            session.type("same.txt")
            session.key("RET")
            session.wait_for_region_exact_text("body", "!left", index=0, strip_right=True)

            session.assert_file_bytes(left_path, b"!left\n")
            session.assert_file_bytes(right_path, b"right\n")
            output, code = session.quit()
        if code != 0:
            raise AssertionError(f"find-file buffer reuse and names exited with {code}: {output!r}")
