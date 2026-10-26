"""Result-list command routes when no result list is active."""

import tempfile

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _assert_exit_zero(name, output, code):
    if code != 0:
        raise AssertionError(f"{name} exited with {code}: {output!r}")


@scenario(
    "search result navigation without active list",
    commands=[
        "execute-extended-command",
        "search-result-visit",
        "search-next-error",
        "search-previous-error",
    ],
)
def search_result_navigation_without_active_list(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = f"{directory}/search-results.txt"
        with open(path, "wb") as handle:
            handle.write(b"alpha beta\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.send(keys.meta("g") + b"n")
            session.wait_for_region_text("body", "alpha beta")
            session.send(keys.meta("g") + b"p")
            session.wait_for_region_cursor("body", 0)
            session.extended_command("next-error")
            session.wait_for_region_cursor("body", 0)
            session.extended_command("previous-error")
            session.wait_for_region_cursor("body", 0)
            session.extended_command("search-result-visit")
            session.wait_for_region_cursor("body", 0)
            output, code = session.quit()
    _assert_exit_zero("search result navigation without active list", output, code)
