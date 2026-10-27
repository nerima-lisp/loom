"""Exercise Nix comment-dwim through M-;."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _write(path, content):
    with open(path, "wb") as handle:
        handle.write(content)


def _save(session, path, expected):
    session.send(keys.ctrl("x") + keys.ctrl("s"))
    session.wait_for_file(path, expected)
    session.assert_file_bytes(path, expected)


def _close(session, name):
    output, code = session.quit()
    if session.observe_exit_code(code, 0) is not True:
        raise AssertionError(f"{name}: loom exited with {code}: {output!r}")


@scenario(
    "lang-nix-comment-dwim",
    commands=[
        "comment-line",
        "set-mark-command",
        "save-buffer",
    ],
)
def lang_nix_comment_dwim(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "comment.nix")
        _write(path, b"value\n# disabled\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.key(keys.meta(";"))
            _save(session, path, b"value # \n# disabled\n")

            session.send(keys.ctrl("n") + keys.ctrl("a"))
            session.extended_command("set-mark-command")
            session.send(keys.ctrl("e"))
            session.key(keys.meta(";"))
            _save(session, path, b"value # \ndisabled\n")
            _close(session, "lang-nix-comment-dwim")


@scenario(
    "lang-nix-mode-assignment",
    commands=["find-file"],
)
def lang_nix_mode_assignment(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        initial_path = os.path.join(directory, "before.txt")
        nix_path = os.path.join(directory, "flake.nix")
        _write(initial_path, b"plain text buffer\n")
        _write(nix_path, b"nix file body\n")

        with Session(binary, [initial_path]) as session:
            session.wait_ready()
            session.wait_for_region_text("body", "plain text buffer")

            session.extended_command("find-file")
            session.wait_for_region_text("minibuffer", "Find file: ")
            session.type(nix_path)
            session.key("RET")
            session.wait_for_region_text("body", "nix file body")
            session.wait_for_region_text("mode-line", "Nix")
            session.assert_screen_text(
                "Nix", match="contains", region="mode-line"
            )
            session.assert_file_bytes(nix_path, b"nix file body\n")
            if session.observe_cursor(expected=(0, 0), region="body") is not True:
                raise AssertionError(
                    "lang-nix-mode-assignment: cursor is not at the start of the .nix buffer"
                )
            _close(session, "lang-nix-mode-assignment")
