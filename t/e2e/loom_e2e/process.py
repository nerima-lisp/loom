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


TIMEOUT_SECONDS = 10.0
REAP_RESERVE_SECONDS = 0.25


def _exit_code(status):
    if os.WIFEXITED(status):
        return os.WEXITSTATUS(status)
    if os.WIFSIGNALED(status):
        return 128 + os.WTERMSIG(status)
    return status


class LoomProcess:
    """A loom process running under a pty.fork() child.

    ENV, when given, replaces the child's environment entirely (via
    os.execve) rather than inheriting the parent's, so callers control
    HOME/LOOM_INIT_FILE isolation precisely.
    """

    def __init__(self, binary, arguments, env=None, columns=80, rows=24):
        self._pid = None
        self._fd = None
        self._status = None
        self._eof = False
        self._force_reap_poll = False
        self._output = bytearray()
        try:
            # At-fork callbacks can swallow exceptions raised by signal handlers.
            previous_mask = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGALRM})
            try:
                self._pid, self._fd = pty.fork()
                if self._pid == 0:
                    signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
                    argv = [binary, *arguments]
                    if env is None:
                        os.execv(binary, argv)
                    else:
                        os.execve(binary, argv, env)
            finally:
                if self._pid != 0:
                    signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
            self._set_terminal_size(columns, rows)
            os.set_blocking(self._fd, False)
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
        if isinstance(columns, bool) or not isinstance(columns, int) or columns <= 0:
            raise ValueError("terminal columns must be a positive integer")
        if isinstance(rows, bool) or not isinstance(rows, int) or rows <= 0:
            raise ValueError("terminal rows must be a positive integer")
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

    def force_kill(self):
        """Send the final signal without waiting for PTY EOF or child reap."""
        if self._status is not None:
            return
        try:
            os.kill(self._pid, signal.SIGKILL)
        except ProcessLookupError:
            pass

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
                    try:
                        os.kill(self._pid, termination_signal)
                    except ProcessLookupError:
                        pass
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
                            os.kill(self._pid, signal.SIGKILL)
                        except ProcessLookupError:
                            pass
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
                            os.kill(self._pid, signal.SIGKILL)
                        except ProcessLookupError:
                            pass
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
