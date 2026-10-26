"""Exercise bracket insertion and mode-specific closer skipping."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


_MODES = (
    ("ts", "TS", (("(", ")"), ("[", "]"), ("{", "}"))),
    ("tsx", "TSX", (("(", ")"), ("[", "]"), ("{", "}"))),
    ("js", "JS", (("(", ")"), ("[", "]"), ("{", "}"))),
    ("jsx", "JSX", (("(", ")"), ("[", "]"), ("{", "}"))),
    ("json", "JSON", (("[", "]"), ("{", "}"))),
    ("css", "CSS", (("(", ")"), ("[", "]"), ("{", "}"))),
    ("html", "HTML", (("<", ">"),)),
    ("yaml", "YAML", (("[", "]"), ("{", "}"))),
)


def _find_file(session, path, marker):
    session.extended_command("find-file")
    session.wait_for_region_text("minibuffer", "Find file: ")
    session.type(path)
    session.key("RET")
    session.wait_for_region_exact_text("body", marker)


@scenario(
    "lang-web/pair-completion",
    commands=["find-file", "save-buffer"],
)
def lang_web_pair_completion(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-lang-web-pairs-") as directory:
        cases = []
        for extension, marker, pairs in _MODES:
            path = os.path.join(directory, f"buffer.{extension}")
            with open(path, "wb") as handle:
                handle.write(marker.encode("ascii"))
            cases.append((path, marker, pairs))

        with Session(binary, [cases[0][0]]) as session:
            session.wait_ready()
            for index, (path, marker, pairs) in enumerate(cases):
                if index:
                    _find_file(session, path, marker)
                else:
                    session.wait_for_region_exact_text("body", marker)

                session.send(keys.ctrl("e"))
                expected_text = marker
                for opener, closer in pairs:
                    session.type(opener)
                    inserted_pair = expected_text + opener + closer
                    session.wait_for_region_exact_text("body", inserted_pair)
                    session.wait_for_region_cursor(
                        "body", len(expected_text) + 1
                    )

                    session.type(closer)
                    expected_text = inserted_pair
                    expected_column = len(expected_text)
                    session.wait_for_region_exact_text("body", expected_text)
                    session.wait_for_region_cursor("body", expected_column)
                    session.send(keys.ctrl("e"))

                expected_bytes = expected_text.encode("ascii")
                session.send(keys.ctrl("x") + keys.ctrl("s"))
                session.wait_for_file(path, expected_bytes)
                session.assert_file_bytes(path, expected_bytes)

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"lang-web/pair-completion exited with {code}: {output!r}"
                )
