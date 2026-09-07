"""Window selection, buffer views, and workspace navigation."""

import os
import tempfile

from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _assert_exit_zero(name, output, code):
    if code != 0:
        raise AssertionError(f"{name} exited with {code}: {output!r}")


def _assert_mode_line(session):
    session.wait_until(
        lambda screen: "Ln " in screen.text(session.layout.row("mode-line")),
        what="the mode-line region to render",
    )


def _wait_for_body_text(session, substring, index=0):
    session.wait_for_region_text("body", substring, index=index)


def _wait_for_vertical_buffers(session, left_name, right_name):
    body_row = session.layout.row("body")

    def has_panes(screen):
        left = screen.find(left_name)
        right = screen.find(right_name)
        return (
            left is not None
            and right is not None
            and left[0] == body_row
            and right[0] == body_row
            and left[1] < right[1]
        )

    session.wait_until(has_panes, what="the two vertical buffer panes")


@scenario(
    "window split selection",
    commands=[
        "split-window-below",
        "split-window-right",
        "other-window",
        "delete-window",
        "delete-other-windows",
        "toggle-truncate-lines",
        "switch-to-buffer",
    ],
)
def window_split_selection(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        left_path = os.path.join(directory, "left.txt")
        right_path = os.path.join(directory, "right.txt")
        with open(left_path, "wb") as handle:
            handle.write(("LEFT-WINDOW-" + "x" * 90 + "\n").encode())
        with open(right_path, "wb") as handle:
            handle.write(b"RIGHT-WINDOW\n")

        with Session(binary, [left_path]) as session:
            session.wait_ready()
            _assert_mode_line(session)

            session.extended_command("split-window-below")
            split_row = session.layout.body_height // 2
            _wait_for_body_text(session, "LEFT-WINDOW")
            _wait_for_body_text(session, "LEFT-WINDOW", index=split_row)

            session.extended_command("find-file")
            session.wait_for_region_text("minibuffer", "Find file: ")
            session.type(right_path)
            session.send(b"\n")
            _wait_for_body_text(session, "RIGHT-WINDOW", index=split_row)

            session.extended_command("other-window")
            session.extended_command("switch-to-buffer")
            session.wait_for_region_text("minibuffer", "Switch to buffer: ")
            session.type("right.txt")
            session.send(b"\n")
            _wait_for_body_text(session, "RIGHT-WINDOW")
            _wait_for_body_text(session, "RIGHT-WINDOW", index=split_row)

            session.extended_command("delete-window")
            _wait_for_body_text(session, "RIGHT-WINDOW")
            session.wait_until(
                lambda screen: screen.find("LEFT-WINDOW") is None,
                what="the deleted window to disappear",
            )

            session.extended_command("split-window-right")
            session.extended_command("switch-to-buffer")
            session.wait_for_region_text("minibuffer", "Switch to buffer: ")
            session.type("left.txt")
            session.send(b"\n")
            _wait_for_vertical_buffers(session, "RIGHT-WINDOW", "LEFT-WINDOW")

            session.extended_command("toggle-truncate-lines")
            session.wait_for_region_text("minibuffer", "Truncate long lines")
            _assert_mode_line(session)

            session.extended_command("delete-other-windows")
            _wait_for_body_text(session, "LEFT-WINDOW")
            session.wait_until(
                lambda screen: screen.find("RIGHT-WINDOW") is None,
                what="the deleted sibling windows to disappear",
            )
            _assert_mode_line(session)

            output, code = session.quit()
        _assert_exit_zero("window split selection", output, code)


@scenario(
    "workspace switching",
    commands=[
        "new-workspace",
        "switch-workspace",
        "next-workspace",
        "previous-workspace",
        "kill-workspace",
        "switch-to-buffer",
    ],
)
def workspace_switching(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        main_path = os.path.join(directory, "main.txt")
        other_path = os.path.join(directory, "other.txt")
        with open(main_path, "wb") as handle:
            handle.write(b"MAIN-WORKSPACE\n")
        with open(other_path, "wb") as handle:
            handle.write(b"OTHER-WORKSPACE\n")

        with Session(binary, [main_path]) as session:
            session.wait_ready()
            _assert_mode_line(session)

            session.extended_command("find-file")
            session.wait_for_region_text("minibuffer", "Find file: ")
            session.type(other_path)
            session.send(b"\n")
            _wait_for_body_text(session, "OTHER-WORKSPACE")
            session.extended_command("switch-to-buffer")
            session.wait_for_region_text("minibuffer", "Switch to buffer: ")
            session.type("main.txt")
            session.send(b"\n")
            _wait_for_body_text(session, "MAIN-WORKSPACE")

            session.extended_command("new-workspace")
            _assert_mode_line(session)
            _wait_for_body_text(session, "MAIN-WORKSPACE")

            session.extended_command("switch-to-buffer")
            session.wait_for_region_text("minibuffer", "Switch to buffer: ")
            session.type("other.txt")
            session.send(b"\n")
            _wait_for_body_text(session, "OTHER-WORKSPACE")
            _assert_mode_line(session)

            session.extended_command("previous-workspace")
            _wait_for_body_text(session, "MAIN-WORKSPACE")
            _assert_mode_line(session)

            session.extended_command("next-workspace")
            _wait_for_body_text(session, "OTHER-WORKSPACE")
            _assert_mode_line(session)

            session.extended_command("switch-workspace")
            session.wait_for_region_text("minibuffer", "Switch to workspace: ")
            session.type("main")
            session.send(b"\n")
            _wait_for_body_text(session, "MAIN-WORKSPACE")
            _assert_mode_line(session)

            session.extended_command("switch-workspace")
            session.wait_for_region_text("minibuffer", "Switch to workspace: ")
            session.type("workspace-2")
            session.send(b"\n")
            _wait_for_body_text(session, "OTHER-WORKSPACE")
            _assert_mode_line(session)

            session.extended_command("kill-workspace")
            _wait_for_body_text(session, "MAIN-WORKSPACE")
            _assert_mode_line(session)
            session.wait_for_region_text(
                "minibuffer", "Deleted workspace: workspace-2"
            )

            output, code = session.quit()
        _assert_exit_zero("workspace switching", output, code)
