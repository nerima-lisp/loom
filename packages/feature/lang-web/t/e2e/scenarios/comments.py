"""Exercise language-specific comments with M-; in web language modes."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


LINE_CASES = (
    (
        "source.ts",
        "TypeScript",
        b"const value = 1;\n",
        b"const value = 1; //\n",
        19,
    ),
    (
        "component.tsx",
        "TypeScript React",
        b"const value = 1;\n",
        b"const value = 1; //\n",
        19,
    ),
    (
        "script.js",
        "JavaScript",
        b"const value = 1;\n",
        b"const value = 1; //\n",
        19,
    ),
    (
        "component.jsx",
        "JavaScript React",
        b"const value = 1;\n",
        b"const value = 1; //\n",
        19,
    ),
    ("page.html", "HTML", b"value\n", b"<!--value-->\n", 4),
    ("site.css", "CSS", b"value\n", b"/*value*/\n", 2),
    ("config.yaml", "YAML", b"value: 1\n", b"value: 1 #\n", 10),
)

REGION_CASES = (
    ("region.js", "JavaScript", b"// first\n// second\n", b"first\nsecond\n", 9),
    (
        "region.html",
        "HTML",
        b"<!--first\nsecond-->\n",
        b"first\nsecond\n",
        6,
    ),
)


def _find_file(session, path):
    session.extended_command("find-file")
    session.wait_for_region_text("minibuffer", "Find file: ")
    session.type(path)
    session.key("RET")


def _toggle_current_line(session, path, mode_name, expected, column):
    session.wait_for_region_text("mode-line", mode_name)
    session.send(keys.meta("<") + keys.ctrl("e") + keys.meta(";"))
    session.send(keys.ctrl("x") + keys.ctrl("s"))
    session.wait_for_file(path, expected)
    session.assert_file_bytes(path, expected)
    session.wait_for_region_cursor("body", column)


def _toggle_region(
    session, path, mode_name, wrapped, original, column
):
    session.wait_for_region_text("mode-line", mode_name)
    selection_length = len(original.rstrip(b"\n"))
    session.send(
        keys.meta("<")
        + keys.ctrl("@")
        + keys.ctrl("f") * selection_length
        + keys.meta(";")
    )
    session.send(keys.ctrl("x") + keys.ctrl("s"))
    session.wait_for_file(path, wrapped)
    session.assert_file_bytes(path, wrapped)
    session.wait_for_region_cursor("body", column, index=1)

    session.send(keys.meta(";"))
    session.send(keys.ctrl("x") + keys.ctrl("s"))
    session.wait_for_file(path, original)
    session.assert_file_bytes(path, original)
    session.wait_for_region_cursor("body", len(original.splitlines()[1]), index=1)


@scenario(
    "lang-web/comments",
    commands=["find-file", "save-buffer"],
)
def comments(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-lang-web-comments-") as directory:
        line_paths = []
        for filename, mode_name, initial, expected, column in LINE_CASES:
            path = os.path.join(directory, filename)
            with open(path, "wb") as handle:
                handle.write(initial)
            line_paths.append((path, mode_name, expected, column))

        json_path = os.path.join(directory, "config.json")
        json_initial = b'{"value": 1}\n'
        with open(json_path, "wb") as handle:
            handle.write(json_initial)

        region_paths = []
        region_initial = b"first\nsecond\n"
        for filename, mode_name, wrapped, original, column in REGION_CASES:
            path = os.path.join(directory, filename)
            with open(path, "wb") as handle:
                handle.write(region_initial)
            region_paths.append((path, mode_name, wrapped, original, column))

        with Session(binary, [line_paths[0][0]]) as session:
            session.wait_ready()
            for index, (path, mode_name, expected, column) in enumerate(line_paths):
                if index:
                    _find_file(session, path)
                _toggle_current_line(session, path, mode_name, expected, column)

            _find_file(session, json_path)
            session.wait_for_region_text("mode-line", "JSON")
            session.send(keys.meta("<") + keys.ctrl("e") + keys.meta(";"))
            session.wait_for_region_text(
                "minibuffer", "Mode JSON has no line comment syntax"
            )
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(json_path, json_initial)
            session.assert_file_bytes(json_path, json_initial)
            session.wait_for_region_cursor("body", len(json_initial.rstrip(b"\n")))

            for path, mode_name, wrapped, original, column in region_paths:
                _find_file(session, path)
                _toggle_region(session, path, mode_name, wrapped, original, column)

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"lang-web/comments exited with {code}: {output!r}"
                )
