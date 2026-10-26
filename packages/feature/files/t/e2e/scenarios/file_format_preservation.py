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

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.type("!")
            session.wait_for_region_text("body", "!alpha", index=0)
            session.extended_command("save-buffer")
            session.wait_for_file(path, _EDITED)
            session.assert_file_bytes(path, _EDITED)
            output, code = session.quit()
        if code != 0:
            raise AssertionError(
                f"file-format-preservation exited with {code}: {output!r}"
            )
