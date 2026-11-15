"""File control characters must stay out of terminal output when rendered."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


@scenario("files/control-characters", commands=["save-buffer"])
def text_control_characters(binary):
    osc = b"\x1b]0;s1-title\x07"
    sgr = b"\x1b[31m"
    c1_csi = "\u009b2J".encode("utf-8")
    contents = b"\n".join(
        (
            b"before-OSC" + osc + b"after-OSC",
            b"before-SGR" + sgr + b"after-SGR",
            b"before-C1" + c1_csi + b"after-C1 remains visible",
        )
    ) + b"\n"

    with tempfile.TemporaryDirectory(prefix="loom-e2e-controls-") as directory:
        directory = os.path.realpath(directory)
        path = os.path.join(directory, "controls.txt")
        with open(path, "wb") as handle:
            handle.write(contents)

        with Session(binary, [path]) as session:
            session.wait_ready()
            for visible_text in (
                "before-OSC",
                "after-OSC",
                "before-SGR",
                "after-SGR",
                "before-C1",
                "after-C1 remains visible",
            ):
                session.wait_for_region_contents("body", visible_text)

            session.save_buffer(path, contents)
            session.wait_for_region_exact_text("minibuffer", f"Wrote {path}")
            session.assert_file_bytes(path, contents)

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"text control character scenario exited with {code}: {output!r}"
                )

            terminal_output = session.output_bytes
            for label, sequence in (
                ("OSC", osc),
                ("SGR", sgr),
                ("C1 CSI", c1_csi),
            ):
                if session.observe_pty_output(
                    terminal_output,
                    sequence,
                    match="not_contains",
                    purpose=f"{label} control sequence stays out of terminal output",
                ) is not True:
                    raise AssertionError(
                        f"S1: raw {label} control sequence reached terminal output: "
                        f"{sequence!r}; output was {terminal_output!r}"
                    )
