"""Exercise bracket indentation in the web language modes."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


# Reference behavior: GNU Emacs 31.1 js.el's js--proper-indentation and
# js-indent-line, ELPA typescript-mode.el, and json-mode.el's inheritance from
# javascript-mode. The fixtures also ensure literal closers inside multiline
# block comments and template strings do not close an outer bracket.
# https://github.com/emacs-mirror/emacs/blob/emacs-31.1/lisp/progmodes/js.el
# https://github.com/emacs-typescript/typescript.el/blob/master/typescript-mode.el
# https://github.com/json-emacs/json-mode/blob/master/json-mode.el
SCRIPT_CASES = (
    ("source.ts", "TypeScript", "ts"),
    ("component.tsx", "TypeScript React", "tsx"),
    ("script.js", "JavaScript", "js"),
    ("component.jsx", "JavaScript React", "jsx"),
)


def _find_file(session, path):
    session.extended_command("find-file")
    session.wait_for_region_text("minibuffer", "Find file: ")
    session.type(path)
    session.key("RET")


def _script_bytes(marker, *, expected):
    lines = (
        f'const marker_{marker} = "{{[("; // string brackets: {{[(\n'
        f'// comment brackets: {{[( marker_{marker}\n'
        "{\n"
        f"  /* block comment marker_{marker}\n"
        "}\n"
        "        block comment end */\n"
        f"  `template marker_{marker}\n"
        "}\n"
        "        template end`;\n"
        "        [\n"
        "    (\n"
        "value\n"
        ")\n"
        "]\n"
        "        }\n"
    )
    if expected:
        return (
            f'const marker_{marker} = "{{[("; // string brackets: {{[(\n'
            f'// comment brackets: {{[( marker_{marker}\n'
            "{\n"
            f"  /* block comment marker_{marker}\n"
            "  }\n"
            "  block comment end */\n"
            f"  `template marker_{marker}\n"
            "  }\n"
            "  template end`;\n"
            "  [\n"
            "    (\n"
            "      value\n"
            "    )\n"
            "  ]\n"
            "}\n"
        ).encode("utf-8")
    return lines.encode("utf-8")


def _json_bytes(*, expected):
    if expected:
        return (
            "{\n"
            '  "mode_marker": "json-marker",\n'
            '  "text": "{[(",\n'
            '  "items": [\n'
            "    {\n"
            '      "value": true\n'
            "    }\n"
            "  ]\n"
            "}\n"
        ).encode("utf-8")
    return (
        "{\n"
        '"mode_marker": "json-marker",\n'
        '      "text": "{[(",\n'
        '  "items": [\n'
        "       {\n"
        '"value": true\n'
        "          }\n"
        " ]\n"
        "        }\n"
    ).encode("utf-8")


def _indent_all_lines(session, path, expected):
    lines = expected.splitlines()
    payload = bytearray(keys.meta("<"))
    for index in range(len(lines)):
        payload.extend(keys.ctrl("a"))
        payload.extend(keys.key("TAB"))
        if index + 1 < len(lines):
            payload.extend(keys.ctrl("n"))
    payload.extend(keys.ctrl("e"))
    session.send(bytes(payload))
    session.send(keys.ctrl("x") + keys.ctrl("s"))
    session.wait_for_file(path, expected)
    session.assert_file_bytes(path, expected)
    session.wait_for_region_cursor("body", 1, index=len(lines) - 1)


@scenario(
    "lang-web/syntax-indentation",
    commands=["find-file", "indent-for-tab-command", "save-buffer"],
)
def syntax_indentation(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-syntax-indent-") as directory:
        cases = []
        for filename, mode_name, marker in SCRIPT_CASES:
            path = os.path.join(directory, filename)
            initial = _script_bytes(marker, expected=False)
            expected = _script_bytes(marker, expected=True)
            with open(path, "wb") as handle:
                handle.write(initial)
            cases.append((path, mode_name, f"marker_{marker}", expected))

        json_path = os.path.join(directory, "config.json")
        json_initial = _json_bytes(expected=False)
        json_expected = _json_bytes(expected=True)
        with open(json_path, "wb") as handle:
            handle.write(json_initial)
        cases.append((json_path, "JSON", "json-marker", json_expected))

        first_path = cases[0][0]
        with Session(binary, [first_path]) as session:
            session.wait_ready()
            for index, (path, mode_name, body_marker, expected) in enumerate(cases):
                if index:
                    _find_file(session, path)
                marker_line = 1 if mode_name == "JSON" else 0
                session.wait_for_region_text("body", body_marker, index=marker_line)
                session.wait_for_region_text("mode-line", mode_name)
                _indent_all_lines(session, path, expected)

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"lang-web/syntax-indentation exited with {code}: {output!r}"
                )
