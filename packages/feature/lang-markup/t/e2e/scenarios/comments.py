"""Exercise Markdown and Org comments through M-; in a PTY session."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


@scenario(
    "lang-markup/markdown-org-comment-dwim",
    commands=[
        "comment-line",
        "find-file",
        "forward-char",
        "move-beginning-of-line",
        "next-line",
        "save-buffer",
        "set-mark-command",
    ],
)
def markdown_org_comment_dwim(binary):
    markdown_initial = b"hello\nselected words\n"
    markdown_after_line = b"<!-- hello -->\nselected words\n"
    markdown_after_region = b"<!-- hello -->\n<!-- selected --> words\n"
    org_initial = b"org text\nselected words\n"
    org_after_line = b"# org text\nselected words\n"
    org_after_region = b"# org text\n# selected words\n"

    with tempfile.TemporaryDirectory(prefix="loom-e2e-lang-markup-") as directory:
        markdown_path = os.path.join(directory, "notes.md")
        org_path = os.path.join(directory, "notes.org")
        with open(markdown_path, "wb") as handle:
            handle.write(markdown_initial)
        with open(org_path, "wb") as handle:
            handle.write(org_initial)

        with Session(binary, [markdown_path]) as session:
            session.wait_ready()
            session.wait_for_region_exact_text("body", "hello", index=0)
            session.wait_for_region_cursor("body", 0, index=0)

            session.send(keys.meta(";"))
            session.wait_for_region_exact_text("body", "<!-- hello -->", index=0)
            session.wait_for_region_cursor("body", 5, index=0)
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(markdown_path, markdown_after_line)
            session.assert_file_bytes(markdown_path, markdown_after_line)

            session.send(
                keys.ctrl("n")
                + keys.ctrl("a")
                + b"\x00"
                + keys.ctrl("f") * 8
                + keys.meta(";")
            )
            session.wait_for_region_exact_text(
                "body", "<!-- selected --> words", index=1
            )
            session.wait_for_region_cursor("body", 13, index=1)
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(markdown_path, markdown_after_region)
            session.assert_file_bytes(markdown_path, markdown_after_region)

            session.send(keys.ctrl("x") + keys.ctrl("f"))
            session.wait_for_text("Find file: ")
            session.type(org_path)
            session.key("RET")
            session.wait_for_region_exact_text("body", "org text", index=0)
            session.wait_for_region_cursor("body", 0, index=0)

            session.send(keys.meta(";"))
            session.wait_for_region_exact_text("body", "# org text", index=0)
            session.wait_for_region_cursor("body", 2, index=0)
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(org_path, org_after_line)
            session.assert_file_bytes(org_path, org_after_line)

            session.send(
                keys.ctrl("n")
                + keys.ctrl("a")
                + b"\x00"
                + keys.ctrl("f") * 8
                + keys.meta(";")
            )
            session.wait_for_region_exact_text(
                "body", "# selected words", index=1
            )
            session.wait_for_region_cursor("body", 10, index=1)
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(org_path, org_after_region)
            session.assert_file_bytes(org_path, org_after_region)

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"lang-markup/markdown-org-comment-dwim exited "
                    f"with {code}: {output!r}"
                )
