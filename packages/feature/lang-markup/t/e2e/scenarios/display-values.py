"""Exercise Markdown and Org multi-line display values through eval-expression."""

import os
import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


@scenario(
    "lang-markup/display-values",
    commands=["eval-expression", "switch-to-buffer"],
)
def markup_display_values(binary):
    markdown_source = (
        "# Heading\n"
        "<!-- begin\n"
        "middle\n"
        "end -->\n"
        "```text\n"
        "literal\n"
        "```"
    )
    org_source = (
        "* Heading\n"
        "# line comment\n"
        "#+BEGIN_COMMENT\n"
        "hidden\n"
        "#+END_COMMENT\n"
        "#+BEGIN_SRC text\n"
        "literal\n"
        "#+END_SRC"
    )
    markdown_lisp_source = markdown_source.replace("\n", "~%")
    org_lisp_source = org_source.replace("\n", "~%")
    expression = (
        f'(and (equal (loom/feature/lang-markup:markup-display-lines '
        f'(format nil "{markdown_lisp_source}") :markdown) '
        "((( :heading \"# Heading\")) "
        "((:comment \"<!-- begin\")) ((:comment \"middle\")) "
        "((:comment \"end -->\")) ((:code \"```text\")) "
        "((:code \"literal\")) ((:code \"```\")))) "
        f'(equal (loom/feature/lang-markup:markup-display-lines '
        f'(format nil "{org_lisp_source}") :org) '
        "((( :heading \"* Heading\")) "
        "((:comment \"# line comment\")) "
        "((:comment \"#+BEGIN_COMMENT\")) ((:comment \"hidden\")) "
        "((:comment \"#+END_COMMENT\")) ((:code \"#+BEGIN_SRC text\")) "
        "((:code \"literal\")) ((:code \"#+END_SRC\"))))) "
    )

    with tempfile.TemporaryDirectory(prefix="loom-e2e-lang-markup-") as directory:
        path = os.path.join(directory, "notes.md")
        initial = b"# unchanged\n"
        with open(path, "wb") as handle:
            handle.write(initial)

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.wait_for_region_exact_text("body", "# unchanged", index=0)
            session.wait_for_region_cursor("body", 0, index=0)
            session.assert_file_bytes(path, initial)

            session.send(keys.meta(":"))
            session.wait_for_region_text("minibuffer", "Eval: ")
            session.type(expression)
            session.key("RET")
            session.wait_for_text("loom-eval>")
            session.assert_screen_text("=> T", match="contains")
            session.assert_file_bytes(path, initial)

            session.send(keys.ctrl("x") + b"b")
            session.wait_for_region_text("minibuffer", "Switch to buffer: ")
            session.type("notes.md")
            session.key("RET")
            session.wait_for_region_exact_text("body", "# unchanged", index=0)
            session.wait_for_region_cursor("body", 0, index=0)
            session.observe_cursor(expected=(0, 0), region="body", index=0)
            session.assert_file_bytes(path, initial)

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"lang-markup/display-values exited with {code}: {output!r}"
                )
