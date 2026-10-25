"""Check grapheme and tab cell positions in the rendered buffer."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _move_and_assert(session, payload, expected, description):
    before = session.screen.cursor
    session.send(payload)
    session.wait_until(
        lambda screen: screen.cursor != before,
        what=f"cursor movement for {description}",
    )
    if session.observe_cursor(expected=expected, sample=description) is not True:
        raise AssertionError(
            f"cursor after {description} was {session.screen.cursor!r}, "
            f"expected {expected!r}"
        )


def _next_line(session, line, column):
    session.send(keys.ctrl("a"))
    session.wait_for_cursor(line, column)
    session.send(keys.ctrl("n"))
    session.wait_for_cursor(line + 1, column)


def _write_buffer(directory, lines, filename="layout.lisp"):
    path = os.path.join(directory, filename)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")
    return path


@scenario(
    "d7/grapheme-cell-layout",
    commands=["forward-char", "next-line"],
)
def d7_grapheme_cell_layout(binary):
    family = "👩‍👩‍👧‍👦"
    lines = ["e\u0301x", family + "x", "漢x", "\tb"]
    with tempfile.TemporaryDirectory(prefix="loom-d7-") as directory:
        path = _write_buffer(directory, lines)
        with Session(binary, [path], columns=40, rows=12) as session:
            session.wait_ready()
            session.wait_for_region_text("body", "漢x", index=2)
            for glyph in ("e\u0301", family, "漢"):
                session.assert_pty_output(
                    session.output_bytes,
                    glyph.encode("utf-8"),
                    match="contains",
                )

            start_row, start_column = session.screen.cursor
            session.wait_for_region_cursor("body", start_column)
            _move_and_assert(
                session,
                keys.ctrl("f") * 2,
                (start_row, start_column + 1),
                "cursor after a base and combining mark",
            )

            _next_line(session, start_row, start_column)
            _move_and_assert(
                session,
                keys.ctrl("f") * len(family),
                (start_row + 1, start_column + 2),
                "cursor after a ZWJ emoji cluster",
            )

            _next_line(session, start_row + 1, start_column)
            _move_and_assert(
                session,
                keys.ctrl("f"),
                (start_row + 2, start_column + 2),
                "cursor after a fullwidth character",
            )

            _next_line(session, start_row + 2, start_column)
            _move_and_assert(
                session,
                keys.ctrl("f"),
                (start_row + 3, start_column + 8),
                "cursor after an eight-cell TAB",
            )
            session.assert_screen_text(
                "        b", match="contains", region="body", index=3
            )


@scenario(
    "d7/grapheme-vs16-width",
    commands=["forward-char"],
)
def d7_grapheme_vs16_width(binary):
    lines = ["☝️x"]
    with tempfile.TemporaryDirectory(prefix="loom-d7-") as directory:
        path = _write_buffer(directory, lines)
        with Session(binary, [path], columns=40, rows=12) as session:
            session.wait_ready()
            session.wait_for_region_text("body", "☝", index=0)
            session.assert_pty_output(
                session.output_bytes,
                "☝️".encode("utf-8"),
                match="contains",
            )

            start_row, start_column = session.screen.cursor
            _move_and_assert(
                session,
                keys.ctrl("f") * 2,
                (start_row, start_column + 2),
                "cursor after a variation-selector cluster",
            )


@scenario(
    "d7/grapheme-wrap-boundary",
    commands=["forward-char", "keyboard-quit", "toggle-truncate-lines"],
)
def d7_grapheme_wrap_boundary(binary):
    with tempfile.TemporaryDirectory(prefix="loom-d7-") as directory:
        path = _write_buffer(directory, ["a" * 39 + "e\u0301x"])
        with Session(binary, [path], columns=40, rows=12) as session:
            session.wait_ready()
            session.wait_for_region_text("mode-line", "Truncate")
            session.extended_command("toggle-truncate-lines")
            session.wait_for_region_text("minibuffer", "Wrap long lines")
            session.wait_for_region_text("body", "aaaa", index=0)
            start_row, start_column = session.screen.cursor
            expected = (start_row + 1, start_column)
            description = "grapheme ending at the wrap boundary"
            session.send(keys.ctrl("f") * 41 + keys.ctrl("g"))
            session.wait_for_region_text("minibuffer", "Quit", timeout=1.0)
            if session.observe_cursor(expected=expected, sample=description) is not True:
                raise AssertionError(
                    f"cursor after {description} was {session.screen.cursor!r}, "
                    f"expected {expected!r}"
                )


@scenario(
    "d7/grapheme-overlay-replacement",
    commands=["forward-char", "set-mark-command", "kill-region"],
)
def d7_grapheme_overlay_replacement(binary):
    family = "👩‍👩‍👧‍👦"
    with tempfile.TemporaryDirectory(prefix="loom-d7-") as directory:
        path = _write_buffer(directory, [family + "x"])
        with Session(binary, [path], columns=40, rows=12) as session:
            session.wait_ready()
            session.wait_for_region_text("body", family[0] + "x", index=0)
            session.assert_pty_output(
                session.output_bytes,
                family.encode("utf-8"),
                match="contains",
            )
            start_row, start_column = session.screen.cursor
            initial_bg = session.screen.cell_attrs(
                start_row, start_column
            )["bg"]

            session.send(keys.ctrl("a"))
            session.send(keys.ctrl("@"))
            session.send(keys.ctrl("f") * len(family))
            session.wait_until(
                lambda screen: screen.cell_attrs(
                    start_row, start_column
                )["bg"] != initial_bg,
                what="selected grapheme background style changed",
            )
            session.observe_cell_attrs(
                start_row, start_column, purpose="selected grapheme background"
            )
            session.assert_cell_attrs(
                start_row, start_column, {"bg": "00cd00"}
            )
            session.assert_cell_attrs(
                start_row, start_column + 1, {"bg": "00cd00"}
            )
            session.wait_for_cursor(start_row, start_column + 2)

            session.send(keys.ctrl("a"))
            session.send(keys.ctrl("@"))
            session.send(keys.ctrl("f") * len(family))
            session.send(keys.ctrl("w"))
            session.send(keys.text("漢"))
            session.wait_for_region_text("body", "漢x", index=0)
            if family[0] in session.screen.text(start_row):
                raise AssertionError("replaced grapheme remained on screen")
            session.wait_for_cursor(start_row, start_column + 2)
            session.assert_cell_attrs(
                start_row, start_column, {"bg": initial_bg}
            )
            session.assert_cell_attrs(
                start_row, start_column + 1, {"bg": initial_bg}
            )


@scenario(
    "d7/grapheme-resize-overlay-cleanup",
    commands=["forward-char", "kill-line", "toggle-truncate-lines"],
)
def d7_grapheme_resize_overlay_cleanup(binary):
    family = "👩‍👩‍👧‍👦"
    with tempfile.TemporaryDirectory(prefix="loom-d7-") as directory:
        path = _write_buffer(directory, ["a" * 19 + family + "x"])
        with Session(binary, [path], columns=40, rows=12) as session:
            session.wait_ready()
            session.wait_for_region_text("mode-line", "Truncate")
            session.extended_command("toggle-truncate-lines")
            session.wait_for_region_text("minibuffer", "Wrap long lines")
            session.wait_for_region_text("body", family[0] + "x", index=0)
            session.assert_pty_output(
                session.output_bytes,
                family.encode("utf-8"),
                match="contains",
            )
            start_row, start_column = session.screen.cursor
            _move_and_assert(
                session,
                keys.ctrl("f") * (19 + len(family) + 1),
                (start_row, start_column + 22),
                "cursor after an edge grapheme before resize",
            )

            session.send(keys.ctrl("a"))
            session.resize(columns=20, rows=12)
            session.wait_for_region_text("body", "aaaa", index=0)
            session.wait_for_region_text("body", family[0], index=1)
            session.observe_cell_attrs(
                start_row, start_column + 19,
                purpose="old glyph cell after shrinking across its right half",
            )
            if (
                session.screen.cell_attrs(
                    start_row, start_column + 19
                )["data"]
                == family[0]
            ):
                raise AssertionError("resized screen retained a clipped glyph head")

            session.send(keys.ctrl("k"))
            session.send(keys.text("z"))
            session.wait_for_region_text("body", "z", index=0)
            if session.screen.find(family[0]) is not None:
                raise AssertionError("replaced buffer retained a stale grapheme")

            session.resize(columns=40, rows=12)
            session.send(keys.ctrl("a"))
            session.wait_for_cursor(start_row, start_column)
            session.send(keys.ctrl("f"))
            session.wait_for_cursor(start_row, start_column + 1)
            session.wait_for_region_text("body", "z", index=0)
            if session.screen.find(family[0]) is not None:
                raise AssertionError("resized screen retained a stale grapheme")
