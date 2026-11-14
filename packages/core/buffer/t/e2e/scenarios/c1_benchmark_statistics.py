import json
import os
import statistics
import subprocess
import tempfile

from loom_e2e.benchmarks import (
    _measure_redraw,
    _percentile_95,
    _redraw_samples,
)
from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _uptime():
    return subprocess.run(
        ["uptime"],
        check=True,
        capture_output=True,
        text=True,
        timeout=1.0,
    ).stdout.strip()


def _d13_samples(binary):
    line_count = 20_000
    with tempfile.TemporaryDirectory(prefix="loom-c1-d13-statistics-") as directory:
        path = os.path.join(directory, "large.txt")
        with open(path, "wb") as handle:
            for index in range(line_count):
                handle.write(b"line-%05d " % index + b"x" * 20 + b"\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.wait_for_region_text("body", "line-00000")
            session.wait_for_region_cursor("body", 0)
            session.observe_external_state(
                "C1 D13 input line count", line_count, expected=20_000
            )
            session.observe_external_state(
                "C1 D13 input byte count",
                os.path.getsize(path),
                expected=640_000,
            )
            samples = [
                elapsed * 1000.0
                for elapsed in _redraw_samples(session, sample_count=25)
            ]
            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"C1 D13 statistics exited with {code}: {output!r}"
                )
    return samples


def _statistics(samples):
    return {
        "sample_count": len(samples),
        "median_ms": statistics.median(samples),
        "p95_ms": _percentile_95(samples),
        "maximum_ms": max(samples),
        "samples_ms": samples,
    }


@scenario("c1/benchmark-statistics", commands=["forward-char"])
def c1_benchmark_statistics(binary):
    uptime_before = _uptime()
    d13 = _d13_samples(binary)
    redraw = []
    for _batch in range(4):
        redraw.extend(_measure_redraw(binary, sample_count=25)["samples"])
    if len(d13) != 25 or len(redraw) != 100:
        raise AssertionError("C1 benchmark statistics did not collect 25/100 samples")

    report = {
        "uptime_before": uptime_before,
        "uptime_after": _uptime(),
        "protocol": {
            "warmup_samples": 0,
            "percentile": "nearest-rank",
            "d13_sessions": 1,
            "redraw_sessions": 4,
            "redraw_samples_per_session": 25,
        },
        "d13": _statistics(d13),
        "redraw": _statistics(redraw),
    }
    print(
        "C1_BENCHMARK_STATISTICS "
        + json.dumps(report, allow_nan=False, sort_keys=True),
        flush=True,
    )
