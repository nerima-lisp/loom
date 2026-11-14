import argparse
import json
import math
from pathlib import Path
import runpy
import statistics
import subprocess
import sys


root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / "t" / "e2e"))
harness = runpy.run_path(str(root / "t" / "e2e" / "loom-test.py"))
from loom_e2e import benchmarks
from loom_e2e.deadline import run_scenario
from loom_e2e.results import ScenarioResult, capture_scenario


def measure(name, function, binary, artifacts):
    result = ScenarioResult(name, binary_realpath=str(binary.resolve()))
    try:
        with capture_scenario(result):
            value = run_scenario(function, str(binary))
        if isinstance(value, dict):
            for field in ("first_row_observed", "last_line_observed"):
                if field in value and value[field] is not True:
                    raise AssertionError(f"{name}: {field} was not observed")
        result.status = "passed"
    except BaseException as error:
        result.status = "failed"
        result.error = {"type": type(error).__name__, "message": str(error)}
        raise
    finally:
        result.save(str(artifacts))
    values = {}
    for observation in result.observations:
        if observation["type"] == "benchmark_measurement":
            metric = observation["metric"]
            values.setdefault(metric, []).extend(
                observation.get("samples", [observation["actual"]])
            )
    if not values:
        raise AssertionError(f"{name}: no benchmark measurements")
    return values


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--before", type=Path, required=True)
    parser.add_argument("--after", type=Path, required=True)
    parser.add_argument("--artifacts-dir", type=Path, required=True)
    parser.add_argument("--rounds", type=int, default=20)
    args = parser.parse_args()
    if args.rounds < 20:
        parser.error("at least 20 measured rounds are required")
    for binary in (args.before, args.after):
        if not binary.is_file():
            parser.error(f"missing executable: {binary}")
    args.artifacts_dir.mkdir(parents=True, exist_ok=True)
    harness["_run_harness_preflight"]()
    d13 = next(
        function
        for name, _commands, function in harness["all_scenarios"]()
        if name == "d13/20k-line-key-response"
    )
    scenarios = {
        "startup": benchmarks._measure_startup,
        "file-open": benchmarks._measure_large_file_open,
        "file-eof": benchmarks._measure_large_file_eof,
        "redraw": benchmarks._measure_redraw,
        # R-7 judges the collected p95. The ordinary CI benchmark gate is retained.
        "d13": d13,
    }
    samples = {arm: {} for arm in ("before", "after")}
    loads = []
    # One complete warmup per arm is excluded. Measured arm order alternates.
    for round_index in range(-1, args.rounds):
        order = ("before", "after") if round_index % 2 == 0 else ("after", "before")
        loads.append({
            "round": round_index,
            "uptime": subprocess.check_output(["uptime"], text=True).strip(),
        })
        for arm in order:
            binary = getattr(args, arm)
            for name, function in scenarios.items():
                values = measure(
                    f"k1/{arm}/round-{round_index}/{name}", function, binary,
                    args.artifacts_dir,
                )
                if round_index >= 0:
                    for metric, observations in values.items():
                        samples[arm].setdefault(metric, []).extend(observations)
        print(f"completed paired round {round_index}", flush=True)
    targets = {
        "startup_to_first_screen_seconds": benchmarks._STARTUP_TARGET_SECONDS,
        "open_100000_lines_5mb_seconds": benchmarks._FILE_OPEN_TARGET_SECONDS,
        "input_to_redraw_p95_milliseconds": benchmarks._REDRAW_TARGET_MILLISECONDS,
        "D13 input-to-redraw": benchmarks._D13_KEY_RESPONSE_TARGET_MS,
    }
    report = {
        "binaries": {arm: str(getattr(args, arm).resolve()) for arm in samples},
        "protocol": {"rounds": args.rounds, "warmup_rounds_excluded": 1,
                     "order": "alternating paired arms", "uptime": loads},
        "statistics": {}, "samples": samples,
    }
    for arm, metrics in samples.items():
        if not set(targets).issubset(metrics):
            raise AssertionError(f"{arm}: missing metrics {set(targets) - set(metrics)}")
        report["statistics"][arm] = {}
        for metric, observations in metrics.items():
            if len(observations) < 20 or not all(math.isfinite(x) for x in observations):
                raise AssertionError(f"{arm}/{metric}: invalid sample set")
            p95 = benchmarks._percentile_95(observations)
            stats = {"count": len(observations), "median": statistics.median(observations),
                     "p95": p95, "maximum": max(observations)}
            if metric in targets:
                stats.update(target=targets[metric], passed=p95 <= targets[metric])
            report["statistics"][arm][metric] = stats
    destination = args.artifacts_dir / "paired-benchmarks.json"
    destination.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print(json.dumps(report, indent=2, sort_keys=True))
    return int(any(stats.get("passed") is False
                   for stats in report["statistics"]["after"].values()))


if __name__ == "__main__":
    raise SystemExit(main())
