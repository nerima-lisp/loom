import signal
import sys
import unittest

from loom_e2e import keys
from loom_e2e.deadline import (
    ScenarioDeadlineExceeded,
    mark_phase,
    phase_step,
    run_scenario,
    scenario_deadline,
    scenario_preparation,
)
from loom_e2e.results import ScenarioResult, capture_scenario
from loom_e2e.session import Session, _describe_input


_READY_THEN_STALL = """\
import sys
import time
sys.stdout.write("ready-marker\\n")
sys.stdout.flush()
sys.stdin.buffer.read(1)
sys.stdout.write("got-input\\n")
sys.stdout.flush()
time.sleep(30)
"""


class PhaseTimelineTests(unittest.TestCase):
    def setUp(self):
        self._handler = signal.getsignal(signal.SIGALRM)
        self._timer = signal.getitimer(signal.ITIMER_REAL)
        signal.setitimer(signal.ITIMER_REAL, 0.0, 0.0)
        self.addCleanup(self._restore_signal_state)

    def _restore_signal_state(self):
        signal.setitimer(signal.ITIMER_REAL, 0.0, 0.0)
        signal.signal(signal.SIGALRM, self._handler)
        signal.setitimer(signal.ITIMER_REAL, *self._timer)

    def test_enclosing_step_owns_nested_marks(self):
        result = ScenarioResult("nested")
        with capture_scenario(result):
            with scenario_deadline(seconds=5.0, cleanup_seconds=1.0):
                with phase_step("M-x lsp-start"):
                    mark_phase("key RET")
                    with phase_step("type 'yes'"):
                        pass
                mark_phase("quit")
        self.assertEqual(
            [phase["phase"] for phase in result.phases],
            ["fixture setup", "M-x lsp-start", "quit"],
        )

    def test_nested_deadline_shares_the_outer_timeline(self):
        result = ScenarioResult("nested-deadline")
        with capture_scenario(result):
            with scenario_deadline(seconds=8.0, cleanup_seconds=2.0):
                with scenario_deadline(seconds=5.0, cleanup_seconds=1.0):
                    mark_phase("inner step")
                mark_phase("outer step")
        self.assertEqual(
            [phase["phase"] for phase in result.phases],
            ["fixture setup", "inner step", "outer step"],
        )

    def test_input_bytes_are_named_with_key_names(self):
        profile = keys.DEFAULT_PROFILE
        self.assertEqual(
            _describe_input(keys.ctrl("x") + keys.ctrl("c"), profile), "C-x C-c"
        )
        self.assertEqual(_describe_input(keys.meta("."), profile), "M-.")
        self.assertEqual(_describe_input(b"\x1b[A\r", profile), "UP RET")
        self.assertEqual(_describe_input(b"ab\x00", profile), "'ab' C-@")
        self.assertEqual(_describe_input(b"\x1b[105;7u", profile), "CSI 105;7u")

    def test_preparation_splits_the_current_phase_as_budget_paused(self):
        result = ScenarioResult("paused")
        with capture_scenario(result):
            with scenario_deadline(seconds=5.0, cleanup_seconds=1.0):
                mark_phase("initial screen")
                with scenario_preparation():
                    pass
                mark_phase("quit")
        self.assertEqual(
            [(phase["phase"], phase["budget_paused"]) for phase in result.phases],
            [
                ("fixture setup", False),
                ("initial screen", False),
                ("initial screen", True),
                ("initial screen", False),
                ("quit", False),
            ],
        )

    def test_timeout_report_names_phases_screen_and_trace(self):
        result = ScenarioResult("stall")

        def body(_binary):
            with Session(sys.executable, ["-c", _READY_THEN_STALL]) as session:
                session.wait_for_text("ready-marker")
                session.key("RET")
                session.wait_for_text("never-printed", timeout=30)

        with capture_scenario(result):
            with self.assertRaises(ScenarioDeadlineExceeded) as raised:
                run_scenario(body, "unused", seconds=2.0, cleanup_seconds=1.0)

        report = raised.exception.scenario_timeout_report
        self.assertIn("execution budget 1s, cleanup reserve 1s", report)
        for phase in ("fixture setup", "launch", "initial screen", "session teardown"):
            self.assertIn(f"  {phase}", report)
        self.assertRegex(
            report, r"key RET  <- execution budget \(1s\) expired\n"
        )
        self.assertIn("first screen content", report)
        self.assertIn("--- screen at timeout", report)
        self.assertIn("ready-marker", report)
        self.assertIn("--- command trace tail at timeout (last 0 of 0 records) ---", report)
        self.assertEqual(
            [phase["phase"] for phase in result.phases],
            [
                "fixture setup",
                "launch",
                "initial screen",
                "key RET",
                "session teardown",
                "after session close",
            ],
        )


if __name__ == "__main__":
    unittest.main()
