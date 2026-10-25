"""Exercise Lisp indentation through real terminal input."""

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


def _assert_exit_zero(name, output, code):
    if code != 0:
        raise AssertionError(f"{name} exited with {code}: {output!r}")


@scenario(
    "lang-lisp/indent",
    commands=["newline", "indent-for-tab-command", "save-buffer"],
)
def lisp_indent(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        ret_path = os.path.join(directory, "ret.lisp")
        _write(ret_path, b"(when ready")

        with Session(binary, [ret_path]) as session:
            session.wait_ready()
            session.send(keys.ctrl("e") + keys.key("RET"))
            session.wait_for_region_cursor("body", 2, index=1)
            _save(session, ret_path, b"(when ready\n  \n")
            output, code = session.quit()
        _assert_exit_zero("lang-lisp/indent RET", output, code)

        tab_path = os.path.join(directory, "tab.lisp")
        _write(tab_path, b"(consume value\nx\n)\n")

        with Session(binary, [tab_path]) as session:
            session.wait_ready()
            session.send(keys.key("DOWN") + keys.key("TAB"))
            session.wait_for_region_cursor("body", 9, index=1)
            _save(
                session,
                tab_path,
                b"(consume value\n         x\n)\n",
            )
            output, code = session.quit()
        _assert_exit_zero("lang-lisp/indent TAB", output, code)
