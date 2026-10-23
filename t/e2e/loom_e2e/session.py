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
from .results import current_result, record_observation
from .screen import Screen


DEFAULT_TIMEOUT = 10.0
_SESSION_ENVIRONMENT_ALLOWLIST = ("PATH",)
_UNSET = object()


def _session_environment(
    home_dir, locale_name, profile=keys.DEFAULT_PROFILE, trace_path=None
):
    """Build the child environment without inheriting parent credentials."""
    env = {
        name: os.environ[name]
        for name in _SESSION_ENVIRONMENT_ALLOWLIST
        if name in os.environ
    }
    env.update(
        {
            "HOME": home_dir,
            "TERM": profile.term,
            "SHELL": "/bin/sh",
            "LANG": locale_name,
            "LC_ALL": locale_name,
        }
    )
    if trace_path is not None:
        env["LOOM_TRACE_COMMANDS"] = trace_path
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

    def __init__(
        self, binary, arguments=None, columns=80, rows=24,
        profile=keys.DEFAULT_PROFILE,
    ):
        self.binary = binary
        self.arguments = list(arguments or [])
        self.profile = keys.get_profile(profile)
        self.columns = columns
        self.rows = rows
        self.process = None
        self.screen = None
        self.layout = Layout(rows, columns)
        self._scratch_dir = None
        self._home_dir = None
        self._trace_path = None
        self._trace_bytes = b""
        self._artifacts_captured = False
        self.started_at = None
        self.first_screen_at = None

    @property
    def scratch_dir(self):
        return self._scratch_dir

    @property
    def home_dir(self):
        return self._home_dir

    @property
    def output_bytes(self):
        return self.process.output_bytes if self.process is not None else b""

    @property
    def trace_bytes(self):
        return self._trace_bytes

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
            self._trace_path = os.path.join(self._scratch_dir, "loom-trace.jsonl")

            env = _session_environment(
                self._home_dir, locale, self.profile, self._trace_path
            )

            self.started_at = time.monotonic()
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
            artifact_error = None
            try:
                self._capture_artifacts()
            except BaseException as error:
                artifact_error = error
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
        if artifact_error is not None:
            raise artifact_error

    def _capture_artifacts(self):
        if self.process is None or self._artifacts_captured:
            return
        try:
            with open(self._trace_path, "rb") as handle:
                self._trace_bytes = handle.read()
        except FileNotFoundError:
            self._trace_bytes = b""
        result = current_result()
        if result is not None:
            result.add_session(self.process.output_bytes, self._trace_bytes)
        self._artifacts_captured = True

    def pump(self, poll_timeout=0.05):
        """Read whatever is available without blocking and feed the screen."""
        data = self.process.poll(poll_timeout)
        self.screen.feed(data)
        return data

    def resize(self, columns, rows):
        """Resize the PTY and keep pyte and layout dimensions in sync."""
        if isinstance(columns, bool) or not isinstance(columns, int) or columns <= 0:
            raise ValueError("terminal columns must be a positive integer")
        if isinstance(rows, bool) or not isinstance(rows, int) or rows <= 0:
            raise ValueError("terminal rows must be a positive integer")
        if self.process is None or self.screen is None:
            raise RuntimeError("cannot resize a session before it is entered")
        self.process.resize(columns, rows)
        self.screen.resize(columns, rows)
        self.columns = columns
        self.rows = rows
        self.layout = Layout(rows, columns)
        actual = self.process.window_size
        record_observation(
            "external_state",
            actual,
            (rows, columns),
            actual == (rows, columns),
            name="PTY window size",
        )

    def observe_screen_text(
        self, actual, expected=None, match="exact", passed=None, **details
    ):
        if passed is None and expected is not None:
            if match == "contains":
                passed = expected in actual
            elif match == "not_contains":
                passed = expected not in actual
            elif match == "starts_with":
                passed = actual.startswith(expected)
            elif match == "ends_with":
                passed = actual.endswith(expected)
            elif match == "non_empty":
                passed = bool(actual.strip())
            elif match == "changed":
                passed = actual != expected
            elif match == "exact":
                passed = actual == expected
            else:
                raise ValueError(f"unknown screen-text match mode: {match!r}")
        record_observation(
            "screen_text", actual, expected, passed, match=match, **details
        )
        return actual

    def assert_screen_text(self, actual, expected, match="exact", **details):
        self.observe_screen_text(actual, expected, match=match, **details)
        passed = {
            "contains": lambda: expected in actual,
            "not_contains": lambda: expected not in actual,
            "starts_with": lambda: actual.startswith(expected),
            "ends_with": lambda: actual.endswith(expected),
            "changed": lambda: actual != expected,
            "exact": lambda: actual == expected,
            "non_empty": lambda: bool(actual.strip()),
        }.get(match)
        if passed is None:
            raise ValueError(f"unknown screen-text match mode: {match!r}")
        if not passed():
            raise AssertionError(
                f"screen text did not satisfy {match} for {expected!r}: {actual!r}"
            )
        return actual

    def observe_pty_output(self, actual, expected=None, match="exact", passed=None):
        if passed is None and expected is not None:
            if match == "contains":
                passed = expected in actual
            elif match == "not_contains":
                passed = expected not in actual
            elif match == "exact":
                passed = actual == expected
            else:
                raise ValueError(f"unknown PTY-output match mode: {match!r}")
        record_observation("pty_output", actual, expected, passed, match=match)
        return actual

    def assert_pty_output(self, actual, expected, match="contains"):
        self.observe_pty_output(actual, expected, match=match)
        matched = {
            "contains": lambda: expected in actual,
            "not_contains": lambda: expected not in actual,
            "exact": lambda: actual == expected,
        }.get(match)
        if matched is None:
            raise ValueError(f"unknown PTY-output match mode: {match!r}")
        if not matched():
            raise AssertionError(
                f"PTY output did not satisfy {match} for {expected!r}"
            )
        return actual

    def observe_cursor(self, expected=None, passed=None, **details):
        actual = self.screen.cursor
        if passed is None and expected is not None:
            passed = actual == expected
        record_observation("cursor", actual, expected, passed, **details)
        return actual

    def observe_cell_attrs(self, row, column, expected=None):
        actual = self.screen.cell_attrs(row, column)
        passed = None
        if expected is not None:
            if not expected:
                raise ValueError("cell attribute expectations must not be empty")
            passed = all(actual.get(name) == value for name, value in expected.items())
        record_observation(
            "cell_attrs",
            actual,
            expected,
            passed,
            row=row,
            column=column,
        )
        return actual

    def assert_cell_attrs(self, row, column, expected):
        actual = self.observe_cell_attrs(row, column, expected=expected)
        if any(actual.get(name) != value for name, value in expected.items()):
            raise AssertionError(
                f"cell attributes at {(row, column)!r} did not match {expected!r}"
            )
        return actual

    def observe_file_bytes(self, path, actual=_UNSET, expected=None):
        if actual is _UNSET:
            try:
                with open(path, "rb") as handle:
                    actual = handle.read()
            except FileNotFoundError:
                actual = None
        passed = None if expected is None else actual == expected
        record_observation(
            "file_bytes",
            actual,
            expected,
            passed,
            target=self._observation_target(path),
        )
        return actual

    def assert_file_bytes(self, path, expected):
        actual = self.observe_file_bytes(path, expected=expected)
        if actual != expected:
            raise AssertionError(
                f"file bytes at {self._observation_target(path)!r} did not match"
            )
        return actual

    def observe_external_state(self, name, actual, expected=None, passed=None):
        if passed is None and expected is not None:
            passed = actual == expected
        record_observation(
            "external_state", actual, expected, passed, name=name
        )
        return actual

    def assert_external_state(self, name, actual, expected):
        self.observe_external_state(name, actual, expected)
        if actual != expected:
            raise AssertionError(
                f"external state {name!r} was {actual!r}, expected {expected!r}"
            )
        return actual

    def observe_exit_code(self, actual, expected=None):
        passed = None if expected is None else actual == expected
        record_observation("exit_code", actual, expected, passed)
        return actual

    def _observation_target(self, path):
        path = os.fspath(path)
        if self._scratch_dir is not None:
            try:
                return os.path.relpath(path, self._scratch_dir)
            except ValueError:
                pass
        return os.path.basename(path)

    def wait_for_external_state(
        self, name, read_state, expected, timeout=DEFAULT_TIMEOUT
    ):
        last_observed = _UNSET

        def matches_expected(_screen):
            nonlocal last_observed
            last_observed = read_state()
            return last_observed == expected

        try:
            self.wait_until(
                matches_expected,
                timeout,
                f"external state {name!r} to become {expected!r}",
            )
        except TimeoutError:
            actual = read_state()
            self.observe_external_state(name, actual, expected, passed=False)
            raise
        actual = last_observed
        self.observe_external_state(name, actual, expected)
        return actual

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
        lines = [line for line in self.screen.lines() if line.strip()]
        self.first_screen_at = time.monotonic()
        self.observe_screen_text(
            "\n".join(lines),
            expected={"non_empty": True},
            match="non_empty",
            purpose="precondition",
        )

    def wait_for_text(self, substring, timeout=DEFAULT_TIMEOUT):
        try:
            self.wait_until(
                lambda screen: screen.find(substring) is not None,
                timeout, f"{substring!r} to appear on screen",
            )
        except TimeoutError:
            self.observe_screen_text(
                "\n".join(self.screen.lines()),
                expected=substring,
                match="contains",
                passed=False,
            )
            raise
        row, _column = self.screen.find(substring)
        self.observe_screen_text(
            self.screen.text(row), expected=substring, match="contains"
        )

    def wait_for_row_text(self, row, substring, timeout=DEFAULT_TIMEOUT):
        try:
            self.wait_until(
                lambda screen: substring in screen.text(row),
                timeout, f"row {row} to contain {substring!r}",
            )
        except TimeoutError:
            self.observe_screen_text(
                self.screen.text(row), expected=substring, match="contains",
                passed=False, row=row,
            )
            raise
        self.observe_screen_text(
            self.screen.text(row), expected=substring, match="contains", row=row
        )

    def region_text(self, region, index=0):
        return self.screen.text(self.layout.row(region, index))

    def region_contents(self, region):
        if region == "body":
            rows = range(self.layout.body_height)
        else:
            rows = (self.layout.row(region),)
        return "\n".join(self.screen.text(row) for row in rows)

    def wait_for_region_text(self, region, substring, index=0, timeout=DEFAULT_TIMEOUT):
        row = self.layout.row(region, index)
        try:
            self.wait_until(
                lambda screen: substring in screen.text(row),
                timeout,
                f"{region} row {index} to contain {substring!r}",
            )
        except TimeoutError:
            self.observe_screen_text(
                self.screen.text(row), expected=substring, match="contains",
                passed=False, region=region, row=row,
            )
            raise
        self.observe_screen_text(
            self.screen.text(row), expected=substring, match="contains",
            region=region, row=row,
        )

    def wait_for_region_exact_text(
        self, region, expected, index=0, strip_right=True, timeout=DEFAULT_TIMEOUT
    ):
        row = self.layout.row(region, index)

        def read_text():
            actual = self.screen.text(row)
            return actual.rstrip() if strip_right else actual

        try:
            self.wait_until(
                lambda _screen: read_text() == expected,
                timeout,
                f"{region} row {index} to equal {expected!r}",
            )
        except TimeoutError:
            self.observe_screen_text(
                read_text(), expected=expected, match="exact", passed=False,
                region=region, row=row,
            )
            raise
        return self.observe_screen_text(
            read_text(), expected=expected, match="exact", region=region, row=row
        )

    def wait_for_region_text_prefix(
        self, region, expected, index=0, timeout=DEFAULT_TIMEOUT
    ):
        row = self.layout.row(region, index)
        try:
            self.wait_until(
                lambda _screen: self.screen.text(row).startswith(expected),
                timeout,
                f"{region} row {index} to start with {expected!r}",
            )
        except TimeoutError:
            self.observe_screen_text(
                self.screen.text(row), expected=expected, match="starts_with",
                passed=False, region=region, row=row,
            )
            raise
        return self.observe_screen_text(
            self.screen.text(row), expected=expected, match="starts_with",
            region=region, row=row,
        )

    def wait_for_region_contents(
        self, region, substring, timeout=DEFAULT_TIMEOUT
    ):
        def read_text():
            return self.region_contents(region)

        try:
            self.wait_until(
                lambda _screen: substring in read_text(),
                timeout,
                f"{region} region to contain {substring!r}",
            )
        except TimeoutError:
            self.observe_screen_text(
                read_text(), expected=substring, match="contains", passed=False,
                region=region,
            )
            raise
        return self.observe_screen_text(
            read_text(), expected=substring, match="contains", region=region
        )

    def wait_for_row_and_cursor(
        self, row, expected_text, column, timeout=DEFAULT_TIMEOUT
    ):
        expected_cursor = (row, column)
        expected_line = expected_text
        try:
            self.wait_until(
                lambda screen: (
                    screen.text(row).rstrip(" ") == expected_line
                    and screen.cursor == expected_cursor
                ),
                timeout,
                f"row {row} to equal {expected_line!r} with cursor at {expected_cursor!r}",
            )
        except TimeoutError:
            self.observe_screen_text(
                self.screen.text(row).rstrip(" "),
                expected=expected_line,
                match="exact",
                passed=False,
                row=row,
            )
            self.observe_cursor(expected=expected_cursor, passed=False)
            raise
        self.observe_screen_text(
            self.screen.text(row).rstrip(" "),
            expected=expected_line,
            match="exact",
            row=row,
        )
        self.observe_cursor(expected=expected_cursor)

    def wait_for_region_absent_text(
        self, region, substring, index=0, timeout=DEFAULT_TIMEOUT
    ):
        row = self.layout.row(region, index)
        try:
            self.wait_until(
                lambda _screen: substring not in self.screen.text(row),
                timeout,
                f"{substring!r} to disappear from {region} row {index}",
            )
        except TimeoutError:
            self.observe_screen_text(
                self.screen.text(row), expected=substring, match="not_contains",
                passed=False, region=region, row=row,
            )
            raise
        return self.observe_screen_text(
            self.screen.text(row), expected=substring, match="not_contains",
            region=region, row=row,
        )

    def wait_for_text_absent(self, substring, timeout=DEFAULT_TIMEOUT):
        def read_text():
            return "\n".join(self.screen.lines())

        try:
            self.wait_until(
                lambda _screen: self.screen.find(substring) is None,
                timeout,
                f"{substring!r} to disappear from the screen",
            )
        except TimeoutError:
            self.observe_screen_text(
                read_text(), expected=substring, match="not_contains", passed=False
            )
            raise
        return self.observe_screen_text(
            read_text(), expected=substring, match="not_contains"
        )

    def wait_for_cursor(self, row, col, timeout=DEFAULT_TIMEOUT):
        expected = (row, col)
        try:
            self.wait_until(
                lambda screen: screen.cursor == expected,
                timeout, f"cursor to reach (row={row}, col={col})",
            )
        except TimeoutError:
            self.observe_cursor(expected=expected, passed=False)
            raise
        self.observe_cursor(expected=expected)

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
                self.observe_file_bytes(path, actual=last_seen, expected=expected_bytes)
                return
            if time.monotonic() >= deadline:
                self.observe_file_bytes(path, actual=last_seen, expected=expected_bytes)
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
            payload.extend(
                name
                if isinstance(name, (bytes, bytearray))
                else self.profile.key(name)
            )
        self.send(bytes(payload))

    def extended_command(self, name, timeout=DEFAULT_TIMEOUT):
        """Invoke NAME through the real M-x key path."""
        self.send(keys.meta("x"))
        self.wait_for_region_text("minibuffer", "M-x ", timeout=timeout)
        self.type(name)
        self.key("RET")

    def quit(self, timeout=DEFAULT_TIMEOUT):
        self.send(keys.ctrl("x") + keys.ctrl("c"))
        output, code = self.process.wait(timeout=timeout)
        self.observe_exit_code(code, expected=0)
        return output, code
