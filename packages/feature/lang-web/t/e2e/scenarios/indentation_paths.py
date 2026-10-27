"""Exercise newline and region indentation in web language modes."""

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


def _finish(session, name):
    output, code = session.quit()
    if code != 0:
        raise AssertionError(f"{name} exited with {code}: {output!r}")


@scenario(
    "lang-web/indentation-ret",
    commands=["newline", "save-buffer"],
)
def indentation_ret(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-web-indent-ret-") as directory:
        path = os.path.join(directory, "source.ts")
        _write(path, b"function run() {\nvalue\n}\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.wait_for_region_text("mode-line", "TypeScript")
            session.send(keys.ctrl("e"))
            session.key("RET")
            session.wait_for_region_cursor("body", 2, index=1)
            session.assert_screen_text(
                "  ", match="starts_with", region="body", index=1
            )
            expected = b"function run() {\n  \nvalue\n}\n"
            _save(session, path, expected)
            if session.observe_cursor(expected=(1, 2), region="body") is not True:
                raise AssertionError("lang-web/indentation-ret: cursor moved unexpectedly")
            _finish(session, "lang-web/indentation-ret")


@scenario(
    "lang-web/indentation-region",
    commands=["set-mark-command", "indent-for-tab-command", "save-buffer"],
)
def indentation_region(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-web-indent-region-") as directory:
        path = os.path.join(directory, "source.ts")
        _write(path, b"function run() {\nvalue\nnext\n}\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.wait_for_region_text("mode-line", "TypeScript")
            session.send(keys.ctrl("n"))
            session.extended_command("set-mark-command")
            session.send(keys.ctrl("n") + keys.ctrl("e"))
            session.send(b"\x1b" + keys.ctrl("\\"))
            expected = b"function run() {\n  value\n  next\n}\n"
            _save(session, path, expected)
            session.assert_screen_text(
                "  value", match="starts_with", region="body", index=1
            )
            if session.observe_cursor(expected=(2, 6), region="body") is not True:
                raise AssertionError("lang-web/indentation-region: cursor moved unexpectedly")
            _finish(session, "lang-web/indentation-region")
