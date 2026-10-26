"""Exercise mode-local structural-editing keys in both Lisp modes."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


_CONTROL_RIGHT = b"\x1b[1;5C"
_CONTROL_LEFT = b"\x1b[1;5D"
_CONTROL_ALT_LEFT = b"\x1b[1;7D"
_CONTROL_ALT_RIGHT = b"\x1b[1;7C"


def _run_structural_edit(
    binary,
    extension,
    scenario_name,
    command,
    content,
    expected,
    point_offset,
    expected_point,
    key_sequence,
):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "structure." + extension)
        with open(path, "wb") as handle:
            handle.write(content)

        with Session(binary, [path]) as session:
            session.wait_ready(timeout=1.25)
            session.wait_for_region_exact_text(
                "body", content.decode("utf-8").rstrip("\n"), timeout=0.5
            )
            session.wait_for_region_cursor("body", 0, timeout=0.5)
            if session.observe_cursor(expected=(0, 0), region="body") is not True:
                raise AssertionError(f"{scenario_name}: file did not open at point-min")
            if point_offset:
                session.send(keys.key("RIGHT") * point_offset)
                session.wait_for_region_cursor("body", point_offset, timeout=0.4)
            session.send(key_sequence)
            expected_text = expected.decode("utf-8").rstrip("\n")
            session.wait_for_region_exact_text("body", expected_text, timeout=0.45)
            session.wait_for_region_cursor("body", expected_point, timeout=0.45)
            if session.observe_cursor(
                expected=(0, expected_point), region="body"
            ) is not True:
                raise AssertionError(
                    f"{scenario_name}: point was {session.region_cursor('body')!r}, "
                    f"expected (0, {expected_point})"
                )

            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, expected, timeout=0.6)
            session.assert_file_bytes(path, expected)
            output, code = session.quit(timeout=0.75)

        if code != 0:
            raise AssertionError(f"{scenario_name} exited with {code}: {output!r}")


def _register_case(mode, extension, command, content, expected, point, result_point, key):
    scenario_name = f"lang-lisp/structural-{command}-{mode}"
    commands = (["forward-char"] if point else []) + [command, "save-buffer"]

    @scenario(scenario_name, commands=commands)
    def run(binary):
        _run_structural_edit(
            binary,
            extension,
            scenario_name,
            command,
            content,
            expected,
            point,
            result_point,
            key,
        )

    return run


_CASES = (
    ("forward-slurp-sexp", b"(a) b\n", b"(a b)\n", 1, 1, _CONTROL_RIGHT),
    ("forward-barf-sexp", b"(a b)\n", b"(a) b\n", 1, 1, _CONTROL_LEFT),
    ("backward-slurp-sexp", b"a (b)\n", b"(a b)\n", 3, 3, _CONTROL_ALT_LEFT),
    ("backward-barf-sexp", b"(a b)\n", b"a (b)\n", 1, 0, _CONTROL_ALT_RIGHT),
    ("wrap-round", b"a b\n", b"(a) b\n", 0, 1, keys.meta("(")),
    ("splice-sexp", b"(a (b c) d)\n", b"(a b c d)\n", 4, 3, keys.meta("s")),
    ("raise-sexp", b"(a (b c) d)\n", b"(b c)\n", 3, 0, keys.meta("r")),
)

for _mode, _extension in (("cl", "lisp"), ("el", "el")):
    for _command, _content, _expected, _point, _result_point, _key in _CASES:
        _register_case(
            _mode,
            _extension,
            _command,
            _content,
            _expected,
            _point,
            _result_point,
            _key,
        )
