"""Exercise loading a saved session after replacing the editor process."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _wait_for_exact_line(session, region, expected, index=0):
    session.wait_for_region_exact_text(
        region, expected.rstrip(), index=index, strip_right=True
    )


def _run_prompted_command(session, command, prompt, value):
    session.extended_command(command)
    _wait_for_exact_line(session, "minibuffer", prompt)
    session.type(value)
    session.key("RET")


@scenario(
    "session restart restores saved state",
    commands=[
        "find-file",
        "set-bookmark",
        "save-session",
        "load-session",
        "jump-to-bookmark",
        "switch-to-buffer",
    ],
)
def session_restart_restores_saved_state(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        buffer_path = os.path.join(directory, "restart.txt")
        session_only_path = os.path.join(directory, "session-only.txt")
        with open(buffer_path, "wb") as handle:
            handle.write(b"before\nrestored\n")
        with open(session_only_path, "wb") as handle:
            handle.write(b"session-only-buffer\n")

        with Session(binary, [buffer_path]) as session:
            session.wait_ready()
            session.send(keys.ctrl("n") + keys.ctrl("f") * 2)
            session.wait_for_region_cursor("body", 2, index=1)
            _run_prompted_command(
                session,
                "set-bookmark",
                "Set bookmark: ",
                "restart-spot",
            )
            session.wait_for_text("Bookmark set: restart-spot")

            _run_prompted_command(
                session,
                "find-file",
                "Find file: ",
                session_only_path,
            )
            _wait_for_exact_line(session, "body", "session-only-buffer")

            session_path = os.path.join(session.home_dir, "session.sexp")
            _run_prompted_command(
                session,
                "save-session",
                "Save session to: ",
                session_path,
            )
            session.wait_for_text("Session saved:")
            session.wait_for_external_state(
                "saved session exists",
                lambda: os.path.isfile(session_path),
                True,
            )
            saved_session = session.observe_file_bytes(session_path)
            session.assert_external_state(
                "saved session contains its bookmark",
                b"restart-spot" in saved_session,
                True,
            )

            previous_process = session.process
            session.restart()
            session.assert_external_state(
                "restart replaces the child process",
                session.process is not previous_process,
                True,
            )
            session.assert_external_state(
                "restart reaps the previous process",
                previous_process.has_exited(),
                True,
            )
            session.assert_external_state(
                "restart retains the saved file in scratch HOME",
                os.path.isfile(session_path),
                True,
            )
            session.wait_ready()

            _run_prompted_command(
                session,
                "load-session",
                "Load session: ",
                session_path,
            )
            session.wait_for_text("Session loaded:")

            _run_prompted_command(
                session,
                "switch-to-buffer",
                "Switch to buffer: ",
                "session-only.txt",
            )
            session.wait_until(
                lambda screen: (
                    "session-only-buffer"
                    in screen.text(session.layout.row("body"))
                    or "No such buffer: session-only.txt"
                    in screen.text(session.layout.row("minibuffer"))
                ),
                what="saved-only buffer switch result",
            )
            if session.region_text("body").rstrip() != "session-only-buffer":
                raise AssertionError(
                    "saved-only buffer was not restored: "
                    f"{session.region_text('minibuffer')!r}"
                )

            _run_prompted_command(
                session,
                "switch-to-buffer",
                "Switch to buffer: ",
                "restart.txt",
            )
            _wait_for_exact_line(session, "body", "before", index=0)
            _wait_for_exact_line(session, "body", "restored", index=1)
            session.wait_for_region_cursor("body", 2, index=1)

            session.send(keys.ctrl("p"))
            _wait_for_exact_line(session, "body", "before", index=0)
            session.wait_for_region_cursor("body", 2, index=0)

            _run_prompted_command(
                session,
                "jump-to-bookmark",
                "Jump to bookmark: ",
                "restart-spot",
            )
            session.wait_for_region_cursor("body", 2, index=1)
            _wait_for_exact_line(session, "body", "restored", index=1)

            output, code = session.quit()
            if session.observe_exit_code(code, 0) is not True:
                raise AssertionError(
                    f"loom exited with {code}: {output!r}"
                )
