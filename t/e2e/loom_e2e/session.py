"""Drive a loom process end to end: scratch HOME isolation, key input, and
screen/file assertions that wait on real state instead of a fixed sleep."""

import locale
import os
import shutil
import signal
import subprocess
import tempfile
import time

from . import keys
from .deadline import (
    ScenarioCleanupDeadlineExceeded,
    ScenarioDeadlineExceeded,
    current_deadline,
)
from .layout import Layout
from .process import LoomProcess
from .screen import Screen


DEFAULT_TIMEOUT = 10.0
_SESSION_ENVIRONMENT_ALLOWLIST = ("PATH",)


def _session_environment(home_dir, locale_name):
    """Build the child environment without inheriting parent credentials."""
    env = {
        name: os.environ[name]
        for name in _SESSION_ENVIRONMENT_ALLOWLIST
        if name in os.environ
    }
    env.update(
        {
            "HOME": home_dir,
            "TERM": "xterm-256color",
            "SHELL": "/bin/sh",
            "LANG": locale_name,
            "LC_ALL": locale_name,
        }
    )
    return env


def _available_locales():
    try:
        output = subprocess.run(
            ["locale", "-a"], capture_output=True, text=True, timeout=5
        ).stdout
    except ScenarioDeadlineExceeded:
        raise
    except (OSError, subprocess.SubprocessError):
        return set()
    return set(output.split())


def _pick_utf8_locale():
    encoding = locale.getlocale(locale.LC_CTYPE)[1]
    if encoding is not None and encoding.upper().replace("-", "") == "UTF8":
        return locale.setlocale(locale.LC_CTYPE)
    available = _available_locales()
    for candidate in ("C.UTF-8", "en_US.UTF-8"):
        if candidate in available:
            return candidate
    return "en_US.UTF-8"


class Session:
    """Context manager owning one loom child process and its reconstructed
    screen. Each session gets its own scratch HOME so a run never reads or
    writes the real user's ~/.loom."""

    def __init__(self, binary, arguments=None, columns=80, rows=24):
        self.binary = binary
        self.arguments = list(arguments or [])
        self.columns = columns
        self.rows = rows
        self.process = None
        self.screen = None
        self.layout = Layout(rows)
        self._scratch_dir = None
        self._home_dir = None

    @property
    def scratch_dir(self):
        return self._scratch_dir

    @property
    def home_dir(self):
        return self._home_dir

    def __enter__(self):
        locale = _pick_utf8_locale()
        try:
            # Retain ownership before a pending deadline can interrupt allocation.
            previous_mask = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGALRM})
            try:
                self._scratch_dir = tempfile.mkdtemp(prefix="loom-e2e-")
            finally:
                signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
            self._home_dir = os.path.join(self._scratch_dir, "home")
            os.makedirs(self._home_dir, exist_ok=True)

            env = _session_environment(self._home_dir, locale)

            self.process = LoomProcess(
                self.binary, self.arguments, env=env,
                columns=self.columns, rows=self.rows,
            )
            budget = current_deadline()
            if budget is not None:
                budget.register_process(self.process)
            self.screen = Screen(self.columns, self.rows)
            return self
        except BaseException as error:
            try:
                self.__exit__(type(error), error, error.__traceback__)
            except BaseException as cleanup_error:
                raise error from cleanup_error
            raise

    def __exit__(self, _exception_type, _exception, _traceback):
        budget = current_deadline()
        force_error = None
        if budget is not None and budget.expired:
            try:
                budget.force_cleanup()
            except BaseException as error:
                force_error = error
        close_error = None
        try:
            if self.process is not None:
                self.process.close()
        except BaseException as error:
            close_error = error
        finally:
            budget = current_deadline()
            try:
                if self._scratch_dir is not None:
                    if budget is not None and budget.remaining() <= 0:
                        if os.path.exists(self._scratch_dir):
                            raise ScenarioCleanupDeadlineExceeded(
                                "scenario cleanup deadline left scratch directory: "
                                f"{self._scratch_dir}"
                            ) from (close_error or force_error)
                    else:
                        shutil.rmtree(self._scratch_dir, ignore_errors=True)
            finally:
                if budget is not None and self.process is not None:
                    budget.unregister_process(self.process)
        if close_error is not None:
            if force_error is not None:
                raise close_error from force_error
            raise close_error
        if force_error is not None:
            raise force_error

    def pump(self, poll_timeout=0.05):
        """Read whatever is available without blocking and feed the screen."""
        data = self.process.poll(poll_timeout)
        self.screen.feed(data)
        return data

    def wait_until(self, predicate, timeout=DEFAULT_TIMEOUT, what="condition"):
        deadline = time.monotonic() + timeout
        if predicate(self.screen):
            return
        while True:
            self.pump()
            if predicate(self.screen):
                return
            if time.monotonic() >= deadline:
                raise TimeoutError(
                    f"timed out waiting for {what}; cursor={self.screen.cursor}\n"
                    f"--- screen ---\n{self.screen.dump()}"
                )

    def wait_ready(self, timeout=DEFAULT_TIMEOUT):
        """Wait for the initial frame to contain rendered content."""
        self.wait_until(
            lambda screen: screen.has_content(),
            timeout, "the initial frame to render",
        )

    def wait_for_text(self, substring, timeout=DEFAULT_TIMEOUT):
        self.wait_until(
            lambda screen: screen.find(substring) is not None,
            timeout, f"{substring!r} to appear on screen",
        )

    def wait_for_row_text(self, row, substring, timeout=DEFAULT_TIMEOUT):
        self.wait_until(
            lambda screen: substring in screen.text(row),
            timeout, f"row {row} to contain {substring!r}",
        )

    def region_text(self, region, index=0):
        return self.screen.text(self.layout.row(region, index))

    def wait_for_region_text(self, region, substring, index=0, timeout=DEFAULT_TIMEOUT):
        self.wait_until(
            lambda screen: substring in screen.text(self.layout.row(region, index)),
            timeout,
            f"{region} row {index} to contain {substring!r}",
        )

    def wait_for_cursor(self, row, col, timeout=DEFAULT_TIMEOUT):
        self.wait_until(
            lambda screen: screen.cursor == (row, col),
            timeout, f"cursor to reach (row={row}, col={col})",
        )

    def wait_for_region_cursor(self, region, col, index=0, timeout=DEFAULT_TIMEOUT):
        self.wait_for_cursor(self.layout.row(region, index), col, timeout)

    def wait_for_file(self, path, expected_bytes, timeout=DEFAULT_TIMEOUT):
        deadline = time.monotonic() + timeout
        last_seen = None
        while True:
            self.pump()
            try:
                with open(path, "rb") as handle:
                    last_seen = handle.read()
            except FileNotFoundError:
                last_seen = None
            if last_seen == expected_bytes:
                return
            if time.monotonic() >= deadline:
                raise TimeoutError(
                    f"timed out waiting for {path} to contain {expected_bytes!r}; "
                    f"last read {last_seen!r}\n--- screen ---\n{self.screen.dump()}"
                )

    def send(self, data):
        self.process.write(data)

    def type(self, text):
        self.send(keys.text(text))

    def key(self, *names):
        payload = bytearray()
        for name in names:
            payload.extend(name if isinstance(name, (bytes, bytearray)) else keys.NAMED[name])
        self.send(bytes(payload))

    def extended_command(self, name, timeout=DEFAULT_TIMEOUT):
        """Invoke NAME through the real M-x key path."""
        self.send(keys.meta("x"))
        self.wait_for_region_text("minibuffer", "M-x ", timeout=timeout)
        self.type(name)
        self.send(keys.RET)

    def quit(self, timeout=DEFAULT_TIMEOUT):
        self.send(keys.ctrl("x") + keys.ctrl("c"))
        return self.process.wait(timeout=timeout)
