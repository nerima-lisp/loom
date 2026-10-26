"""Exercise loading a saved session after replacing the editor process."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _wait_for_exact_line(session, region, expected, index=0, timeout=4.0):
    session.wait_for_region_exact_text(
        region, expected.rstrip(), index=index, strip_right=True, timeout=timeout
    )


def _run_prompted_command(session, command, prompt, value):
    session.send(keys.meta("x") + keys.text(command))
    session.key("RET")
    _wait_for_exact_line(session, "minibuffer", prompt)
    session.type(value)
    session.key("RET")


@scenario(
    "session restart restores saved state",
    commands=[
        "save-session",
        "load-session",
    ],
)
def session_restart_restores_saved_state(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-session-buffers-") as directory:
        first_path = os.path.join(directory, "first.txt")
        alternate_path = os.path.join(directory, "alternate.txt")
        with open(first_path, "wb") as handle:
            handle.write(b"FIRST-BUFFER\nRESTORE-POINT\n")
        with open(alternate_path, "wb") as handle:
            handle.write(b"ALTERNATE-ROOT\n")

        with Session(binary, [first_path]) as session:
            session.wait_ready()
            session.send(keys.ctrl("n"))
            session.wait_for_region_cursor("body", 0, index=1, timeout=4.0)

            session_path = os.path.join(session.home_dir, "session.sexp")
            _run_prompted_command(
                session,
                "save-session",
                "Save session to: ",
                session_path,
            )
            _wait_for_exact_line(
                session, "minibuffer", f"Session saved: {session_path}"
            )
            with open(session_path, "rb") as handle:
                saved_session = handle.read()
            session.assert_external_state(
                "saved session contains the open buffer",
                os.fsencode(first_path) in saved_session,
                True,
            )

            session.arguments = [alternate_path]
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
                "restart retains the saved file",
                os.path.isfile(session_path),
                True,
            )
            _run_prompted_command(
                session,
                "load-session",
                "Load session: ",
                session_path,
            )
            _wait_for_exact_line(session, "body", "RESTORE-POINT", index=1)
            session.assert_screen_text("FIRST-BUFFER", match="contains", region="body")
            session.assert_screen_text(
                "RESTORE-POINT", match="contains", region="body", index=1
            )
            session.wait_for_region_cursor("body", 0, index=1, timeout=4.0)

            output, code = session.quit()
            if session.observe_exit_code(code, 0) is not True:
                raise AssertionError(f"loom exited with {code}: {output!r}")


@scenario(
    "session restart restores command history",
    commands=[
        "execute-extended-command",
        "save-session",
        "load-session",
    ],
)
def session_restart_restores_command_history(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-session-history-") as directory:
        saved_path = os.path.join(directory, "saved.txt")
        with open(saved_path, "wb") as handle:
            handle.write(b"HISTORY-RESTORED\n")

        with Session(binary, [saved_path]) as session:
            session.wait_ready()
            session_path = os.path.join(session.home_dir, "session.sexp")
            _run_prompted_command(
                session,
                "save-session",
                "Save session to: ",
                session_path,
            )
            _wait_for_exact_line(
                session, "minibuffer", f"Session saved: {session_path}"
            )
            session.assert_external_state(
                "saved history session exists",
                os.path.isfile(session_path),
                True,
            )

            session.arguments = []
            session.restart()
            _run_prompted_command(
                session,
                "load-session",
                "Load session: ",
                session_path,
            )

            session.send(keys.meta("x"))
            session.wait_for_region_text("minibuffer", "M-x ", timeout=4.0)
            session.key("UP")
            session.wait_for_region_text("minibuffer", "session.sexp", timeout=4.0)
            session.key("UP")
            session.wait_for_region_text("minibuffer", "save-session", timeout=4.0)
            session.assert_screen_text(
                "save-session", match="contains", region="minibuffer"
            )
            session.send(keys.ctrl("g"))

            output, code = session.quit()
            if session.observe_exit_code(code, 0) is not True:
                raise AssertionError(f"loom exited with {code}: {output!r}")
@scenario(
    "session restart restores split windows",
    commands=[
        "execute-extended-command",
        "split-window-below",
        "save-session",
        "load-session",
    ],
)
def session_restart_restores_split_windows(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-session-split-") as directory:
        upper_path = os.path.join(directory, "upper.txt")
        alternate_path = os.path.join(directory, "alternate.txt")
        with open(upper_path, "wb") as handle:
            handle.write(b"UPPER-BUFFER\n")
        with open(alternate_path, "wb") as handle:
            handle.write(b"ALTERNATE-ROOT\n")

        with Session(binary, [upper_path]) as session:
            session.wait_ready()
            session.extended_command("split-window-below")

            def has_split_windows(screen):
                visible_copies = sum(
                    line.count("UPPER-BUFFER") for line in screen.lines()
                )
                return visible_copies >= 2

            session.wait_until(has_split_windows, what="split windows before save")
            session.assert_external_state(
                "split windows before save",
                has_split_windows(session.screen),
                True,
            )

            session_path = os.path.join(session.home_dir, "session.sexp")
            _run_prompted_command(
                session,
                "save-session",
                "Save session to: ",
                session_path,
            )
            _wait_for_exact_line(
                session, "minibuffer", f"Session saved: {session_path}"
            )
            with open(session_path, "rb") as handle:
                saved_session = handle.read()
            session.assert_external_state(
                "saved split session references its buffer",
                os.fsencode(upper_path) in saved_session,
                True,
            )
            session.arguments = [alternate_path]
            session.restart()
            session.wait_for_text("ALTERNATE-ROOT")

            _run_prompted_command(
                session,
                "load-session",
                "Load session: ",
                session_path,
            )

            def has_restored_split(screen):
                visible_copies = sum(
                    line.count("UPPER-BUFFER") for line in screen.lines()
                )
                return visible_copies >= 2

            session.wait_until(has_restored_split, what="restored split layout")
            session.assert_external_state(
                "restored split layout",
                has_restored_split(session.screen),
                True,
            )
            output, code = session.quit()
            if session.observe_exit_code(code, 0) is not True:
                raise AssertionError(f"loom exited with {code}: {output!r}")


@scenario(
    "session restart restores workspace",
    commands=[
        "execute-extended-command",
        "new-workspace",
        "switch-workspace",
        "find-file",
        "save-session",
        "load-session",
    ],
)
def session_restart_restores_workspace(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-session-workspace-") as directory:
        main_path = os.path.join(directory, "main.txt")
        workspace_path = os.path.join(directory, "workspace.txt")
        alternate_path = os.path.join(directory, "alternate.txt")
        with open(main_path, "wb") as handle:
            handle.write(b"MAIN-WORKSPACE\n")
        with open(workspace_path, "wb") as handle:
            handle.write(b"WORKSPACE-TWO\n")
        with open(alternate_path, "wb") as handle:
            handle.write(b"ALTERNATE-ROOT\n")

        with Session(binary, [main_path]) as session:
            session.wait_ready()
            session.extended_command("new-workspace")
            session.wait_for_region_text("minibuffer", "Workspace: workspace-2")
            session.assert_screen_text(
                "Workspace: workspace-2", match="contains", region="minibuffer"
            )
            _run_prompted_command(
                session,
                "switch-workspace",
                "Switch to workspace: ",
                "workspace-2",
            )
            session.wait_for_region_text("minibuffer", "Workspace: workspace-2")
            session.assert_screen_text(
                "Workspace: workspace-2", match="contains", region="minibuffer"
            )
            _run_prompted_command(
                session,
                "find-file",
                "Find file: ",
                workspace_path,
            )
            _wait_for_exact_line(session, "body", "WORKSPACE-TWO")

            session_path = os.path.join(session.home_dir, "session.sexp")
            _run_prompted_command(
                session,
                "save-session",
                "Save session to: ",
                session_path,
            )
            _wait_for_exact_line(
                session, "minibuffer", f"Session saved: {session_path}"
            )
            with open(session_path, "rb") as handle:
                saved_session = handle.read()
            session.assert_external_state(
                "saved workspace session references its buffer",
                os.fsencode(workspace_path) in saved_session,
                True,
            )
            session.arguments = [alternate_path]
            session.restart()
            session.wait_for_text("ALTERNATE-ROOT")

            _run_prompted_command(
                session,
                "load-session",
                "Load session: ",
                session_path,
            )
            _wait_for_exact_line(session, "body", "WORKSPACE-TWO")
            session.wait_for_text_absent("MAIN-WORKSPACE")
            session.assert_screen_text(
                "WORKSPACE-TWO", match="contains", region="body"
            )
            output, code = session.quit()
            if session.observe_exit_code(code, 0) is not True:
                raise AssertionError(f"loom exited with {code}: {output!r}")
