"""Check previous-line indentation for HTML, CSS, and YAML."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


CASES = (
    (
        "page.html",
        "HTML",
        b"  html-marker\n        child-html\n",
        b"  html-marker\n  child-html\n",
        2,
    ),
    (
        "site.css",
        "CSS",
        b"    css-marker\n  child-css\n",
        b"    css-marker\n    child-css\n",
        4,
    ),
    (
        "config.yaml",
        "YAML",
        b"      yaml-marker\n child-yaml\n",
        b"      yaml-marker\n      child-yaml\n",
        6,
    ),
)


def _find_file(session, path):
    session.extended_command("find-file")
    session.wait_for_region_text("minibuffer", "Find file: ")
    session.type(path)
    session.key("RET")


def _indent_second_line(session, path, expected, column):
    session.send(
        keys.meta("<")
        + keys.ctrl("n")
        + keys.ctrl("a")
        + keys.key("TAB")
        + keys.ctrl("e")
    )
    session.send(keys.ctrl("x") + keys.ctrl("s"))
    session.wait_for_file(path, expected)
    session.assert_file_bytes(path, expected)
    cursor_column = column + len(expected.splitlines()[1].lstrip())
    session.wait_for_region_cursor("body", cursor_column, index=1)


@scenario(
    "lang-web/default-indentation",
    commands=["find-file", "indent-for-tab-command", "save-buffer"],
)
def default_indentation(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-default-indent-") as directory:
        paths = []
        for filename, mode_name, initial, expected, column in CASES:
            path = os.path.join(directory, filename)
            with open(path, "wb") as handle:
                handle.write(initial)
            marker = initial.splitlines()[0].decode().strip()
            paths.append((path, mode_name, marker, expected, column))

        first_path = paths[0][0]
        with Session(binary, [first_path]) as session:
            session.wait_ready()
            for index, (path, mode_name, marker, expected, column) in enumerate(paths):
                if index:
                    _find_file(session, path)
                session.wait_for_region_text("body", marker, index=0)
                session.wait_for_region_text("mode-line", mode_name)
                _indent_second_line(session, path, expected, column)

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"lang-web/default-indentation exited with {code}: {output!r}"
                )
