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


TIMEOUT_SECONDS = 10.0


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
        self._pid, self._fd = pty.fork()
        if self._pid == 0:
            argv = [binary, *arguments]
            if env is None:
                os.execv(binary, argv)
            else:
                os.execve(binary, argv, env)

        self._status = None
        self._eof = False
        self._set_terminal_size(columns, rows)
        os.set_blocking(self._fd, False)

    def _set_terminal_size(self, columns, rows):
        size = struct.pack("HHHH", rows, columns, 0, 0)
        fcntl.ioctl(self._fd, termios.TIOCSWINSZ, size)

    def _poll_exit(self):
        if self._status is not None:
            return self._status
        pid, status = os.waitpid(self._pid, os.WNOHANG)
        if pid == self._pid:
            self._status = _exit_code(status)
        return self._status

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
        if self._fd is None:
            return
        if self._poll_exit() is None:
            for termination_signal in (signal.SIGHUP, signal.SIGTERM):
                try:
                    os.kill(self._pid, termination_signal)
                except ProcessLookupError:
                    break
                deadline = time.monotonic() + 1.0
                while self._poll_exit() is None and time.monotonic() < deadline:
                    time.sleep(0.02)
                if self._status is not None:
                    break
            if self._status is None:
                try:
                    os.kill(self._pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                try:
                    self.wait(timeout=2.0)
                except TimeoutError:
                    pass
        os.close(self._fd)
        self._fd = None

    def __enter__(self):
        return self

    def __exit__(self, _exception_type, _exception, _traceback):
        self.close()
