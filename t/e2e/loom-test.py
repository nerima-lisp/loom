#!/usr/bin/env python3
"""Exercise the built loom executable through a real Unix PTY."""

import errno
import fcntl
import os
import pty
import select
import signal
import struct
import sys
import tempfile
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
    def __init__(self, binary, arguments):
        self._pid, self._fd = pty.fork()
        if self._pid == 0:
            os.execv(binary, [binary, *arguments])

        self._status = None
        self._eof = False
        self._set_terminal_size(80, 24)
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

    def _read_available(self):
        if self._eof:
            return b""
        try:
            data = os.read(self._fd, 4096)
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

    def _wait_for_activity(self, deadline):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError("loom process did not finish before the timeout")
        select.select([self._fd], [], [], min(0.05, remaining))

    def wait_for_output(self, timeout=TIMEOUT_SECONDS):
        deadline = time.monotonic() + timeout
        output = bytearray()
        while True:
            data = self._read_available()
            if data:
                output.extend(data)
                return bytes(output)
            if self._poll_exit() is not None and self._eof:
                return bytes(output)
            self._wait_for_activity(deadline)

    def wait(self, timeout=TIMEOUT_SECONDS):
        deadline = time.monotonic() + timeout
        output = bytearray()
        while True:
            data = self._read_available()
            if data:
                output.extend(data)
                continue
            status = self._poll_exit()
            if status is not None:
                return bytes(output), status
            self._wait_for_activity(deadline)

    def pump(self):
        self._read_available()
        self._poll_exit()

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
                self.wait(timeout=2.0)
        os.close(self._fd)
        self._fd = None

    def __enter__(self):
        return self

    def __exit__(self, _exception_type, _exception, _traceback):
        self.close()


def _assert_exit_zero(name, output, code):
    if code != 0:
        raise AssertionError(f"{name} exited with {code}: {output!r}")


def _assert_exit_code(name, output, code, expected):
    if code != expected:
        raise AssertionError(
            f"{name} exited with {code}, expected {expected}: {output!r}"
        )


def _test_help(binary):
    with LoomProcess(binary, ["--help"]) as process:
        output, code = process.wait()
    _assert_exit_zero("--help", output, code)
    if b"Usage: loom [PATH]" not in output:
        raise AssertionError(f"--help output missing usage line: {output!r}")


def _test_version(binary):
    with LoomProcess(binary, ["--version"]) as process:
        output, code = process.wait()
    _assert_exit_zero("--version", output, code)
    if b"loom 0.1.0" not in output:
        raise AssertionError(f"--version output missing version: {output!r}")


def _test_invalid_option(binary):
    with LoomProcess(binary, ["--definitely-invalid"]) as process:
        output, code = process.wait()
    _assert_exit_code("invalid option", output, code, 64)
    if b"Unknown option" not in output:
        raise AssertionError(f"invalid option output missing diagnostic: {output!r}")


def _test_missing_path(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "missing.txt")
        with LoomProcess(binary, [path]) as process:
            output, code = process.wait()
    _assert_exit_code("missing path", output, code, 64)
    if b"PATH does not exist" not in output:
        raise AssertionError(f"missing path output missing diagnostic: {output!r}")


def _test_startup_without_path(binary):
    with LoomProcess(binary, []) as process:
        process.wait_for_output()
        process.write(b"\x18\x03")
        output, code = process.wait()
    _assert_exit_zero("startup without path", output, code)


def _test_startup_directory(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        with LoomProcess(binary, [directory]) as process:
            process.wait_for_output()
            process.write(b"\x18\x03")
            output, code = process.wait()
    _assert_exit_zero("startup directory", output, code)


def _test_edit_save_exit(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "notes.txt")
        with open(path, "wb") as file:
            file.write(b"x\n")

        with LoomProcess(binary, [path]) as process:
            process.wait_for_output()
            process.write(b"a")
            process.write(b"\x18\x13")

            deadline = time.monotonic() + TIMEOUT_SECONDS
            while True:
                process.pump()
                with open(path, "rb") as file:
                    if file.read() == b"ax\n":
                        break
                if time.monotonic() >= deadline:
                    raise TimeoutError("C-x C-s did not save the edited file")
                time.sleep(0.05)

            process.write(b"\x18\x03")
            output, code = process.wait()
        _assert_exit_zero("edit/save/exit", output, code)


def _binary_from_arguments():
    binary = os.environ.get("LOOM_BINARY")
    if binary is None and len(sys.argv) == 2:
        binary = sys.argv[1]
    if binary is None:
        raise SystemExit("set LOOM_BINARY or pass the loom executable path")
    binary = os.path.abspath(binary)
    if not os.path.isfile(binary) or not os.access(binary, os.X_OK):
        raise SystemExit(f"loom executable is not runnable: {binary}")
    return binary


def main():
    binary = _binary_from_arguments()
    tests = [
        ("--help", _test_help),
        ("--version", _test_version),
        ("invalid option", _test_invalid_option),
        ("missing path", _test_missing_path),
        ("startup without path", _test_startup_without_path),
        ("startup directory", _test_startup_directory),
        ("edit/save/exit", _test_edit_save_exit),
    ]
    for name, test in tests:
        test(binary)
        print(f"PASS {name}")
    print(f"{len(tests)} E2E tests passed")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, OSError, TimeoutError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
