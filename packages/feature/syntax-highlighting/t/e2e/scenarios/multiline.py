"""Observe Common Lisp lexical state across physical lines."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _assert_word(session, word, foreground):
    session.wait_for_text(word)
    position = session.screen.find(word)
    if position is None:
        raise AssertionError(f"missing syntax marker {word!r}")
    session.assert_cell_attrs(
        *position, expected={"data": word[0], "fg": foreground}
    )


def _multiline_case(binary, contents, checks):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-cl-multiline-") as directory:
        path = os.path.join(directory, "multiline.lisp")
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(contents)
        with Session(binary, [path]) as session:
            session.wait_ready()
            for word, foreground in checks:
                _assert_word(session, word, foreground)
            session.quit()


@scenario("syntax-highlighting/multiline/block-comment", commands=[])
def block_comment(binary):
    _multiline_case(
        binary,
        "#| first\nMIDDLE_COMMENT\nlast |# OUTSIDE_COMMENT\n",
        [("MIDDLE_COMMENT", "brightblack"), ("OUTSIDE_COMMENT", "default")],
    )


@scenario("syntax-highlighting/multiline/nested-comment", commands=[])
def nested_comment(binary):
    _multiline_case(
        binary,
        "#| outer #| inner\nINNER_COMMENT |# OUTER_COMMENT\n|# OUTSIDE_NESTED\n",
        [("INNER_COMMENT", "brightblack"), ("OUTER_COMMENT", "brightblack"),
         ("OUTSIDE_NESTED", "default")],
    )


@scenario("syntax-highlighting/multiline/docstring", commands=[])
def docstring(binary):
    _multiline_case(
        binary,
        '(defun sample () "first\nMIDDLE_DOCSTRING\nlast" OUTSIDE_STRING)\n',
        [("MIDDLE_DOCSTRING", "green"), ("OUTSIDE_STRING", "default")],
    )


@scenario("syntax-highlighting/multiline/delete-opening-quote", commands=["delete-backward-char"])
def delete_opening_quote(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-cl-multiline-") as directory:
        path = os.path.join(directory, "multiline.lisp")
        with open(path, "w", encoding="utf-8") as handle:
            handle.write('"first\nRESTORED_CODE\nlast\n')
        with Session(binary, [path]) as session:
            session.wait_ready()
            _assert_word(session, "RESTORED_CODE", "green")
            session.send(keys.ctrl("f"))
            session.wait_for_region_cursor("body", 1)
            session.send(keys.ctrl("?"))
            session.wait_for_region_cursor("body", 0)
            _assert_word(session, "RESTORED_CODE", "default")
