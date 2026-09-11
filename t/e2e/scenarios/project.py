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
            session.send(keys.RET)
            session.type("a")
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(other_path, b"aother\n")

            output, code = session.quit()
        _assert_exit_zero("project find file", output, code)


@scenario("project search", commands=["project-search", "previous-line"])
def project_search(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        source_directory = os.path.join(directory, "src")
        ignored_directory = os.path.join(directory, "target")
        os.mkdir(source_directory)
        os.mkdir(ignored_directory)
        with open(os.path.join(directory, "flake.nix"), "wb") as handle:
            handle.write(b"{}\n")
        source_path = os.path.join(source_directory, "main.py")
        with open(source_path, "wb") as handle:
            handle.write(b"needle\n")
        with open(os.path.join(ignored_directory, "generated.py"), "wb") as handle:
            handle.write(b"needle\n")

        with Session(binary, [source_path]) as session:
            session.wait_ready()
            session.send(keys.ctrl("x") + b"ps")
            session.wait_for_text("Project search: ")
            session.type("needle")
            session.send(keys.RET)
            # Rendering occurs in the same event-loop turn as RET.
            session.wait_for_text("Matches:")
            if session.screen.find("src/main.py:1") is None:
                raise AssertionError(
                    f"project search output missing the source match:\n{session.screen.dump()}"
                )

            output, code = session.quit()
        _assert_exit_zero("project search", output, code)
