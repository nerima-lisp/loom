"""Exercise Lisp indentation through real terminal input."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


# Expected indentation follows Emacs 31.1's lisp-indent-function:
# https://github.com/emacs-mirror/emacs/blob/emacs-31.1/lisp/emacs-lisp/lisp-mode.el#L1013-L1063
# https://github.com/emacs-mirror/emacs/blob/emacs-31.1/lisp/emacs-lisp/lisp-mode.el#L1176-L1238
# Common Lisp LOOP/FLET macro indentation:
# https://github.com/emacs-mirror/emacs/blob/emacs-31.1/lisp/emacs-lisp/cl-indent.el#L141-L273
# https://www.gnu.org/software/emacs/manual/html_node/elisp/Indenting-Macros.html
def _write(path, content):
    with open(path, "wb") as handle:
        handle.write(content)


def _save(session, path, expected):
    session.send(keys.ctrl("x") + keys.ctrl("s"))
    session.wait_for_file(path, expected, timeout=0.75)
    session.assert_file_bytes(path, expected)


def _assert_cursor(session, row, column):
    session.wait_for_region_cursor("body", column, index=row, timeout=0.75)
    if session.observe_cursor(expected=(row, column), region="body") is not True:
        raise AssertionError(
            f"cursor was {session.region_cursor('body')!r}, expected {(row, column)!r}"
        )


def _assert_exit_zero(name, output, code):
    if code != 0:
        raise AssertionError(f"{name} exited with {code}: {output!r}")


@scenario("lang-lisp/indent-ret", commands=["newline", "save-buffer"])
def lisp_indent_ret(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "ret.lisp")
        _write(path, b"(when ready\n)")

        with Session(binary, [path]) as session:
            session.wait_ready(timeout=2.0)
            session.send(keys.ctrl("e") + keys.key("RET"))
            _assert_cursor(session, 1, 2)
            session.assert_screen_text(
                "  ", match="starts_with", region="body", index=1
            )
            _save(session, path, b"(when ready\n  \n)")
            output, code = session.quit(timeout=1.0)
        _assert_exit_zero("lang-lisp/indent-ret", output, code)


@scenario("lang-lisp/indent-tab", commands=["indent-for-tab-command", "save-buffer"])
def lisp_indent_tab(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "tab.lisp")
        _write(path, b"(consume value\nx\n)\n")

        with Session(binary, [path]) as session:
            session.wait_ready(timeout=2.0)
            session.send(keys.key("DOWN") + keys.key("TAB"))
            _assert_cursor(session, 1, 9)
            session.assert_screen_text(
                "         x", match="starts_with", region="body", index=1
            )
            _save(session, path, b"(consume value\n         x\n)\n")
            output, code = session.quit(timeout=1.0)
        _assert_exit_zero("lang-lisp/indent-tab", output, code)


@scenario(
    "lang-lisp/indent-special-forms",
    commands=["indent-for-tab-command", "save-buffer"],
)
def lisp_indent_special_forms(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "special-forms.lisp")
        _write(
            path,
            b'(defun process (x)\n'
            b'(let ((items (list "([;])" x))) #| ) ( |#\n'
            b'(when items ; )\n'
            b'(flet ((helper (item) (list item)))\n'
            b'(loop for item in items collect (helper item))\n'
            b')\n)\n)\n)\n',
        )

        with Session(binary, [path]) as session:
            session.wait_ready(timeout=2.0)
            session.send(keys.key("DOWN") + keys.key("TAB"))
            _assert_cursor(session, 1, 2)
            session.send(keys.ctrl("n") + keys.ctrl("a") + keys.key("TAB"))
            _assert_cursor(session, 2, 4)
            session.send(keys.ctrl("n") + keys.ctrl("a") + keys.key("TAB"))
            _assert_cursor(session, 3, 6)
            session.send(keys.ctrl("n") + keys.ctrl("a") + keys.key("TAB"))
            _assert_cursor(session, 4, 8)
            session.assert_screen_text(
                "        (loop for item",
                match="starts_with",
                region="body",
                index=4,
            )
            _save(
                session,
                path,
                b'(defun process (x)\n'
                b'  (let ((items (list "([;])" x))) #| ) ( |#\n'
                b'    (when items ; )\n'
                b'      (flet ((helper (item) (list item)))\n'
                b'        (loop for item in items collect (helper item))\n'
                b')\n)\n)\n)\n',
            )
            output, code = session.quit(timeout=1.0)
        _assert_exit_zero("lang-lisp/indent-special-forms", output, code)


@scenario(
    "lang-lisp/indent-elisp",
    commands=["indent-for-tab-command", "save-buffer"],
)
def elisp_indent_special_forms(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "special-forms.el")
        _write(
            path,
            b'(defun el-f (x)\n'
            b'(let ((value (list "([;])" x))) #| ) ( |#\n'
            b'(when value ; )\n'
            b'(lambda (item)\n'
            b'(+ item value))\n)\n)\n)\n',
        )

        with Session(binary, [path]) as session:
            session.wait_ready(timeout=2.0)
            session.send(keys.key("DOWN") + keys.key("TAB"))
            _assert_cursor(session, 1, 2)
            session.send(keys.ctrl("n") + keys.ctrl("a") + keys.key("TAB"))
            _assert_cursor(session, 2, 4)
            session.send(keys.ctrl("n") + keys.ctrl("a") + keys.key("TAB"))
            _assert_cursor(session, 3, 6)
            session.send(keys.ctrl("n") + keys.ctrl("a") + keys.key("TAB"))
            _assert_cursor(session, 4, 8)
            session.assert_screen_text(
                "        (+ item value))",
                match="starts_with",
                region="body",
                index=4,
            )
            _save(
                session,
                path,
                b'(defun el-f (x)\n'
                b'  (let ((value (list "([;])" x))) #| ) ( |#\n'
                b'    (when value ; )\n'
                b'      (lambda (item)\n'
                b'        (+ item value))\n)\n)\n)\n',
            )
            output, code = session.quit(timeout=1.0)
        _assert_exit_zero("lang-lisp/indent-elisp", output, code)


@scenario(
    "lang-lisp/indent-cl-flet-loop",
    commands=["indent-for-tab-command", "save-buffer"],
)
def common_lisp_flet_and_loop(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "flet-loop.lisp")
        _write(
            path,
            b"(flet ((helper (item)\n"
            b"(list item)))\n"
            b"(helper 1))\n"
            b"(loop for item in items\n"
            b"collect (helper item))\n",
        )

        with Session(binary, [path]) as session:
            session.wait_ready(timeout=2.0)
            session.send(keys.key("DOWN") + keys.key("TAB"))
            _assert_cursor(session, 1, 9)
            session.send(keys.ctrl("n") + keys.ctrl("a") + keys.key("TAB"))
            _assert_cursor(session, 2, 2)
            session.send(
                keys.ctrl("n") + keys.ctrl("n") + keys.ctrl("a") + keys.key("TAB")
            )
            _assert_cursor(session, 4, 6)
            session.assert_screen_text(
                "      collect (helper item))",
                match="starts_with",
                region="body",
                index=4,
            )
            _save(
                session,
                path,
                b"(flet ((helper (item)\n"
                b"         (list item)))\n"
                b"  (helper 1))\n"
                b"(loop for item in items\n"
                b"      collect (helper item))\n",
            )
            output, code = session.quit(timeout=1.0)
        _assert_exit_zero("lang-lisp/indent-cl-flet-loop", output, code)


@scenario(
    "lang-lisp/indent-cl-lambda",
    commands=["indent-for-tab-command", "save-buffer"],
)
def common_lisp_lambda(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "lambda.lisp")
        _write(path, b"(lambda (item)\n(+ item 1))\n")

        with Session(binary, [path]) as session:
            session.wait_ready(timeout=2.0)
            session.send(keys.key("DOWN") + keys.key("TAB"))
            _assert_cursor(session, 1, 2)
            session.assert_screen_text(
                "  (+ item 1)", match="starts_with", region="body", index=1
            )
            _save(session, path, b"(lambda (item)\n  (+ item 1))\n")
            output, code = session.quit(timeout=1.0)
        _assert_exit_zero("lang-lisp/indent-cl-lambda", output, code)


@scenario(
    "lang-lisp/indent-region",
    commands=[
        "move-beginning-of-line",
        "set-mark-command",
        "next-line",
        "move-end-of-line",
        "indent-for-tab-command",
        "save-buffer",
    ],
)
def lisp_indent_region(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "region.lisp")
        _write(
            path,
            b"(defun region-indent (x)\n"
            b"(let ((value x))\n"
            b"(when value\n"
            b"(+ value 1))))\n",
        )

        with Session(binary, [path]) as session:
            session.wait_ready(timeout=2.0)
            session.send(
                keys.ctrl("a")
                + keys.ctrl("@")
                + keys.ctrl("n") * 3
                + keys.ctrl("e")
                + keys.meta("\x1c")
            )
            _assert_cursor(session, 3, 20)
            session.assert_screen_text(
                "      (+ value 1)", match="starts_with", region="body", index=3
            )
            _save(
                session,
                path,
                b"(defun region-indent (x)\n"
                b"  (let ((value x))\n"
                b"    (when value\n"
                b"      (+ value 1))))\n",
            )
            output, code = session.quit(timeout=1.0)
        _assert_exit_zero("lang-lisp/indent-region", output, code)


@scenario(
    "lang-lisp/indent-emacs-cases",
    commands=["indent-for-tab-command", "save-buffer"],
)
def common_lisp_emacs_indent_cases(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "emacs-cases.lisp")
        _write(
            path,
            b"(cond\n(test x))\n"
            b"(case\nkey\n(1 (work)))\n"
            b"(defvar\n*flag*\nt)\n"
            b'(defun f ()\n"doc"\n(body))\n'
            b"(loop\nfor x in xs)\n",
        )

        with Session(binary, [path]) as session:
            session.wait_ready(timeout=2.0)
            previous_row = 0
            for row, column in (
                (1, 2),
                (3, 4),
                (4, 2),
                (6, 4),
                (7, 2),
                (9, 2),
                (10, 2),
                (12, 6),
            ):
                session.send(keys.ctrl("n") * (row - previous_row))
                session.send(keys.ctrl("a") + keys.key("TAB"))
                _assert_cursor(session, row, column)
                previous_row = row
            session.assert_screen_text(
                "      for x in xs)",
                match="starts_with",
                region="body",
                index=12,
            )
            _save(
                session,
                path,
                b"(cond\n  (test x))\n"
                b"(case\n    key\n  (1 (work)))\n"
                b"(defvar\n    *flag*\n  t)\n"
                b'(defun f ()\n  "doc"\n  (body))\n'
                b"(loop\n      for x in xs)\n",
            )
            output, code = session.quit(timeout=1.0)
        _assert_exit_zero("lang-lisp/indent-emacs-cases", output, code)


@scenario(
    "lang-lisp/indent-nested-block-comment",
    commands=["indent-for-tab-command", "save-buffer"],
)
def common_lisp_nested_block_comment(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "nested-comment.lisp")
        _write(
            path,
            b"(defun f ()\n"
            b"#| outer\n"
            b"#| inner |# ) |#\n"
            b"(body))\n",
        )

        with Session(binary, [path]) as session:
            session.wait_ready(timeout=2.0)
            session.send(keys.ctrl("n") * 3 + keys.ctrl("a") + keys.key("TAB"))
            _assert_cursor(session, 3, 2)
            session.assert_screen_text(
                "  (body))", match="starts_with", region="body", index=3
            )
            _save(
                session,
                path,
                b"(defun f ()\n#| outer\n#| inner |# ) |#\n  (body))\n",
            )
            output, code = session.quit(timeout=1.0)
        _assert_exit_zero("lang-lisp/indent-nested-block-comment", output, code)
