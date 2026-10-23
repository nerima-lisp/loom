import json
import os
import sys
import tempfile
import time
import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, Mock, patch

from loom_e2e import keys
from loom_e2e.benchmarks import _redraw_samples, benchmark_scenarios
from loom_e2e.deadline import run_scenario
from loom_e2e.process import LoomProcess
from loom_e2e.results import (
    ScenarioResult,
    capture_scenario,
    record_observation,
)
from loom_e2e.screen import Screen
from loom_e2e.session import Session, _session_environment


class TerminalProfileTests(unittest.TestCase):
    def test_return_and_profile_end_sequences(self):
        self.assertEqual(keys.RET, b"\r")
        self.assertEqual(keys.LF, b"\n")
        self.assertEqual(keys.key("END", keys.XTERM_256COLOR), b"\x1b[F")
        self.assertEqual(keys.key("END", keys.XTERM), b"\x1b[4~")
        self.assertEqual(keys.get_profile("xterm").term, "xterm")

    def test_session_environment_selects_profile_and_trace_path(self):
        with patch.dict(os.environ, {"PATH": "/usr/bin", "UNLISTED_TEST_VALUE": "x"}):
            environment = _session_environment(
                "/scratch/home", "C.UTF-8", keys.XTERM, "/scratch/trace.jsonl"
            )
        self.assertEqual(environment["TERM"], "xterm")
        self.assertEqual(environment["LOOM_TRACE_COMMANDS"], "/scratch/trace.jsonl")
        self.assertNotIn("UNLISTED_TEST_VALUE", environment)

    def test_session_key_uses_selected_profile(self):
        session = Session("unused", profile=keys.XTERM)
        session.process = Mock()
        session.key("END", "RET")
        session.process.write.assert_called_once_with(b"\x1b[4~\r")


class ScreenAttributeTests(unittest.TestCase):
    def test_cell_attributes_and_resize(self):
        screen = Screen(columns=12, rows=4)
        screen.feed(b"\x1b[7mX\x1b[0m")
        self.assertTrue(screen.cell_attrs(0, 0)["reverse"])
        self.assertEqual(screen.cell_attrs(0, 0)["data"], "X")
        screen.resize(columns=8, rows=2)
        self.assertEqual((screen.columns, screen.rows), (8, 2))
        with self.assertRaises(IndexError):
            screen.cell_attrs(2, 0)


class PtyResizeTests(unittest.TestCase):
    def _read_until(self, process, initial, marker, timeout=3.0):
        output = bytearray(initial)
        deadline = time.monotonic() + timeout
        while marker not in output and time.monotonic() < deadline:
            remaining = deadline - time.monotonic()
            output.extend(process.poll(min(0.05, remaining)))
        self.assertIn(marker, output)
        return bytes(output)

    def test_resize_sets_winsize_and_delivers_sigwinch(self):
        script = "\n".join(
            (
                "import fcntl, signal, struct, sys, termios",
                "def report(_signum, _frame):",
                "    size = fcntl.ioctl(0, termios.TIOCGWINSZ, b'\\0' * 8)",
                "    rows, columns, _, _ = struct.unpack('HHHH', size)",
                "    print(f'WINCH:{rows}:{columns}', flush=True)",
                "signal.signal(signal.SIGWINCH, report)",
                "print('READY', flush=True)",
                "sys.stdin.buffer.readline()",
            )
        )
        process = LoomProcess(
            sys.executable,
            ["-c", script],
            env=dict(os.environ),
            columns=80,
            rows=24,
        )
        try:
            output = self._read_until(process, b"", b"READY")
            process.resize(columns=17, rows=7)
            self.assertEqual(process.window_size, (7, 17))
            output = self._read_until(process, output, b"WINCH:7:17")
            process.write(b"\n")
            remaining, code = process.wait(timeout=3.0)
            self.assertEqual(code, 0)
            self.assertEqual(process.output_bytes, output + remaining)
            self.assertIn(b"WINCH:7:17", process.output_bytes)
        finally:
            process.close()


class ScenarioResultTests(unittest.TestCase):
    def test_preconditions_do_not_count_as_effect_observations(self):
        exit_result = ScenarioResult("exit only")
        exit_result.status = "passed"
        with capture_scenario(exit_result):
            record_observation(
                "screen_text", "ready", {"non_empty": True}, True,
                purpose="precondition",
            )
            record_observation("exit_code", 0, 0, True)
        self.assertEqual(exit_result._classification(), ("exit-code-only", True))
        with tempfile.TemporaryDirectory() as directory:
            result_path = exit_result.save(directory)
            with open(result_path, encoding="utf-8") as handle:
                payload = json.load(handle)
        self.assertEqual(payload["observation_class"], "exit-code-only")
        self.assertIs(payload["exit_code_only"], True)

        runtime_result = ScenarioResult("runtime observation")
        with capture_scenario(runtime_result):
            record_observation("exit_code", 0, 0, True)
            record_observation("screen_text", "ready", "ready", True)
        self.assertEqual(runtime_result._classification(), ("effect-verified", False))

    def test_failed_expected_effect_prevents_effect_verified_classification(self):
        for passed in (False, None):
            with self.subTest(passed=passed):
                result = ScenarioResult("mixed effect observations")
                with capture_scenario(result):
                    record_observation("screen_text", "ready", "ready", True)
                    record_observation("file_bytes", b"actual", b"expected", passed)
                self.assertEqual(
                    result._classification(), ("effect-unverified", False)
                )

    def test_unchecked_observations_do_not_count_as_verified_effects(self):
        result = ScenarioResult("unchecked observation")
        with capture_scenario(result):
            record_observation("screen_text", "ready")
        self.assertEqual(result._classification(), ("effect-unverified", False))

    def test_save_writes_raw_bytes_and_empty_trace_as_literal_files(self):
        with tempfile.TemporaryDirectory() as directory:
            result = ScenarioResult("raw artifacts")
            result.status = "passed"
            result.add_session(b"\x1b[?25lraw\xff", b"")
            with capture_scenario(result):
                record_observation("file_bytes", b"saved\x00", expected=b"saved\x00", passed=True)
                record_observation("external_state", True, expected=True, passed=True, name="marker")
            result_path = result.save(directory)
            scenario_dir = os.path.dirname(result_path)
            with open(os.path.join(scenario_dir, "output.pty"), "rb") as handle:
                self.assertEqual(handle.read(), b"\x1b[?25lraw\xff")
            with open(os.path.join(scenario_dir, "trace.jsonl"), "rb") as handle:
                self.assertEqual(handle.read(), b"")
            with open(result_path, encoding="utf-8") as handle:
                payload = json.load(handle)
            self.assertEqual(payload["observation_class"], "effect-verified")
            self.assertEqual(
                payload["observations"][0]["actual"],
                {"encoding": "base64", "data": "c2F2ZWQA", "length": 6},
            )
            self.assertEqual(payload["observations"][1]["type"], "external_state")


class SessionObservationTests(unittest.TestCase):
    def test_session_captures_nonempty_command_trace_bytes(self):
        trace = b'{"command":"save-buffer","route":"key","seq":1}\n'
        result = ScenarioResult("trace capture")
        with tempfile.TemporaryDirectory() as directory:
            trace_path = os.path.join(directory, "trace.jsonl")
            with open(trace_path, "wb") as handle:
                handle.write(trace)
            session = Session("unused")
            session.process = Mock(output_bytes=b"pty bytes")
            session._trace_path = trace_path
            with capture_scenario(result):
                session._capture_artifacts()
        self.assertEqual(session.trace_bytes, trace)
        self.assertEqual(result.trace_output, trace)
        self.assertEqual(result.sessions[0]["trace_length"], len(trace))

    def test_named_helpers_record_runtime_values_and_expectations(self):
        session = Session("unused")
        session.screen = Screen(columns=20, rows=4)
        session.screen.feed(b"\x1b[7mready\x1b[0m")
        result = ScenarioResult("typed observations")
        with tempfile.NamedTemporaryFile() as handle:
            handle.write(b"fixture\x00")
            handle.flush()
            with capture_scenario(result):
                session.assert_screen_text(
                    session.screen.text(0).rstrip(), "ready", region="body"
                )
                session.observe_cursor(expected=(0, 5), sample=0)
                session.assert_cell_attrs(0, 0, expected={"reverse": True})
                session.assert_pty_output(b"\x1b[7m", b"\x1b[7m")
                session.assert_file_bytes(handle.name, b"fixture\x00")
                session.assert_external_state("fixture present", True, True)
                session.observe_exit_code(0, expected=0)
        self.assertEqual(
            [item["type"] for item in result.observations],
            [
                "screen_text",
                "cursor",
                "cell_attrs",
                "pty_output",
                "file_bytes",
                "external_state",
                "exit_code",
            ],
        )
        self.assertTrue(all(item.get("passed") is True for item in result.observations))
        self.assertEqual(result.observations[1]["sample"], 0)

    def test_cell_attribute_assertion_rejects_mismatch_and_empty_expectation(self):
        session = Session("unused")
        session.screen = Screen(columns=4, rows=2)
        session.screen.feed(b"plain")
        with self.assertRaisesRegex(AssertionError, "cell attributes"):
            session.assert_cell_attrs(0, 0, {"reverse": True})
        with self.assertRaisesRegex(ValueError, "must not be empty"):
            session.observe_cell_attrs(0, 0, {})

    def test_wait_for_external_state_records_the_value_that_satisfied_wait(self):
        session = Session("unused")
        session.screen = Screen(columns=4, rows=2)
        read_state = Mock(return_value="ready")
        result = ScenarioResult("stable external state")
        with capture_scenario(result):
            self.assertEqual(
                session.wait_for_external_state("service", read_state, "ready"),
                "ready",
            )
        read_state.assert_called_once_with()
        self.assertTrue(result.observations[0]["passed"])


class BenchmarkDeadlineTests(unittest.TestCase):
    def test_each_benchmark_scenario_requires_the_existing_deadline(self):
        for name, scenario in benchmark_scenarios().items():
            with self.subTest(scenario=name):
                with self.assertRaisesRegex(RuntimeError, "active scenario deadline"):
                    scenario("unused")
        with self.assertRaisesRegex(RuntimeError, "active scenario deadline"):
            _redraw_samples(None)

    def test_redraw_samples_move_cursor_without_modifying_buffer(self):
        class CursorOnlySession:
            def __init__(self):
                self.screen = SimpleNamespace(cursor=(0, 0))
                self.sent = []
                self.modified = False

            def send(self, data):
                self.sent.append(data)

            def pump(self, poll_timeout):
                row, column = self.screen.cursor
                self.screen.cursor = (row, column + 1)

            def observe_cursor(self, expected, **_details):
                return self.screen.cursor

        session = CursorOnlySession()
        samples = run_scenario(
            lambda _binary: _redraw_samples(session),
            "unused",
            seconds=1.0,
        )
        self.assertEqual(len(samples), 25)
        self.assertEqual(session.sent, [keys.ctrl("f")] * 25)
        self.assertEqual(session.screen.cursor, (0, 25))
        self.assertFalse(session.modified)

    def test_large_file_has_exact_size_and_unique_last_line(self):
        from loom_e2e.benchmarks import (
            _LINE_BYTES,
            _LINE_COUNT,
            _OPEN_LAST_LINE_MARKER,
            _large_file,
        )

        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "large.txt")
            line_count, byte_count = _large_file(path)
            with open(path, "rb") as handle:
                lines = handle.readlines()
            actual_size = os.path.getsize(path)
        self.assertEqual(line_count, _LINE_COUNT)
        self.assertEqual(len(lines), _LINE_COUNT)
        self.assertEqual(byte_count, 5_000_000)
        self.assertEqual(actual_size, 5_000_000)
        self.assertEqual(len(lines[-1]), _LINE_BYTES)
        self.assertIn(_OPEN_LAST_LINE_MARKER, lines[-1])


class BenchmarkMeasurementTests(unittest.TestCase):
    def test_each_benchmark_serializes_its_measurement_observation(self):
        expected = {
            "startup": ("startup_to_first_screen_seconds", "seconds"),
            "redraw": ("input_to_redraw_p95_milliseconds", "milliseconds"),
            "large-file-open": ("open_100000_lines_5mb_seconds", "seconds"),
        }
        for scenario_name, scenario in benchmark_scenarios().items():
            with self.subTest(scenario=scenario_name):
                session = MagicMock()
                session.__enter__.return_value = session
                session.__exit__.return_value = False
                session.started_at = 10.0
                session.first_screen_at = 10.25
                result = ScenarioResult(f"benchmarks/{scenario_name}")
                with patch("loom_e2e.benchmarks.Session", return_value=session):
                    with patch(
                        "loom_e2e.benchmarks._redraw_samples",
                        return_value=[0.02] * 25,
                    ):
                        with capture_scenario(result):
                            run_scenario(scenario, "unused")

                metric, unit = expected[scenario_name]
                measurements = [
                    item
                    for item in result.observations
                    if item["type"] == "benchmark_measurement"
                ]
                self.assertEqual(len(measurements), 1)
                self.assertEqual(measurements[0]["metric"], metric)
                self.assertEqual(measurements[0]["unit"], unit)
                self.assertIsInstance(measurements[0]["actual"], (int, float))

                with tempfile.TemporaryDirectory() as directory:
                    result_path = result.save(directory)
                    with open(result_path, encoding="utf-8") as handle:
                        payload = json.load(handle)
                saved = [
                    item
                    for item in payload["observations"]
                    if item["type"] == "benchmark_measurement"
                ]
                self.assertEqual(saved, measurements)


if __name__ == "__main__":
    unittest.main()
