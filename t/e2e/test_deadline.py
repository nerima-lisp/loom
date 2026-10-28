import errno
import locale
import os
import pty
import select
import signal
import shutil
import sys
import tempfile
import time
import unittest
from unittest import mock

import loom_e2e.deadline as deadline_module
from loom_e2e.deadline import (
    SCENARIO_CLEANUP_TIMEOUT_SECONDS,
    SCENARIO_EXECUTION_TIMEOUT_SECONDS,
    SCENARIO_TIMEOUT_SECONDS,
    ScenarioCleanupDeadlineExceeded,
    ScenarioDeadlineBudget,
    ScenarioDeadlineExceeded,
    current_deadline,
    run_scenario,
    scenario_deadline,
)
from loom_e2e.process import LoomProcess
from loom_e2e.session import Session, _available_locales, _pick_utf8_locale


_UNKILLABLE_CHILD = """\
import signal
import time
signal.signal(signal.SIGHUP, signal.SIG_IGN)
signal.signal(signal.SIGTERM, signal.SIG_IGN)
while True:
    time.sleep(1)
"""


class ScenarioDeadlineTests(unittest.TestCase):
    def setUp(self):
        self._handler = signal.getsignal(signal.SIGALRM)
        self._timer = signal.getitimer(signal.ITIMER_REAL)
        signal.setitimer(signal.ITIMER_REAL, 0.0, 0.0)
        self.addCleanup(self._restore_signal_state)

    def _restore_signal_state(self):
        signal.setitimer(signal.ITIMER_REAL, 0.0, 0.0)
        signal.signal(signal.SIGALRM, self._handler)
        signal.setitimer(signal.ITIMER_REAL, *self._timer)

    def _track_unkillable_process(self):
        process = LoomProcess(sys.executable, ["-c", _UNKILLABLE_CHILD])
        pid = process._pid

        def assert_reaped():
            self.assertTrue(process.has_exited())
            with self.assertRaises(ProcessLookupError):
                os.kill(pid, 0)

        self.addCleanup(assert_reaped)
        self.addCleanup(process.close)
        self.assertFalse(process.has_exited())
        return process

    def test_run_scenario_reports_execution_elapsed_to_callback(self):
        elapsed = []
        with mock.patch(
            "loom_e2e.deadline.time.monotonic",
            side_effect=[10.0, 10.125, 10.125],
        ):
            value = run_scenario(
                lambda _binary: "done",
                "unused",
                execution_elapsed_callback=elapsed.append,
            )
        self.assertEqual(value, "done")
        self.assertEqual(elapsed, [0.125])

    def test_budget_separates_execution_time_from_cleanup_reserve(self):
        budget = ScenarioDeadlineBudget(110.0, 105.0)
        with mock.patch("loom_e2e.deadline.time.monotonic", return_value=103.5):
            self.assertEqual(budget.execution_remaining(), 1.5)
            self.assertEqual(budget.remaining(), 6.5)
        with mock.patch("loom_e2e.deadline.time.monotonic", return_value=106.0):
            self.assertEqual(budget.execution_remaining(), 0.0)
            self.assertEqual(budget.remaining(), 4.0)

    def test_run_scenario_enforces_total_deadline(self):
        started = 100.0
        execution_seconds = 0.07
        elapsed = []

        def expire(_binary):
            clock.return_value = started + execution_seconds
            signal.getsignal(signal.SIGALRM)(signal.SIGALRM, None)

        with mock.patch(
            "loom_e2e.deadline.time.monotonic", return_value=started
        ) as clock, mock.patch("loom_e2e.deadline.signal.setitimer"):
            with self.assertRaises(ScenarioDeadlineExceeded):
                run_scenario(
                    expire,
                    "unused",
                    seconds=0.1,
                    cleanup_seconds=0.03,
                    execution_elapsed_callback=elapsed.append,
                )
        self.assertEqual(len(elapsed), 1)
        self.assertAlmostEqual(elapsed[0], execution_seconds)

    def test_preparation_time_does_not_consume_execution_budget(self):
        clock = [100.0]
        budget = ScenarioDeadlineBudget(110.0, 105.0)
        with (
            mock.patch(
                "loom_e2e.deadline.current_deadline", return_value=budget
            ),
            mock.patch(
                "loom_e2e.deadline.signal.getitimer", return_value=(5.0, 0.0)
            ),
            mock.patch("loom_e2e.deadline.signal.setitimer") as setitimer,
            mock.patch(
                "loom_e2e.deadline.time.monotonic", side_effect=lambda: clock[0]
            ),
        ):
            with deadline_module.scenario_preparation():
                clock[0] = 130.0
                self.assertEqual(budget.execution_remaining(), 5.0)
                self.assertEqual(budget.remaining(), 10.0)

            self.assertEqual(budget.execution_remaining(), 5.0)
            self.assertEqual(budget.remaining(), 10.0)
            clock[0] += 1.0
            self.assertEqual(budget.execution_remaining(), 4.0)
            self.assertEqual(budget.remaining(), 9.0)
            self.assertEqual(
                setitimer.call_args_list,
                [
                    mock.call(signal.ITIMER_REAL, 0.0, 0.0),
                    mock.call(signal.ITIMER_REAL, 5.0, 0.0),
                ],
            )

    def test_delayed_execution_alarm_preserves_absolute_deadline(self):
        for elapsed, remaining in [(0.6, 0.4), (0.9, 0.1), (1.1, 0.0)]:
            with self.subTest(elapsed=elapsed):
                with mock.patch(
                    "loom_e2e.deadline.time.monotonic", return_value=100.0
                ) as clock, mock.patch("loom_e2e.deadline.signal.setitimer") as timer:
                    with scenario_deadline(seconds=1.0, cleanup_seconds=0.4):
                        clock.return_value = 100.0 + elapsed
                        expire = signal.getsignal(signal.SIGALRM)
                        error = (
                            ScenarioCleanupDeadlineExceeded
                            if remaining == 0.0
                            else ScenarioDeadlineExceeded
                        )
                        with self.assertRaises(error) as raised:
                            expire(signal.SIGALRM, None)
                        self.assertIs(type(raised.exception), error)
                        self.assertTrue(current_deadline().expired)
                        self.assertEqual(timer.call_args.args[0], signal.ITIMER_REAL)
                        self.assertAlmostEqual(timer.call_args.args[1], remaining)
                        self.assertEqual(timer.call_args.args[2], 0.0)

    def test_cleanup_deadline_interrupts_cleanup(self):
        cleanup_finished = []
        started = 100.0
        execution_seconds = 0.09
        total_seconds = 0.12

        def expiring_cleanup(_binary):
            try:
                clock.return_value = started + execution_seconds
                signal.getsignal(signal.SIGALRM)(signal.SIGALRM, None)
            finally:
                clock.return_value = started + total_seconds
                signal.getsignal(signal.SIGALRM)(signal.SIGALRM, None)
                cleanup_finished.append(True)

        with mock.patch(
            "loom_e2e.deadline.time.monotonic", return_value=started
        ) as clock, mock.patch("loom_e2e.deadline.signal.setitimer"):
            with self.assertRaises(ScenarioCleanupDeadlineExceeded):
                run_scenario(
                    expiring_cleanup,
                    "unused",
                    seconds=total_seconds,
                    cleanup_seconds=0.03,
                )

        self.assertFalse(cleanup_finished)

    def test_body_timeout_reaps_unkillable_pty_with_final_kill(self):
        processes = []

        def body(_binary):
            process = self._track_unkillable_process()
            processes.append(process)
            try:
                signal.pause()
            finally:
                process.close()

        with self.assertRaises(ScenarioDeadlineExceeded) as raised:
            run_scenario(
                body,
                "unused",
                seconds=SCENARIO_TIMEOUT_SECONDS,
                cleanup_seconds=SCENARIO_CLEANUP_TIMEOUT_SECONDS,
            )

        self.assertIn("execution budget expired after 5 seconds", str(raised.exception))
        process = processes[0]
        self.assertTrue(process.has_exited())
        self.assertIsNone(process._fd)

    def test_cleanup_timeout_during_pty_close_still_reaps_child(self):
        processes = []

        def body(_binary):
            process = self._track_unkillable_process()
            processes.append(process)
            try:
                signal.pause()
            finally:
                process.close()

        # A loaded macOS arm64 calibration ran 100 trials with 16 logical
        # cores and 0% CPU idle. From the nominal execution deadline to
        # successful close, p50/p95/p99/max were 10.006/14.176/22.995/23.218
        # ms. The 0.25-second reserve gives 10.8x the observed maximum while
        # preserving the 0.2-second execution phase and both assertions below.
        with self.assertRaises(ScenarioDeadlineExceeded):
            run_scenario(body, "unused", seconds=0.45, cleanup_seconds=0.25)

        process = processes[0]
        self.assertTrue(process.has_exited())
        self.assertIsNone(process._fd)

    def test_close_reaps_child_after_pty_descriptor_was_closed(self):
        process = LoomProcess(
            sys.executable,
            ["-c", "import time; time.sleep(60)"],
        )
        self.addCleanup(process.close)
        descriptor = process._fd
        os.close(descriptor)
        process._fd = None

        process.close()

        self.assertTrue(process.has_exited())
        self.assertIsNone(process._fd)

    def test_forced_reap_survives_cleanup_interrupt(self):
        process = self._track_unkillable_process()
        real_wait_for_exit = process._wait_for_exit
        waits = iter([
            TimeoutError("grace period expired"),
            ScenarioCleanupDeadlineExceeded("forced wait interrupted"),
            ScenarioCleanupDeadlineExceeded("forced wait interrupted again"),
        ])

        def wait_with_interrupts(remaining):
            try:
                raise next(waits)
            except StopIteration:
                return real_wait_for_exit(remaining)

        process._wait_for_exit = mock.Mock(side_effect=wait_with_interrupts)

        with scenario_deadline(seconds=0.5, cleanup_seconds=0.2):
            with self.assertRaises(ScenarioCleanupDeadlineExceeded):
                process.close()

        self.assertTrue(process.has_exited())
        self.assertIsNone(process._fd)

    def test_alarm_after_waitpid_preserves_reaped_status(self):
        process = LoomProcess(sys.executable, ["-c", "pass"])
        self.addCleanup(process.close)
        real_waitpid = os.waitpid

        def interrupt_after_reap(pid, _options):
            result = real_waitpid(pid, 0)
            os.kill(os.getpid(), signal.SIGALRM)
            return result

        def interrupt(_signum, _frame):
            raise ScenarioCleanupDeadlineExceeded("interrupted after reap")

        signal.signal(signal.SIGALRM, interrupt)
        with mock.patch("loom_e2e.process.os.waitpid", interrupt_after_reap):
            with self.assertRaises(ScenarioCleanupDeadlineExceeded):
                process._poll_exit()

        self.assertTrue(process.has_exited())
        self.assertEqual(process._status, 0)

    def test_alarm_after_close_preserves_closed_pty_state(self):
        process = self._track_unkillable_process()
        process.force_kill()
        process._wait_for_exit(2.0)
        fd = process._fd
        real_close = os.close
        error = ScenarioCleanupDeadlineExceeded("interrupted after PTY close")

        def interrupt_after_close(target):
            real_close(target)
            os.kill(os.getpid(), signal.SIGALRM)

        def interrupt(_signum, _frame):
            raise error

        signal.signal(signal.SIGALRM, interrupt)
        with mock.patch("loom_e2e.process.os.close", interrupt_after_close):
            with self.assertRaises(ScenarioCleanupDeadlineExceeded) as raised:
                process.close()

        self.assertIs(raised.exception, error)
        self.assertTrue(process.has_exited())
        self.assertIsNone(process._fd)
        with self.assertRaises(OSError) as closed:
            os.fstat(fd)
        self.assertEqual(closed.exception.errno, errno.EBADF)

    def test_locale_discovery_preserves_scenario_deadlines(self):
        for error_type in (ScenarioDeadlineExceeded, ScenarioCleanupDeadlineExceeded):
            with self.subTest(error_type=error_type):
                error = error_type("locale discovery interrupted")
                with mock.patch("loom_e2e.session.subprocess.run", side_effect=error):
                    with self.assertRaises(error_type) as raised:
                        _available_locales()
                self.assertIs(raised.exception, error)

    def test_locale_discovery_retains_os_error_fallback(self):
        with mock.patch("loom_e2e.session.subprocess.run", side_effect=OSError("locale unavailable")):
            self.assertEqual(_available_locales(), set())

    def test_locale_selection_reuses_active_utf8_locale(self):
        for active, encoding in (("C.UTF-8", "UTF-8"), ("ja_JP.UTF-8", "utf8")):
            with self.subTest(active=active):
                with mock.patch("locale.getlocale", return_value=("unused", encoding)) as getlocale:
                    with mock.patch("locale.setlocale", return_value=active) as setlocale:
                        with mock.patch("loom_e2e.session._available_locales", return_value={"en_US.UTF-8"}) as discovery:
                            self.assertEqual(_pick_utf8_locale(), active)
                getlocale.assert_called_once_with(locale.LC_CTYPE)
                setlocale.assert_called_once_with(locale.LC_CTYPE)
                discovery.assert_not_called()

    def test_locale_selection_discovers_utf8_when_active_locale_is_not_utf8(self):
        with mock.patch("locale.getlocale", return_value=(None, None)):
            with mock.patch("locale.setlocale") as setlocale:
                with mock.patch("loom_e2e.session._available_locales", return_value={"C.UTF-8"}) as discovery:
                    self.assertEqual(_pick_utf8_locale(), "C.UTF-8")
        discovery.assert_called_once_with()
        setlocale.assert_not_called()

    def test_expired_locale_setup_does_not_allocate_scratch_directory(self):
        session = Session("unused")
        error = ScenarioCleanupDeadlineExceeded("locale setup exhausted cleanup")
        real_mkdtemp = tempfile.mkdtemp
        try:
            with mock.patch("loom_e2e.session.tempfile.mkdtemp", wraps=real_mkdtemp) as mkdtemp:
                with mock.patch("loom_e2e.session._pick_utf8_locale", side_effect=error):
                    with scenario_deadline(seconds=1.0, cleanup_seconds=0.2):
                        budget = current_deadline()
                        budget.expired = True
                        budget.deadline = time.monotonic() - 1.0
                        with self.assertRaises(ScenarioCleanupDeadlineExceeded) as raised:
                            session.__enter__()
        finally:
            if session.scratch_dir is not None:
                self.addCleanup(shutil.rmtree, session.scratch_dir, ignore_errors=True)
        self.assertIs(raised.exception, error)
        mkdtemp.assert_not_called()
        self.assertIsNone(session.scratch_dir)

    def test_session_setup_failure_removes_scratch_directory(self):
        session = Session("unused")
        error = ScenarioDeadlineExceeded("session setup interrupted")
        with mock.patch("loom_e2e.session._pick_utf8_locale", return_value="C.UTF-8"):
            with mock.patch("loom_e2e.session.LoomProcess", side_effect=error):
                with self.assertRaises(ScenarioDeadlineExceeded) as raised:
                    session.__enter__()
        self.assertIs(raised.exception, error)
        self.assertIsNotNone(session.scratch_dir)
        self.addCleanup(shutil.rmtree, session.scratch_dir, ignore_errors=True)
        self.assertFalse(os.path.exists(session.scratch_dir))

    def test_session_does_not_inherit_parent_credentials(self):
        session = Session("unused")
        credential_name = "LOOM_E2E_TEST_CREDENTIAL"
        parent_path = os.environ.get("PATH")
        parent_environment = {
            credential_name: "test-only-sentinel",
            "LOOM_INIT_FILE": "test-only-init-sentinel",
        }
        with mock.patch.dict(os.environ, parent_environment, clear=False):
            with mock.patch(
                "loom_e2e.session._pick_utf8_locale", return_value="C.UTF-8"
            ):
                with mock.patch("loom_e2e.session.LoomProcess") as process_type:
                    with mock.patch("loom_e2e.session.Screen"):
                        session.__enter__()
                        self.addCleanup(session.__exit__, None, None, None)
                        env = process_type.call_args.kwargs["env"]

        self.assertNotIn(credential_name, env)
        self.assertNotIn("LOOM_INIT_FILE", env)
        if parent_path is None:
            self.assertNotIn("PATH", env)
        else:
            self.assertEqual(env["PATH"], parent_path)
        self.assertEqual(env["HOME"], session.home_dir)
        self.assertEqual(env["TERM"], "xterm-256color")
        self.assertEqual(env["SHELL"], "/bin/sh")
        self.assertEqual(env["LANG"], "C.UTF-8")
        self.assertEqual(env["LC_ALL"], "C.UTF-8")

    def test_alarm_before_scratch_return_removes_directory(self):
        session = Session("unused")
        real_mkdtemp = tempfile.mkdtemp
        directories = []
        error = ScenarioDeadlineExceeded("interrupted before scratch returned")

        def create_and_interrupt(*args, **kwargs):
            directory = real_mkdtemp(*args, **kwargs)
            directories.append(directory)
            self.addCleanup(shutil.rmtree, directory, ignore_errors=True)
            os.kill(os.getpid(), signal.SIGALRM)
            return directory

        def interrupt(_signum, _frame):
            raise error

        previous_mask = signal.pthread_sigmask(signal.SIG_BLOCK, set())
        signal.signal(signal.SIGALRM, interrupt)
        with mock.patch("loom_e2e.session._pick_utf8_locale", return_value="C.UTF-8"):
            with mock.patch("loom_e2e.session.tempfile.mkdtemp", side_effect=create_and_interrupt):
                with mock.patch("loom_e2e.session.LoomProcess") as process:
                    with self.assertRaises(ScenarioDeadlineExceeded) as raised:
                        session.__enter__()
        self.assertIs(raised.exception, error)
        self.assertEqual(signal.pthread_sigmask(signal.SIG_BLOCK, set()), previous_mask)
        self.assertEqual(len(directories), 1)
        self.assertEqual(session.scratch_dir, directories[0])
        self.assertFalse(os.path.exists(directories[0]))
        process.assert_not_called()

    def test_scratch_creation_failure_restores_alarm_signal_mask(self):
        session = Session("unused")
        previous_mask = signal.pthread_sigmask(signal.SIG_BLOCK, set())
        error = OSError("scratch creation failed")
        with mock.patch("loom_e2e.session._pick_utf8_locale", return_value="C.UTF-8"):
            with mock.patch("loom_e2e.session.tempfile.mkdtemp", side_effect=error):
                with mock.patch("loom_e2e.session.LoomProcess") as process:
                    with self.assertRaises(OSError) as raised:
                        session.__enter__()
        self.assertIs(raised.exception, error)
        self.assertEqual(signal.pthread_sigmask(signal.SIG_BLOCK, set()), previous_mask)
        self.assertIsNone(session.scratch_dir)
        process.assert_not_called()

    def test_session_screen_setup_failure_closes_registered_process(self):
        session = Session("unused")
        process = mock.Mock()
        error = RuntimeError("screen setup failed")
        with mock.patch("loom_e2e.session._pick_utf8_locale", return_value="C.UTF-8"):
            with mock.patch("loom_e2e.session.LoomProcess", return_value=process):
                with mock.patch("loom_e2e.session.Screen", side_effect=error):
                    with scenario_deadline(seconds=1.0, cleanup_seconds=0.2):
                        budget = current_deadline()
                        with self.assertRaises(RuntimeError) as raised:
                            session.__enter__()
                        self.assertNotIn(process, budget._cleanup_processes)
        self.assertIs(raised.exception, error)
        process.close.assert_called_once_with()
        self.addCleanup(shutil.rmtree, session.scratch_dir, ignore_errors=True)
        self.assertFalse(os.path.exists(session.scratch_dir))

    def test_session_setup_preserves_original_error_when_cleanup_fails(self):
        session = Session("unused")
        process = mock.Mock()
        setup_error = ScenarioDeadlineExceeded("screen setup interrupted")
        cleanup_error = RuntimeError("process close failed")
        process.close.side_effect = cleanup_error
        with mock.patch("loom_e2e.session._pick_utf8_locale", return_value="C.UTF-8"):
            with mock.patch("loom_e2e.session.LoomProcess", return_value=process):
                with mock.patch("loom_e2e.session.Screen", side_effect=setup_error):
                    with self.assertRaises(ScenarioDeadlineExceeded) as raised:
                        session.__enter__()
        self.assertIs(raised.exception, setup_error)
        self.assertIs(raised.exception.__cause__, cleanup_error)
        process.close.assert_called_once_with()
        self.addCleanup(shutil.rmtree, session.scratch_dir, ignore_errors=True)
        self.assertFalse(os.path.exists(session.scratch_dir))

    def test_alarm_before_fork_return_reaps_child_and_closes_pty(self):
        real_fork = pty.fork
        real_read = os.read
        children = []
        pty_fds = []
        blocking_reads = []
        child_ready = [False]
        ready_read, ready_write = os.pipe()
        os.set_inheritable(ready_write, True)
        child = f'''import os, signal, time
signal.signal(signal.SIGHUP, signal.SIG_IGN)
signal.signal(signal.SIGTERM, signal.SIG_IGN)
os.write({ready_write}, b"R")
while True: time.sleep(1)
'''

        def cleanup_children():
            deadline = time.monotonic() + SCENARIO_CLEANUP_TIMEOUT_SECONDS
            for pid, fd in children:
                try:
                    try:
                        waited, _ = os.waitpid(pid, os.WNOHANG)
                    except ChildProcessError:
                        continue
                    if waited == 0:
                        try:
                            os.kill(pid, signal.SIGKILL)
                        except ProcessLookupError:
                            pass
                    while waited == 0:
                        remaining = deadline - time.monotonic()
                        if remaining <= 0:
                            raise TimeoutError("test child was not reaped during cleanup")
                        time.sleep(min(0.01, remaining))
                        try:
                            waited, _ = os.waitpid(pid, os.WNOHANG)
                        except ChildProcessError:
                            break
                        if waited == pid:
                            break
                finally:
                    try:
                        os.close(fd)
                    except OSError:
                        pass

        def cleanup_ready_pipe():
            for fd in (ready_read, ready_write):
                try:
                    os.close(fd)
                except OSError:
                    pass

        self.addCleanup(cleanup_children)
        self.addCleanup(cleanup_ready_pipe)

        def fork_and_interrupt():
            pid, fd = real_fork()
            if pid > 0:
                children.append((pid, fd))
                pty_fds.append(fd)
                os.close(ready_write)
                readable, _, _ = select.select(
                    [ready_read], [], [], SCENARIO_EXECUTION_TIMEOUT_SECONDS
                )
                if readable:
                    child_ready[0] = real_read(ready_read, 1) == b"R"
                os.kill(os.getpid(), signal.SIGALRM)
            return pid, fd

        def reject_blocking_pty_read(fd, size):
            if fd in pty_fds and os.get_blocking(fd):
                blocking_reads.append(fd)
                raise OSError(errno.EIO, "intercepted blocking PTY read")
            return real_read(fd, size)

        previous_mask = signal.pthread_sigmask(signal.SIG_BLOCK, set())
        with self.assertRaises(ScenarioDeadlineExceeded):
            with scenario_deadline(
                seconds=SCENARIO_TIMEOUT_SECONDS,
                cleanup_seconds=SCENARIO_CLEANUP_TIMEOUT_SECONDS,
            ):
                with mock.patch(
                    "loom_e2e.process.pty.fork", side_effect=fork_and_interrupt
                ):
                    with mock.patch(
                        "loom_e2e.process.os.read", side_effect=reject_blocking_pty_read
                    ):
                        LoomProcess(sys.executable, ["-c", child])
        self.assertTrue(child_ready[0], "child did not install handlers before SIGALRM")
        self.assertEqual(signal.pthread_sigmask(signal.SIG_BLOCK, set()), previous_mask)
        self.assertEqual(len(children), 1)
        pid, fd = children[0]
        with self.assertRaises(ProcessLookupError):
            os.kill(pid, 0)
        with self.assertRaises(ChildProcessError):
            os.waitpid(pid, os.WNOHANG)
        with self.assertRaises(OSError) as closed:
            os.fstat(fd)
        self.assertEqual(closed.exception.errno, errno.EBADF)
        self.assertEqual(blocking_reads, [], "cleanup attempted a blocking PTY read")
        children.clear()

    def test_fork_failure_restores_alarm_signal_mask(self):
        previous_mask = signal.pthread_sigmask(signal.SIG_BLOCK, set())
        error = OSError("fork failed")
        with mock.patch("loom_e2e.process.pty.fork", side_effect=error):
            with mock.patch.object(LoomProcess, "close") as close:
                with self.assertRaises(OSError) as raised:
                    LoomProcess("unused", [])
        self.assertIs(raised.exception, error)
        self.assertEqual(signal.pthread_sigmask(signal.SIG_BLOCK, set()), previous_mask)
        close.assert_not_called()

    def test_child_exec_restores_alarm_signal_mask(self):
        def exit_with_signal_mask(_binary, _argv):
            mask = signal.pthread_sigmask(signal.SIG_BLOCK, set())
            os._exit(int(signal.SIGALRM in mask))

        with mock.patch("loom_e2e.process.os.execv", side_effect=exit_with_signal_mask):
            process = LoomProcess("unused", [])
        self.addCleanup(process.close)
        _output, status = process.wait(timeout=2.0)
        self.assertEqual(status, 0)

    def test_process_parent_setup_failure_reaps_child_and_closes_pty(self):
        real_fork = pty.fork
        for failure_point in ("LoomProcess._set_terminal_size", "os.set_blocking"):
            with self.subTest(failure_point=failure_point):
                children = []

                def fork_and_track():
                    pid, fd = real_fork()
                    if pid > 0:
                        children.append((pid, fd))
                    return pid, fd

                def cleanup_children(children=children):
                    for pid, fd in children:
                        try:
                            os.kill(pid, signal.SIGKILL)
                        except ProcessLookupError:
                            pass
                        try:
                            os.waitpid(pid, 0)
                        except ChildProcessError:
                            pass
                        try:
                            os.close(fd)
                        except OSError:
                            pass

                self.addCleanup(cleanup_children)
                error = RuntimeError("parent PTY setup failed")
                with mock.patch("loom_e2e.process.pty.fork", side_effect=fork_and_track):
                    with mock.patch("loom_e2e.process." + failure_point, side_effect=error):
                        with self.assertRaises(RuntimeError) as raised:
                            LoomProcess(sys.executable, ["-c", _UNKILLABLE_CHILD])
                self.assertIs(raised.exception, error)
                self.assertEqual(len(children), 1)
                pid, fd = children[0]
                with self.assertRaises(ProcessLookupError):
                    os.kill(pid, 0)
                with self.assertRaises(ChildProcessError):
                    os.waitpid(pid, os.WNOHANG)
                with self.assertRaises(OSError):
                    os.fstat(fd)
                children.clear()

    def test_shared_deadline_reaps_multiple_sessions(self):
        sessions = []
        scratch_dirs = []

        def remove_scratch_dirs():
            for path in scratch_dirs:
                shutil.rmtree(path, ignore_errors=True)

        self.addCleanup(remove_scratch_dirs)

        def body(_binary):
            with Session(sys.executable, ["-c", _UNKILLABLE_CHILD]) as first:
                sessions.append(first)
                scratch_dirs.append(first.scratch_dir)
                with Session(sys.executable, ["-c", _UNKILLABLE_CHILD]) as second:
                    sessions.append(second)
                    scratch_dirs.append(second.scratch_dir)
                    self.assertIsNotNone(current_deadline())
                    signal.getsignal(signal.SIGALRM)(signal.SIGALRM, None)

        with self.assertRaises(ScenarioDeadlineExceeded):
            run_scenario(body, "unused", seconds=0.8, cleanup_seconds=0.4)

        self.assertEqual(len(sessions), 2)
        for session in sessions:
            self.assertTrue(session.process.has_exited())
            self.assertIsNone(session.process._fd)
        self.assertTrue(all(not os.path.exists(path) for path in scratch_dirs))

    def test_execution_deadline_interrupts_success_finalizer_and_reaps_pty(self):
        processes = []

        def body(_binary):
            process = self._track_unkillable_process()
            processes.append(process)
            try:
                return
            finally:
                signal.getsignal(signal.SIGALRM)(signal.SIGALRM, None)
                process.close()

        with self.assertRaises(ScenarioDeadlineExceeded):
            run_scenario(body, "unused", seconds=0.4, cleanup_seconds=0.2)

        process = processes[0]
        process.close()
        self.assertTrue(process.has_exited())
        self.assertIsNone(process._fd)

    @mock.patch("loom_e2e.session.shutil.rmtree")
    def test_session_scratch_cleanup_runs_when_process_close_fails(self, rmtree):
        session = Session("unused")
        session._scratch_dir = "scratch-under-test"
        session.process = mock.Mock()
        session.process.close.side_effect = RuntimeError("close failed")

        with self.assertRaisesRegex(RuntimeError, "close failed"):
            session.__exit__(None, None, None)

        rmtree.assert_called_once_with("scratch-under-test", ignore_errors=True)

    def test_exhausted_session_cleanup_reports_scratch_directory(self):
        session = Session("unused")
        session._scratch_dir = tempfile.mkdtemp(prefix="loom-deadline-test-")
        self.addCleanup(shutil.rmtree, session.scratch_dir, ignore_errors=True)
        with scenario_deadline(seconds=1.0, cleanup_seconds=0.2):
            budget = current_deadline()
            budget.expired = True
            budget.deadline = time.monotonic() - 1.0
            with mock.patch("loom_e2e.session.shutil.rmtree") as rmtree:
                with self.assertRaises(ScenarioCleanupDeadlineExceeded) as raised:
                    session.__exit__(None, None, None)
        self.assertIn(session.scratch_dir, str(raised.exception))
        self.assertTrue(os.path.isdir(session.scratch_dir))
        rmtree.assert_not_called()

    def test_interrupted_scratch_cleanup_unregisters_process(self):
        session = Session("unused")
        session._scratch_dir = tempfile.mkdtemp(prefix="loom-deadline-test-")
        self.addCleanup(shutil.rmtree, session.scratch_dir, ignore_errors=True)
        session.process = mock.Mock()
        error = ScenarioCleanupDeadlineExceeded("scratch removal interrupted")
        with scenario_deadline(seconds=1.0, cleanup_seconds=0.2):
            budget = current_deadline()
            budget.register_process(session.process)
            with mock.patch("loom_e2e.session.shutil.rmtree", side_effect=error):
                with self.assertRaises(ScenarioCleanupDeadlineExceeded) as raised:
                    session.__exit__(None, None, None)
            self.assertNotIn(session.process, budget._cleanup_processes)
        self.assertIs(raised.exception, error)
        session.process.close.assert_called_once_with()

    def test_timeout_restores_handler_and_prior_timer(self):
        def previous_handler(_signum, _frame):
            pass

        signal.signal(signal.SIGALRM, previous_handler)
        started = 100.0
        execution_seconds = 0.07

        def expire(_binary):
            clock.return_value = started + execution_seconds
            signal.getsignal(signal.SIGALRM)(signal.SIGALRM, None)

        with mock.patch(
            "loom_e2e.deadline.time.monotonic", return_value=started
        ) as clock, mock.patch(
            "loom_e2e.deadline.signal.getitimer",
            return_value=(30.0, 0.0),
        ), mock.patch("loom_e2e.deadline.signal.setitimer") as timer:
            with self.assertRaises(ScenarioDeadlineExceeded):
                run_scenario(
                    expire, "unused", seconds=0.1, cleanup_seconds=0.03
                )

        self.assertIs(signal.getsignal(signal.SIGALRM), previous_handler)
        timer_restoration = timer.call_args_list[-1].args
        self.assertEqual(timer_restoration[0], signal.ITIMER_REAL)
        self.assertAlmostEqual(timer_restoration[1], 29.93)
        self.assertEqual(timer_restoration[2], 0.0)

    def test_restores_existing_handler_and_timer(self):
        def previous_handler(_signum, _frame):
            pass

        signal.signal(signal.SIGALRM, previous_handler)

        with mock.patch(
            "loom_e2e.deadline.time.monotonic",
            side_effect=[100.0, 100.025],
        ), mock.patch(
            "loom_e2e.deadline.signal.getitimer",
            return_value=(30.0, 0.0),
        ), mock.patch("loom_e2e.deadline.signal.setitimer") as timer:
            with scenario_deadline(seconds=0.1, cleanup_seconds=0.03):
                pass

        self.assertIs(signal.getsignal(signal.SIGALRM), previous_handler)
        timer_restoration = timer.call_args_list[-1].args
        self.assertEqual(timer_restoration[0], signal.ITIMER_REAL)
        self.assertAlmostEqual(timer_restoration[1], 29.975)
        self.assertEqual(timer_restoration[2], 0.0)


if __name__ == "__main__":
    unittest.main()
