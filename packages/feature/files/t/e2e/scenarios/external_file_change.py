"""Protect external file updates during saves and buffer switches."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


_SOURCE = b"alpha\nbeta\n"
_EXTERNAL = b"external\nreplacement\n"


def _write(path, content):
    with open(path, "wb") as handle:
        handle.write(content)


@scenario(
    "files/external-file-change-revert",
    commands=["save-buffer", "revert-buffer"],
)
def external_file_change_revert(binary):
    with tempfile.TemporaryDirectory(prefix="loom-files-external-") as directory:
        path = os.path.join(directory, "external.txt")
        _write(path, _SOURCE)

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.type("!")
            session.wait_for_region_text("body", "!alpha", index=0)
            _write(path, _EXTERNAL)

            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_region_text("minibuffer", "Overwrite? (y/n): ")
            session.assert_file_bytes(path, _EXTERNAL)
            session.type("n")
            session.key("RET")
            session.wait_for_region_text("minibuffer", "Save cancelled")

            session.extended_command("revert-buffer")
            session.wait_for_region_text(
                "minibuffer", "Discard local changes and revert "
            )
            session.type("y")
            session.key("RET")
            session.wait_for_region_text("minibuffer", "Reverted ")
            session.wait_for_region_exact_text("body", "external", index=0)
            session.wait_for_region_exact_text(
                "body", "replacement", index=1
            )
            session.assert_file_bytes(path, _EXTERNAL)
            output, code = session.quit()
        if code != 0:
            raise AssertionError(
                f"external-file-change-revert exited with {code}: {output!r}"
            )


@scenario(
    "files/external-file-change-buffer-switch",
    commands=["find-file", "switch-to-buffer"],
)
def external_file_change_buffer_switch(binary):
    with tempfile.TemporaryDirectory(prefix="loom-files-switch-") as directory:
        path = os.path.join(directory, "switch.txt")
        alternate_path = os.path.join(directory, "alternate.txt")
        _write(path, b"before\n")
        _write(alternate_path, b"alternate\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.wait_for_region_exact_text("body", "before", index=0)
            session.extended_command("find-file")
            session.wait_for_region_text("minibuffer", "Find file: ")
            session.type(alternate_path)
            session.key("RET")
            session.wait_for_region_exact_text("body", "alternate", index=0)

            _write(path, b"after\n")
            session.send(keys.ctrl("x") + b"b")
            session.wait_for_region_text("minibuffer", "Switch to buffer: ")
            session.type(os.path.basename(path))
            session.key("RET")
            session.wait_for_region_text("minibuffer", "[r]eload (discard local edits)")
            session.assert_file_bytes(path, b"after\n")
            session.type("r")
            session.key("RET")
            session.wait_for_region_exact_text("body", "after", index=0)
            session.assert_file_bytes(path, b"after\n")
            output, code = session.quit()
        if code != 0:
            raise AssertionError(
                f"external-file-change-buffer-switch exited with {code}: {output!r}"
            )
