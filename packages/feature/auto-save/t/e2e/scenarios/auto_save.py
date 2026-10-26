"""PTY scenario for enabling auto-save on the selected buffer."""

import os
import stat
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _write(path, content):
    with open(path, "wb") as handle:
        handle.write(content)


def _discard_and_close(session, name):
    session.send(keys.ctrl("x") + keys.ctrl("c"))
    session.wait_for_region_text("minibuffer", "Save ", timeout=2)
    session.key("d")
    output, code = session.process.wait()
    session.observe_exit_code(code, expected=0)
    if code != 0:
        raise AssertionError(f"{name} exited with {code}: {output!r}")


@scenario("auto-save/toggle-auto-save", commands=["toggle-auto-save"])
def toggle_auto_save(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "toggle.txt")
        with open(path, "wb") as handle:
            handle.write(b"draft\n")

        with Session(binary, [path]) as session:
            session.wait_ready(timeout=2)
            session.extended_command("toggle-auto-save", timeout=2)
            session.wait_for_region_text(
                "minibuffer", "Auto-save enabled for", timeout=2
            )
            session.assert_screen_text(
                "Auto-save enabled for",
                match="contains",
                region="minibuffer",
            )
            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"auto-save/toggle-auto-save exited with {code}: {output!r}"
                )


@scenario("auto-save/mode-sidecar-write", commands=["auto-save-mode"])
def mode_sidecar_write(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "mode.txt")
        sidecar = os.path.join(directory, "#mode.txt#")
        _write(path, b"draft\n")

        with Session(binary, [path]) as session:
            session.wait_ready(timeout=2)
            session.type("x")
            session.extended_command("auto-save-mode", timeout=2)
            session.wait_for_file(sidecar, b"xdraft\n", timeout=2)
            session.assert_screen_text(
                "Auto-save mode enabled",
                match="contains",
                region="minibuffer",
            )
            session.assert_screen_text(
                "xdraft", match="contains", region="body"
            )
            session.assert_file_bytes(sidecar, b"xdraft\n")
            session.assert_file_bytes(path, b"draft\n")
            _discard_and_close(session, "auto-save/mode-sidecar-write")


@scenario(
    "auto-save/current-buffer-write-failure",
    commands=["auto-save-mode", "auto-save-current-buffer"],
)
def current_buffer_write_failure(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "failure.txt")
        sidecar = os.path.join(directory, "#failure.txt#")
        probe = os.path.join(directory, ".write-probe")
        _write(path, b"draft\n")
        original_mode = stat.S_IMODE(os.stat(directory).st_mode)

        try:
            os.chmod(directory, original_mode & ~0o222)
            try:
                with open(probe, "xb"):
                    pass
            except OSError:
                pass
            else:
                os.unlink(probe)
                os.chmod(directory, original_mode)
                os.mkdir(sidecar)

            with Session(binary, [path]) as session:
                session.wait_ready(timeout=2)
                session.extended_command("auto-save-mode", timeout=2)
                session.type("x")
                session.extended_command("auto-save-current-buffer", timeout=2)
                session.wait_for_region_text(
                    "minibuffer", "Auto-save error:", timeout=2
                )
                session.assert_screen_text(
                    "Auto-save error:",
                    match="contains",
                    region="minibuffer",
                )
                session.assert_screen_text(
                    "xdraft", match="contains", region="body"
                )
                session.assert_file_bytes(path, b"draft\n")
                _discard_and_close(
                    session, "auto-save/current-buffer-write-failure"
                )
        finally:
            os.chmod(directory, original_mode)
