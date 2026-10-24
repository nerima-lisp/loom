import json
import os
import sys
import tempfile
import unittest
from unittest.mock import patch

from loom_e2e import keys
from loom_e2e.deadline import current_deadline, scenario_deadline
from loom_e2e.process import LoomProcess
from loom_e2e.results import ScenarioResult, capture_scenario
from loom_e2e.session import Session


class SessionRestartTests(unittest.TestCase):
    def test_restart_reuses_session_and_captures_each_child(self):
        with tempfile.TemporaryDirectory() as root:
            scratch = os.path.join(root, "scratch")
            os.makedirs(scratch)
            session_file = os.path.join(scratch, "session.state")
            with open(session_file, "wb") as handle:
                handle.write(b"retained session")

            script = "\n".join(
                (
                    "import json, os, pathlib, sys, time",
                    "with open(",
                    "    os.environ['LOOM_TRACE_COMMANDS'], 'a', encoding='utf-8'",
                    ") as trace:",
                    "    trace.write(json.dumps({'pid': os.getpid()}) + '\\n')",
                    "print(",
                    "    'READY:' + pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'),",
                    "    flush=True,",
                    ")",
                    "time.sleep(60)",
                )
            )
            arguments = ["-c", script, session_file]
            session = Session(
                sys.executable,
                arguments,
                columns=42,
                rows=9,
                profile=keys.XTERM,
            )
            original_arguments = session.arguments
            original_profile = session.profile
            result = ScenarioResult("session restart")
            spawns = []
            real_loom_process = LoomProcess

            def spawn(binary, process_arguments, **options):
                if spawns:
                    old_process = spawns[0]["process"]
                    self.assertIsNone(session.process)
                    self.assertIsNone(session.screen)
                    self.assertTrue(old_process.has_exited())
                    self.assertIsNone(old_process._fd)
                    budget = current_deadline()
                    self.assertNotIn(old_process, budget._cleanup_processes)

                entry = {
                    "binary": binary,
                    "arguments": process_arguments,
                    "env": dict(options["env"]),
                    "columns": options["columns"],
                    "rows": options["rows"],
                }
                process = real_loom_process(binary, process_arguments, **options)
                entry["process"] = process
                spawns.append(entry)
                return process

            with patch("loom_e2e.session._pick_utf8_locale", return_value="C.UTF-8"):
                with patch("loom_e2e.session.tempfile.mkdtemp", return_value=scratch):
                    with patch("loom_e2e.session.LoomProcess", side_effect=spawn):
                        with scenario_deadline(seconds=8.0, cleanup_seconds=2.0):
                            with capture_scenario(result):
                                with session:
                                    session.wait_for_text(
                                        "READY:retained session", timeout=2.0
                                    )
                                    self.assertEqual(
                                        result.observations[-1]["trace_lines"], 1
                                    )
                                    first_process = session.process
                                    first_screen = session.screen
                                    original_scratch = session.scratch_dir
                                    original_home = session.home_dir
                                    original_locale = session._locale_name
                                    original_trace_path = session._trace_path
                                    original_screen_profile = session.profile
                                    original_started_at = session.started_at

                                    self.assertEqual(original_arguments[-1], session_file)
                                    self.assertIs(original_arguments, session.arguments)
                                    self.assertIs(original_profile, session.profile)
                                    self.assertTrue(first_screen.has_content())

                                    self.assertIs(session.restart(), session)

                                    second_process = session.process
                                    self.assertIsNot(first_process, second_process)
                                    self.assertIsNot(first_screen, session.screen)
                                    self.assertFalse(session.screen.has_content())
                                    self.assertTrue(first_process.has_exited())
                                    self.assertIsNone(first_process._fd)
                                    self.assertIs(session.scratch_dir, original_scratch)
                                    self.assertIs(session.home_dir, original_home)
                                    self.assertIs(session._locale_name, original_locale)
                                    self.assertIs(session.profile, original_screen_profile)
                                    self.assertIs(session._trace_path, original_trace_path)
                                    self.assertIs(session.arguments, original_arguments)
                                    self.assertEqual(session.arguments, arguments)
                                    self.assertGreater(session.started_at, original_started_at)
                                    with open(session_file, "rb") as handle:
                                        self.assertEqual(handle.read(), b"retained session")

                                    first_spawn, second_spawn = spawns
                                    self.assertIs(
                                        first_spawn["arguments"], original_arguments
                                    )
                                    self.assertIs(
                                        second_spawn["arguments"], original_arguments
                                    )
                                    self.assertEqual(
                                        first_spawn["binary"], second_spawn["binary"]
                                    )
                                    self.assertEqual(first_spawn["env"], second_spawn["env"])
                                    self.assertEqual(first_spawn["columns"], 42)
                                    self.assertEqual(second_spawn["columns"], 42)
                                    self.assertEqual(first_spawn["rows"], 9)
                                    self.assertEqual(second_spawn["rows"], 9)
                                    self.assertEqual(first_spawn["env"]["HOME"], original_home)
                                    self.assertEqual(first_spawn["env"]["LANG"], "C.UTF-8")
                                    self.assertEqual(first_spawn["env"]["LC_ALL"], "C.UTF-8")
                                    self.assertEqual(first_spawn["env"]["TERM"], keys.XTERM.term)
                                    self.assertEqual(
                                        first_spawn["env"]["LOOM_TRACE_COMMANDS"],
                                        original_trace_path,
                                    )
                                    budget = current_deadline()
                                    self.assertNotIn(first_process, budget._cleanup_processes)
                                    self.assertIn(second_process, budget._cleanup_processes)

                                    session.wait_for_text(
                                        "READY:retained session", timeout=2.0
                                    )
                                    self.assertEqual(
                                        result.observations[-1]["trace_lines"], 2
                                    )
                                    self.assertEqual(len(result.sessions), 1)

                        self.assertTrue(first_process.has_exited())
                        self.assertIsNone(first_process._fd)
                        self.assertTrue(second_process.has_exited())
                        self.assertIsNone(second_process._fd)

            self.assertFalse(os.path.exists(scratch))
            self.assertEqual(len(result.sessions), 2)
            trace_lines = result.trace_output.decode("utf-8").splitlines()
            self.assertEqual(len(trace_lines), 2)
            trace_pids = [json.loads(line)["pid"] for line in trace_lines]
            self.assertEqual(trace_pids, [first_process._pid, second_process._pid])
            self.assertEqual(result.pty_output.count(b"READY:retained session"), 2)
            self.assertEqual(session.trace_bytes, bytes(result.trace_output))


if __name__ == "__main__":
    unittest.main()
