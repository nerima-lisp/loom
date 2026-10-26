"""Exercise minibuffer editing and M-p/M-n history through the PTY."""

# GNU Emacs documents M-p/M-n minibuffer history traversal here:
# https://www.gnu.org/software/emacs/manual/html_node/emacs/Minibuffer-History.html
import os
import tempfile
from contextlib import contextmanager

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


@contextmanager
def _working_directory(directory):
    previous_directory = os.getcwd()
    os.chdir(directory)
    try:
        yield
    finally:
        os.chdir(previous_directory)


@scenario("minibuffer/editing-and-meta-history", commands=["find-file"])
def minibuffer_editing_and_meta_history(binary):
    with tempfile.TemporaryDirectory(
        prefix="mh-", dir="/tmp"
    ) as directory:
        start_path = "start.txt"
        older_path = "fileold.txt"
        newer_path = "filenew.txt"
        for name, content in (
            (start_path, b"initial buffer\n"),
            (older_path, b"older buffer\n"),
            (newer_path, b"newer buffer\n"),
        ):
            with open(os.path.join(directory, name), "wb") as handle:
                handle.write(content)

        with _working_directory(directory), Session(binary, [start_path]) as session:
            session.wait_ready()
            for path, content in (
                (older_path, "older buffer"),
                (newer_path, "newer buffer"),
            ):
                session.send(keys.ctrl("x") + keys.ctrl("f"))
                session.wait_for_region_text("minibuffer", "Find file: ")
                session.type(path)
                session.key("RET")
                session.wait_for_region_exact_text("body", content)

            prompt = "Find file: "
            draft_path = "file"
            session.send(keys.ctrl("x") + keys.ctrl("f"))
            session.wait_for_region_text("minibuffer", prompt)
            session.type(draft_path)

            session.send(keys.meta("p"))
            session.wait_for_region_exact_text("minibuffer", prompt + newer_path)
            session.send(keys.meta("p"))
            session.wait_for_region_exact_text("minibuffer", prompt + older_path)
            session.send(keys.meta("n"))
            session.wait_for_region_exact_text("minibuffer", prompt + newer_path)
            session.send(keys.meta("n"))
            session.wait_for_region_exact_text("minibuffer", prompt + draft_path)

            session.send(keys.ctrl("a"))
            session.wait_for_region_cursor("minibuffer", len(prompt))
            session.send(keys.ctrl("f"))
            session.wait_for_region_cursor("minibuffer", len(prompt) + 1)
            session.send(keys.ctrl("b"))
            session.wait_for_region_cursor("minibuffer", len(prompt))
            session.send(keys.ctrl("e"))
            session.wait_for_region_cursor(
                "minibuffer", len(prompt) + len(draft_path)
            )
            session.send(keys.ctrl("b"))
            session.wait_for_region_cursor(
                "minibuffer", len(prompt) + len(draft_path) - 1
            )
            session.send(keys.ctrl("f"))
            session.wait_for_region_cursor(
                "minibuffer", len(prompt) + len(draft_path)
            )

            session.send(b"\x1b\x7f")
            shortened_path = ""
            session.wait_for_region_exact_text(
                "minibuffer", (prompt + shortened_path).rstrip()
            )
            session.send(keys.ctrl("y"))
            session.wait_for_region_exact_text("minibuffer", prompt + draft_path)

            session.send(keys.ctrl("a") + keys.ctrl("f") + keys.ctrl("k"))
            session.wait_for_region_exact_text(
                "minibuffer", prompt + draft_path[:1]
            )
            session.send(keys.ctrl("y"))
            session.wait_for_region_exact_text("minibuffer", prompt + draft_path)

            session.send(keys.ctrl("a") + keys.ctrl("k"))
            session.wait_for_region_exact_text("minibuffer", prompt.rstrip())
            session.type(older_path)
            session.key("RET")
            session.wait_for_region_exact_text("body", "older buffer")
            session.assert_screen_text(
                "older buffer", match="contains", region="body"
            )

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"minibuffer/editing-and-meta-history exited with {code}: "
                    f"{output!r}"
                )
