import json
import tempfile
import unittest
from pathlib import Path

from loom_e2e.command_path_scenarios import (
    CommandPathScenarioError,
    _assert_screen,
    _wait_for_screen_expectation,
    load_command_path_scenarios,
)
from loom_e2e.layout import Layout
from loom_e2e.screen import Screen
from loom_e2e.session import Session


COLUMNS, ROWS = 20, 6


def _session(rows, body_x=0):
    """A real Session over a fixed screen; a false wait times out."""
    session = Session("unused-binary", [], columns=COLUMNS, rows=ROWS)
    session.screen = Screen(COLUMNS, ROWS)
    for index, text in enumerate(rows):
        session.screen.feed(f"\x1b[{index + 1};1H{text}".encode("utf-8"))
    session.layout = Layout(ROWS, COLUMNS)
    session.layout.body_x = body_x
    session.pump = lambda *args, **kwargs: b""
    return session


def _case(expectation):
    return {
        "name": "command-path/r1/row-test/key",
        "path_id": "r1:row-test:key:x",
        "lane": "W3-3",
        "rule": "r1",
        "entry": "key:x",
        "commands": ["row-test"],
        "command": "row-test",
        "entry_mode": "key",
        "entry_keys": ["x"],
        "initial_bytes": "",
        "expected_bytes": "",
        "expected_cursor": [0, 0],
        "expected_minibuffer": "",
        "expected_screen": [expectation],
    }


def _load(expectation):
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "command-paths.json"
        path.write_text(
            json.dumps({"schema_version": 1, "scenarios": [_case(expectation)]}),
            encoding="utf-8",
        )
        return load_command_path_scenarios(path)


class _RecordingSession(Session):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.calls = []

    def wait_for_row_exact_text(self, row, expected, **kwargs):
        self.calls.append(("wait", row, expected))
        return super().wait_for_row_exact_text(row, expected, **kwargs)

    def assert_screen_text(self, expected, match="exact", **source):
        self.calls.append(("assert", source, expected, match))
        return super().assert_screen_text(expected, match=match, **source)


class ScreenRowExpectationTests(unittest.TestCase):
    def test_validation_accepts_row_and_rejects_row_with_region_or_index(self):
        self.assertEqual(
            _load({"row": 0, "text": "abc"})[0]["expected_screen"],
            [{"row": 0, "text": "abc"}],
        )
        for bad in (
            {"row": 0, "region": "body", "text": "abc"},
            {"row": 0, "index": 1, "text": "abc"},
            {"row": -1, "text": "abc"},
            {"row": True, "text": "abc"},
        ):
            with self.subTest(bad=bad), self.assertRaises(CommandPathScenarioError):
                _load(bad)

    def test_exact_row_ignores_the_selected_window_body_offset(self):
        # body_x 2 is the gutter of a selected window elsewhere on the screen.
        session = _session(["abc", "", "1 list"], body_x=2)
        expectation = {"row": 0, "text": "abc"}
        _wait_for_screen_expectation(session, expectation, "exact")
        _assert_screen(session, [expectation])

    def test_rejects_the_same_text_on_a_different_row(self):
        session = _session(["", "abc"])
        expectation = {"row": 0, "text": "abc"}
        with self.assertRaises(AssertionError):
            _assert_screen(session, [expectation])
        with self.assertRaises(TimeoutError):
            session.wait_for_row_exact_text(0, "abc", timeout=0.05)

    def test_empty_text_requires_an_empty_row(self):
        session = _session(["", "abc"])
        session.wait_for_row_exact_text(0, "", timeout=0.05)
        _assert_screen(session, [{"row": 0, "text": ""}])
        with self.assertRaises(TimeoutError):
            session.wait_for_row_exact_text(1, "", timeout=0.05)
        with self.assertRaises(AssertionError):
            _assert_screen(session, [{"row": 1, "text": ""}])

    def test_row_reaches_the_wait_and_the_final_assertion(self):
        session = _RecordingSession("unused-binary", [], columns=COLUMNS, rows=ROWS)
        session.screen = Screen(COLUMNS, ROWS)
        session.screen.feed(b"\x1b[3;1Hxyz")
        session.pump = lambda *args, **kwargs: b""
        expectation = {"row": 2, "text": "xyz"}
        _wait_for_screen_expectation(session, expectation, "exact")
        _assert_screen(session, [expectation])
        self.assertEqual(
            session.calls,
            [
                ("wait", 2, "xyz"),
                ("assert", {"strip_right": True, "row": 2}, "xyz", "exact"),
            ],
        )


if __name__ == "__main__":
    unittest.main()
