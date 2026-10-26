"""Exercise find-file path completion and candidate filtering through the PTY."""

# GNU Emacs documents the TAB completion command here:
# https://www.gnu.org/software/emacs/manual/html_node/emacs/Completion-Commands.html
import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


@scenario("completion/find-file-flex-path", commands=["find-file"])
def find_file_partial_path_completion(binary):
    # GNU Emacs documents TAB completion and alternative listing here:
    # https://www.gnu.org/software/emacs/manual/html_node/emacs/Completion-Commands.html
    with tempfile.TemporaryDirectory(
        prefix="ff-", dir="/tmp"
    ) as directory:
        first_path = "foo-bar.txt"
        second_path = "foo-baz.txt"
        other_path = "other-gamma.txt"
        start_path = "start.txt"
        for path, content in (
            (os.path.join(directory, first_path), b"bar candidate\n"),
            (os.path.join(directory, second_path), b"second candidate\n"),
            (os.path.join(directory, other_path), b"unmatched candidate\n"),
            (os.path.join(directory, start_path), b"initial buffer\n"),
        ):
            with open(path, "wb") as handle:
                handle.write(content)

        previous_directory = os.getcwd()
        os.chdir(directory)
        try:
            with Session(binary, [start_path]) as session:
                session.wait_ready()
                session.send(keys.ctrl("x") + keys.ctrl("f"))
                session.wait_for_region_text("minibuffer", "Find file: ")

                partial_path = "fb"
                session.type(partial_path)
                session.key("TAB")
                session.wait_for_region_exact_text(
                    "minibuffer", f"Find file: {partial_path}"
                )
                first_candidate_row = session.layout.minibuffer_row - 2
                session.wait_for_row_text(first_candidate_row, "foo-bar.txt")
                session.wait_for_row_text(first_candidate_row + 1, "foo-baz.txt")
                session.assert_screen_text(
                    "other-gamma.txt", match="not_contains", region="screen"
                )

                session.type("r")
                session.wait_for_region_exact_text("minibuffer", "Find file: fbr")
                session.wait_for_text("foo-bar.txt")
                session.wait_for_text_absent("foo-baz.txt")

                session.key("TAB")
                session.wait_for_region_exact_text(
                    "minibuffer", f"Find file: {first_path}"
                )
                session.key("RET")
                session.wait_for_region_exact_text("body", "bar candidate")

                output, code = session.quit()
                if code != 0:
                    raise AssertionError(
                        f"completion/find-file-flex-path exited with {code}: "
                        f"{output!r}"
                    )
        finally:
            os.chdir(previous_directory)
