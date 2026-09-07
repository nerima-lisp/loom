#!/usr/bin/env python3
"""Entry point for loom's PTY end-to-end suite.

Exercises the built loom executable through a real Unix PTY, reconstructing
the terminal screen with pyte so scenarios can assert on rendered state
instead of raw-byte substrings and fixed sleeps.
"""

import argparse
import os
import sys

_THIS_DIR = os.path.dirname(os.path.abspath(__file__))
if _THIS_DIR not in sys.path:
    sys.path.insert(0, _THIS_DIR)

from loom_e2e import commands  # noqa: E402
from loom_e2e.registry import all_scenarios, covered_commands  # noqa: E402
import scenarios  # noqa: E402,F401  (registers every @scenario)


_REPO_ROOT = os.path.abspath(os.path.join(_THIS_DIR, "..", ".."))


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
    parser.add_argument("--list", action="store_true", help="list scenario names and exit")
    parser.add_argument(
        "--require-full-coverage", action="store_true",
        help="exit 1 when a registered command-spec is not exercised by any scenario",
    )
    return parser.parse_args(argv)


def main(argv):
    args = _parse_args(argv)
    registered = all_scenarios()

    if args.list:
        for name, scenario_commands, _fn in registered:
            print(f"{name}\tcommands={','.join(scenario_commands) or '(none)'}")
        return 0

    binary = _binary_from_arguments(args.binary)
    selected = [
        entry for entry in registered
        if args.only is None or args.only in entry[0]
    ]
    if not selected:
        raise SystemExit(f"--only {args.only!r} matched no scenario")

    passed = 0
    failed = 0
    for name, _scenario_commands, fn in selected:
        try:
            fn(binary)
        except (AssertionError, OSError, TimeoutError) as error:
            failed += 1
            print(f"FAIL {name}: {error}", file=sys.stderr)
        else:
            passed += 1
            print(f"PASS {name}")

    total = len(selected)
    print(f"{passed} passed, {failed} failed, {total} total")

    all_command_names = commands.parse_command_names(_REPO_ROOT)
    covered = covered_commands() & set(all_command_names)
    print(f"commands covered: {len(covered)} / {len(all_command_names)}")

    if failed:
        return 1
    if args.require_full_coverage and len(covered) < len(all_command_names):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
