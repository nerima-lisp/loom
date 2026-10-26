"""Exercise Markdown and Org list continuation and indentation in PTY sessions."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


@scenario(
    "lang-markup/markdown-list-continuation",
    commands=[
        "find-file",
        "move-end-of-line",
        "next-line",
        "save-buffer",
    ],
)
def markdown_list_continuation(binary):
    markdown_initial = b"- alpha\n* beta\n1. gamma\n- [ ] task\n- [ ] \n- "
    markdown_expected = (
        b"- alpha\n- \n* beta\n* \n1. gamma\n2. \n"
        b"- [ ] task\n- [ ] \n\n\n\n"
    )

    with tempfile.TemporaryDirectory(prefix="loom-e2e-lang-markup-") as directory:
        markdown_path = os.path.join(directory, "notes.md")
        with open(markdown_path, "wb") as handle:
            handle.write(markdown_initial)

        with Session(binary, [markdown_path]) as session:
            session.wait_ready()
            session.wait_for_region_exact_text("body", "- alpha", index=0)
            session.wait_for_region_cursor("body", 0, index=0)

            session.send(keys.ctrl("e"))
            session.key("RET")
            session.wait_for_region_exact_text("body", "-", index=1)
            session.wait_for_region_cursor("body", 2, index=1)

            session.send(keys.ctrl("n") + keys.ctrl("e"))
            session.key("RET")
            session.wait_for_region_exact_text("body", "*", index=3)
            session.wait_for_region_cursor("body", 2, index=3)

            session.send(keys.ctrl("n") + keys.ctrl("e"))
            session.key("RET")
            session.wait_for_region_exact_text("body", "2.", index=5)
            session.wait_for_region_cursor("body", 3, index=5)

            session.send(keys.ctrl("n") + keys.ctrl("e"))
            session.key("RET")
            session.wait_for_region_exact_text("body", "- [ ]", index=7)
            session.wait_for_region_cursor("body", 6, index=7)

            session.send(keys.ctrl("n") + keys.ctrl("e"))
            session.key("RET")
            session.wait_for_region_exact_text("body", "", index=8)
            session.wait_for_region_cursor("body", 0, index=9)

            session.send(keys.ctrl("n") + keys.ctrl("e"))
            session.key("RET")
            session.wait_for_region_exact_text("body", "", index=10)
            session.wait_for_region_cursor("body", 0, index=11)
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(markdown_path, markdown_expected)
            session.assert_file_bytes(markdown_path, markdown_expected)

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"lang-markup/markdown-list-continuation exited "
                    f"with {code}: {output!r}"
                )


@scenario(
    "lang-markup/org-list-continuation",
    commands=[
        "find-file",
        "move-end-of-line",
        "next-line",
        "save-buffer",
    ],
)
def org_list_continuation(binary):
    org_initial = b"- alpha\n1. gamma\n* Heading\n- "
    org_expected = b"- alpha\n- \n1. gamma\n2. \n* Heading\n\n\n"

    with tempfile.TemporaryDirectory(prefix="loom-e2e-lang-markup-") as directory:
        org_path = os.path.join(directory, "notes.org")
        with open(org_path, "wb") as handle:
            handle.write(org_initial)

        with Session(binary, [org_path]) as session:
            session.wait_ready()
            session.wait_for_region_exact_text("body", "- alpha", index=0)
            session.wait_for_region_cursor("body", 0, index=0)

            session.send(keys.ctrl("e"))
            session.key("RET")
            session.wait_for_region_exact_text("body", "-", index=1)
            session.wait_for_region_cursor("body", 2, index=1)

            session.send(keys.ctrl("n") + keys.ctrl("e"))
            session.key("RET")
            session.wait_for_region_exact_text("body", "2.", index=3)
            session.wait_for_region_cursor("body", 3, index=3)

            session.send(keys.ctrl("n") + keys.ctrl("e"))
            session.key("RET")
            session.wait_for_region_exact_text("body", "", index=5)
            session.wait_for_region_cursor("body", 0, index=5)

            session.send(keys.ctrl("n") + keys.ctrl("e"))
            session.key("RET")
            session.wait_for_region_exact_text("body", "", index=6)
            session.wait_for_region_cursor("body", 0, index=7)
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(org_path, org_expected)
            session.assert_file_bytes(org_path, org_expected)

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"lang-markup/org-list-continuation exited "
                    f"with {code}: {output!r}"
                )

@scenario(
    "lang-markup/markdown-indent-ret",
    commands=["move-end-of-line", "newline", "save-buffer"],
)
def markdown_indent_ret(binary):
    initial = b"- item\n"
    expected = b"- item\n- "

    with tempfile.TemporaryDirectory(prefix="loom-e2e-lang-markup-") as directory:
        path = os.path.join(directory, "markdown-indent-ret.md")
        with open(path, "wb") as handle:
            handle.write(initial)

        with Session(binary, [path]) as session:
            session.wait_ready(timeout=2.0)
            session.wait_for_region_exact_text(
                "body", "- item", index=0, timeout=2.0
            )
            session.send(keys.ctrl("e"))
            session.key("RET")
            session.wait_for_region_exact_text(
                "body", "-", index=1, timeout=2.0
            )
            session.wait_for_region_cursor(
                "body", 2, index=1, timeout=2.0
            )
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, expected, timeout=2.0)
            session.assert_file_bytes(path, expected)

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"lang-markup/markdown-indent-ret exited "
                    f"with {code}: {output!r}"
                )


@scenario(
    "lang-markup/markdown-indent-tab",
    commands=[
        "next-line",
        "move-end-of-line",
        "indent-for-tab-command",
        "save-buffer",
    ],
)
def markdown_indent_tab(binary):
    initial = b"- root\n  - child\n      continuation\n"
    expected = b"- root\n  - child\n  continuation\n"

    with tempfile.TemporaryDirectory(prefix="loom-e2e-lang-markup-") as directory:
        path = os.path.join(directory, "markdown-indent-tab.md")
        with open(path, "wb") as handle:
            handle.write(initial)

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.wait_for_region_exact_text("body", "- root", index=0)
            session.send(keys.ctrl("n") * 2 + keys.ctrl("e"))
            session.key("TAB")
            session.wait_for_region_exact_text(
                "body", "  continuation", index=2
            )
            session.wait_for_region_cursor("body", 14, index=2)
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, expected)
            session.assert_file_bytes(path, expected)

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"lang-markup/markdown-indent-tab exited "
                    f"with {code}: {output!r}"
                )


@scenario(
    "lang-markup/markdown-indent-region",
    commands=[
        "move-beginning-of-line",
        "set-mark-command",
        "next-line",
        "move-end-of-line",
        "indent-for-tab-command",
        "save-buffer",
    ],
)
def markdown_indent_region(binary):
    initial = (
        b"# Heading\n"
        b"- root\n"
        b"  - child\n"
        b"      continuation\n"
        b"        deeper\n"
    )
    expected = (
        b"# Heading\n"
        b"- root\n"
        b"  - child\n"
        b"  continuation\n"
        b"  deeper\n"
    )

    with tempfile.TemporaryDirectory(prefix="loom-e2e-lang-markup-") as directory:
        path = os.path.join(directory, "markdown-indent-region.md")
        with open(path, "wb") as handle:
            handle.write(initial)

        with Session(binary, [path]) as session:
            session.wait_ready(timeout=2.0)
            session.wait_for_region_exact_text(
                "body", "# Heading", index=0, timeout=2.0
            )
            session.send(
                keys.ctrl("a")
                + keys.ctrl("n") * 3
                + keys.ctrl("@")
                + keys.ctrl("n")
                + keys.ctrl("e")
            )
            session.key(b"\x1b[92;7u")
            session.wait_for_region_exact_text(
                "body", "  deeper", index=4, timeout=2.0
            )
            session.wait_for_region_cursor(
                "body", 8, index=4, timeout=2.0
            )
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, expected, timeout=2.0)
            session.assert_file_bytes(path, expected)

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"lang-markup/markdown-indent-region exited "
                    f"with {code}: {output!r}"
                )


@scenario(
    "lang-markup/org-indent-ret",
    commands=["move-end-of-line", "newline", "save-buffer"],
)
def org_indent_ret(binary):
    initial = b"- item\n"
    expected = b"- item\n- "

    with tempfile.TemporaryDirectory(prefix="loom-e2e-lang-markup-") as directory:
        path = os.path.join(directory, "org-indent-ret.org")
        with open(path, "wb") as handle:
            handle.write(initial)

        with Session(binary, [path]) as session:
            session.wait_ready(timeout=2.0)
            session.wait_for_region_exact_text(
                "body", "- item", index=0, timeout=2.0
            )
            session.send(keys.ctrl("e"))
            session.key("RET")
            session.wait_for_region_exact_text(
                "body", "-", index=1, timeout=2.0
            )
            session.wait_for_region_cursor(
                "body", 2, index=1, timeout=2.0
            )
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, expected, timeout=2.0)
            session.assert_file_bytes(path, expected)

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"lang-markup/org-indent-ret exited "
                    f"with {code}: {output!r}"
                )


@scenario(
    "lang-markup/org-indent-tab",
    commands=[
        "next-line",
        "move-end-of-line",
        "indent-for-tab-command",
        "save-buffer",
    ],
)
def org_indent_tab(binary):
    initial = b"- root\n  - child\n      continuation\n"
    expected = b"- root\n  - child\n  continuation\n"

    with tempfile.TemporaryDirectory(prefix="loom-e2e-lang-markup-") as directory:
        path = os.path.join(directory, "org-indent-tab.org")
        with open(path, "wb") as handle:
            handle.write(initial)

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.wait_for_region_exact_text("body", "- root", index=0)
            session.send(keys.ctrl("n") * 2 + keys.ctrl("e"))
            session.key("TAB")
            session.wait_for_region_exact_text(
                "body", "  continuation", index=2
            )
            session.wait_for_region_cursor("body", 14, index=2)
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, expected)
            session.assert_file_bytes(path, expected)

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"lang-markup/org-indent-tab exited "
                    f"with {code}: {output!r}"
                )


@scenario(
    "lang-markup/org-indent-region",
    commands=[
        "move-beginning-of-line",
        "set-mark-command",
        "next-line",
        "move-end-of-line",
        "indent-for-tab-command",
        "save-buffer",
    ],
)
def org_indent_region(binary):
    initial = (
        b"* Heading\n"
        b"- root\n"
        b"  - child\n"
        b"      continuation\n"
        b"        deeper\n"
    )
    expected = (
        b"* Heading\n"
        b"- root\n"
        b"  - child\n"
        b"  continuation\n"
        b"  deeper\n"
    )

    with tempfile.TemporaryDirectory(prefix="loom-e2e-lang-markup-") as directory:
        path = os.path.join(directory, "org-indent-region.org")
        with open(path, "wb") as handle:
            handle.write(initial)

        with Session(binary, [path]) as session:
            session.wait_ready(timeout=2.0)
            session.wait_for_region_exact_text(
                "body", "* Heading", index=0, timeout=2.0
            )
            session.send(
                keys.ctrl("a")
                + keys.ctrl("n") * 3
                + keys.ctrl("@")
                + keys.ctrl("n")
                + keys.ctrl("e")
            )
            session.key(b"\x1b[92;7u")
            session.wait_for_region_exact_text(
                "body", "  deeper", index=4, timeout=2.0
            )
            session.wait_for_region_cursor(
                "body", 8, index=4, timeout=2.0
            )
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, expected, timeout=2.0)
            session.assert_file_bytes(path, expected)

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"lang-markup/org-indent-region exited "
                    f"with {code}: {output!r}"
                )
