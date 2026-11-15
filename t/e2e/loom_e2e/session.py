"""Drive a loom process end to end: scratch HOME isolation, key input, and
screen/file assertions that wait on real state instead of a fixed sleep."""

import json
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
    mark_phase,
    note_phase_event,
    phase_step,
)
from .layout import Layout, validate_dimensions
from .process import LoomProcess
from .results import (
    UNSET,
    count_trace_lines,
    current_result,
    record_event,
    record_observation,
    reset_trace_line_counter,
    set_trace_line_counter,
)
from .screen import Screen


DEFAULT_TIMEOUT = 10.0
_SESSION_ENVIRONMENT_ALLOWLIST = ("PATH",)
_COMMAND_TRACE_ALIASES = {
    "newline-and-indent": "newline",
    "mode/newline-and-indent": "newline",
    "mode/comment-dwim": "comment-line",
}


def _canonical_command_trace_name(command):
    return _COMMAND_TRACE_ALIASES.get(command, command)


_PHASE_LABEL_LIMIT = 48
_TIMEOUT_TRACE_TAIL_LINES = 20
_TIMEOUT_TRACE_LINE_LIMIT = 300


def _clip(label):
    if len(label) <= _PHASE_LABEL_LIMIT:
        return label
    return label[: _PHASE_LABEL_LIMIT - 3] + "..."


def _describe_input(data, profile):
    """Name raw input bytes with profile key names and C-/M- chords."""
    sequences = sorted(
        ((sequence, name) for name, sequence in profile.key_sequences.items()),
        key=lambda item: -len(item[0]),
    )
    words = []
    text = bytearray()
    index = 0
    data = bytes(data)

    def flush_text():
        if text:
            words.append(repr(text.decode("utf-8", errors="replace")))
            text.clear()

    while index < len(data):
        for sequence, name in sequences:
            if len(sequence) > 1 and data.startswith(sequence, index):
                flush_text()
                words.append(name)
                index += len(sequence)
                break
        else:
            byte = data[index]
            following = data[index + 1] if index + 1 < len(data) else None
            if byte == 0x1B and following == ord("["):
                end = index + 2
                while end < len(data) and not 0x40 <= data[end] <= 0x7E:
                    end += 1
                flush_text()
                words.append(
                    "CSI " + data[index + 2 : end + 1].decode("ascii", "replace")
                )
                index = end + 1
                continue
            if byte == 0x1B and following is not None and 0x20 < following < 0x7F:
                flush_text()
                words.append(f"M-{chr(following)}")
                index += 2
                continue
            if byte in (0x0D, 0x09, 0x1B):
                flush_text()
                words.append({0x0D: "RET", 0x09: "TAB", 0x1B: "ESC"}[byte])
            elif byte < 0x20:
                flush_text()
                words.append(f"C-{chr(byte + 0x40).lower()}")
            elif byte == 0x7F:
                flush_text()
                words.append("C-?")
            else:
                text.append(byte)
            index += 1
    flush_text()
    return " ".join(words)


def _session_environment(
    home_dir, locale_name, profile=keys.DEFAULT_PROFILE, trace_path=None,
    layout_trace_path=None,
    shell="/bin/sh",
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
            "SHELL": shell,
            "LANG": locale_name,
            "LC_ALL": locale_name,
        }
    )
    if trace_path is not None:
        env["LOOM_TRACE_COMMANDS"] = trace_path
    if layout_trace_path is not None:
        env["LOOM_TRACE_LAYOUT"] = layout_trace_path
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
        profile=keys.DEFAULT_PROFILE, shell="/bin/sh",
        supervise_job_control=False,
    ):
        self.binary = binary
        self.arguments = list(arguments or [])
        self.profile = keys.get_profile(profile)
        self.shell = shell
        self.columns = columns
        self.rows = rows
        self.supervise_job_control = supervise_job_control
        self.process = None
        self.screen = None
        self.layout = Layout(rows, columns)
        self._scratch_dir = None
        self._home_dir = None
        self._locale_name = None
        self._trace_path = None
        self._layout_trace_path = None
        self._trace_bytes = b""
        self._trace_offset = 0
        self._write_in_flight = None
        self._trace_line_counter_token = None
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

    def _mark_launch(self, label):
        budget = current_deadline()
        if budget is None:
            return
        budget.timeline.session_count += 1
        count = budget.timeline.session_count
        mark_phase(label if count == 1 else f"{label} (session {count})")

    def _record_timeout_snapshot(self):
        """Record screen and trace tail once after expiry; return a deferred
        deadline error so the caller can finish process cleanup first."""
        budget = current_deadline()
        if budget is None or not budget.expired:
            return None
        if budget.timeline.snapshot is not None:
            return None
        try:
            self._write_timeout_snapshot(budget)
        except ScenarioDeadlineExceeded as error:
            return error
        except Exception as error:
            budget.timeline.record_snapshot(
                f"--- screen and trace snapshot failed: {error!r} ---"
            )
        return None

    def _write_timeout_snapshot(self, budget):
        if self.screen is None:
            screen = "(no screen: the session had not created one)"
            cursor = None
        else:
            screen = self.screen.dump()
            cursor = self.screen.cursor
        trace_lines = self._read_trace_data().decode(
            "utf-8", errors="replace"
        ).splitlines()
        tail = [
            line
            if len(line) <= _TIMEOUT_TRACE_LINE_LIMIT
            else line[: _TIMEOUT_TRACE_LINE_LIMIT - 3] + "..."
            for line in trace_lines[-_TIMEOUT_TRACE_TAIL_LINES:]
        ]
        first_screen = (
            "never"
            if self.first_screen_at is None or self.started_at is None
            else f"{self.first_screen_at - self.started_at:.3f}s after launch"
        )
        budget.timeline.record_snapshot(
            "\n".join(
                [
                    f"--- screen at timeout (cursor={cursor!r}; "
                    f"first content {first_screen}) ---",
                    screen,
                    "--- command trace tail at timeout "
                    f"(last {len(tail)} of {len(trace_lines)} records) ---",
                    *(tail or ["(empty)"]),
                ]
            )
        )

    def __enter__(self):
        self._mark_launch("launch")
        locale = _pick_utf8_locale()
        self._locale_name = locale
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
            self._layout_trace_path = os.path.join(
                self._scratch_dir, "loom-layout-trace.jsonl"
            )

            env = _session_environment(
                self._home_dir,
                locale,
                self.profile,
                self._trace_path,
                self._layout_trace_path,
                shell=self.shell,
            )

            self.started_at = time.monotonic()
            self.process = LoomProcess(
                self.binary, self.arguments, env=env,
                columns=self.columns, rows=self.rows,
                supervise_job_control=self.supervise_job_control,
            )
            budget = current_deadline()
            if budget is not None:
                budget.register_process(self.process)
            self.screen = Screen(self.columns, self.rows)
            self._trace_line_counter_token = set_trace_line_counter(
                self._trace_line_count
            )
            mark_phase("initial screen")
            return self
        except BaseException as error:
            try:
                self.__exit__(type(error), error, error.__traceback__)
            except BaseException as cleanup_error:
                raise error from cleanup_error
            raise

    def __exit__(self, _exception_type, _exception, _traceback):
        force_error = self._record_timeout_snapshot()
        mark_phase("session teardown")
        budget = current_deadline()
        if budget is not None and budget.expired:
            try:
                budget.force_cleanup()
            except BaseException as error:
                force_error = force_error or error
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
                if self._trace_line_counter_token is not None:
                    reset_trace_line_counter(self._trace_line_counter_token)
                    self._trace_line_counter_token = None
                mark_phase("after session close")
        if close_error is not None:
            if force_error is not None:
                raise close_error from force_error
            raise close_error
        if force_error is not None:
            raise force_error
        if artifact_error is not None:
            raise artifact_error

    def restart(self):
        """Replace the child while keeping this session's files and settings."""
        if self.process is None or self._locale_name is None:
            raise RuntimeError("cannot restart a session before it is entered")

        previous_process = self.process
        force_error = self._record_timeout_snapshot()
        self._mark_launch("restart")
        budget = current_deadline()
        if budget is not None and budget.expired:
            try:
                budget.force_cleanup()
            except BaseException as error:
                force_error = force_error or error

        close_error = None
        try:
            previous_process.close()
        except BaseException as error:
            close_error = error
        finally:
            if budget is not None:
                budget.unregister_process(previous_process)

        if close_error is not None:
            if force_error is not None:
                raise close_error from force_error
            raise close_error
        if force_error is not None:
            raise force_error

        self._capture_artifacts()
        self.process = None
        self.screen = None
        self._artifacts_captured = False
        self.started_at = time.monotonic()
        self.first_screen_at = None

        env = _session_environment(
            self._home_dir,
            self._locale_name,
            self.profile,
            self._trace_path,
            self._layout_trace_path,
            shell=self.shell,
        )
        self.process = LoomProcess(
            self.binary, self.arguments, env=env,
            columns=self.columns, rows=self.rows,
            supervise_job_control=self.supervise_job_control,
        )
        budget = current_deadline()
        if budget is not None:
            budget.register_process(self.process)
        self.screen = Screen(self.columns, self.rows)
        mark_phase("initial screen")
        return self

    def _read_trace_data(self):
        if self._trace_path is None:
            return b""
        try:
            with open(self._trace_path, "rb") as handle:
                return handle.read()
        except FileNotFoundError:
            return b""

    def _read_complete_command_trace_records(self):
        trace_data = self._read_trace_data()
        lines = trace_data.splitlines()
        if trace_data and not trace_data.endswith(b"\n"):
            lines = lines[:-1]
        return [json.loads(line.decode("utf-8")) for line in lines]

    def command_trace_count(self):
        """Return the number of complete command trace records observed so far."""
        return len(self._read_complete_command_trace_records())

    def wait_for_command_completion(
        self,
        command,
        *,
        route=None,
        after=0,
        timeout=DEFAULT_TIMEOUT,
    ):
        """Wait for a post-call command trace after record index AFTER."""
        if not isinstance(command, str) or not command:
            raise ValueError("command must be non-empty text")
        if route is not None and (not isinstance(route, str) or not route):
            raise ValueError("route must be non-empty text when provided")
        if type(after) is not int or after < 0:
            raise ValueError("after must be a non-negative integer")
        command = _canonical_command_trace_name(command)
        deadline = time.monotonic() + timeout
        while True:
            records = self._read_complete_command_trace_records()
            if any(
                index >= after
                and _canonical_command_trace_name(record.get("command")) == command
                and (route is None or record.get("route") == route)
                for index, record in enumerate(records)
            ):
                return
            if time.monotonic() >= deadline:
                raise TimeoutError(
                    f"timed out waiting for {command} command completion"
                    f"{f' on {route} route' if route is not None else ''}; "
                    f"trace records={len(records)}\n--- screen ---\n"
                    f"{self.screen.dump() if self.screen is not None else ''}"
                )
            self.pump()

    def _capture_artifacts(self):
        if self.process is None or self._artifacts_captured:
            return
        trace_data = self._read_trace_data()
        trace_offset = self._trace_offset
        if len(trace_data) < trace_offset:
            trace_offset = 0
        trace_bytes = trace_data[trace_offset:]
        result = current_result()
        if result is not None:
            result.add_session(self.process.output_bytes, trace_bytes)
        self._trace_bytes += trace_bytes
        self._trace_offset = len(trace_data)
        self._artifacts_captured = True

    def _refresh_layout_trace(self):
        if self._layout_trace_path is None:
            return
        try:
            with open(self._layout_trace_path, "rb") as handle:
                trace_data = handle.read()
        except FileNotFoundError:
            return

        lines = trace_data.splitlines()
        if trace_data and not trace_data.endswith(b"\n"):
            lines = lines[:-1]
        latest_body_x = None
        for line_number, line in enumerate(lines, 1):
            try:
                record = json.loads(line.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError) as error:
                raise ValueError(
                    f"invalid layout trace JSON at line {line_number}"
                ) from error
            if not isinstance(record, dict):
                raise ValueError(
                    f"invalid layout trace record at line {line_number}: expected an object"
                )
            if "body_x" not in record:
                continue
            body_x = record["body_x"]
            if (
                isinstance(body_x, bool)
                or not isinstance(body_x, int)
                or not 0 <= body_x <= self.columns
            ):
                raise ValueError(
                    f"invalid layout body_x at line {line_number}: {body_x!r}"
                )
            latest_body_x = body_x
        if latest_body_x is not None:
            self.layout.body_x = latest_body_x

    def pump(self, poll_timeout=0.05):
        """Read whatever is available without blocking and feed the screen."""
        had_content = self.screen.has_content()
        data = self.process.poll(poll_timeout)
        read_at = time.monotonic()
        self.screen.feed(data)
        if (
            data
            and not had_content
            and self.first_screen_at is None
            and self.screen.has_content()
        ):
            self.first_screen_at = read_at
            note_phase_event("first screen content")
        self._refresh_layout_trace()
        return data

    def _trace_line_count(self):
        result = current_result()
        previous_trace = self._trace_bytes if result is None else result.trace_output
        if self._trace_path is None:
            return count_trace_lines(previous_trace)
        trace_data = self._read_trace_data()
        trace_offset = self._trace_offset
        if len(trace_data) < trace_offset:
            trace_offset = 0
        return count_trace_lines(previous_trace) + count_trace_lines(
            trace_data[trace_offset:]
        )

    def resize(self, columns, rows):
        """Resize the PTY and keep pyte and layout dimensions in sync."""
        validate_dimensions(columns, rows)
        if self.process is None or self.screen is None:
            raise RuntimeError("cannot resize a session before it is entered")
        mark_phase(f"resize {columns}x{rows}")
        while self.pump(poll_timeout=0.0):
            pass
        self.process.resize(columns, rows)
        self.screen.resize(columns, rows)
        self.columns = columns
        self.rows = rows
        self.layout = Layout(rows, columns)
        record_event(
            "terminal_resize", columns=columns, rows=rows
        )
        self.observe_external_state(
            "PTY window size",
            self.process.window_size,
            (rows, columns),
            purpose="precondition",
        )

    @staticmethod
    def _matches(actual, expected, match):
        if expected is UNSET:
            return None
        if match == "contains":
            return expected in actual
        if match == "not_contains":
            return expected not in actual
        if match == "starts_with":
            return actual.startswith(expected)
        if match == "ends_with":
            return actual.endswith(expected)
        if match == "non_empty":
            return bool(actual.strip())
        if match == "changed":
            return actual != expected
        if match == "exact":
            return actual == expected
        raise ValueError(f"unknown observation match mode: {match!r}")

    def _read_screen_text(
        self, *, region=None, row=None, index=0, strip_right=False
    ):
        if (region is None) == (row is None):
            raise ValueError("screen text observation requires one region or row")
        if row is not None:
            actual = self.screen.text(row)
        elif region == "screen":
            actual = "\n".join(self.screen.lines())
        elif region == "body":
            self._refresh_layout_trace()
            if index is None:
                actual = "\n".join(
                    self.screen.text(body_row)[self.layout.body_x:]
                    for body_row in range(self.layout.body_height)
                )
            else:
                body_row = self.layout.row(region, index)
                actual = self.screen.text(body_row)[self.layout.body_x:]
        else:
            row = self.layout.row(region, index)
            actual = self.screen.text(row)
        if strip_right:
            actual = actual.rstrip()
        return actual

    def observe_screen_text(
        self,
        expected=UNSET,
        match="exact",
        *,
        region=None,
        row=None,
        index=0,
        strip_right=False,
        purpose="scenario",
    ):
        trace_lines = self._trace_line_count()
        actual = self._read_screen_text(
            region=region, row=row, index=index, strip_right=strip_right
        )
        passed = self._matches(actual, expected, match)
        details = {"match": match, "purpose": purpose}
        if region is not None:
            details["region"] = region
            if region != "screen" and index is not None:
                details["row"] = self.layout.row(region, index)
        else:
            details["row"] = row
        record_observation(
            "screen_text", actual, expected, passed,
            trace_lines=trace_lines, **details,
        )
        return passed

    def assert_screen_text(self, expected, match="exact", **source):
        passed = self.observe_screen_text(expected, match=match, **source)
        if passed is not True:
            raise AssertionError(
                f"screen text did not satisfy {match} for {expected!r}"
            )
        return True

    def observe_pty_output(
        self, actual, expected=UNSET, match="exact", *, purpose="scenario"
    ):
        trace_lines = self._trace_line_count()
        passed = self._matches(actual, expected, match)
        record_observation(
            "pty_output", actual, expected, passed,
            trace_lines=trace_lines, match=match, purpose=purpose,
        )
        return passed

    def assert_pty_output(self, actual, expected, match="contains"):
        if self.observe_pty_output(actual, expected, match=match) is not True:
            raise AssertionError(
                f"PTY output did not satisfy {match} for {expected!r}"
            )
        return actual

    def observe_cursor(
        self, expected=UNSET, *, purpose="scenario", sample=UNSET,
        region=None, index=0,
    ):
        trace_lines = self._trace_line_count()
        actual = (
            self.screen.cursor
            if region is None
            else self.region_cursor(region, index)
        )
        passed = None if expected is UNSET else actual == expected
        details = {} if sample is UNSET else {"sample": sample}
        if region is not None:
            details.update(region=region, index=index)
        record_observation(
            "cursor", actual, expected, passed,
            trace_lines=trace_lines, purpose=purpose, **details,
        )
        return passed

    def region_cursor(self, region, index=0):
        self.layout.row(region, index)
        if region == "body":
            self._refresh_layout_trace()
        origin_row = self.layout.row(region, 0)
        body_x = self.layout.body_x if region == "body" else 0
        row, column = self.screen.cursor
        return row - origin_row, column - body_x

    def observe_cell_attrs(
        self, row, column, expected=UNSET, *, purpose="scenario"
    ):
        trace_lines = self._trace_line_count()
        actual = self.screen.cell_attrs(row, column)
        if expected is not UNSET and not expected:
            raise ValueError("cell attribute expectations must not be empty")
        passed = (
            None
            if expected is UNSET
            else all(actual.get(name) == value for name, value in expected.items())
        )
        record_observation(
            "cell_attrs", actual, expected, passed,
            trace_lines=trace_lines, row=row, column=column, purpose=purpose,
        )
        return passed

    def assert_cell_attrs(self, row, column, expected):
        if self.observe_cell_attrs(row, column, expected) is not True:
            raise AssertionError(
                f"cell attributes at {(row, column)!r} did not match {expected!r}"
            )
        return True

    def _observe_file_bytes(self, path, expected=UNSET, *, purpose="scenario"):
        trace_lines = self._trace_line_count()
        try:
            with open(path, "rb") as handle:
                actual = handle.read()
        except FileNotFoundError:
            actual = None
        passed = None if expected is UNSET else actual == expected
        record_observation(
            "file_bytes", actual, expected, passed,
            trace_lines=trace_lines,
            target=self._observation_target(path),
            purpose=purpose,
        )
        return actual, passed

    def observe_file_bytes(self, path, expected=UNSET, *, purpose="scenario"):
        actual, _passed = self._observe_file_bytes(
            path, expected, purpose=purpose
        )
        return actual

    def assert_file_bytes(self, path, expected):
        actual, passed = self._observe_file_bytes(path, expected)
        if passed is not True:
            raise AssertionError(
                f"file bytes at {self._observation_target(path)!r} did not match"
            )
        return actual

    def observe_external_state(
        self, name, actual, expected=UNSET, *, purpose="scenario"
    ):
        trace_lines = self._trace_line_count()
        passed = None if expected is UNSET else actual == expected
        record_observation(
            "external_state", actual, expected, passed,
            trace_lines=trace_lines, name=name, purpose=purpose,
        )
        return passed

    def assert_external_state(
        self, name, actual, expected, *, purpose="scenario"
    ):
        if self.observe_external_state(
            name, actual, expected, purpose=purpose
        ) is not True:
            raise AssertionError(
                f"external state {name!r} was {actual!r}, expected {expected!r}"
            )
        return actual

    def observe_exit_code(self, actual, expected=UNSET, *, purpose="scenario"):
        trace_lines = self._trace_line_count()
        passed = None if expected is UNSET else actual == expected
        record_observation(
            "exit_code", actual, expected, passed,
            trace_lines=trace_lines, purpose=purpose,
        )
        return passed

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
        last_observed = UNSET

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
            self.observe_external_state(
                name, actual, expected, purpose="precondition"
            )
            raise
        actual = last_observed
        self.observe_external_state(
            name, actual, expected, purpose="precondition"
        )
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
        self.observe_screen_text(
            expected={"non_empty": True},
            match="non_empty",
            region="screen",
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
                expected=substring,
                match="contains",
                region="screen",
                purpose="precondition",
            )
            raise
        row, _column = self.screen.find(substring)
        self.observe_screen_text(
            expected=substring,
            match="contains",
            row=row,
            purpose="precondition",
        )

    def wait_for_row_text(self, row, substring, timeout=DEFAULT_TIMEOUT):
        try:
            self.wait_until(
                lambda screen: substring in screen.text(row),
                timeout, f"row {row} to contain {substring!r}",
            )
        except TimeoutError:
            self.observe_screen_text(
                expected=substring,
                match="contains",
                row=row,
                purpose="precondition",
            )
            raise
        self.observe_screen_text(
            expected=substring,
            match="contains",
            row=row,
            purpose="precondition",
        )

    def wait_for_row_exact_text(
        self, row, expected, strip_right=True, timeout=DEFAULT_TIMEOUT
    ):
        def read_text():
            actual = self.screen.text(row)
            return actual.rstrip() if strip_right else actual

        try:
            self.wait_until(
                lambda _screen: read_text() == expected,
                timeout,
                f"row {row} to equal {expected!r}",
            )
        except TimeoutError:
            self.observe_screen_text(
                expected=expected,
                match="exact",
                row=row,
                strip_right=strip_right,
                purpose="precondition",
            )
            raise
        return self.observe_screen_text(
            expected=expected,
            match="exact",
            row=row,
            strip_right=strip_right,
            purpose="precondition",
        )

    def region_text(self, region, index=0):
        row = self.layout.row(region, index)
        if region == "body":
            self._refresh_layout_trace()
            return self.screen.text(row)[self.layout.body_x:]
        return self.screen.text(row)

    def region_contents(self, region):
        if region == "body":
            self._refresh_layout_trace()
            rows = range(self.layout.body_height)
            return "\n".join(
                self.screen.text(row)[self.layout.body_x:] for row in rows
            )
        else:
            rows = (self.layout.row(region),)
        return "\n".join(self.screen.text(row) for row in rows)

    def wait_for_region_text(self, region, substring, index=0, timeout=DEFAULT_TIMEOUT):
        row = self.layout.row(region, index)
        try:
            self.wait_until(
                lambda _screen: substring in self.region_text(region, index),
                timeout,
                f"{region} row {index} to contain {substring!r}",
            )
        except TimeoutError:
            self.observe_screen_text(
                expected=substring,
                match="contains",
                region=region,
                index=index,
                purpose="precondition",
            )
            raise
        self.observe_screen_text(
            expected=substring,
            match="contains",
            region=region,
            index=index,
            purpose="precondition",
        )

    def wait_for_region_exact_text(
        self, region, expected, index=0, strip_right=True, timeout=DEFAULT_TIMEOUT
    ):
        row = self.layout.row(region, index)

        def read_text():
            actual = self.region_text(region, index)
            return actual.rstrip() if strip_right else actual

        try:
            self.wait_until(
                lambda _screen: read_text() == expected,
                timeout,
                f"{region} row {index} to equal {expected!r}",
            )
        except TimeoutError:
            self.observe_screen_text(
                expected=expected,
                match="exact",
                region=region,
                index=index,
                strip_right=strip_right,
                purpose="precondition",
            )
            raise
        return self.observe_screen_text(
            expected=expected,
            match="exact",
            region=region,
            index=index,
            strip_right=strip_right,
            purpose="precondition",
        )

    def wait_for_region_text_prefix(
        self, region, expected, index=0, timeout=DEFAULT_TIMEOUT
    ):
        row = self.layout.row(region, index)
        try:
            self.wait_until(
                lambda _screen: self.region_text(region, index).startswith(expected),
                timeout,
                f"{region} row {index} to start with {expected!r}",
            )
        except TimeoutError:
            self.observe_screen_text(
                expected=expected,
                match="starts_with",
                region=region,
                index=index,
                purpose="precondition",
            )
            raise
        return self.observe_screen_text(
            expected=expected,
            match="starts_with",
            region=region,
            index=index,
            purpose="precondition",
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
                expected=substring,
                match="contains",
                region=region,
                index=None if region == "body" else 0,
                purpose="precondition",
            )
            raise
        return self.observe_screen_text(
            expected=substring,
            match="contains",
            region=region,
            index=None if region == "body" else 0,
            purpose="precondition",
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
                expected=expected_line,
                match="exact",
                row=row,
                strip_right=True,
                purpose="precondition",
            )
            self.observe_cursor(
                expected=expected_cursor, purpose="precondition"
            )
            raise
        self.observe_screen_text(
            expected=expected_line,
            match="exact",
            row=row,
            strip_right=True,
            purpose="precondition",
        )
        self.observe_cursor(expected=expected_cursor, purpose="precondition")

    def wait_for_region_absent_text(
        self, region, substring, index=0, timeout=DEFAULT_TIMEOUT
    ):
        row = self.layout.row(region, index)
        try:
            self.wait_until(
                lambda _screen: substring not in self.region_text(region, index),
                timeout,
                f"{substring!r} to disappear from {region} row {index}",
            )
        except TimeoutError:
            self.observe_screen_text(
                expected=substring,
                match="not_contains",
                region=region,
                index=index,
                purpose="precondition",
            )
            raise
        return self.observe_screen_text(
            expected=substring,
            match="not_contains",
            region=region,
            index=index,
            purpose="precondition",
        )

    def wait_for_text_absent(self, substring, timeout=DEFAULT_TIMEOUT):
        try:
            self.wait_until(
                lambda _screen: self.screen.find(substring) is None,
                timeout,
                f"{substring!r} to disappear from the screen",
            )
        except TimeoutError:
            self.observe_screen_text(
                expected=substring,
                match="not_contains",
                region="screen",
                purpose="precondition",
            )
            raise
        return self.observe_screen_text(
            expected=substring,
            match="not_contains",
            region="screen",
            purpose="precondition",
        )

    def wait_for_cursor(
        self, row, col, timeout=DEFAULT_TIMEOUT, *, region=None, index=0,
        body_col=None,
    ):
        expected = (row, col)
        observation_expected = expected
        if region is not None:
            if region == "body":
                self._refresh_layout_trace()
                if body_col is None:
                    body_col = col - self.layout.body_x
            origin_row = self.layout.row(region, 0)
            body_x = self.layout.body_x if region == "body" else 0
            observation_expected = (
                row - origin_row,
                body_col if region == "body" else col - body_x,
            )

        def cursor_matches(screen):
            if region == "body":
                self._refresh_layout_trace()
                terminal_col = body_col + self.layout.body_x
                return screen.cursor == (row, terminal_col)
            return screen.cursor == expected

        try:
            self.wait_until(
                cursor_matches,
                timeout, f"cursor to reach (row={row}, col={col})",
            )
        except TimeoutError:
            self.observe_cursor(
                expected=observation_expected,
                purpose="precondition",
                region=region,
                index=index,
            )
            raise
        self.observe_cursor(
            expected=observation_expected,
            purpose="precondition",
            region=region,
            index=index,
        )

    def wait_for_region_cursor(self, region, col, index=0, timeout=DEFAULT_TIMEOUT):
        row = self.layout.row(region, index)
        self._refresh_layout_trace()
        terminal_col = col + (self.layout.body_x if region == "body" else 0)
        self.wait_for_cursor(
            row,
            terminal_col,
            timeout,
            region=region,
            index=index,
            body_col=col if region == "body" else None,
        )

    def wait_for_file(
        self,
        path,
        expected_bytes,
        timeout=DEFAULT_TIMEOUT,
        *,
        command=None,
        after=None,
        route=None,
    ):
        """Check PATH once COMMAND's trace row after record AFTER appears.

        This is the low-level form for runners that send the writing input
        themselves and keep AFTER from just before it.  Scenarios use
        write_and_wait or save_buffer, which send the input and take AFTER in
        one call.  loom appends a trace row only after the command returns,
        so bytes read after the row are that write's final output.  The bytes
        are read once, at the first such row; a mismatch fails, and a row with
        completed:false fails because unchanged bytes would otherwise pass for
        a write that never ran.
        """
        if command is None or after is None:
            raise TypeError(
                f"wait_for_file({path!r}) needs the writer: use "
                "write_and_wait/save_buffer for a command write, "
                "wait_for_prompted_file for a write from a minibuffer answer, "
                "or wait_for_untraced_file for a writer without a trace row"
            )
        command = _canonical_command_trace_name(command)
        deadline = time.monotonic() + timeout
        while True:
            records = self._read_complete_command_trace_records()
            row = next(
                (
                    (index, record)
                    for index, record in enumerate(records)
                    if index >= after
                    and _canonical_command_trace_name(record.get("command")) == command
                    and (route is None or record.get("route") == route)
                ),
                None,
            )
            if row is not None:
                index, record = row
                actual = self.observe_file_bytes(
                    path, expected_bytes, purpose="precondition"
                )
                if record.get("completed") is not True:
                    raise AssertionError(
                        f"{command} trace row {index} for {path} has "
                        "completed:false, so the write did not finish"
                        f"\n--- screen ---\n{self._screen_dump()}"
                    )
                if actual != expected_bytes:
                    raise AssertionError(
                        f"{path} contained {actual!r} after {command} trace row "
                        f"{index}; expected {expected_bytes!r}"
                        f"\n--- screen ---\n{self._screen_dump()}"
                    )
                return
            if time.monotonic() >= deadline:
                self.observe_file_bytes(
                    path, expected_bytes, purpose="precondition"
                )
                raise TimeoutError(
                    f"timed out waiting for {command} completion after trace "
                    f"record {after} before reading {path}"
                    f"\n--- screen ---\n{self._screen_dump()}"
                )
            self.pump()

    def _screen_dump(self):
        return self.screen.dump() if self.screen is not None else ""

    def wait_for_prompted_file(
        self, path, expected_bytes, message, *, timeout=DEFAULT_TIMEOUT
    ):
        """Check PATH after a minibuffer answer ran the write.

        A prompting command records its trace when the prompt opens, before
        the answer runs the write, and the answer records no trace.  loom
        renders only after an input dispatch returns, so MESSAGE, which the
        writer sets after writing, marks completion once it replaces the
        prompt.  Wait for the prompt before answering so MESSAGE is not stale.
        """
        self.wait_for_region_text("minibuffer", message, timeout=timeout)
        actual = self.observe_file_bytes(
            path, expected_bytes, purpose="precondition"
        )
        if actual != expected_bytes:
            raise AssertionError(
                f"{path} contained {actual!r} after {message!r} appeared; "
                f"expected {expected_bytes!r}\n--- screen ---\n"
                f"{self.screen.dump() if self.screen is not None else ''}"
            )

    def write_and_wait(
        self,
        path,
        expected_bytes,
        *,
        command,
        route,
        keys=None,
        mx=None,
        timeout=DEFAULT_TIMEOUT,
    ):
        """Send one writing input, then check PATH after COMMAND completes.

        Send KEYS (bytes) or run MX through M-x; COMMAND and ROUTE name the
        trace row that input records, for example save-buffer on the macro
        route for a replay with C-x e.  The trace count is taken just before
        the input, so only this input's row satisfies the wait provided no
        unfinished raw writing input is mixed in: a raw write whose row lands
        after that count would satisfy it too.  Raw sends are not tracked, so
        after writing with raw input, confirm that write's completion
        explicitly before calling this method.  A write sent through this
        method and never confirmed blocks the next one.
        """
        if (keys is None) == (mx is None):
            raise ValueError("write_and_wait needs exactly one of keys or mx")
        if self._write_in_flight is not None:
            raise RuntimeError(
                f"{self._write_in_flight} was sent through write_and_wait but "
                "its completion was never confirmed; a new write cannot be "
                "told apart from it"
            )
        after = self.command_trace_count()
        self._write_in_flight = f"{command} for {path}"
        if keys is not None:
            self.send(keys)
        else:
            self.extended_command(mx, timeout=timeout)
        self.wait_for_file(
            path,
            expected_bytes,
            timeout,
            command=command,
            route=route,
            after=after,
        )
        self._write_in_flight = None

    def save_buffer(
        self, path, expected_bytes, *, route="key", timeout=DEFAULT_TIMEOUT
    ):
        """Run save-buffer through ROUTE ("key" or "mx") and check PATH."""
        if route == "key":
            self.write_and_wait(
                path,
                expected_bytes,
                command="save-buffer",
                route="key",
                keys=keys.ctrl("x") + keys.ctrl("s"),
                timeout=timeout,
            )
        elif route == "mx":
            self.write_and_wait(
                path,
                expected_bytes,
                command="save-buffer",
                route="mx",
                mx="save-buffer",
                timeout=timeout,
            )
        else:
            raise ValueError("save_buffer route must be 'key' or 'mx'")

    def wait_for_untraced_file(
        self, path, expected_bytes, timeout=DEFAULT_TIMEOUT
    ):
        """Poll PATH for bytes written outside any traced loom command.

        Use this only for writers that record no command trace, such as a
        child process or a timer.  A command's file effect goes through
        wait_for_file so that its completion is observed first.
        """
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
                self.observe_file_bytes(
                    path, expected_bytes, purpose="precondition"
                )
                return
            if time.monotonic() >= deadline:
                self.observe_file_bytes(
                    path, expected_bytes, purpose="precondition"
                )
                raise TimeoutError(
                    f"timed out waiting for {path} to contain {expected_bytes!r}; "
                    f"last read {last_seen!r}\n--- screen ---\n{self.screen.dump()}"
                )

    def send(self, data):
        with phase_step(
            lambda: "key " + _clip(_describe_input(data, self.profile))
        ):
            self.process.write(data)

    def type(self, text):
        with phase_step(lambda: "type " + _clip(repr(text))):
            self.send(keys.text(text))
            record_event("text_input", text=text)

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
        with phase_step(lambda: "M-x " + _clip(name)):
            self.send(keys.meta("x"))
            self.wait_for_region_text("minibuffer", "M-x ", timeout=timeout)
            self.type(name)
            self.key("RET")

    def quit(self, timeout=DEFAULT_TIMEOUT):
        with phase_step("quit"):
            self.send(keys.ctrl("x") + keys.ctrl("c"))
            output, code = self.process.wait(timeout=timeout)
            self.observe_exit_code(code, expected=0)
        return output, code
