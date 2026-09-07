"""Movement, search, mark, and structural-editing PTY scenarios."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _assert_exit_zero(name, output, code):
    if code != 0:
        raise AssertionError(f"{name} exited with {code}: {output!r}")


def _write_file(directory, name, content):
    path = os.path.join(directory, name)
    with open(path, "wb") as handle:
        handle.write(content)
    return path


def _mx(session, name):
    session.extended_command(name)


def _prompted_mx(session, name, prompt, value):
    _mx(session, name)
    session.wait_for_region_text("minibuffer", prompt)
    session.type(value)
    session.send(keys.RET)


def _save(session):
    session.send(keys.ctrl("x") + keys.ctrl("s"))


def _lines(count):
    return "\n".join(f"line{index}" for index in range(count)).encode()


@scenario("movement/forward-char", commands=["execute-extended-command", "forward-char"])
def forward_char(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _write_file(directory, "forward.txt", b"abc\n")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _mx(session, "forward-char")
            session.wait_for_region_cursor("body", 1)
            if not session.region_text("body").startswith("abc"):
                raise AssertionError("forward-char changed the visible line")
            output, code = session.quit()
    _assert_exit_zero("movement/forward-char", output, code)


@scenario(
    "movement/backward-char",
    commands=["execute-extended-command", "end-of-buffer", "backward-char"],
)
def backward_char(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _write_file(directory, "backward.txt", b"abc")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _mx(session, "end-of-buffer")
            session.wait_for_region_cursor("body", 3)
            _mx(session, "backward-char")
            session.wait_for_region_cursor("body", 2)
            output, code = session.quit()
    _assert_exit_zero("movement/backward-char", output, code)


@scenario(
    "movement/backward-word",
    commands=["execute-extended-command", "end-of-buffer", "backward-word"],
)
def backward_word(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _write_file(directory, "backward-word.txt", b"one, two")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _mx(session, "end-of-buffer")
            session.wait_for_region_cursor("body", 8)
            _mx(session, "backward-word")
            session.wait_for_region_cursor("body", 5)
            output, code = session.quit()
    _assert_exit_zero("movement/backward-word", output, code)


@scenario("movement/forward-word", commands=["execute-extended-command", "forward-word"])
def forward_word(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _write_file(directory, "forward-word.txt", b"one two\n")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _mx(session, "forward-word")
            session.wait_for_region_cursor("body", 3)
            output, code = session.quit()
    _assert_exit_zero("movement/forward-word", output, code)


@scenario(
    "movement/previous-line",
    commands=["execute-extended-command", "goto-line", "previous-line"],
)
def previous_line(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _write_file(directory, "previous-line.txt", b"one\nhi\n")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _prompted_mx(session, "goto-line", "Go to line: ", "2")
            session.wait_for_region_cursor("body", 0, index=1)
            _mx(session, "previous-line")
            session.wait_for_region_cursor("body", 0, index=0)
            output, code = session.quit()
    _assert_exit_zero("movement/previous-line", output, code)


@scenario(
    "movement/next-line",
    commands=["execute-extended-command", "move-end-of-line", "next-line"],
)
def next_line(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _write_file(directory, "next-line.txt", b"hell\nhello\n")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _mx(session, "move-end-of-line")
            session.wait_for_region_cursor("body", 4, index=0)
            _mx(session, "next-line")
            session.wait_for_region_cursor("body", 4, index=1)
            output, code = session.quit()
    _assert_exit_zero("movement/next-line", output, code)


@scenario(
    "movement/beginning-of-buffer",
    commands=["execute-extended-command", "end-of-buffer", "beginning-of-buffer"],
)
def beginning_of_buffer(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _write_file(directory, "beginning.txt", b"abc")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _mx(session, "end-of-buffer")
            session.wait_for_region_cursor("body", 3)
            _mx(session, "beginning-of-buffer")
            session.wait_for_region_cursor("body", 0)
            output, code = session.quit()
    _assert_exit_zero("movement/beginning-of-buffer", output, code)


@scenario("movement/end-of-buffer", commands=["execute-extended-command", "end-of-buffer"])
def end_of_buffer(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _write_file(directory, "end.txt", b"abc")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _mx(session, "end-of-buffer")
            session.wait_for_region_cursor("body", 3)
            output, code = session.quit()
    _assert_exit_zero("movement/end-of-buffer", output, code)


@scenario(
    "movement/move-beginning-of-line",
    commands=[
        "execute-extended-command",
        "move-end-of-line",
        "move-beginning-of-line",
    ],
)
def move_beginning_of_line(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _write_file(directory, "line-beginning.txt", b"abc")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _mx(session, "move-end-of-line")
            session.wait_for_region_cursor("body", 3)
            _mx(session, "move-beginning-of-line")
            session.wait_for_region_cursor("body", 0)
            output, code = session.quit()
    _assert_exit_zero("movement/move-beginning-of-line", output, code)


@scenario("movement/move-end-of-line", commands=["execute-extended-command", "move-end-of-line"])
def move_end_of_line(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _write_file(directory, "line-end.txt", b"abc\n")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _mx(session, "move-end-of-line")
            session.wait_for_region_cursor("body", 3)
            output, code = session.quit()
    _assert_exit_zero("movement/move-end-of-line", output, code)


@scenario("movement/goto-line", commands=["execute-extended-command", "goto-line"])
def goto_line(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _write_file(directory, "goto-line.txt", b"one\ntwo\nthree\n")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _prompted_mx(session, "goto-line", "Go to line: ", "3")
            session.wait_for_region_cursor("body", 0, index=2)
            output, code = session.quit()
    _assert_exit_zero("movement/goto-line", output, code)


@scenario(
    "movement/scroll-up-command",
    commands=["execute-extended-command", "goto-line", "scroll-up-command"],
)
def scroll_up_command(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _write_file(directory, "scroll-up.txt", _lines(20))
        with Session(binary, [path], rows=8) as session:
            session.wait_ready()
            _prompted_mx(session, "goto-line", "Go to line: ", "15")
            session.wait_for_region_text("body", "line9")
            _mx(session, "scroll-up-command")
            session.wait_for_region_text("body", "line14", index=1)
            output, code = session.quit()
    _assert_exit_zero("movement/scroll-up-command", output, code)


@scenario(
    "movement/scroll-down-command",
    commands=[
        "execute-extended-command",
        "goto-line",
        "scroll-up-command",
        "scroll-down-command",
    ],
)
def scroll_down_command(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _write_file(directory, "scroll-down.txt", _lines(20))
        with Session(binary, [path], rows=8) as session:
            session.wait_ready()
            _prompted_mx(session, "goto-line", "Go to line: ", "15")
            session.wait_for_region_text("body", "line9")
            _mx(session, "scroll-up-command")
            session.wait_for_region_text("body", "line14", index=1)
            _mx(session, "scroll-down-command")
            session.wait_for_region_text("body", "line9")
            output, code = session.quit()
    _assert_exit_zero("movement/scroll-down-command", output, code)


@scenario("movement/backward-sexp", commands=["execute-extended-command", "end-of-buffer", "backward-sexp"])
def backward_sexp(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _write_file(directory, "backward-sexp.lisp", b"(a b) c")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _mx(session, "end-of-buffer")
            session.wait_for_region_cursor("body", 7)
            _mx(session, "backward-sexp")
            session.wait_for_region_cursor("body", 6)
            _mx(session, "backward-sexp")
            session.wait_for_region_cursor("body", 0)
            output, code = session.quit()
    _assert_exit_zero("movement/backward-sexp", output, code)


@scenario("movement/forward-sexp", commands=["execute-extended-command", "forward-sexp"])
def forward_sexp(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _write_file(directory, "forward-sexp.lisp", b"(a b) c")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _mx(session, "forward-sexp")
            session.wait_for_region_cursor("body", 5)
            _mx(session, "forward-sexp")
            session.wait_for_region_cursor("body", 7)
            output, code = session.quit()
    _assert_exit_zero("movement/forward-sexp", output, code)


@scenario(
    "movement/backward-up-list",
    commands=["execute-extended-command", "forward-char", "backward-up-list"],
)
def backward_up_list(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _write_file(directory, "up-list.lisp", b"(a (b c) d)")
        with Session(binary, [path]) as session:
            session.wait_ready()
            for _ in range(5):
                _mx(session, "forward-char")
            session.wait_for_region_cursor("body", 5)
            _mx(session, "backward-up-list")
            session.wait_for_region_cursor("body", 3)
            _mx(session, "backward-up-list")
            session.wait_for_region_cursor("body", 0)
            output, code = session.quit()
    _assert_exit_zero("movement/backward-up-list", output, code)


@scenario("movement/down-list", commands=["execute-extended-command", "down-list"])
def down_list(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _write_file(directory, "down-list.lisp", b"(a b)")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _mx(session, "down-list")
            session.wait_for_region_cursor("body", 1)
            output, code = session.quit()
    _assert_exit_zero("movement/down-list", output, code)


def _structural_scenario(binary, scenario_name, filename, initial, setup_column, command, expected):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _write_file(directory, filename, initial)
        with Session(binary, [path]) as session:
            session.wait_ready()
            for _ in range(setup_column):
                _mx(session, "forward-char")
            session.wait_for_region_cursor("body", setup_column)
            _mx(session, command)
            _save(session)
            session.wait_for_file(path, expected)
            output, code = session.quit()
    _assert_exit_zero(scenario_name, output, code)


@scenario(
    "movement/backward-barf-sexp",
    commands=[
        "execute-extended-command",
        "forward-char",
        "backward-barf-sexp",
        "save-buffer",
    ],
)
def backward_barf_sexp(binary):
    _structural_scenario(
        binary, "backward-barf-sexp", "backward-barf.lisp", b"(a b)", 1,
        "backward-barf-sexp", b"a (b)",
    )


@scenario(
    "movement/backward-slurp-sexp",
    commands=[
        "execute-extended-command",
        "forward-char",
        "backward-slurp-sexp",
        "save-buffer",
    ],
)
def backward_slurp_sexp(binary):
    _structural_scenario(
        binary, "backward-slurp-sexp", "backward-slurp.lisp", b"a (b)", 3,
        "backward-slurp-sexp", b"(a b)",
    )


@scenario(
    "movement/forward-barf-sexp",
    commands=[
        "execute-extended-command",
        "forward-char",
        "forward-barf-sexp",
        "save-buffer",
    ],
)
def forward_barf_sexp(binary):
    _structural_scenario(
        binary, "forward-barf-sexp", "forward-barf.lisp", b"(a b)", 1,
        "forward-barf-sexp", b"(a) b",
    )


@scenario(
    "movement/forward-slurp-sexp",
    commands=[
        "execute-extended-command",
        "forward-char",
        "forward-slurp-sexp",
        "save-buffer",
    ],
)
def forward_slurp_sexp(binary):
    _structural_scenario(
        binary, "forward-slurp-sexp", "forward-slurp.lisp", b"(a) b", 1,
        "forward-slurp-sexp", b"(a b)",
    )


@scenario(
    "movement/raise-sexp",
    commands=[
        "execute-extended-command",
        "forward-char",
        "raise-sexp",
        "save-buffer",
    ],
)
def raise_sexp(binary):
    _structural_scenario(
        binary, "raise-sexp", "raise.lisp", b"(a (b c) d)", 3,
        "raise-sexp", b"(b c)",
    )


@scenario(
    "movement/wrap-round",
    commands=["execute-extended-command", "wrap-round", "save-buffer"],
)
def wrap_round(binary):
    _structural_scenario(
        binary, "wrap-round", "wrap.lisp", b"a b", 0, "wrap-round", b"(a) b",
    )


@scenario(
    "movement/search-backward",
    commands=["execute-extended-command", "end-of-buffer", "search-backward"],
)
def search_backward(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _write_file(directory, "search-backward.txt", b"alpha needle omega needle")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _mx(session, "end-of-buffer")
            _prompted_mx(session, "search-backward", "Search backward (regex): ", "needle")
            session.wait_for_region_text("minibuffer", "Found")
            session.wait_for_region_cursor("body", 19)
            output, code = session.quit()
    _assert_exit_zero("movement/search-backward", output, code)


@scenario("movement/search-forward", commands=["execute-extended-command", "search-forward"])
def search_forward(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _write_file(directory, "search-forward.txt", b"alpha needle omega needle")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _prompted_mx(session, "search-forward", "Search (regex): ", "needle")
            session.wait_for_region_text("minibuffer", "Found")
            session.wait_for_region_cursor("body", 6)
            output, code = session.quit()
    _assert_exit_zero("movement/search-forward", output, code)


@scenario(
    "movement/isearch-backward",
    commands=["execute-extended-command", "end-of-buffer", "isearch-backward"],
)
def isearch_backward(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _write_file(directory, "isearch-backward.txt", b"alpha needle omega needle")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _mx(session, "end-of-buffer")
            _mx(session, "isearch-backward")
            session.wait_for_region_text("minibuffer", "I-search backward: ")
            session.type("needle")
            session.send(keys.RET)
            session.wait_for_region_cursor("body", 19)
            output, code = session.quit()
    _assert_exit_zero("movement/isearch-backward", output, code)


@scenario("movement/isearch-forward", commands=["execute-extended-command", "isearch-forward"])
def isearch_forward(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _write_file(directory, "isearch-forward.txt", b"alpha needle omega needle")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _mx(session, "isearch-forward")
            session.wait_for_region_text("minibuffer", "I-search: ")
            session.type("needle")
            session.send(keys.RET)
            session.wait_for_region_cursor("body", 6)
            output, code = session.quit()
    _assert_exit_zero("movement/isearch-forward", output, code)


@scenario(
    "movement/exchange-point-and-mark",
    commands=[
        "execute-extended-command",
        "set-mark-command",
        "forward-char",
        "exchange-point-and-mark",
    ],
)
def exchange_point_and_mark(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _write_file(directory, "exchange-mark.txt", b"abc")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _mx(session, "set-mark-command")
            _mx(session, "forward-char")
            session.wait_for_region_cursor("body", 1)
            _mx(session, "exchange-point-and-mark")
            session.wait_for_region_cursor("body", 0)
            output, code = session.quit()
    _assert_exit_zero("movement/exchange-point-and-mark", output, code)


@scenario(
    "movement/set-mark-command",
    commands=[
        "execute-extended-command",
        "set-mark-command",
        "forward-char",
        "exchange-point-and-mark",
    ],
)
def set_mark_command(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _write_file(directory, "set-mark.txt", b"abc")
        with Session(binary, [path]) as session:
            session.wait_ready()
            _mx(session, "set-mark-command")
            _mx(session, "forward-char")
            _mx(session, "exchange-point-and-mark")
            session.wait_for_region_cursor("body", 0)
            output, code = session.quit()
    _assert_exit_zero("movement/set-mark-command", output, code)


@scenario(
    "movement/fullwidth cursor column",
    commands=["execute-extended-command", "forward-char"],
)
def fullwidth_cursor_column(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _write_file(directory, "fullwidth.txt", "あい\n".encode())
        with Session(binary, [path]) as session:
            session.wait_ready()
            _mx(session, "forward-char")
            session.wait_for_region_cursor("body", 2)
            output, code = session.quit()
    _assert_exit_zero("movement/fullwidth cursor column", output, code)


@scenario(
    "movement/horizontal scroll follow",
    commands=["execute-extended-command", "move-end-of-line"],
)
def horizontal_scroll_follow(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _write_file(directory, "horizontal.py", b"abcdefghijklmnop\n")
        with Session(binary, [path], columns=12, rows=8) as session:
            session.wait_ready()
            _mx(session, "move-end-of-line")
            session.wait_for_region_cursor("body", 11)
            row = session.region_text("body")
            if not row.startswith("fgh") or not row.rstrip().endswith("p"):
                raise AssertionError(f"horizontal viewport did not follow point: {row!r}")
            output, code = session.quit()
    _assert_exit_zero("movement/horizontal scroll follow", output, code)


@scenario("movement/wrapped next-line", commands=["execute-extended-command", "next-line"])
def wrapped_next_line(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = _write_file(directory, "wrapped.md", b"abcdefghijklmnop\nnext\n")
        with Session(binary, [path], columns=12, rows=8) as session:
            session.wait_ready()
            _mx(session, "next-line")
            session.wait_for_region_text("body", "abcdefghijkl", index=0)
            session.wait_for_region_text("body", "mnop", index=1)
            session.wait_for_region_cursor("body", 0, index=1)
            output, code = session.quit()
    _assert_exit_zero("movement/wrapped next-line", output, code)
