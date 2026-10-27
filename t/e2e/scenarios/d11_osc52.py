"""OSC 52 clipboard behavior through Loom's real PTY entry point."""

import base64
import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


@scenario(
    "clipboard-mouse/d11-mw-osc52",
    commands=[
        "set-mark-command",
        "kill-ring-save",
        "save-buffers-kill-terminal",
    ],
)
def meta_writes_osc52_to_terminal(binary):
    copied_text = b"hello"
    expected = b"\x1b]52;c;" + base64.b64encode(copied_text) + b"\x07"

    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        fake_bin = os.path.join(directory, "bin")
        os.makedirs(fake_bin)
        for utility in ("pbcopy", "wl-copy"):
            utility_path = os.path.join(fake_bin, utility)
            with open(utility_path, "w", encoding="utf-8") as handle:
                handle.write("#!/bin/sh\nexec /bin/cat >/dev/null\n")
            os.chmod(utility_path, 0o755)

        path = os.path.join(directory, "copy.txt")
        with open(path, "wb") as handle:
            handle.write(b"hello-world\n")

        previous_path = os.environ.get("PATH")
        try:
            os.environ["PATH"] = fake_bin + (
                os.pathsep + previous_path if previous_path else ""
            )
            with Session(binary, [path]) as session:
                session.wait_ready()
                session.extended_command("set-mark-command")
                session.send(keys.ctrl("f") * len(copied_text))
                session.wait_for_region_cursor("body", len(copied_text))
                session.send(keys.meta("w"))
                session.pump()
                output, code = session.quit()
                if code != 0:
                    raise AssertionError(
                        f"M-w clipboard scenario exited with {code}: {output!r}"
                    )

                terminal_output = session.output_bytes
                if session.observe_pty_output(
                    terminal_output,
                    expected,
                    match="contains",
                    purpose="M-w OSC 52 clipboard payload",
                ) is not True:
                    raise AssertionError(
                        "D11: M-w omitted OSC 52 clipboard bytes "
                        f"{expected!r}; terminal output was {terminal_output!r}"
                    )
        finally:
            if previous_path is None:
                os.environ.pop("PATH", None)
            else:
                os.environ["PATH"] = previous_path
