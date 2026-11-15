"""Exercise the prompted save-some-buffers command through the PTY."""

from pathlib import Path
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import DEFAULT_TIMEOUT, Session


_FIRST = b"alpha\n"
_SECOND = b"beta\n"
_EXTERNAL = b"external\n"


def _session(binary, path):
    return Session(binary, [str(path)], columns=160)


def _edit_current(session, expected):
    session.type("!")
    session.wait_for_region_exact_text("body", expected, index=0)


def _open_second_modified(session, second_path):
    _edit_current(session, "!alpha")
    session.extended_command("find-file")
    session.wait_for_region_text("minibuffer", "Find file: ")
    session.type(str(second_path))
    session.key("RET")
    session.wait_for_region_exact_text("body", "beta", index=0)
    _edit_current(session, "!beta")


def _start_save_some_buffers(session):
    after = session.command_trace_count()
    session.send(keys.ctrl("x") + b"s")
    return after


def _wait_for_prompt(session, path):
    session.wait_for_region_text(
        "minibuffer", f"Save file {path.resolve()}? (y, n, !, q, C-g)"
    )


def _finish_command(session, after):
    session.wait_for_command_completion(
        "save-some-buffers", route="key", after=after
    )


def _quit_discarding(session):
    session.send(keys.ctrl("x") + keys.ctrl("c"))
    session.wait_for_region_text("minibuffer", "Save ")
    session.wait_for_region_text("minibuffer", "(s/d/c):")
    session.type("d")
    session.key("RET")
    output, code = session.process.wait(timeout=DEFAULT_TIMEOUT)
    session.observe_exit_code(code, expected=0)
    if code != 0:
        raise AssertionError(f"discarding modified buffers exited with {code}: {output!r}")


@scenario("files/save-some-buffers-n", commands=["save-some-buffers"])
def save_some_buffers_n(binary):
    with tempfile.TemporaryDirectory(prefix="loom-save-some-buffers-") as directory:
        path = Path(directory) / "buffer.txt"
        path.write_bytes(_FIRST)
        with _session(binary, path) as session:
            session.wait_ready()
            _edit_current(session, "!alpha")
            after = _start_save_some_buffers(session)
            _wait_for_prompt(session, path)
            session.type("n")
            session.wait_for_region_text("minibuffer", "Saved 0 file(s)")
            _finish_command(session, after)
            session.assert_file_bytes(path, _FIRST)
            _quit_discarding(session)


@scenario("files/save-some-buffers-bang", commands=["save-some-buffers", "find-file"])
def save_some_buffers_bang(binary):
    with tempfile.TemporaryDirectory(prefix="loom-save-some-buffers-") as directory:
        first_path = Path(directory) / "first.txt"
        second_path = Path(directory) / "second.txt"
        first_path.write_bytes(_FIRST)
        second_path.write_bytes(_SECOND)
        with _session(binary, first_path) as session:
            session.wait_ready()
            _open_second_modified(session, second_path)
            after = _start_save_some_buffers(session)
            _wait_for_prompt(session, second_path)
            session.type("!")
            session.wait_for_region_text("minibuffer", "Saved 2 file(s)")
            _finish_command(session, after)
            session.assert_file_bytes(first_path, b"!alpha\n")
            session.assert_file_bytes(second_path, b"!beta\n")
            session.quit()


@scenario("files/save-some-buffers-q", commands=["save-some-buffers", "find-file"])
def save_some_buffers_q(binary):
    with tempfile.TemporaryDirectory(prefix="loom-save-some-buffers-") as directory:
        first_path = Path(directory) / "first.txt"
        second_path = Path(directory) / "second.txt"
        first_path.write_bytes(_FIRST)
        second_path.write_bytes(_SECOND)
        with _session(binary, first_path) as session:
            session.wait_ready()
            _open_second_modified(session, second_path)
            after = _start_save_some_buffers(session)
            _wait_for_prompt(session, second_path)
            session.type("y")
            _wait_for_prompt(session, first_path)
            session.type("q")
            session.wait_for_region_text("minibuffer", "Saved 1 file(s)")
            _finish_command(session, after)
            session.assert_file_bytes(first_path, _FIRST)
            session.assert_file_bytes(second_path, b"!beta\n")
            _quit_discarding(session)


@scenario(
    "files/save-some-buffers-external-change",
    commands=["save-some-buffers"],
)
def save_some_buffers_external_change(binary):
    with tempfile.TemporaryDirectory(prefix="loom-save-some-buffers-") as directory:
        path = Path(directory) / "buffer.txt"
        path.write_bytes(_FIRST)
        with _session(binary, path) as session:
            session.wait_ready()
            _edit_current(session, "!alpha")
            path.write_bytes(_EXTERNAL)
            session.assert_file_bytes(path, _EXTERNAL)

            after = _start_save_some_buffers(session)
            _wait_for_prompt(session, path)
            session.type("y")
            session.wait_for_region_text("minibuffer", "Overwrite? (y/n): ")
            session.type("n")
            session.key("RET")
            session.wait_for_region_text("minibuffer", "Saved 0 file(s)")
            _finish_command(session, after)
            session.assert_file_bytes(path, _EXTERNAL)
            _quit_discarding(session)


def _single_prompt_scenario(binary, response):
    with tempfile.TemporaryDirectory(prefix="loom-save-some-buffers-") as directory:
        path = Path(directory) / "buffer.txt"
        path.write_bytes(_FIRST)
        with _session(binary, path) as session:
            session.wait_ready()
            _edit_current(session, "!alpha")
            after = _start_save_some_buffers(session)
            _wait_for_prompt(session, path)

            if response == "accept":
                session.type("y")
                session.wait_for_prompted_file(
                    path, b"!alpha\n", "Saved 1 file(s)"
                )
                _finish_command(session, after)
                session.assert_file_bytes(path, b"!alpha\n")
                session.quit()
            elif response == "cancel":
                session.send(keys.ctrl("g"))
                session.wait_for_region_text("minibuffer", "Quit")
                session.assert_screen_text(
                    "Quit", region="minibuffer", match="contains"
                )
                _finish_command(session, after)
                session.assert_file_bytes(path, _FIRST)
                _quit_discarding(session)
            else:
                session.type("x")
                session.wait_for_region_text(
                    "minibuffer", "Allowed keys: y, n, !, q"
                )
                session.assert_screen_text(
                    "Save file", region="minibuffer", match="contains"
                )
                session.assert_screen_text(
                    "Allowed keys: y, n, !, q",
                    region="minibuffer",
                    match="contains",
                )
                session.send(keys.ctrl("g"))
                session.wait_for_region_text("minibuffer", "Quit")
                session.assert_screen_text(
                    "Quit", region="minibuffer", match="contains"
                )
                _finish_command(session, after)
                session.assert_file_bytes(path, _FIRST)
                _quit_discarding(session)


@scenario(
    "command-path/r2/save-some-buffers/prompt-1/char/accept",
    commands=["save-some-buffers"],
)
def save_some_buffers_prompt_accept(binary):
    _single_prompt_scenario(binary, "accept")


@scenario(
    "command-path/r2/save-some-buffers/prompt-1/char/cancel",
    commands=["save-some-buffers"],
)
def save_some_buffers_prompt_cancel(binary):
    _single_prompt_scenario(binary, "cancel")


@scenario(
    "command-path/r2/save-some-buffers/prompt-1/char/invalid",
    commands=["save-some-buffers"],
)
def save_some_buffers_prompt_invalid(binary):
    _single_prompt_scenario(binary, "invalid")
