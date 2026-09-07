"""Drive a loom process end to end: scratch HOME isolation, key input, and
screen/file assertions that wait on real state instead of a fixed sleep."""

import os
import shutil
import subprocess
import tempfile
import time

from . import keys
from .process import LoomProcess
from .screen import Screen


# height=24 -> minibuffer-row = height-1 = 23, shortcuts-row = minibuffer-row-1
# = 22 (src/presentation/frame-layout-cursor.lisp:%layout-minibuffer-row,
# src/presentation/frame-layout.lisp:19), confirmed against a live capture's
# own CUP escape sequences.
SHORTCUT_ROW = 22
MINIBUFFER_ROW = 23

DEFAULT_TIMEOUT = 10.0


def _available_locales():
    try:
        output = subprocess.run(
            ["locale", "-a"], capture_output=True, text=True, timeout=5
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return set()
    return set(output.split())


def _pick_utf8_locale():
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
        self._scratch_dir = None
        self._home_dir = None

    @property
    def scratch_dir(self):
        return self._scratch_dir

    @property
    def home_dir(self):
        return self._home_dir

    def __enter__(self):
        self._scratch_dir = tempfile.mkdtemp(prefix="loom-e2e-")
        self._home_dir = os.path.join(self._scratch_dir, "home")
        os.makedirs(self._home_dir, exist_ok=True)

        locale = _pick_utf8_locale()
        env = dict(os.environ)
        env["HOME"] = self._home_dir
        env.pop("LOOM_INIT_FILE", None)
        env["TERM"] = "xterm-256color"
        env["LANG"] = locale
        env["LC_ALL"] = locale

        self.process = LoomProcess(
            self.binary, self.arguments, env=env,
            columns=self.columns, rows=self.rows,
        )
        self.screen = Screen(self.columns, self.rows)
        return self

    def __exit__(self, _exception_type, _exception, _traceback):
        if self.process is not None:
            self.process.close()
        if self._scratch_dir is not None:
            shutil.rmtree(self._scratch_dir, ignore_errors=True)

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
        """Wait for the initial frame (shortcut line populated)."""
        self.wait_until(
            lambda screen: screen.text(SHORTCUT_ROW).strip() != "",
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

    def wait_for_cursor(self, row, col, timeout=DEFAULT_TIMEOUT):
        self.wait_until(
            lambda screen: screen.cursor == (row, col),
            timeout, f"cursor to reach (row={row}, col={col})",
        )

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
        self.wait_for_row_text(MINIBUFFER_ROW, "M-x ", timeout=timeout)
        self.type(name)
        self.send(keys.RET)

    def quit(self, timeout=DEFAULT_TIMEOUT):
        self.send(keys.ctrl("x") + keys.ctrl("c"))
        return self.process.wait(timeout=timeout)
