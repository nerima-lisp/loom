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
