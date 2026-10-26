"""Fork loom under a real PTY and expose raw, non-blocking I/O."""

import errno
import fcntl
import os
import pty
import select
import signal
import struct
import termios
import time

from .deadline import current_deadline
from .layout import validate_dimensions


TIMEOUT_SECONDS = 10.0
REAP_RESERVE_SECONDS = 0.25


def _exit_code(status):
    if os.WIFEXITED(status):
        return os.WEXITSTATUS(status)
    if os.WIFSIGNALED(status):
        return 128 + os.WTERMSIG(status)
    return status


def _close_fds(*file_descriptors):
    for descriptor in file_descriptors:
        if descriptor is None:
            continue
        try:
            os.close(descriptor)
        except OSError as error:
            if error.errno != errno.EBADF:
                raise


def _run_job_control_supervisor(
    binary,
    arguments,
    env,
    previous_mask,
    application_pid_pipe,
    ready_pipe,
    start_pipe,
):
    application_pid_read, application_pid_write = application_pid_pipe
    ready_read, ready_write = ready_pipe
    start_read, start_write = start_pipe
    _close_fds(application_pid_read)

    application_pid = os.fork()
    if application_pid == 0:
        _close_fds(application_pid_write, ready_read, start_write)
        os.setpgid(0, 0)
        os.write(ready_write, b"ready")
        _close_fds(ready_write)
        if os.read(start_read, 2) != b"go":
            os._exit(126)
        _close_fds(start_read)
        signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
        signal.signal(signal.SIGTSTP, signal.SIG_DFL)
        argv = [binary, *arguments]
        if env is None:
            os.execv(binary, argv)
        os.execve(binary, argv, env)

    _close_fds(ready_write, start_read)
    if os.read(ready_read, 5) != b"ready":
        _close_fds(ready_read, start_write)
        _waited_pid, status = os.waitpid(application_pid, 0)
        os._exit(_exit_code(status))
    _close_fds(ready_read)
    os.tcsetpgrp(0, application_pid)
    os.write(start_write, b"go")
    _close_fds(start_write)

    child_status = None

    def _forward_child_signal(signum, _frame):
        nonlocal child_status
        if signum == signal.SIGCONT:
            try:
                child_pid, status = os.waitpid(application_pid, os.WNOHANG)
            except ChildProcessError:
                return
            except InterruptedError:
                pass
            else:
                if child_pid == application_pid and (
                    os.WIFEXITED(status) or os.WIFSIGNALED(status)
                ):
                    child_status = status
                    return
        try:
            os.killpg(application_pid, signum)
        except ProcessLookupError:
            pass
        except PermissionError:
            # A killed application group can reject SIGCONT while it disappears.
            if signum != signal.SIGCONT:
                raise

    signal.signal(signal.SIGCONT, _forward_child_signal)
    signal.signal(signal.SIGHUP, _forward_child_signal)
    signal.signal(signal.SIGTERM, _forward_child_signal)
    signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
    os.write(application_pid_write, f"{application_pid}\n".encode("ascii"))
    _close_fds(application_pid_write)

    wait_options = os.WNOHANG | os.WUNTRACED
    if hasattr(os, "WCONTINUED"):
        wait_options |= os.WCONTINUED
    while True:
        if child_status is not None:
            os._exit(_exit_code(child_status))
        try:
            child_pid, status = os.waitpid(application_pid, wait_options)
        except InterruptedError:
            continue
        if child_pid == application_pid:
            if os.WIFSTOPPED(status):
                os.kill(os.getpid(), signal.SIGSTOP)
            elif os.WIFEXITED(status) or os.WIFSIGNALED(status):
                os._exit(_exit_code(status))
        time.sleep(0.01)


class LoomProcess:
    """A loom process running under a pty.fork() child.

    ENV, when given, replaces the child's environment entirely (via
    os.execve) rather than inheriting the parent's, so callers control
    HOME/LOOM_INIT_FILE isolation precisely.
    """

    def __init__(
        self,
        binary,
        arguments,
        env=None,
        columns=80,
        rows=24,
        supervise_job_control=False,
    ):
        self._pid = None
        self._fd = None
        self._status = None
        self._eof = False
        self._force_reap_poll = False
        self._output = bytearray()
        self._supervise_job_control = supervise_job_control
        self.application_pid = None
        application_pid_pipe = None
        ready_pipe = None
        start_pipe = None
        try:
            # At-fork callbacks can swallow exceptions raised by signal handlers.
            previous_mask = signal.pthread_sigmask(
                signal.SIG_BLOCK, {signal.SIGALRM}
            )
            try:
                if supervise_job_control:
                    application_pid_pipe = os.pipe()
                    ready_pipe = os.pipe()
                    start_pipe = os.pipe()
                self._pid, self._fd = pty.fork()
                if self._pid == 0:
                    if supervise_job_control:
                        _run_job_control_supervisor(
                            binary,
                            arguments,
                            env,
                            previous_mask,
                            application_pid_pipe,
                            ready_pipe,
                            start_pipe,
                        )
                        os._exit(127)
                    signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
                    argv = [binary, *arguments]
                    if env is None:
                        os.execv(binary, argv)
                    os.execve(binary, argv, env)
                if supervise_job_control:
                    _close_fds(
                        application_pid_pipe[1],
                        ready_pipe[0],
                        ready_pipe[1],
                        start_pipe[0],
                        start_pipe[1],
                    )
                    reported_pid = bytearray()
                    while b"\n" not in reported_pid:
                        chunk = os.read(application_pid_pipe[0], 32)
                        if not chunk:
                            raise RuntimeError(
                                "job-control supervisor exited before reporting "
                                "the application PID"
                            )
                        reported_pid.extend(chunk)
                    self.application_pid = int(
                        reported_pid.partition(b"\n")[0]
                    )
                    _close_fds(application_pid_pipe[0])
                else:
                    self.application_pid = self._pid
                os.set_blocking(self._fd, False)
            finally:
                if self._pid != 0:
                    for pipe in (application_pid_pipe, ready_pipe, start_pipe):
                        if pipe is not None:
                            _close_fds(*pipe)
                    signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
            self._set_terminal_size(columns, rows)
        except BaseException as error:
            if self._pid is not None and self._pid > 0:
                try:
                    self.close()
                except BaseException as cleanup_error:
                    raise error from cleanup_error
            raise

    def _set_terminal_size(self, columns, rows):
        size = struct.pack("HHHH", rows, columns, 0, 0)
        fcntl.ioctl(self._fd, termios.TIOCSWINSZ, size)

    def resize(self, columns, rows):
        """Resize the controlling PTY and let the kernel deliver SIGWINCH."""
        validate_dimensions(columns, rows)
        if self._fd is None:
            raise RuntimeError("cannot resize a closed PTY")
        self._set_terminal_size(columns, rows)

    @property
    def window_size(self):
        """Return the controlling PTY size as (rows, columns)."""
        if self._fd is None:
            raise RuntimeError("cannot inspect a closed PTY")
        size = fcntl.ioctl(self._fd, termios.TIOCGWINSZ, b"\0" * 8)
        return struct.unpack("HHHH", size)[:2]

    @property
    def output_bytes(self):
        """Return every PTY byte read so far, including bytes drained during cleanup."""
        return bytes(self._output)

    def _poll_exit(self):
        if self._status is not None:
            return self._status
        # A deadline exception must not discard a status already consumed by waitpid.
        previous_mask = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGALRM})
        try:
            pid, status = os.waitpid(self._pid, os.WNOHANG)
            if pid == self._pid:
                self._status = _exit_code(status)
        finally:
            signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
        return self._status

    def _wait_for_exit(self, timeout):
        deadline = time.monotonic() + timeout
        while self._status is None:
            self.read_available()
            try:
                status = self._poll_exit()
            except InterruptedError:
                continue
            if status is not None:
                return status
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError("loom child did not exit before the timeout")
            poll_interval = 0.001 if self._force_reap_poll else 0.02
            time.sleep(min(poll_interval, remaining))
        return self._status

    def _reap_after_sigkill(self):
        """Try to reap a SIGKILLed child without depending on PTY EOF."""
        return self._poll_exit() is not None

    def _reap_after_sigkill_until(self, deadline):
        while self._status is None:
            if self._reap_after_sigkill():
                return True
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                return False
            time.sleep(min(0.001, remaining))
        return True

    def _send_signal(self, signum):
        if self._status is not None:
            return
        if self._supervise_job_control and self.application_pid is not None:
            try:
                os.killpg(self.application_pid, signum)
            except ProcessLookupError:
                pass
            if signum in (signal.SIGHUP, signal.SIGTERM, signal.SIGKILL):
                try:
                    os.kill(self._pid, signal.SIGCONT)
                except ProcessLookupError:
                    pass
            return
        try:
            os.kill(self._pid, signum)
        except ProcessLookupError:
            pass

    def force_kill(self):
        """Send the final signal without waiting for PTY EOF or child reap."""
        self._send_signal(signal.SIGKILL)

    def read_available(self):
        """Return whatever bytes are ready without blocking (possibly empty)."""
        if self._eof:
            return b""
        try:
            data = os.read(self._fd, 65536)
        except BlockingIOError:
            return b""
        except OSError as error:
            if error.errno in (errno.EIO, errno.EBADF):
                self._eof = True
                return b""
            raise
        if not data:
            self._eof = True
        else:
            self._output.extend(data)
        return data

    def poll(self, poll_timeout=0.05):
        """Block up to POLL_TIMEOUT for readability, then return read_available()."""
        select.select([self._fd], [], [], poll_timeout)
        return self.read_available()

    def _wait_for_activity(self, deadline):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError("loom process did not finish before the timeout")
        select.select([self._fd], [], [], min(0.05, remaining))

    def has_exited(self):
        return self._poll_exit() is not None

    def wait(self, timeout=TIMEOUT_SECONDS):
        """Drain output until EOF and the child has exited; return (output, code)."""
        deadline = time.monotonic() + timeout
        output = bytearray()
        while True:
            data = self.read_available()
            if data:
                output.extend(data)
                continue
            status = self._poll_exit()
            if status is not None and self._eof:
                return bytes(output), status
            self._wait_for_activity(deadline)

    def write(self, data):
        view = memoryview(data)
        while view:
            written = os.write(self._fd, view)
            view = view[written:]

    def close(self):
        if self._fd is None and self._status is not None:
            return
        pending_error = None
        try:
            if self._status is None:
                try:
                    self._poll_exit()
                except BaseException as error:
                    pending_error = error

            budget = current_deadline()
            if (
                self._status is None
                and pending_error is None
                and (budget is None or not budget.expired)
            ):
                for termination_signal in (signal.SIGHUP, signal.SIGTERM):
                    budget = current_deadline()
                    if budget is not None:
                        remaining = budget.remaining()
                        if remaining <= REAP_RESERVE_SECONDS:
                            break
                    self._send_signal(termination_signal)
                    try:
                        timeout = 1.0
                        if budget is not None:
                            timeout = min(
                                timeout,
                                budget.remaining() - REAP_RESERVE_SECONDS,
                            )
                        self._wait_for_exit(timeout)
                    except TimeoutError as error:
                        if type(error) is not TimeoutError:
                            pending_error = error
                            break
                        continue
                    except BaseException as error:
                        pending_error = error
                        break
                    if self._status is not None:
                        break

            if self._status is None:
                forced_error = None
                budget = current_deadline()
                force_deadline = (
                    budget.deadline
                    if budget is not None
                    else time.monotonic() + 2.0
                )
                self._force_reap_poll = True
                try:
                    while self._status is None:
                        try:
                            self._send_signal(signal.SIGKILL)
                        except BaseException as error:
                            forced_error = forced_error or error
                            break
                        if budget is None:
                            remaining = force_deadline - time.monotonic()
                        else:
                            remaining = budget.remaining()
                        if remaining <= 0:
                            if budget is not None:
                                try:
                                    reaped = self._reap_after_sigkill()
                                except BaseException as error:
                                    forced_error = forced_error or error
                                else:
                                    if not reaped:
                                        forced_error = forced_error or TimeoutError(
                                            "loom child was not reaped before the scenario deadline"
                                        )
                            else:
                                try:
                                    self._poll_exit()
                                except BaseException as error:
                                    forced_error = forced_error or error
                            if self._status is None:
                                forced_error = forced_error or TimeoutError(
                                    "loom child did not report an exit status after SIGKILL"
                                )
                            break
                        try:
                            self._wait_for_exit(remaining)
                        except TimeoutError as error:
                            forced_error = forced_error or error
                            if type(error) is not TimeoutError:
                                break
                            continue
                        except BaseException as error:
                            forced_error = forced_error or error
                            continue
                finally:
                    self._force_reap_poll = False
                    for _attempt in range(2):
                        if self._status is not None:
                            break
                        try:
                            self._send_signal(signal.SIGKILL)
                        except BaseException as error:
                            forced_error = forced_error or error
                        try:
                            if self._reap_after_sigkill():
                                break
                        except BaseException as error:
                            forced_error = forced_error or error
                    if self._status is None:
                        reap_deadline = (
                            budget.deadline
                            if budget is not None
                            else force_deadline
                        )
                        try:
                            if not self._reap_after_sigkill_until(reap_deadline):
                                forced_error = forced_error or TimeoutError(
                                    "loom child was not reaped before the scenario deadline"
                                )
                        except BaseException as error:
                            forced_error = forced_error or error
                if (
                    forced_error is not None
                    and pending_error is None
                    and (
                        self._status is None
                        or type(forced_error) is not TimeoutError
                    )
                ):
                    pending_error = forced_error
        except BaseException as error:
            pending_error = pending_error or error
        finally:
            if self._fd is not None:
                try:
                    while self.read_available():
                        pass
                except BaseException as error:
                    pending_error = pending_error or error
                # Keep a deadline exception from leaving a closed descriptor recorded.
                previous_mask = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGALRM})
                try:
                    os.close(self._fd)
                    self._fd = None
                finally:
                    signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)

        if self._status is None:
            raise pending_error or RuntimeError(
                "loom child closed without a recorded exit status"
            )
        if pending_error is not None:
            raise pending_error

    def __enter__(self):
        return self

    def __exit__(self, _exception_type, _exception, _traceback):
        self.close()
