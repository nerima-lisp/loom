"""Confirm creation of missing parent directories before saving files."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


_CREATED = b"created"


def _assert_parent_prompt(session, parent, path):
    session.wait_for_region_text(
        "minibuffer", "Parent directory does not exist. Create it? (y/n):"
    )
    session.assert_external_state(
        "parent directory before confirmation", os.path.isdir(parent), False
    )
    session.assert_file_bytes(path, None)


def _switch_to_buffer(session, name):
    session.extended_command("switch-to-buffer")
    session.wait_for_region_text("minibuffer", "Switch to buffer: ")
    session.type(name)
    session.key("RET")


@scenario(
    "files/missing-parent-startup-save-confirmation",
    commands=["save-buffer", "switch-to-buffer"],
)
def missing_parent_startup_save_confirmation(binary):
    with tempfile.TemporaryDirectory(prefix="loom-missing-parent-") as directory:
        created_path = os.path.join(directory, "create", "deep", "created.txt")
        declined_path = os.path.join(directory, "decline", "deep", "declined.txt")
        cancelled_path = os.path.join(directory, "cancel", "deep", "cancelled.txt")

        with Session(binary, [created_path, declined_path, cancelled_path]) as session:
            session.wait_ready()
            session.wait_for_region_exact_text("body", "", index=0)
            session.type("created")
            session.wait_for_region_exact_text("body", "created", index=0)
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            _assert_parent_prompt(
                session, os.path.dirname(created_path), created_path
            )
            session.type("y")
            session.key("RET")
            session.wait_for_file(created_path, _CREATED)
            session.assert_file_bytes(created_path, _CREATED)
            session.assert_external_state(
                "parent directory after confirmation",
                os.path.isdir(os.path.dirname(created_path)),
                True,
            )

            _switch_to_buffer(session, "declined.txt")
            session.wait_for_region_exact_text("body", "", index=0)
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            _assert_parent_prompt(
                session, os.path.dirname(declined_path), declined_path
            )
            session.type("n")
            session.key("RET")
            session.wait_for_region_text("minibuffer", "Save cancelled")
            session.assert_external_state(
                "parent directory after negative answer",
                os.path.isdir(os.path.dirname(declined_path)),
                False,
            )
            session.assert_file_bytes(declined_path, None)

            _switch_to_buffer(session, "cancelled.txt")
            session.wait_for_region_exact_text("body", "", index=0)
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            _assert_parent_prompt(
                session, os.path.dirname(cancelled_path), cancelled_path
            )
            session.send(keys.ctrl("g"))
            session.wait_for_region_text("minibuffer", "Quit")
            session.assert_external_state(
                "parent directory after cancellation",
                os.path.isdir(os.path.dirname(cancelled_path)),
                False,
            )
            session.assert_file_bytes(cancelled_path, None)

            output, code = session.quit()
    if code != 0:
        raise AssertionError(
            f"missing-parent startup save exited with {code}: {output!r}"
        )


@scenario("files/write-file-missing-parent-confirmation", commands=["write-file"])
def write_file_missing_parent_confirmation(binary):
    with tempfile.TemporaryDirectory(prefix="loom-write-file-missing-parent-") as directory:
        source = os.path.join(directory, "source.txt")
        target = os.path.join(directory, "nested", "deep", "new.txt")
        with open(source, "wb") as handle:
            handle.write(_CREATED)

        with Session(binary, [source]) as session:
            session.wait_ready()
            session.wait_for_region_exact_text("body", "created", index=0)
            session.extended_command("write-file")
            session.wait_for_region_text("minibuffer", "Write file: ")
            session.type(target)
            session.key("RET")
            _assert_parent_prompt(session, os.path.dirname(target), target)
            session.type("y")
            session.key("RET")
            session.wait_for_file(target, _CREATED)
            session.assert_file_bytes(target, _CREATED)
            session.assert_external_state(
                "write-file parent directory after confirmation",
                os.path.isdir(os.path.dirname(target)),
                True,
            )
            output, code = session.quit()
    if code != 0:
        raise AssertionError(
            f"write-file missing-parent save exited with {code}: {output!r}"
        )
