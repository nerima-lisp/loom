"""PTY benchmark scenarios for startup, redraw, file open, and key response."""

import math
import os
import tempfile
import time

from . import keys
from .deadline import (
    SCENARIO_CLEANUP_TIMEOUT_SECONDS,
    SCENARIO_EXECUTION_TIMEOUT_SECONDS,
    SCENARIO_TIMEOUT_SECONDS,
    current_deadline,
)
from .results import record_observation
from .session import Session


_LINE_COUNT = 100_000
_LINE_BYTES = 50
_OPEN_MARKER = b"LOOM_E2E_OPEN_BENCHMARK"
_OPEN_LAST_LINE_MARKER = b"LOOM_E2E_LAST_LINE_MARKER"
_REDRAW_SAMPLES = 25
_D13_KEY_RESPONSE_TARGET_MS = 50.0


def _large_file(path):
    line = _OPEN_MARKER + b"x" * (_LINE_BYTES - len(_OPEN_MARKER) - 1) + b"\n"
    last_line = (
        _OPEN_LAST_LINE_MARKER
        + b"x" * (_LINE_BYTES - len(_OPEN_LAST_LINE_MARKER) - 1)
        + b"\n"
    )
    with open(path, "wb") as handle:
        for _line in range(_LINE_COUNT - 1):
            handle.write(line)
        handle.write(last_line)
    return _LINE_COUNT, _LINE_COUNT * len(line)


def _redraw_samples(session):
    samples = []
    budget = current_deadline()
    if budget is None:
        raise RuntimeError("PTY benchmarks require an active scenario deadline")
    for sample in range(_REDRAW_SAMPLES):
        before = session.screen.cursor
        expected = (before[0], before[1] + 1)
        started = time.monotonic()
        session.send(keys.ctrl("f"))
        while budget.remaining() > 0:
            session.pump(poll_timeout=0.001)
            if session.screen.cursor != before:
                if session.observe_cursor(
                    expected=expected, sample=sample
                ) is not True:
                    raise AssertionError(
                        f"cursor moved to {session.screen.cursor!r}, "
                        f"expected {expected!r}"
                    )
                samples.append(time.monotonic() - started)
                break
        else:
            raise TimeoutError("PTY input did not produce a screen redraw")
    return samples


def _percentile_95(values):
    ordered = sorted(values)
    return ordered[math.ceil(0.95 * len(ordered)) - 1]


def _require_active_deadline():
    if current_deadline() is None:
        raise RuntimeError("PTY benchmarks require an active scenario deadline")


def _record_measurement(metric, value, unit):
    record_observation(
        "benchmark_measurement", value, metric=metric, unit=unit
    )


def _measure_startup(binary):
    _require_active_deadline()
    with Session(binary) as session:
        session.wait_ready()
        measurement = session.first_screen_at - session.started_at
        _record_measurement(
            "startup_to_first_screen_seconds", measurement, "seconds"
        )
        session.quit()
    return {"startup_to_first_screen_seconds": measurement}


def _measure_redraw(binary):
    _require_active_deadline()
    with tempfile.TemporaryDirectory(prefix="loom-e2e-benchmark-") as directory:
        path = os.path.join(directory, "redraw.txt")
        with open(path, "wb") as handle:
            handle.write(b"x" * 64)
        with Session(binary, [path]) as session:
            session.wait_ready()
            session.wait_for_text("x" * 64)
            session.wait_for_region_cursor("body", 0)
            measurement = _percentile_95(_redraw_samples(session)) * 1000.0
            _record_measurement(
                "input_to_redraw_p95_milliseconds",
                measurement,
                "milliseconds",
            )
            session.quit()
    return {"input_to_redraw_p95_milliseconds": measurement}


def _measure_large_file_open(binary):
    _require_active_deadline()
    with tempfile.TemporaryDirectory(prefix="loom-e2e-benchmark-") as directory:
        path = os.path.join(directory, "large.txt")
        line_count, byte_count = _large_file(path)
        with Session(binary) as session:
            session.wait_ready()
            session.send(keys.ctrl("x") + keys.ctrl("f"))
            session.wait_for_region_text("minibuffer", "Find file: ")
            started = time.monotonic()
            session.type(path)
            session.key("RET")
            session.wait_for_text(_OPEN_MARKER.decode("ascii"))
            session.wait_for_region_cursor("body", 0)
            session.extended_command("end-of-buffer")
            session.wait_for_text(_OPEN_LAST_LINE_MARKER.decode("ascii"))
            measurement = time.monotonic() - started
            _record_measurement(
                "open_100000_lines_5mb_seconds", measurement, "seconds"
            )
            session.observe_external_state(
                "benchmark input size", os.path.getsize(path), expected=byte_count
            )
            session.observe_external_state(
                "benchmark input line count", line_count, expected=_LINE_COUNT
            )
            session.quit()
    return {
        "open_100000_lines_5mb_seconds": measurement,
        "input": {"lines": line_count, "bytes": byte_count},
    }


def benchmark_scenarios(registered=None):
    scenarios = {
        "startup": _measure_startup,
        "redraw": _measure_redraw,
    }
    if registered is not None:
        d13_scenario = next(
            (
                function
                for name, _commands, function in registered
                if name == "d13/20k-line-key-response"
            ),
            None,
        )
        if d13_scenario is not None:
            def measure_d13_key_response(binary):
                return d13_scenario(
                    binary,
                    benchmark_target_ms=_D13_KEY_RESPONSE_TARGET_MS,
                )

            scenarios["d13-20k-line-key-response"] = measure_d13_key_response
    scenarios["large-file-open"] = _measure_large_file_open
    return scenarios


def build_benchmark_report(measurements):
    values = {
        name: value
        for result in measurements.values()
        for name, value in result.items()
        if name != "input"
    }
    startup_seconds = values["startup_to_first_screen_seconds"]
    open_seconds = values["open_100000_lines_5mb_seconds"]
    redraw_milliseconds = values["input_to_redraw_p95_milliseconds"]
    report = {
        "measurements": {
            "startup_to_first_screen_seconds": startup_seconds,
            "open_100000_lines_5mb_seconds": open_seconds,
            "input_to_redraw_p95_milliseconds": redraw_milliseconds,
        },
        "targets": {
            "startup_to_first_screen_seconds": 0.3,
            "open_100000_lines_5mb_seconds": 1.0,
            "input_to_redraw_p95_milliseconds": 50.0,
        },
        "within_targets": {
            "startup_to_first_screen": startup_seconds <= 0.3,
            "open_100000_lines_5mb": open_seconds <= 1.0,
            "input_to_redraw_p95": redraw_milliseconds <= 50.0,
        },
        "input": measurements["large-file-open"]["input"],
        "protocol": {
            "startup_samples": 1,
            "file_open_samples": 1,
            "redraw_samples": _REDRAW_SAMPLES,
            "warmup_runs": 0,
            "redraw_interval": (
                "from C-f input to cursor-position output in a loaded "
                "64-character buffer"
            ),
            "file_open_interval": (
                "from filename entry after the Find file prompt to rendering "
                "the unique last-line marker after end-of-buffer"
            ),
            "scenario_deadline_seconds": SCENARIO_TIMEOUT_SECONDS,
            "execution_budget_seconds": SCENARIO_EXECUTION_TIMEOUT_SECONDS,
            "cleanup_budget_seconds": SCENARIO_CLEANUP_TIMEOUT_SECONDS,
        },
    }
    d13_measurement = measurements.get("d13-20k-line-key-response")
    if d13_measurement is not None:
        d13_milliseconds = values[
            "d13_20k_line_key_response_milliseconds"
        ]
        report["measurements"][
            "d13_20k_line_key_response_milliseconds"
        ] = d13_milliseconds
        report["targets"][
            "d13_20k_line_key_response_milliseconds"
        ] = _D13_KEY_RESPONSE_TARGET_MS
        report["within_targets"]["d13_20k_line_key_response"] = (
            d13_milliseconds <= _D13_KEY_RESPONSE_TARGET_MS
        )
        report["protocol"]["d13_key_response_samples"] = 1
        report["protocol"]["d13_key_response_interval"] = (
            "from C-f input to cursor-position output in a loaded "
            "20,000-line buffer"
        )
    return report
