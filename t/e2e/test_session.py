import json
import os
import signal
import sys
import tempfile
import time
import unittest
from unittest.mock import Mock, patch

from loom_e2e import keys
from loom_e2e.deadline import current_deadline, scenario_deadline
from loom_e2e.process import LoomProcess
from loom_e2e.results import ScenarioResult, capture_scenario
from loom_e2e.screen import Screen
from loom_e2e.session import Session


class JobControlSupervisorTests(unittest.TestCase):
    def test_stopped_application_resumes_and_exits_under_pty(self):
        script = "\n".join(
            (
                "import os, signal",
                "print('ready', flush=True)",
                "os.kill(os.getpid(), signal.SIGTSTP)",
                "print('resumed', flush=True)",
            )
        )
        with LoomProcess(
            sys.executable, ["-c", script], supervise_job_control=True
        ) as process:
            self.assertNotEqual(process._pid, process.application_pid)
            self.assertEqual(os.tcgetpgrp(process._fd), process.application_pid)
            self.assertEqual(
                os.getpgid(process.application_pid), process.application_pid
            )
            self.assertEqual(
                os.getsid(process.application_pid), os.getsid(process._pid)
            )
            deadline = time.monotonic() + 2.0
            stopped = None
            while time.monotonic() < deadline:
                waited_pid, status = os.waitpid(
                    process._pid, os.WNOHANG | os.WUNTRACED
                )
                if waited_pid == process._pid:
                    stopped = status
                    break
                time.sleep(0.01)
            self.assertIsNotNone(stopped)
            self.assertTrue(os.WIFSTOPPED(stopped))

            os.kill(process._pid, signal.SIGCONT)
            output, exit_code = process.wait(timeout=2.0)
            self.assertIn(b"ready", output)
            self.assertIn(b"resumed", output)
            self.assertEqual(exit_code, 0)

    def test_force_kill_reaps_a_stopped_application(self):
        script = "\n".join(
            (
                "import os, signal, time",
                "print('ready', flush=True)",
                "os.kill(os.getpid(), signal.SIGTSTP)",
                "time.sleep(60)",
            )
        )
        with LoomProcess(
            sys.executable, ["-c", script], supervise_job_control=True
        ) as process:
            deadline = time.monotonic() + 2.0
            stopped = False
            while time.monotonic() < deadline:
                waited_pid, status = os.waitpid(
                    process._pid, os.WNOHANG | os.WUNTRACED
                )
                if waited_pid == process._pid:
                    stopped = os.WIFSTOPPED(status)
                    break
                time.sleep(0.01)
            self.assertTrue(stopped)

            process.force_kill()
            output, exit_code = process.wait(timeout=2.0)
            self.assertIn(b"ready", output)
            self.assertEqual(exit_code, 128 + signal.SIGKILL)

    def test_close_resumes_and_reaps_a_stopped_application(self):
        script = "\n".join(
            (
                "import os, signal, time",
                "print('ready', flush=True)",
                "os.kill(os.getpid(), signal.SIGTSTP)",
                "time.sleep(60)",
            )
        )
        with LoomProcess(
            sys.executable, ["-c", script], supervise_job_control=True
        ) as process:
            deadline = time.monotonic() + 2.0
            stopped = False
            while time.monotonic() < deadline:
                waited_pid, status = os.waitpid(
                    process._pid, os.WNOHANG | os.WUNTRACED
                )
                if waited_pid == process._pid:
                    stopped = os.WIFSTOPPED(status)
                    break
                time.sleep(0.01)
            self.assertTrue(stopped)

            process.close()
            self.assertEqual(process._status, 128 + signal.SIGHUP)


class SessionCommandCompletionTests(unittest.TestCase):
    def test_wait_for_command_completion_ignores_prior_trace_records(self):
        with tempfile.TemporaryDirectory() as directory:
            trace_path = os.path.join(directory, "trace.jsonl")
            with open(trace_path, "wb") as handle:
                handle.write(
                    b'{"command":"eval-buffer","route":"mx","seq":1,'
                    b'"completed":false}\n'
                )

            session = Session("unused")
            session.screen = Screen(columns=20, rows=2)
            session._trace_path = trace_path

            def finish_command():
                with open(trace_path, "ab") as handle:
                    handle.write(
                        b'{"command":"eval-buffer","route":"mx",'
                        b'"seq":2,"completed":true}\n'
                    )

            session.pump = Mock(side_effect=finish_command)
            after = session.command_trace_count()

            session.wait_for_command_completion(
                "eval-buffer", route="mx", after=after, timeout=1
            )

            session.pump.assert_called_once_with()
            self.assertEqual(session.command_trace_count(), 2)

    def test_wait_for_command_completion_accepts_failed_invocation_trace(self):
        with tempfile.TemporaryDirectory() as directory:
            trace_path = os.path.join(directory, "trace.jsonl")
            session = Session("unused")
            session.screen = Screen(columns=20, rows=2)
            session._trace_path = trace_path

            def finish_command():
                with open(trace_path, "ab") as handle:
                    handle.write(
                        b'{"command":"mode/newline-and-indent",'
                        b'"route":"key","seq":1,"completed":false}\n'
                    )

            session.pump = Mock(side_effect=finish_command)
            session.wait_for_command_completion(
                "newline", route="key", timeout=1
            )

            session.pump.assert_called_once_with()


class SessionFileWaitTests(unittest.TestCase):
    _SAVE_TRACE = b'{"command":"save-buffer","route":"key","seq":1,"completed":true}\n'

    def _session(self, directory):
        trace_path = os.path.join(directory, "trace.jsonl")
        session = Session("unused")
        session.screen = Screen(columns=20, rows=2)
        session._trace_path = trace_path
        return session, trace_path

    def test_unchanged_bytes_are_not_read_before_the_save_trace(self):
        with tempfile.TemporaryDirectory() as directory:
            session, trace_path = self._session(directory)
            path = os.path.join(directory, "buffer.txt")
            with open(path, "wb") as handle:
                handle.write(b"abc\n")
            steps = []

            def save_across_turns():
                # The old bytes equal the expected bytes, so only the trace can
                # show that the save has started, truncated, and rewritten them.
                if not steps:
                    steps.append("idle")
                elif steps == ["idle"]:
                    open(path, "wb").close()
                    steps.append("truncated")
                else:
                    with open(path, "wb") as handle:
                        handle.write(b"abc\n")
                    with open(trace_path, "ab") as handle:
                        handle.write(self._SAVE_TRACE)
                    steps.append("written")

            session.pump = Mock(side_effect=save_across_turns)
            result = ScenarioResult("file wait")
            with capture_scenario(result):
                session.wait_for_file(
                    path,
                    b"abc\n",
                    command="save-buffer",
                    route="key",
                    after=0,
                    timeout=1,
                )

            self.assertEqual(steps, ["idle", "truncated", "written"])
            observation = result.observations[-1]
            self.assertEqual(observation["type"], "file_bytes")
            self.assertIs(observation["passed"], True)
            self.assertEqual(observation["trace_lines"], 1)

    def _write(self, path, data):
        with open(path, "wb") as handle:
            handle.write(data)

    def _append_trace(self, trace_path, completed=True, seq=1, route="key"):
        state = "true" if completed else "false"
        with open(trace_path, "ab") as handle:
            handle.write(
                f'{{"command":"save-buffer","route":"{route}","seq":{seq},'
                f'"completed":{state}}}\n'.encode()
            )

    def test_matching_bytes_without_a_save_trace_time_out(self):
        with tempfile.TemporaryDirectory() as directory:
            session, _trace_path = self._session(directory)
            path = os.path.join(directory, "buffer.txt")
            self._write(path, b"abc\n")
            session.pump = Mock()

            with self.assertRaisesRegex(TimeoutError, "save-buffer completion"):
                session.wait_for_file(
                    path,
                    b"abc\n",
                    command="save-buffer",
                    route="key",
                    after=0,
                    timeout=0.05,
                )

    def test_bytes_that_differ_after_the_trace_fail_on_the_one_read(self):
        with tempfile.TemporaryDirectory() as directory:
            session, trace_path = self._session(directory)
            path = os.path.join(directory, "buffer.txt")
            self._write(path, b"old\n")
            self._append_trace(trace_path)
            session.pump = Mock()

            with self.assertRaisesRegex(AssertionError, "contained b'old"):
                session.wait_for_file(
                    path,
                    b"new\n",
                    command="save-buffer",
                    route="key",
                    after=0,
                    timeout=1,
                )
            session.pump.assert_not_called()

    def test_bare_wait_for_file_raises_before_reading_the_file(self):
        with tempfile.TemporaryDirectory() as directory:
            session, trace_path = self._session(directory)
            path = os.path.join(directory, "buffer.txt")
            self._write(path, b"abc\n")
            self._append_trace(trace_path)
            session.pump = Mock()
            result = ScenarioResult("bare wait")
            with capture_scenario(result), patch(
                "builtins.open", side_effect=AssertionError("file was read")
            ):
                with self.assertRaisesRegex(TypeError, "write_and_wait"):
                    session.wait_for_file(path, b"abc\n")
                with self.assertRaisesRegex(TypeError, "write_and_wait"):
                    session.wait_for_file(path, b"abc\n", command="save-buffer")
            self.assertEqual(result.observations, [])
            session.pump.assert_not_called()

    def test_old_style_raw_save_then_bare_wait_errors(self):
        with tempfile.TemporaryDirectory() as directory:
            session, trace_path = self._session(directory)
            session.process = Mock()
            path = os.path.join(directory, "buffer.txt")
            self._write(path, b"abc\n")
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            self._append_trace(trace_path)

            with self.assertRaises(TypeError):
                session.wait_for_file(path, b"abc\n")

    def test_mx_write_file_by_completion_or_split_input_errors(self):
        for inputs in (
            [keys.text("write-fil"), b"\t", b"\r"],
            [keys.text("write-"), keys.text("file"), b"\r"],
        ):
            with self.subTest(inputs=inputs), tempfile.TemporaryDirectory() as directory:
                session, trace_path = self._session(directory)
                session.process = Mock()
                path = os.path.join(directory, "buffer.txt")
                self._write(path, b"abc\n")
                session.pump = Mock(side_effect=lambda: self._append_trace(trace_path))
                session.save_buffer(path, b"abc\n", timeout=1)
                session.send(keys.meta("x"))
                for data in inputs:
                    session.send(data)

                with self.assertRaises(TypeError):
                    session.wait_for_file(path, b"abc\n")

    def test_unconfirmed_write_blocks_the_next_write(self):
        with tempfile.TemporaryDirectory() as directory:
            session, trace_path = self._session(directory)
            session.process = Mock()
            path = os.path.join(directory, "buffer.txt")
            self._write(path, b"abc\n")
            session.pump = Mock()

            # Two saves sent before the first completion: the first wait gives
            # up, and the second save must not reuse the first one's late row.
            with self.assertRaises(TimeoutError):
                session.save_buffer(path, b"abc\n", timeout=0.05)
            self._append_trace(trace_path)
            with self.assertRaisesRegex(RuntimeError, "never confirmed"):
                session.save_buffer(path, b"abc\n", timeout=1)
            self.assertEqual(session.process.write.call_count, 1)

    def test_second_same_content_save_waits_for_its_own_row(self):
        with tempfile.TemporaryDirectory() as directory:
            session, trace_path = self._session(directory)
            session.process = Mock()
            path = os.path.join(directory, "buffer.txt")
            self._write(path, b"abc\n")
            turns = []

            def finish(seq):
                def pump():
                    turns.append(seq)
                    self._append_trace(trace_path, seq=seq)
                return pump

            session.pump = Mock(side_effect=finish(1))
            session.save_buffer(path, b"abc\n", timeout=1)
            session.pump = Mock()
            with self.assertRaises(TimeoutError):
                session.write_and_wait(
                    path,
                    b"abc\n",
                    command="save-buffer",
                    route="key",
                    keys=keys.ctrl("x") + keys.ctrl("s"),
                    timeout=0.05,
                )
            self.assertEqual(turns, [1])

    def test_failed_save_with_unchanged_bytes_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            session, trace_path = self._session(directory)
            session.process = Mock()
            path = os.path.join(directory, "buffer.txt")
            self._write(path, b"abc\n")
            session.pump = Mock(
                side_effect=lambda: self._append_trace(trace_path, completed=False)
            )

            with self.assertRaisesRegex(AssertionError, "completed:false"):
                session.save_buffer(path, b"abc\n", timeout=1)

    def test_macro_replay_waits_for_the_macro_route_save(self):
        with tempfile.TemporaryDirectory() as directory:
            session, trace_path = self._session(directory)
            session.process = Mock()
            path = os.path.join(directory, "buffer.txt")
            self._write(path, b"aa\n")
            self._append_trace(trace_path)  # the save made while recording
            session.pump = Mock(
                side_effect=lambda: self._append_trace(
                    trace_path, seq=2, route="macro"
                )
            )
            session.write_and_wait(
                path,
                b"aa\n",
                command="save-buffer",
                route="macro",
                keys=keys.ctrl("x") + b"e",
                timeout=1,
            )
            session.pump.assert_called_once_with()

    def test_mx_writer_runs_through_extended_command(self):
        with tempfile.TemporaryDirectory() as directory:
            session, trace_path = self._session(directory)
            sidecar = os.path.join(directory, "#buffer.txt#")
            self._write(sidecar, b"xdraft\n")
            ran = []

            def extended_command(name, timeout):
                ran.append(name)
                with open(trace_path, "ab") as handle:
                    handle.write(
                        b'{"command":"auto-save-current-buffer","route":"mx",'
                        b'"seq":1,"completed":true}\n'
                    )

            session.extended_command = extended_command
            session.pump = Mock()
            session.write_and_wait(
                sidecar,
                b"xdraft\n",
                command="auto-save-current-buffer",
                route="mx",
                mx="auto-save-current-buffer",
                timeout=1,
            )
            self.assertEqual(ran, ["auto-save-current-buffer"])

    def test_save_buffer_anchors_on_the_trace_count_before_sending(self):
        with tempfile.TemporaryDirectory() as directory:
            session, trace_path = self._session(directory)
            path = os.path.join(directory, "buffer.txt")
            with open(trace_path, "wb") as handle:
                handle.write(self._SAVE_TRACE)
            with open(path, "wb") as handle:
                handle.write(b"abc\n")
            sent = []

            def send(data):
                sent.append(data)
                with open(trace_path, "ab") as handle:
                    handle.write(self._SAVE_TRACE.replace(b'"seq":1', b'"seq":2'))

            session.send = send
            session.pump = Mock()
            session.save_buffer(path, b"abc\n", timeout=1)

            self.assertEqual(sent, [keys.ctrl("x") + keys.ctrl("s")])
            self.assertEqual(session.command_trace_count(), 2)

    def test_prompted_file_is_read_after_the_writer_message(self):
        with tempfile.TemporaryDirectory() as directory:
            session, _trace_path = self._session(directory)
            path = os.path.join(directory, "written.txt")
            order = []

            def wait_for_message(region, text, timeout):
                order.append(("message", region, text))
                with open(path, "wb") as handle:
                    handle.write(b"source\n")

            session.wait_for_region_text = wait_for_message
            session.wait_for_prompted_file(path, b"source\n", "Wrote ", timeout=1)

            self.assertEqual(order, [("message", "minibuffer", "Wrote ")])


class SessionStartupTimingTests(unittest.TestCase):
    def test_wait_ready_uses_time_when_output_is_read(self):
        clock = {"now": 10.0}

        class FakeScreen:
            def __init__(self):
                self.content = False
                self.fed_bytes = None

            def has_content(self):
                return self.content

            def feed(self, data):
                self.fed_bytes = data
                clock["now"] = 10.20
                self.content = True

        screen = FakeScreen()
        process = Mock()

        def poll(timeout):
            self.assertEqual(timeout, 0.05)
            clock["now"] = 10.05
            return b"screen"

        process.poll.side_effect = poll
        session = Session("unused")
        session.process = process
        session.screen = screen
        session._refresh_layout_trace = Mock(
            side_effect=lambda: clock.__setitem__("now", 10.30)
        )
        session.observe_screen_text = Mock()

        with patch(
            "loom_e2e.session.time.monotonic",
            side_effect=lambda: clock["now"],
        ):
            session.wait_ready(timeout=1.0)

        self.assertEqual(screen.fed_bytes, b"screen")
        self.assertEqual(clock["now"], 10.30)
        self.assertEqual(session.first_screen_at, 10.05)
        process.poll.assert_called_once_with(0.05)
        session._refresh_layout_trace.assert_called_once_with()


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
