"""Select language modes from web-language file extensions."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


MODE_CASES = (
    ("module.mjs", "JavaScript"),
    ("script.cjs", "JavaScript"),
    ("component.jsx", "JavaScript React"),
    ("page.html", "HTML"),
    ("page.htm", "HTML"),
    ("site.css", "CSS"),
    ("config.yaml", "YAML"),
    ("config.yml", "YAML"),
    ("source.ts", "TypeScript"),
    ("source.mts", "TypeScript"),
    ("source.cts", "TypeScript"),
    ("component.tsx", "TypeScript React"),
    ("config.json", "JSON"),
)


def _find_file(session, path):
    session.extended_command("find-file")
    session.wait_for_region_text("minibuffer", "Find file: ")
    session.type(path)
    session.key("RET")


@scenario(
    "lang-web/language-modes",
    commands=["find-file", "save-buffer"],
)
def language_modes(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-lang-web-") as directory:
        first_path = os.path.join(directory, "script.js")
        initial = b"const value = 1;\n"
        expected = b"const value = 1;!\n"
        with open(first_path, "wb") as handle:
            handle.write(initial)

        paths = []
        for filename, mode_name in MODE_CASES:
            path = os.path.join(directory, filename)
            body_marker = f"loaded-file:{filename}"
            with open(path, "wb") as handle:
                handle.write(f"{body_marker}\n".encode("utf-8"))
            paths.append((path, mode_name, body_marker))

        with Session(binary, [first_path]) as session:
            session.wait_ready()
            session.wait_for_region_text("mode-line", "JavaScript")
            session.wait_for_region_text("body", "const value = 1;")

            session.send(keys.ctrl("e"))
            session.type("!")
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(first_path, expected)
            session.assert_file_bytes(first_path, expected)
            session.wait_for_region_cursor("body", 17)

            for path, mode_name, body_marker in paths:
                _find_file(session, path)
                session.wait_for_region_text("body", body_marker)
                session.wait_for_region_text("mode-line", mode_name)

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"lang-web/language-modes exited with {code}: {output!r}"
                )
