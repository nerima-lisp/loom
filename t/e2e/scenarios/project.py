"""Project-relative file navigation and project-wide search."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _assert_exit_zero(name, output, code):
    if code != 0:
        raise AssertionError(f"{name} exited with {code}: {output!r}")


@scenario("project find file", commands=["project-find-file", "save-buffer"])
def project_find_file(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        source_directory = os.path.join(directory, "src")
        os.mkdir(source_directory)
        with open(os.path.join(directory, "flake.nix"), "wb") as handle:
            handle.write(b"{}\n")
        main_path = os.path.join(source_directory, "main.txt")
        other_path = os.path.join(source_directory, "other.txt")
        with open(main_path, "wb") as handle:
            handle.write(b"main\n")
        with open(other_path, "wb") as handle:
            handle.write(b"other\n")

        with Session(binary, [main_path]) as session:
            session.wait_ready()
            session.send(keys.ctrl("x") + b"pf")
            session.wait_for_text("Project file: ")
            session.type("src/other.txt")
            session.key("RET")
            session.type("a")
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(other_path, b"aother\n")

            output, code = session.quit()
        _assert_exit_zero("project find file", output, code)


@scenario(
    "project search",
    commands=["project-search", "search-result-visit", "search-next-error"],
)
def project_search(binary):
    with tempfile.TemporaryDirectory(prefix="p-", dir="/tmp") as directory:
        source_directory = os.path.join(directory, "src")
        ignored_directory = os.path.join(directory, "target")
        os.mkdir(source_directory)
        os.mkdir(ignored_directory)
        with open(os.path.join(directory, "flake.nix"), "wb") as handle:
            handle.write(b"{}\n")
        source_path = os.path.join(source_directory, "main.py")
        with open(source_path, "wb") as handle:
            handle.write(b"first needle\nsecond needle\n")
        with open(os.path.join(ignored_directory, "generated.py"), "wb") as handle:
            handle.write(b"needle\n")

        with Session(binary, [source_path]) as session:
            session.wait_ready()
            session.send(keys.ctrl("x") + b"ps")
            print("DEBUG project search prompt", repr(session.region_text("minibuffer")), flush=True)
            session.wait_for_text("Project search: ")
            session.type("needle")
            session.key("RET")
            print("DEBUG project search submitted", repr(session.region_text("minibuffer")), repr(session.region_text("body")), flush=True)
            session.wait_for_text("Matches:")
            session.wait_for_text("src/main.py:1")
            print("DEBUG project search result", repr(session.region_text("minibuffer")), repr(session.region_text("body")), flush=True)
            session.key("RET")
            print("DEBUG project search visit", repr(session.region_text("minibuffer")), repr(session.region_text("body")), flush=True)
            session.wait_for_region_cursor("body", 6, index=0)
            session.send(keys.meta("g") + b"n")
            session.wait_for_region_cursor("body", 7, index=1)

            output, code = session.quit()
        _assert_exit_zero("project search", output, code)
