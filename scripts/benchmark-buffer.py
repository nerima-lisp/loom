import argparse
import json
import os
from pathlib import Path
import statistics
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "t" / "e2e"))

from loom_e2e.benchmarks import (
    _measure_redraw,
    _percentile_95,
    _redraw_samples,
)
from loom_e2e.deadline import scenario_deadline
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

        with scenario_deadline(), Session(binary, [path]) as session:
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


def collect_statistics(binary):
    uptime_before = _uptime()
    d13 = _d13_samples(binary)
    redraw = []
    for _batch in range(4):
        with scenario_deadline():
            redraw.extend(_measure_redraw(binary, sample_count=25)["samples"])
    if len(d13) != 25 or len(redraw) != 100:
        raise AssertionError("C1 benchmark statistics did not collect 25/100 samples")

    return {
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


def main(argv=None):
    parser = argparse.ArgumentParser(description="Record buffer benchmark distributions.")
    parser.add_argument("--binary", required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    report = json.dumps(
        collect_statistics(args.binary), allow_nan=False, sort_keys=True
    )
    if args.output is not None:
        args.output.write_text(report + "\n")
    print("C1_BENCHMARK_STATISTICS " + report, flush=True)


if __name__ == "__main__":
    main()
