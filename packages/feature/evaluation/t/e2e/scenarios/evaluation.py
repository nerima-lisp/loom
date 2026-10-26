"""Exercise evaluation command routing through real terminal input."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


_SOURCE = b"(+ 1 2)\n"


@scenario("evaluation/eval-last-sexp", commands=["eval-last-sexp"])
def eval_last_sexp_key(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "expression.lisp")
        with open(path, "wb") as handle:
            handle.write(_SOURCE)

        with Session(binary, [path]) as session:
            session.wait_ready(timeout=2.0)
            session.send(keys.ctrl("x") + keys.ctrl("e"))
            session.wait_for_region_text(
                "minibuffer", "No Lisp expression before point", timeout=0.75
            )
            session.wait_for_region_cursor("body", 0, timeout=0.5)
            session.assert_screen_text(
                "No Lisp expression before point", match="contains", region="minibuffer"
            )
            session.assert_file_bytes(path, _SOURCE)
            if session.observe_cursor(expected=(0, 0), region="body") is not True:
                raise AssertionError(
                    f"cursor was {session.region_cursor('body')!r}, expected {(0, 0)!r}"
                )
            output, code = session.quit(timeout=1.0)

        if code != 0:
            raise AssertionError(f"evaluation/eval-last-sexp exited with {code}: {output!r}")


@scenario("evaluation/eval-last-sexp-mx", commands=["eval-last-sexp"])
def eval_last_sexp_mx(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "expression.lisp")
        with open(path, "wb") as handle:
            handle.write(_SOURCE)

        with Session(binary, [path]) as session:
            session.wait_ready(timeout=2.0)
            session.extended_command("eval-last-sexp")
            session.wait_for_region_text(
                "minibuffer", "No Lisp expression before point", timeout=0.75
            )
            session.wait_for_region_cursor("body", 0, timeout=0.5)
            session.assert_screen_text(
                "No Lisp expression before point", match="contains", region="minibuffer"
            )
            session.assert_file_bytes(path, _SOURCE)
            if session.observe_cursor(expected=(0, 0), region="body") is not True:
                raise AssertionError(
                    f"cursor was {session.region_cursor('body')!r}, expected {(0, 0)!r}"
                )
            output, code = session.quit(timeout=1.0)

        if code != 0:
            raise AssertionError(
                f"evaluation/eval-last-sexp-mx exited with {code}: {output!r}"
            )
