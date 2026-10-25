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
import unittest

_THIS_DIR = os.path.dirname(os.path.abspath(__file__))
if _THIS_DIR not in sys.path:
    sys.path.insert(0, _THIS_DIR)

from loom_e2e import commands  # noqa: E402
from loom_e2e.benchmarks import (  # noqa: E402
    benchmark_scenarios,
    build_benchmark_report,
)
from loom_e2e.deadline import run_scenario  # noqa: E402
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
        "--benchmarks",
        action="store_true",
        help="report PTY startup, large-file open, and input-to-redraw measurements",
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
    name, function, binary, artifacts_dir, declared_commands=()
):
    result = ScenarioResult(
        name,
        binary_realpath=os.path.realpath(binary),
        declared_commands=declared_commands,
    )
    try:
        with capture_scenario(result):
            value = run_scenario(function, binary)
    except Exception as error:
        result.status = "failed"
        result.error = {"type": type(error).__name__, "message": str(error)}
        result.save(artifacts_dir)
        raise
    result.status = "passed"
    result.save(artifacts_dir)
    return value


def main(argv):
    args = _parse_args(argv)
    if args.benchmarks and args.only is not None:
        raise SystemExit("--benchmarks cannot be combined with --only")
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

    if args.benchmarks:
        _run_harness_preflight()
        measurements = {}
        try:
            for name, function in benchmark_scenarios(registered).items():
                try:
                    measurements[name] = _run_with_artifacts(
                        f"benchmarks/{name}", function, binary, artifacts_dir
                    )
                except Exception as error:
                    print(f"FAIL benchmarks/{name}: {error}", file=sys.stderr)
                    return 1
        except Exception as error:
            print(f"FAIL benchmarks: {error}", file=sys.stderr)
            return 1
        report = build_benchmark_report(measurements)
        report_path = os.path.join(artifacts_dir, "benchmarks.json")
        with open(report_path, "w", encoding="utf-8") as handle:
            json.dump(report, handle, ensure_ascii=False, sort_keys=True, indent=2)
            handle.write("\n")
        print(f"PTY benchmark report: {report_path}")
        for metric, value in report["measurements"].items():
            target = report["targets"][metric]
            status = "within target" if report["within_targets"][
                {
                    "startup_to_first_screen_seconds": "startup_to_first_screen",
                    "open_100000_lines_5mb_seconds": "open_100000_lines_5mb",
                    "input_to_redraw_p95_milliseconds": "input_to_redraw_p95",
                    "d13_20k_line_key_response_milliseconds": (
                        "d13_20k_line_key_response"
                    ),
                }[metric]
            ] else "over target"
            print(f"{metric}: {value:.3f} (target {target:g}; {status})")
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
                name, fn, binary, artifacts_dir, scenario_commands
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
