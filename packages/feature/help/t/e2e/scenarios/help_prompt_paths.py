"""Exercise the help commands' prompt outcomes through the PTY interface."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _open_prompt(session, key, prompt):
    session.send(keys.ctrl("h") + key.encode("ascii"))
    session.wait_for_region_text("minibuffer", prompt)


def _quit(session, name):
    output, code = session.quit()
    if code != 0:
        raise AssertionError(f"{name} exited with {code}: {output!r}")


@scenario("help/prompt-paths/describe-key", commands=["describe-key"])
def describe_key_prompt_paths(binary):
    # GNU Emacs documents C-h k and key help here:
    # https://www.gnu.org/software/emacs/manual/html_node/emacs/Key-Help.html
    # Minibuffer history traversal uses M-p/M-n:
    # https://www.gnu.org/software/emacs/manual/html_node/emacs/Minibuffer-History.html
    with tempfile.TemporaryDirectory(prefix="loom-e2e-help-key-") as directory:
        path = os.path.join(directory, "start.txt")
        with open(path, "wb") as handle:
            handle.write(b"abc\n")

        with Session(binary, [path]) as session:
            session.wait_ready()

            _open_prompt(session, "k", "Describe key: ")
            session.type("C-f")
            session.key("RET")
            session.wait_for_text("forward-char (forward-char)")
            session.assert_screen_text("forward-char (forward-char)", region="body")

            _open_prompt(session, "k", "Describe key: ")
            session.type("C-f")
            session.send(keys.ctrl("g"))
            session.wait_for_region_exact_text("minibuffer", "Quit")
            session.assert_screen_text("Quit", region="minibuffer")

            _open_prompt(session, "k", "Describe key: ")
            session.key("RET")
            session.wait_for_text("Could not parse key sequence:")
            session.assert_screen_text("Could not parse key sequence:", region="body")

            _open_prompt(session, "k", "Describe key: ")
            session.type("C-f")
            session.key("TAB")
            session.wait_for_region_exact_text("minibuffer", "Describe key: C-f")
            session.assert_screen_text("Describe key: C-f", region="minibuffer")
            session.key("RET")
            session.wait_for_text("forward-char (forward-char)")
            session.assert_screen_text("forward-char (forward-char)", region="body")

            _open_prompt(session, "k", "Describe key: ")
            session.send(keys.meta("p"))
            session.wait_for_region_exact_text("minibuffer", "Describe key: C-f")
            session.assert_screen_text("Describe key: C-f", region="minibuffer")
            session.key("RET")
            session.wait_for_text("forward-char (forward-char)")
            session.assert_screen_text("forward-char (forward-char)", region="body")

            _quit(session, "help/prompt-paths/describe-key")


@scenario("help/prompt-paths/describe-command", commands=["describe-command"])
def describe_command_prompt_paths(binary):
    # GNU Emacs documents C-h x and command help here:
    # https://www.gnu.org/software/emacs/manual/html_node/emacs/Help-Summary.html
    # Completion and history are minibuffer interactions:
    # https://www.gnu.org/software/emacs/manual/html_node/emacs/Completion-Commands.html
    # https://www.gnu.org/software/emacs/manual/html_node/emacs/Minibuffer-History.html
    with tempfile.TemporaryDirectory(prefix="loom-e2e-help-command-") as directory:
        path = os.path.join(directory, "start.txt")
        with open(path, "wb") as handle:
            handle.write(b"abc\n")

        with Session(binary, [path]) as session:
            session.wait_ready()

            _open_prompt(session, "x", "Describe command: ")
            session.type("forward-char")
            session.key("RET")
            session.wait_for_text("forward-char (forward-char)")
            session.assert_screen_text("forward-char (forward-char)", region="body")

            _open_prompt(session, "x", "Describe command: ")
            session.type("forward-char")
            session.send(keys.ctrl("g"))
            session.wait_for_region_exact_text("minibuffer", "Quit")
            session.assert_screen_text("Quit", region="minibuffer")

            _open_prompt(session, "x", "Describe command: ")
            session.key("RET")
            session.wait_for_text("No command named .")
            session.assert_screen_text("No command named .", region="body")

            _open_prompt(session, "x", "Describe command: ")
            session.type("forward-cha")
            session.key("TAB")
            session.wait_for_region_exact_text(
                "minibuffer", "Describe command: forward-char"
            )
            session.assert_screen_text(
                "Describe command: forward-char", region="minibuffer"
            )
            session.key("RET")
            session.wait_for_text("forward-char (forward-char)")
            session.assert_screen_text("forward-char (forward-char)", region="body")

            _open_prompt(session, "x", "Describe command: ")
            session.send(keys.meta("p"))
            session.wait_for_region_exact_text(
                "minibuffer", "Describe command: forward-char"
            )
            session.assert_screen_text(
                "Describe command: forward-char", region="minibuffer"
            )
            session.key("RET")
            session.wait_for_text("forward-char (forward-char)")
            session.assert_screen_text("forward-char (forward-char)", region="body")

            _open_prompt(session, "x", "Describe command: ")
            session.type("missing-command")
            session.key("RET")
            session.wait_for_text("No command named missing-command.")
            session.assert_screen_text("No command named missing-command.", region="body")

            _quit(session, "help/prompt-paths/describe-command")
