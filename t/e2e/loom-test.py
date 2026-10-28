#!/usr/bin/env python3
"""Entry point for loom's PTY end-to-end suite.

Exercises the built loom executable through a real Unix PTY, reconstructing
the terminal screen with pyte so scenarios can assert on rendered state
instead of raw-byte substrings and fixed sleeps.
"""

import argparse
import json
import os
import sys
import tempfile
import time
import unittest

_THIS_DIR = os.path.dirname(os.path.abspath(__file__))
if _THIS_DIR not in sys.path:
    sys.path.insert(0, _THIS_DIR)

from loom_e2e import commands  # noqa: E402
from loom_e2e.benchmarks import (  # noqa: E402
    benchmark_scenarios,
    build_benchmark_report,
)
from loom_e2e.deadline import (  # noqa: E402
    SCENARIO_EXECUTION_TIMEOUT_SECONDS,
    run_scenario,
)
from loom_e2e.registry import all_scenarios  # noqa: E402
from loom_e2e.scenario_discovery import (  # noqa: E402
    format_scenario_listing,
    load_slice_scenarios,
    select_scenarios,
)
from loom_e2e.results import ScenarioResult, capture_scenario  # noqa: E402
from loom_e2e.path_generation import generate_required_paths  # noqa: E402
from loom_e2e.path_ledger import read_path_ledgers  # noqa: E402
from loom_e2e.path_report import (  # noqa: E402
    build_report as build_path_report,
    render_summary as render_path_summary,
    write_report as write_path_report,
)
import scenarios  # noqa: E402,F401


_REPO_ROOT = os.path.abspath(os.path.join(_THIS_DIR, "..", ".."))
load_slice_scenarios(_REPO_ROOT)


def _binary_from_arguments(explicit):
    binary = explicit or os.environ.get("LOOM_BINARY")
    if binary is None:
        raise SystemExit("pass --binary, or set LOOM_BINARY, to the loom executable")
    binary = os.path.abspath(binary)
    if not os.path.isfile(binary) or not os.access(binary, os.X_OK):
        raise SystemExit(f"loom executable is not runnable: {binary}")
    return binary


def _parse_args(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", default=None, help="path to the loom executable")
    parser.add_argument("--only", default=None, help="run only scenarios whose name contains SUBSTR")
    parser.add_argument(
        "--artifacts-dir",
        default=None,
        help="write per-scenario results here (default: a unique retained temp directory)",
    )
    parser.add_argument(
        "--timing-report",
        default=None,
        help="write one JSON line per scenario with its execution time and budget use",
    )
    parser.add_argument(
        "--benchmarks",
        action="store_true",
        help="report PTY startup, large-file open, and input-to-redraw measurements",
    )
    parser.add_argument(
        "--benchmark-gate",
        action="store_true",
        help="report benchmark measurements and fail when any target is missed",
    )
    parser.add_argument("--list", action="store_true", help="list scenario names and exit")
    parser.add_argument(
        "--require-full-coverage", action="store_true",
        help="exit 1 when a registered command-spec is not exercised by selected scenarios",
    )
    parser.add_argument(
        "--require-path-coverage", action="store_true",
        help="exit 1 when generated paths are missing or fail their trace/observation checks",
    )
    return parser.parse_args(argv)


def _coverage_report(selected, catalog):
    all_command_ids = commands.catalog_command_ids(catalog)
    if not all_command_ids:
        raise SystemExit("command-spec catalogue is empty")
    covered = {
        command for _, scenario_commands, _ in selected
        for command in scenario_commands
    }
    covered_known = covered & all_command_ids
    uncovered = sorted(all_command_ids - covered)
    unknown = sorted(covered - all_command_ids)
    print(f"commands covered: {len(covered_known)} / {len(all_command_ids)}")
    print(f"uncovered commands: {', '.join(uncovered) if uncovered else '(none)'}")
    print(f"uncovered: {len(uncovered)}")
    print(f"未カバー {len(uncovered)}")
    if unknown:
        print(f"unknown scenario command IDs: {', '.join(unknown)}")
    return uncovered, unknown


def _path_coverage_report(
    catalog, artifacts_dir, expected_binary_realpath, selected_scenarios=None
):
    ledger_paths, exclusions = read_path_ledgers(_REPO_ROOT)
    required_paths = generate_required_paths(catalog)
    report = build_path_report(
        required_paths,
        ledger_paths,
        exclusions,
        artifacts_dir,
        _REPO_ROOT,
        expected_binary_realpath,
        selected_scenarios=selected_scenarios,
    )
    report_path = os.path.join(artifacts_dir, "path-coverage.json")
    write_path_report(report, report_path)
    print(render_path_summary(report))
    print(f"path coverage JSON: {report_path}")
    return report


def _run_harness_preflight():
    suite = unittest.defaultTestLoader.discover(
        start_dir=_THIS_DIR,
        pattern="test_*.py",
        top_level_dir=_THIS_DIR,
    )
    if suite.countTestCases() == 0:
        raise SystemExit("harness preflight discovered no tests")
    result = unittest.TextTestRunner(stream=sys.stderr, verbosity=1).run(suite)
    if not result.wasSuccessful():
        raise SystemExit("harness preflight failed")


def _artifact_directory(explicit):
    if explicit is None:
        return tempfile.mkdtemp(prefix="loom-e2e-results-")
    directory = os.path.abspath(explicit)
    os.makedirs(directory, exist_ok=True)
    return directory


def _run_with_artifacts(
    name,
    function,
    binary,
    artifacts_dir,
    declared_commands=(),
    timing_report_path=None,
):
    result = ScenarioResult(
        name,
        binary_realpath=os.path.realpath(binary),
        declared_commands=declared_commands,
    )
    started = time.monotonic()
    execution_elapsed = None

    def record_execution_elapsed(elapsed):
        nonlocal execution_elapsed
        execution_elapsed = elapsed

    try:
        with capture_scenario(result):
            value = run_scenario(
                function,
                binary,
                execution_elapsed_callback=record_execution_elapsed,
            )
    except Exception as error:
        elapsed = (
            time.monotonic() - started
            if execution_elapsed is None
            else execution_elapsed
        )
        result.status = "failed"
        result.error = {"type": type(error).__name__, "message": str(error)}
        timing = result.record_timing(
            "scenario_execution", elapsed, SCENARIO_EXECUTION_TIMEOUT_SECONDS
        )
        result.save(artifacts_dir)
        _write_scenario_timing(result, timing, timing_report_path)
        raise
    result.status = "passed"
    elapsed = (
        time.monotonic() - started
        if execution_elapsed is None
        else execution_elapsed
    )
    timing = result.record_timing(
        "scenario_execution", elapsed, SCENARIO_EXECUTION_TIMEOUT_SECONDS
    )
    result.save(artifacts_dir)
    _write_scenario_timing(result, timing, timing_report_path)
    return value


def _write_scenario_timing(result, timing, report_path):
    record = {
        "scenario": result.name,
        "result": result.status,
        "stage": "scenario_execution",
        **timing,
    }
    line = json.dumps(record, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    if report_path is not None:
        with open(report_path, "a", encoding="utf-8") as handle:
            handle.write(line + "\n")
    print(f"SCENARIO_TIMING {line}")


def main(argv):
    args = _parse_args(argv)
    benchmark_mode = args.benchmarks or args.benchmark_gate
    if benchmark_mode and args.only is not None:
        raise SystemExit("benchmark modes cannot be combined with --only")
    registered = all_scenarios()

    if args.list:
        for line in format_scenario_listing(registered):
            print(line)
        binary = _binary_from_arguments(args.binary)
        uncovered, unknown = _coverage_report(
            registered, commands.load_command_catalog(binary)
        )
        return 1 if uncovered or unknown else 0

    binary = _binary_from_arguments(args.binary)
    artifacts_dir = _artifact_directory(args.artifacts_dir)
    print(f"scenario artifacts: {artifacts_dir}")
    timing_report_path = None
    if args.timing_report is not None:
        timing_report_path = os.path.abspath(args.timing_report)
        os.makedirs(os.path.dirname(timing_report_path) or ".", exist_ok=True)
        with open(timing_report_path, "w", encoding="utf-8"):
            pass

    if benchmark_mode:
        _run_harness_preflight()
        measurements = {}
        benchmark_errors = []
        try:
            for name, function in benchmark_scenarios(registered).items():
                try:
                    measurements[name] = _run_with_artifacts(
                        f"benchmarks/{name}",
                        function,
                        binary,
                        artifacts_dir,
                        timing_report_path=timing_report_path,
                    )
                except Exception as error:
                    print(f"FAIL benchmarks/{name}: {error}", file=sys.stderr)
                    benchmark_errors.append(name)
        except Exception as error:
            print(f"FAIL benchmarks: {error}", file=sys.stderr)
            return 1
        report = build_benchmark_report(measurements)
        report["scenario_errors"] = benchmark_errors
        report_path = os.path.join(artifacts_dir, "benchmarks.json")
        with open(report_path, "w", encoding="utf-8") as handle:
            json.dump(report, handle, ensure_ascii=False, sort_keys=True, indent=2)
            handle.write("\n")
        print(f"PTY benchmark report: {report_path}")
        target_gate_names = {
            "startup_to_first_screen_seconds": "startup_to_first_screen",
            "open_100000_lines_5mb_seconds": "open_100000_lines_5mb",
            "input_to_redraw_p95_milliseconds": "input_to_redraw_p95",
            "d13_20k_line_key_response_milliseconds": (
                "d13_20k_line_key_response"
            ),
        }
        for metric, target in report["targets"].items():
            if metric not in report["measurements"]:
                print(f"{metric}: missing (target {target:g})")
                continue
            value = report["measurements"][metric]
            completed = report["sample_completion"].get(metric)
            if completed and not all(completed):
                samples = report["samples"].get(metric, [])
                missed_samples = [
                    sample
                    for sample, reached in zip(samples, completed)
                    if not reached
                ]
                status = (
                    "over target; first row not observed by execution deadline"
                    if any(sample > target for sample in missed_samples)
                    else "first row not observed by execution deadline"
                )
                sample_text = "; samples=" + repr(samples)
            else:
                status = (
                    "within target"
                    if report["within_targets"][target_gate_names[metric]]
                    else "over target"
                )
                sample_text = ""
            print(
                f"{metric}: {value:.3f} (target {target:g}; {status}"
                f"{sample_text})"
            )
        for metric, value in report["informational_measurements"].items():
            completed = report["informational_completion"][metric]
            status = (
                "last line observed"
                if all(completed)
                else "last line not observed before the execution deadline"
            )
            print(
                f"{metric}: {value:.3f} (informational; no threshold; {status})"
            )
        for metric in report["missing_informational_metrics"]:
            print(f"{metric}: missing (informational; no complete sample set)")
        if benchmark_errors:
            print(
                "benchmark scenarios failed; affected metrics are reported as missing: "
                + ", ".join(benchmark_errors)
            )
        failed_targets = [
            metric
            for metric, within_target in report["within_targets"].items()
            if not within_target
        ]
        if args.benchmark_gate and (failed_targets or benchmark_errors):
            details = []
            if failed_targets:
                details.append("missed targets: " + ", ".join(failed_targets))
            if benchmark_errors:
                details.append("failed scenarios: " + ", ".join(benchmark_errors))
            print("FAIL PTY performance gate: " + "; ".join(details), file=sys.stderr)
            return 1
        return 0

    selected = select_scenarios(registered, args.only)
    if not selected:
        raise SystemExit(f"--only {args.only!r} matched no scenario")

    _run_harness_preflight()
    catalog = commands.load_command_catalog(binary)
    passed = 0
    failed = 0
    for name, scenario_commands, fn in selected:
        try:
            _run_with_artifacts(
                name,
                fn,
                binary,
                artifacts_dir,
                scenario_commands,
                timing_report_path,
            )
        except Exception as error:
            failed += 1
            print(f"FAIL {name}: {error}", file=sys.stderr)
        else:
            passed += 1
            print(f"PASS {name}")

    total = len(selected)
    print(f"{passed} passed, {failed} failed, {total} total")

    uncovered, unknown = _coverage_report(selected, catalog)
    path_report = _path_coverage_report(
        catalog,
        artifacts_dir,
        os.path.realpath(binary),
        selected_scenarios={name for name, _scenario_commands, _fn in selected},
    )

    exit_code = 0
    if failed:
        exit_code = 1
    elif args.require_full_coverage or args.only is None:
        if uncovered or unknown:
            exit_code = 1
    elif unknown:
        exit_code = 1
    if args.require_path_coverage and path_report["has_failures"]:
        exit_code = 1
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
