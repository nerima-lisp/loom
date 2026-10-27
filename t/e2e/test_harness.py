import json
import os
import sys
import tempfile
import time
import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, Mock, patch

from loom_e2e import keys, registry
from loom_e2e.benchmarks import (
    _redraw_samples,
    benchmark_scenarios,
    build_benchmark_report,
)
from loom_e2e.deadline import run_scenario
from loom_e2e.layout import validate_dimensions
from loom_e2e.process import LoomProcess
from loom_e2e.results import (
    ScenarioResult,
    capture_scenario,
    record_observation,
    record_event,
    reset_trace_line_counter,
    set_trace_line_counter,
)
from loom_e2e.screen import Screen
from loom_e2e.session import Session, _session_environment


class TerminalProfileTests(unittest.TestCase):
    def test_control_question_mark_encodes_delete(self):
        self.assertEqual(keys.ctrl("?"), b"\x7f")

    def test_return_and_profile_end_sequences(self):
        self.assertEqual(keys.key("RET"), b"\r")
        self.assertEqual(keys.key("LF"), b"\n")
        self.assertEqual(keys.key("END", keys.XTERM_256COLOR), b"\x1b[F")
        self.assertEqual(keys.key("END", keys.XTERM), b"\x1b[4~")
        self.assertEqual(keys.get_profile("xterm").term, "xterm")
        self.assertFalse(hasattr(keys, "RET"))

    def test_module_key_lookup_honors_custom_profile(self):
        profile = keys.TerminalProfile("custom", "custom", {"RET": b"\n"})
        self.assertEqual(keys.key("RET", profile), b"\n")

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


class ScenarioRegistryTests(unittest.TestCase):
    def test_duplicate_names_fail_when_registered(self):
        with patch.object(registry, "_scenarios", []):
            @registry.scenario("same name")
            def first(_binary):
                pass

            with self.assertRaisesRegex(ValueError, "duplicate scenario name"):
                @registry.scenario("same name")
                def second(_binary):
                    pass

            self.assertEqual(registry.all_scenarios()[0][2], first)


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

    def test_terminal_dimensions_have_one_shared_validation_rule(self):
        self.assertEqual(validate_dimensions(80, 24), (80, 24))
        for dimensions in ((0, 24), (80, 0), (True, 24), (80, 24.0)):
            with self.subTest(dimensions=dimensions):
                with self.assertRaises(ValueError):
                    validate_dimensions(*dimensions)


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
    def test_observations_include_common_fields_and_nullable_passed(self):
        result = ScenarioResult("common observation fields")
        with capture_scenario(result):
            record_observation("external_state", "ready", expected="ready")

        observation = result.observations[0]
        self.assertEqual(
            set(observation),
            {
                "sequence",
                "timeline_sequence",
                "type",
                "actual",
                "trace_lines",
                "purpose",
                "expected",
                "passed",
            },
        )
        self.assertEqual(observation["purpose"], "scenario")
        self.assertIsNone(observation["passed"])
        self.assertEqual(result._classification(), "effect-unverified")

    def test_preconditions_do_not_count_as_effect_observations(self):
        exit_result = ScenarioResult("exit only")
        exit_result.status = "passed"
        with capture_scenario(exit_result):
            record_observation(
                "screen_text", "ready", {"non_empty": True}, True,
                purpose="precondition",
            )
            record_observation("exit_code", 0, 0, True)
        self.assertEqual(exit_result._classification(), "exit-code-only")
        with tempfile.TemporaryDirectory() as directory:
            result_path = exit_result.save(directory)
            with open(result_path, encoding="utf-8") as handle:
                payload = json.load(handle)
        self.assertEqual(payload["observation_class"], "exit-code-only")
        self.assertNotIn("exit_code_only", payload)

        runtime_result = ScenarioResult("runtime observation")
        with capture_scenario(runtime_result):
            record_observation("exit_code", 0, 0, True)
            record_observation("screen_text", "ready", "ready", True)
        self.assertEqual(runtime_result._classification(), "effect-verified")

    def test_failed_expected_effect_prevents_effect_verified_classification(self):
        for passed in (False, None):
            with self.subTest(passed=passed):
                result = ScenarioResult("mixed effect observations")
                with capture_scenario(result):
                    record_observation("screen_text", "ready", "ready", True)
                    record_observation("file_bytes", b"actual", b"expected", passed)
                self.assertEqual(
                    result._classification(), "effect-unverified"
                )

    def test_unchecked_observations_do_not_count_as_verified_effects(self):
        result = ScenarioResult("unchecked observation")
        with capture_scenario(result):
            record_observation("screen_text", "ready")
        self.assertEqual(result._classification(), "effect-unverified")

    def test_pty_output_counts_as_an_effect_observation(self):
        result = ScenarioResult("pty output")
        with capture_scenario(result):
            record_observation("pty_output", b"Usage", b"Usage", True)
        self.assertEqual(result._classification(), "effect-verified")

    def test_exit_code_only_includes_precondition_observations(self):
        result = ScenarioResult("precondition plus exit")
        with capture_scenario(result):
            record_observation(
                "screen_text", "ready", {"non_empty": True}, True,
                purpose="precondition",
            )
            record_observation("exit_code", 0, 0, True)
        self.assertEqual(result._classification(), "exit-code-only")

    def test_save_writes_raw_bytes_and_empty_trace_as_literal_files(self):
        with tempfile.TemporaryDirectory() as directory:
            result = ScenarioResult("raw artifacts")
            result.status = "passed"
            result.add_session(b"\x1b[?25lraw\xff", b"")
            with capture_scenario(result):
                record_observation("file_bytes", b"saved\x00", expected=b"saved\x00", passed=True)
                record_event("text_input", text="saved")
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
            self.assertEqual(payload["binary_realpath"], None)
            self.assertEqual(payload["declared_commands"], [])
            self.assertEqual(
                payload["events"],
                [{
                    "timeline_sequence": 1,
                    "type": "text_input",
                    "text": "saved",
                }],
            )
            self.assertEqual(
                payload["observations"][0]["actual"],
                {"encoding": "base64", "data": "c2F2ZWQA", "length": 6},
            )
            self.assertEqual(payload["observations"][1]["type"], "external_state")


class SessionObservationTests(unittest.TestCase):
    def test_session_type_records_typed_input_before_later_observations(self):
        session = Session("unused")
        session.send = Mock()
        result = ScenarioResult("typed input event")
        with capture_scenario(result):
            session.type("漢")
            encoded = "漢".encode("utf-8")
            record_observation(
                "file_bytes", encoded, expected=encoded, passed=True
            )

        session.send.assert_called_once_with(keys.text("漢"))
        self.assertEqual(
            result.events,
            [{"timeline_sequence": 0, "type": "text_input", "text": "漢"}],
        )
        self.assertEqual(result.observations[0]["timeline_sequence"], 1)

    def test_session_resize_records_dimensions_before_effect_observation(self):
        session = Session("unused", columns=40, rows=12)
        session.process = Mock()
        session.process.window_size = (12, 20)
        session.screen = Screen(columns=40, rows=12)
        session.pump = Mock(return_value=False)
        result = ScenarioResult("terminal resize event")
        with capture_scenario(result):
            session.resize(columns=20, rows=12)
            record_observation("screen_text", "wrapped", "wrapped", True)

        session.process.resize.assert_called_once_with(20, 12)
        self.assertEqual(
            result.events,
            [{
                "timeline_sequence": 0,
                "type": "terminal_resize",
                "columns": 20,
                "rows": 12,
            }],
        )
        self.assertEqual(result.observations[-1]["timeline_sequence"], 2)

    def test_session_captures_nonempty_command_trace_bytes(self):
        trace = b'{"command":"save-buffer","route":"key","seq":1,"pid":1234}\n'
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

    def test_screen_observation_snapshots_trace_before_matching_and_recording(self):
        result = ScenarioResult("observation trace boundary")
        session = Session("unused")
        session.screen = Screen(columns=20, rows=2)
        session.screen.feed(b"ready")
        with tempfile.TemporaryDirectory() as directory:
            trace_path = os.path.join(directory, "trace.jsonl")
            with open(trace_path, "wb") as handle:
                handle.write(b'{"command":"save-buffer","route":"mx","seq":1,"pid":1234}\n')
            session._trace_path = trace_path
            matches = session._matches

            def append_command_after_sample(actual, expected, match):
                with open(trace_path, "ab") as handle:
                    handle.write(
                        b'{"command":"next-command","route":"mx","seq":2,"pid":1234}\n'
                    )
                return matches(actual, expected, match)

            with capture_scenario(result):
                with patch.object(
                    session, "_matches", side_effect=append_command_after_sample
                ):
                    session.observe_screen_text("ready", match="contains", region="screen")

        self.assertEqual(result.observations[0]["trace_lines"], 1)

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
                    "ready", region="body", index=0, strip_right=True
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

    def test_screen_observation_reads_the_selected_screen_region(self):
        session = Session("unused")
        session.screen = Screen(columns=20, rows=4)
        session.screen.feed(b"actual screen text")
        result = ScenarioResult("screen source")
        with capture_scenario(result):
            passed = session.observe_screen_text(
                "actual", match="contains", region="body", index=0
            )
        self.assertIs(passed, True)
        self.assertEqual(result.observations[0]["actual"], "actual screen text  ")
        self.assertIs(result.observations[0]["passed"], True)
        with self.assertRaises(TypeError):
            session.observe_screen_text(
                expected="actual screen text", region="body", passed=True
            )
        with self.assertRaises(ValueError):
            session.observe_screen_text("actual screen text")

    def test_body_region_uses_gutter_origin(self):
        session = Session("unused", columns=12, rows=4)
        session.screen = Screen(columns=12, rows=4)
        session.screen.feed(b"42 alpha")
        session.layout.body_x = 3

        with self.subTest("body text"):
            self.assertEqual(session.region_text("body", 0).rstrip(), "alpha")
            self.assertNotIn("42", session.region_text("body", 0))

        with self.subTest("screen text and wait include gutter"):
            self.assertEqual(session.region_text("screen", 0).rstrip(), "42 alpha")
            session.wait_for_region_text("screen", "42")

        with self.subTest("body cursor"):
            session.screen.feed(b"\x1b[1;4H")
            self.assertEqual(session.screen.cursor, (0, 3))
            self.assertEqual(session.region_cursor("body"), (0, 0))
            self.assertIs(
                session.observe_cursor(expected=(0, 0), region="body"), True
            )
            with patch.object(session, "wait_for_cursor") as wait_for_cursor:
                session.wait_for_region_cursor("body", 0)
            self.assertEqual(wait_for_cursor.call_args.args[:2], (0, 3))

    def test_waited_screen_text_is_a_precondition(self):
        session = Session("unused")
        session.screen = Screen(columns=20, rows=4)
        session.screen.feed(b"M-x ")
        result = ScenarioResult("synchronization wait")
        with capture_scenario(result):
            session.wait_for_region_text("body", "M-x ")
        self.assertEqual(result.observations[0]["purpose"], "precondition")
        self.assertEqual(result._classification(), "none")

    def test_observe_methods_cannot_accept_passed_override(self):
        session = Session("unused")
        session.screen = Screen(columns=4, rows=2)
        with self.assertRaises(TypeError):
            session.observe_cursor(expected=(0, 0), passed=True)
        with self.assertRaises(TypeError):
            session.observe_external_state("state", False, True, passed=True)

    def test_file_observation_can_expect_absence(self):
        session = Session("unused")
        result = ScenarioResult("missing file")
        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "missing")
            with capture_scenario(result):
                self.assertIsNone(session.assert_file_bytes(path, None))
        observation = result.observations[0]
        self.assertIsNone(observation["actual"])
        self.assertIsNone(observation["expected"])
        self.assertIs(observation["passed"], True)

    def test_observation_records_live_trace_line_count(self):
        result = ScenarioResult("trace timeline")
        result.add_session(b"", b'{"seq":0}\n')
        with tempfile.TemporaryDirectory() as directory:
            trace_path = os.path.join(directory, "trace.jsonl")
            with open(trace_path, "wb") as handle:
                handle.write(b'{"seq":1}\n')
            session = Session("unused")
            session._trace_path = trace_path
            token = set_trace_line_counter(session._trace_line_count)
            try:
                with capture_scenario(result):
                    record_observation("external_state", "first")
                    with open(trace_path, "ab") as handle:
                        handle.write(b'{"seq":2}\n')
                    record_observation("external_state", "second")
            finally:
                reset_trace_line_counter(token)
        self.assertEqual(
            [item["trace_lines"] for item in result.observations], [2, 3]
        )

    def test_observe_cell_attrs_returns_match_result_for_assertion(self):
        session = Session("unused")
        session.screen = Screen(columns=4, rows=2)
        session.screen.feed(b"\x1b[7mX\x1b[0m")
        self.assertIs(session.observe_cell_attrs(0, 0, {"reverse": True}), True)
        self.assertIs(session.observe_cell_attrs(0, 0, {"reverse": False}), False)

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
                return self.screen.cursor == expected

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


    def test_d13_benchmark_adapter_returns_registered_scenario_measurement(self):
        d13_scenario = Mock(
            return_value={"d13_20k_line_key_response_milliseconds": 12.345}
        )
        benchmark = benchmark_scenarios(
            [
                (
                    "d13/20k-line-key-response",
                    ["forward-char"],
                    d13_scenario,
                )
            ]
        )["d13-20k-line-key-response"]

        result = benchmark("loom-binary")

        d13_scenario.assert_called_once_with(
            "loom-binary", benchmark_target_ms=50.0
        )
        self.assertEqual(
            result,
            {"d13_20k_line_key_response_milliseconds": 12.345},
        )

    def test_d13_measurement_is_reported_with_its_own_target(self):
        report = build_benchmark_report(
            {
                "startup": {"startup_to_first_screen_seconds": 0.2},
                "redraw": {"input_to_redraw_p95_milliseconds": 12.0},
                "large-file-open": {
                    "open_100000_lines_5mb_seconds": 0.4,
                    "input": {"lines": 100_000, "bytes": 5_000_000},
                },
                "d13-20k-line-key-response": {
                    "d13_20k_line_key_response_milliseconds": 49.5,
                },
            }
        )

        self.assertEqual(
            report["measurements"]["d13_20k_line_key_response_milliseconds"],
            49.5,
        )
        self.assertEqual(
            report["targets"]["d13_20k_line_key_response_milliseconds"],
            50.0,
        )
        self.assertTrue(report["within_targets"]["d13_20k_line_key_response"])


if __name__ == "__main__":
    unittest.main()
