"""Exercise Nix indentation through its editing keys."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


# Behavior follows NixOS nix-mode 1.5.0: two-column indentation, opener and
# matching-closer rules, let/in alignment, the `with expr ; expr`
# continuation, and tokenization that skips strings and comments.
# The pinned source marks `with`/`assert` semicolons as non-separating.
# https://github.com/NixOS/nix-mode/blob/2c77e7e0b7540efbb20ccaee3557ef90a5dc77f0/nix-mode.el
def _write(path, content):
    with open(path, "wb") as handle:
        handle.write(content)


def _save(session, path, expected):
    session.send(keys.ctrl("x") + keys.ctrl("s"))
    session.wait_for_file(path, expected)
    session.assert_file_bytes(path, expected)


def _close(session, name):
    output, code = session.quit()
    if session.observe_exit_code(code, 0) is not True:
        raise AssertionError(f"{name}: loom exited with {code}: {output!r}")


@scenario(
    "lang-nix-indentation-ret",
    commands=["newline", "save-buffer"],
)
def lang_nix_indentation_ret(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "ret.nix")
        _write(path, b"root = {\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.send(keys.ctrl("e"))
            session.wait_for_region_cursor("body", 8, index=0)
            session.key("RET")
            session.wait_for_region_cursor("body", 2, index=1)
            expected = b"root = {\n  \n"
            _save(session, path, expected)
            _close(session, "lang-nix-indentation-ret")


@scenario(
    "lang-nix-indentation-tab",
    commands=["indent-for-tab-command", "save-buffer"],
)
def lang_nix_indentation_tab(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "tab.nix")
        _write(
            path,
            b'root = rec {\nvalue = "}"; # }\ntext = \'\'\n}\n\'\';\n       child = 1;\n  withcase = {\npackages = with pkgs;\nvalue;\n};\n  later = with pkgs; { nested = 1; };\nchild2 = 2;\n      }\n',
        )

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.send(keys.ctrl("n") * 5)
            session.key("TAB")
            session.wait_for_region_cursor("body", 0, index=5)
            session.send(keys.ctrl("n"))
            session.key("TAB")
            session.send(keys.ctrl("n"))
            session.key("TAB")
            session.send(keys.ctrl("n"))
            session.key("TAB")
            session.send(keys.ctrl("n"))
            session.key("TAB")
            session.send(keys.ctrl("n"))
            session.key("TAB")
            session.send(keys.ctrl("n"))
            session.key("TAB")
            session.send(keys.ctrl("n"))
            session.key("TAB")
            expected = (
                b'root = rec {\n'
                b'value = "}"; # }\n'
                b"text = ''\n"
                b"}\n"
                b"'';\n"
                b"  child = 1;\n"
                b"  withcase = {\n"
                b"    packages = with pkgs;\n"
                b"      value;\n"
                b"  };\n"
                b"  later = with pkgs; { nested = 1; };\n"
                b"  child2 = 2;\n"
                b"}\n"
            )
            _save(session, path, expected)
            _close(session, "lang-nix-indentation-tab")


@scenario(
    "lang-nix-indentation-control-meta-backslash",
    commands=["set-mark-command", "indent-for-tab-command", "save-buffer"],
)
def lang_nix_indentation_control_meta_backslash(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "region.nix")
        _write(
            path,
            b"let\nvalue = [\n(\nif\ncondition\nthen\nbranch\nelse\nfallback\n)\n]\nin\nwith pkgs;\nvalue\n",
        )

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("set-mark-command")
            session.send(keys.ctrl("n") * 13 + keys.ctrl("e"))
            session.send(b"\x1b" + keys.ctrl("\\"))
            expected = (
                b"let\n"
                b"  value = [\n"
                b"    (\n"
                b"      if\n"
                b"        condition\n"
                b"      then\n"
                b"        branch\n"
                b"      else\n"
                b"        fallback\n"
                b"    )\n"
                b"  ]\n"
                b"in\n"
                b"with pkgs;\n"
                b"  value\n"
            )
            _save(session, path, expected)
            _close(session, "lang-nix-indentation-control-meta-backslash")
