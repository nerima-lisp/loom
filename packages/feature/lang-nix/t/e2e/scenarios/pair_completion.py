"""Exercise Nix delimiter pair completion through PTY input."""

import os
import tempfile

from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _write(path, content):
    with open(path, "wb") as handle:
        handle.write(content)


def _save(session, path, expected):
    session.send(b"\x18\x13")
    session.wait_for_file(path, expected)
    session.assert_file_bytes(path, expected)


def _close(session, name):
    output, code = session.quit()
    if session.observe_exit_code(code, 0) is not True:
        raise AssertionError(f"{name}: loom exited with {code}: {output!r}")


@scenario("lang-nix-pair-completion", commands=["save-buffer"])
def lang_nix_pair_completion(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "pairs.nix")
        _write(path, b"")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.send(b"{[(")
            expected = b"{[()]}"
            _save(session, path, expected)

            session.send(b")]}")
            _save(session, path, expected)
            _close(session, "lang-nix-pair-completion")
