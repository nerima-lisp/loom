"""Preserve file format bytes when saving edited buffers."""

import os
import tempfile

from loom_e2e.registry import scenario
from loom_e2e.session import Session


_SOURCE = b"\xef\xbb\xbfalpha\r\nbeta\n\xffomega\r\n"
_EDITED = b"\xef\xbb\xbf!alpha\r\nbeta\n\xffomega\r\n"


@scenario("files/file-format-preservation", commands=["save-buffer"])
def file_format_preservation(binary):
    with tempfile.TemporaryDirectory(prefix="loom-files-format-") as directory:
        path = os.path.join(directory, "mixed.txt")
        with open(path, "wb") as handle:
            handle.write(_SOURCE)

        stage = "session startup"
        try:
            with Session(binary, [path]) as session:
                stage = "initial frame"
                session.wait_ready()
                stage = "initial file content"
                session.wait_for_region_exact_text("body", "alpha", index=0)
                stage = "typing edit"
                session.type("!")
                stage = "edited body"
                session.wait_for_region_text("body", "!alpha", index=0)
                stage = "M-x save-buffer"
                session.extended_command("save-buffer")
                stage = "saved file bytes"
                session.wait_for_file(path, _EDITED)
                stage = "file byte assertion"
                session.assert_file_bytes(path, _EDITED)
                stage = "quit"
                output, code = session.quit()
        except TimeoutError as error:
            print(
                f"file-format-preservation timed out at {stage}: {error}",
                flush=True,
            )
            raise
        if code != 0:
            raise AssertionError(
                f"file-format-preservation exited with {code}: {output!r}"
            )
