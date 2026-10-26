"""Exercise buffer text operations across grapheme and layout boundaries."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


_DIMENSIONS = {
    "fullwidth": {"glyph": "漢", "prefix": "A", "suffix": "x", "width": 2},
    "combining": {"glyph": "e\u0301", "prefix": "A", "suffix": "x", "width": 1},
    "emoji": {
        "glyph": "👩‍👩‍👧‍👦",
        "prefix": "A",
        "suffix": "x",
        "width": 2,
    },
    "wrap": {
        "glyph": "e\u0301",
        "prefix": "a" * 39,
        "suffix": "x",
        "width": 1,
    },
    "truncate": {
        "glyph": "G",
        "prefix": "a" * 37,
        "suffix": "x" * 8,
        "width": 1,
    },
}

_OPERATION_COMMANDS = {
    "move": ["forward-char"],
    "insert": ["forward-char", "save-buffer"],
    "delete": ["forward-char", "delete-char", "save-buffer"],
    "undo": ["forward-char", "undo", "save-buffer"],
    "save": ["forward-char", "save-buffer"],
}


def _write_buffer(directory, text):
    path = os.path.join(directory, "r6.txt")
    with open(path, "wb") as handle:
        handle.write(text.encode("utf-8"))
    return path


def _assert_cursor(session, expected, description):
    session.wait_for_region_cursor("body", expected[1], index=expected[0])
    if session.observe_cursor(
        expected=expected,
        sample=description,
        region="body",
    ) is not True:
        raise AssertionError(
            f"cursor after {description} was {session.region_cursor('body')!r}, "
            f"expected {expected!r}"
        )


def _prepare_session(session, name, dimension):
    session.wait_ready()
    session.wait_for_region_text("body", dimension["prefix"][:1], index=0)

    if name == "wrap":
        session.wait_for_region_text("body", dimension["suffix"], index=1)
    elif name == "truncate":
        session.extended_command("toggle-truncate-lines")
        session.wait_for_region_text("minibuffer", "Truncate long lines")
        width = session.columns - session.layout.body_x
        visible = (
            dimension["prefix"] + dimension["glyph"] + dimension["suffix"]
        )[:width]
        session.wait_for_region_text("body", visible, index=0)
        session.assert_screen_text(
            visible, match="exact", region="body", index=0
        )
        session.assert_screen_text(
            " " * width, match="exact", region="body", index=1
        )
        _assert_cursor(session, (0, 0), "cursor before truncation operation")


def _at_glyph(session, dimension):
    session.wait_for_region_cursor("body", 0, index=0)
    session.send(keys.ctrl("f") * len(dimension["prefix"]))
    expected = (0, len(dimension["prefix"]))
    _assert_cursor(session, expected, "cursor at the target grapheme")
    return expected


def _expected_move_cursor(name, dimension):
    if name == "wrap":
        return (1, 0)
    return (0, len(dimension["prefix"]) + dimension["width"])


def _assert_layout_effect(session, name, operation, cursor, dimension):
    if name == "wrap":
        row = 0 if operation == "delete" else 1
        session.assert_screen_text("x", match="contains", region="body", index=row)
    elif name == "truncate":
        width = session.columns - session.layout.body_x
        prefix = dimension["prefix"]
        glyph = dimension["glyph"]
        suffix = dimension["suffix"]
        visible = {
            "move": prefix + glyph + suffix,
            "insert": prefix + glyph + glyph + suffix,
            "delete": prefix + suffix,
            "undo": prefix + glyph + suffix,
            "save": prefix + "!" + glyph + suffix,
        }[operation][:width]
        session.assert_screen_text(
            visible, match="exact", region="body", index=0
        )
        session.assert_screen_text(
            " " * width, match="exact", region="body", index=1
        )

    if name in {"wrap", "truncate"}:
        if operation == "move":
            _assert_cursor(session, cursor, f"cursor after {name} grapheme move")
        else:
            session.send(keys.ctrl("a"))
            _assert_cursor(session, (0, 0), f"cursor on {name} line after {operation}")


def _save_and_assert(session, path, expected):
    expected_bytes = expected.encode("utf-8")
    session.send(keys.ctrl("x") + keys.ctrl("s"))
    session.wait_for_file(path, expected_bytes)
    session.assert_file_bytes(path, expected_bytes)


def _run_text_operation(binary, name, operation):
    dimension = _DIMENSIONS[name]
    original = dimension["prefix"] + dimension["glyph"] + dimension["suffix"]
    with tempfile.TemporaryDirectory(prefix="loom-r6-") as directory:
        path = _write_buffer(directory, original + "\n")
        with Session(binary, [path], columns=40, rows=12) as session:
            _prepare_session(session, name, dimension)
            _run_text_operation_in_session(
                session, path, name, operation, dimension, original
            )


def _run_text_operation_in_session(session, path, name, operation, dimension, original):
    _at_glyph(session, dimension)
    glyph = dimension["glyph"]

    if operation == "move":
        expected_cursor = _expected_move_cursor(name, dimension)
        session.send(keys.ctrl("f") * len(glyph))
        _assert_cursor(session, expected_cursor, f"{name} grapheme move")
        _assert_layout_effect(session, name, operation, expected_cursor, dimension)
        return

    if operation == "insert":
        session.type(glyph)
        edited = dimension["prefix"] + glyph + glyph + dimension["suffix"]
        _save_and_assert(session, path, edited + "\n")
        _assert_layout_effect(
            session,
            name,
            operation,
            _expected_move_cursor(name, dimension),
            dimension,
        )
        return

    if operation == "delete":
        session.send(keys.ctrl("d") * len(glyph))
        _save_and_assert(
            session,
            path,
            dimension["prefix"] + dimension["suffix"] + "\n",
        )
        _assert_layout_effect(
            session, name, operation, (0, len(dimension["prefix"])), dimension
        )
        return

    if operation == "undo":
        original_body = session.region_contents("body")
        session.type(glyph)
        _assert_cursor(
            session,
            _expected_move_cursor(name, dimension),
            f"cursor after inserting {name} text before undo",
        )
        session.send(keys.ctrl("x") + keys.text("u"))
        session.wait_until(
            lambda _screen: session.region_contents("body") == original_body,
            what=f"undo restores the original {name} text",
        )
        session.assert_screen_text(
            original_body, match="exact", region="body", index=None
        )
        _save_and_assert(session, path, original + "\n")
        _assert_layout_effect(
            session, name, operation, (0, len(dimension["prefix"])), dimension
        )
        return

    if operation == "save":
        session.type("!")
        session.wait_for_region_text("body", "!", index=0)
        _save_and_assert(
            session,
            path,
            dimension["prefix"] + "!" + glyph + dimension["suffix"] + "\n",
        )
        _assert_layout_effect(
            session,
            name,
            operation,
            (0, len(dimension["prefix"]) + 1),
            dimension,
        )
        return

    raise ValueError(f"unknown R6 operation: {operation}")


def _register_text_scenario(name, operation):
    commands = list(_OPERATION_COMMANDS[operation])
    if name == "truncate":
        commands.extend(["execute-extended-command", "toggle-truncate-lines"])
    if name in {"wrap", "truncate"} and operation != "move":
        commands.append("move-beginning-of-line")

    def run(binary):
        _run_text_operation(binary, name, operation)

    run.__name__ = f"r6_text_{name}_{operation}"
    scenario(f"r6/text/{name}/{operation}", commands=commands)(run)


for _name in _DIMENSIONS:
    for _operation in _OPERATION_COMMANDS:
        _register_text_scenario(_name, _operation)


@scenario(
    "r6/resize",
    commands=["forward-char"],
)
def r6_resize(binary):
    line = "a" * 30
    with tempfile.TemporaryDirectory(prefix="loom-r6-resize-") as directory:
        path = _write_buffer(directory, line + "\n")
        with Session(binary, [path], columns=40, rows=12) as session:
            session.wait_ready()
            session.wait_for_region_text("body", line, index=0)
            session.assert_screen_text(
                line, match="exact", region="body", index=0, strip_right=True
            )
            session.assert_screen_text(
                "", match="exact", region="body", index=1, strip_right=True
            )
            _assert_cursor(session, (0, 0), "cursor before terminal resize")
            session.send(keys.ctrl("f") * 25)
            _assert_cursor(session, (0, 25), "cursor before terminal resize")

            session.resize(columns=20, rows=12)
            session.wait_for_region_text("body", "a" * 10, index=1)
            session.wait_for_region_cursor("body", 5, index=1)
            session.assert_screen_text(
                "a" * 20,
                match="exact",
                region="body",
                index=0,
                strip_right=True,
            )
            session.assert_screen_text(
                "a" * 10,
                match="exact",
                region="body",
                index=1,
                strip_right=True,
            )
            _assert_cursor(session, (1, 5), "cursor after terminal resize")
