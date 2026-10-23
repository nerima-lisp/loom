"""Classify required command paths against ledger entries and E2E artifacts."""

import json
from collections import defaultdict
from collections.abc import Mapping
from pathlib import Path


_STATUSES = (
    "not-in-ledger",
    "no-result",
    "no-trace",
    "no-observation",
    "mismatch",
    "pass",
    "excluded",
)
_EFFECT_TYPES = frozenset(
    {"screen_text", "cell_attrs", "cursor", "file_bytes", "external_state"}
)


class _DuplicateJsonMember(ValueError):
    pass


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise _DuplicateJsonMember(f"duplicate JSON object member {key!r}")
        result[key] = value
    return result


def _as_list(value):
    if value is None:
        return []
    if isinstance(value, (list, tuple)):
        return list(value)
    if isinstance(value, str):
        return [value]
    return []


def _evidence_error(evidence, repo_root):
    if not isinstance(evidence, str) or ":" not in evidence:
        return "evidence must use file:line format"
    relative, line_text = evidence.rsplit(":", 1)
    if not relative or not line_text.isdecimal() or int(line_text) < 1:
        return "evidence must use file:line format with a positive line number"

    relative_path = Path(relative)
    if relative_path.is_absolute() or ".." in relative_path.parts:
        return "evidence path must be inside the repository"

    root = Path(repo_root).resolve()
    evidence_path = (root / relative_path).resolve()
    try:
        evidence_path.relative_to(root)
    except ValueError:
        return "evidence path must be inside the repository"
    if not evidence_path.is_file():
        return "evidence file does not exist"

    target_line = int(line_text)
    try:
        with evidence_path.open("rb") as handle:
            for number, _line in enumerate(handle, 1):
                if number == target_line:
                    return None
    except OSError:
        return "evidence file cannot be read"
    return "evidence line does not exist"


def _load_results(artifacts_dir):
    by_scenario = defaultdict(list)
    root = Path(artifacts_dir)
    if not root.is_dir():
        return by_scenario

    for result_path in sorted(root.rglob("result.json")):
        try:
            with result_path.open(encoding="utf-8") as handle:
                result = json.load(handle, object_pairs_hook=_unique_object)
        except (
            OSError,
            UnicodeError,
            json.JSONDecodeError,
            _DuplicateJsonMember,
        ) as error:
            by_scenario[None].append((result_path, None, str(error)))
            continue
        if isinstance(result, Mapping) and isinstance(result.get("scenario"), str):
            by_scenario[result["scenario"]].append((result_path, result, None))
    return by_scenario


def _read_trace(result_path, result, artifacts_dir):
    artifacts = result.get("artifacts")
    trace_name = artifacts.get("trace") if isinstance(artifacts, Mapping) else None
    if not isinstance(trace_name, str) or not trace_name:
        trace_name = "trace.jsonl"

    trace_path = (result_path.parent / trace_name).resolve()
    scenario_root = result_path.parent.resolve()
    try:
        trace_path.relative_to(scenario_root)
    except ValueError:
        return None, "trace artifact path escapes the result scenario directory"
    if not trace_path.is_file():
        return None, "trace.jsonl artifact does not exist"

    commands = set()
    try:
        with trace_path.open(encoding="utf-8") as handle:
            for line_number, line in enumerate(handle, 1):
                if not line.strip():
                    continue
                record = json.loads(line, object_pairs_hook=_unique_object)
                if not isinstance(record, Mapping):
                    return None, f"trace line {line_number} is not a JSON object"
                command = record.get("command")
                if isinstance(command, str) and command:
                    route = record.get("route")
                    if route is not None and not isinstance(route, str):
                        return None, f"trace line {line_number} has an invalid route"
                    commands.add((command, route))
    except (
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        _DuplicateJsonMember,
    ) as error:
        return None, f"trace.jsonl cannot be read: {error}"
    return commands, None


def _entry_route(entry):
    if not isinstance(entry, str):
        return None
    normalized = entry.strip().lower()
    route_entry = normalized.split(";prompt:", 1)[0]
    if route_entry == "key" or route_entry.startswith("key:"):
        return "key"
    if route_entry in {"mx", "m-x"}:
        return "mx"
    if route_entry == "macro":
        return "macro"
    if route_entry in {"mouse", "paste"}:
        return route_entry
    return None


def _observe_types(path):
    return {
        observation.strip().lower().removeprefix(":")
        for observation in _as_list(path.get("observe"))
        if isinstance(observation, str) and observation.strip()
    }


def _non_empty(value):
    if isinstance(value, str):
        return bool(value.strip())
    try:
        return len(value) > 0
    except TypeError:
        return bool(value)


def _matches(observation):
    if "actual" not in observation:
        return False
    actual = observation.get("actual")
    expected = observation["expected"]
    kind = observation.get("type")

    if kind == "cell_attrs":
        return (
            isinstance(actual, Mapping)
            and isinstance(expected, Mapping)
            and bool(expected)
            and all(actual.get(key) == value for key, value in expected.items())
        )

    mode = observation.get("match", "exact")
    if mode == "exact":
        return actual == expected
    if mode == "contains":
        try:
            return expected in actual
        except TypeError:
            return False
    if mode == "not_contains":
        try:
            return expected not in actual
        except TypeError:
            return False
    if mode == "starts_with":
        return (
            isinstance(actual, str)
            and isinstance(expected, str)
            and actual.startswith(expected)
        )
    if mode == "ends_with":
        return (
            isinstance(actual, str)
            and isinstance(expected, str)
            and actual.endswith(expected)
        )
    if mode == "changed":
        return actual != expected
    if mode == "non_empty":
        return _non_empty(actual)
    if mode == "subset":
        return (
            isinstance(actual, Mapping)
            and isinstance(expected, Mapping)
            and bool(expected)
            and all(actual.get(key) == value for key, value in expected.items())
        )
    return False


def _counts(items):
    result = {status: 0 for status in _STATUSES}
    result["total"] = len(items)
    result["failures"] = 0
    for item in items:
        result[item["status"]] += 1
        result["failures"] += bool(item["failed"])
    return result


def _group_counts(items, field):
    groups = defaultdict(list)
    for item in items:
        groups[item.get(field) or "unassigned"].append(item)
    return {name: _counts(group) for name, group in sorted(groups.items())}


def _classify_path(
    required,
    ledger,
    exclusion,
    artifacts_by_scenario,
    artifacts_dir,
    selected_scenarios,
):
    item = {
        "id": required.get("id", ""),
        "rule": required.get("rule") or "unassigned",
        "lane": required.get("lane") or "unassigned",
        "commands": _as_list(required.get("commands")),
        "scenario": ledger.get("scenario") if ledger else "",
        "status": "not-in-ledger",
        "failed": True,
        "reason": "generated path has no matching ledger entry",
        "failure_reasons": [],
    }

    exclusion_error = None
    if exclusion is not None:
        exclusion_error = _evidence_error(
            exclusion.get("evidence"), exclusion.get("repo_root")
        )
        if exclusion_error is None:
            item.update(
                status="excluded",
                failed=False,
                reason=exclusion.get("reason") or "excluded by ledger",
            )
            item["evidence"] = exclusion.get("evidence")
            return item
        item["failure_reasons"].append(
            f"invalid exclusion evidence: {exclusion_error}"
        )

    if ledger is None:
        if exclusion_error is not None:
            item["reason"] = "generated path has no ledger entry; exclusion evidence is invalid"
        item["failed"] = True
        return item

    scenario = ledger.get("scenario")
    item["scenario"] = scenario or ""
    item["status"] = "no-result"
    item["reason"] = "ledger scenario has no matching result.json artifact"
    item["failed"] = True
    if not isinstance(scenario, str) or not scenario:
        if exclusion_error is not None:
            item["failure_reasons"].append("ledger scenario name is missing")
        else:
            item["reason"] = "ledger entry has no scenario name"
        return item
    if selected_scenarios is not None and scenario not in selected_scenarios:
        item["reason"] = "ledger scenario was not selected for this run"
        return item

    matches = artifacts_by_scenario.get(scenario, [])
    if len(matches) != 1:
        if len(matches) > 1:
            item["status"] = "mismatch"
            item["reason"] = "multiple result.json artifacts match the ledger scenario"
        return item
    result_path, result, load_error = matches[0]
    if result is None:
        item["reason"] = f"result.json cannot be read: {load_error}"
        return item

    generated_entry = required.get("entry")
    ledger_entry = ledger.get("entry")
    if generated_entry != ledger_entry:
        item["status"] = "mismatch"
        item["reason"] = "generated path and ledger entry do not match"
        return item

    trace_commands, trace_error = _read_trace(result_path, result, artifacts_dir)
    targets = [
        command.strip()
        for command in item["commands"]
        if isinstance(command, str) and command.strip()
    ]
    expected_route = _entry_route(generated_entry)
    missing_commands = (
        sorted(
            command
            for command in set(targets)
            if not any(
                traced_command == command
                and (expected_route is None or route == expected_route)
                for traced_command, route in trace_commands
            )
        )
        if trace_commands is not None
        else targets
    )
    if not targets or trace_error is not None or missing_commands:
        item["status"] = "no-trace"
        item["reason"] = trace_error or (
            (
                "trace.jsonl does not contain every target command on route "
                f"{expected_route!r}: "
                if expected_route is not None
                else "trace.jsonl does not contain every target command: "
            )
            + ", ".join(missing_commands)
            if missing_commands
            else "generated path has no traceable target command"
        )
        item["missing_commands"] = missing_commands
        return item

    observations = result.get("observations")
    if not isinstance(observations, list):
        observations = []
    generated_observe = _observe_types(required)
    ledger_observe = _observe_types(ledger)
    allowed_observations = generated_observe & ledger_observe
    effect_observations = [
        observation
        for observation in observations
        if isinstance(observation, Mapping)
        and observation.get("purpose") != "precondition"
        and observation.get("type") in _EFFECT_TYPES
        and observation.get("type") in allowed_observations
    ]
    expected_effects = [
        observation for observation in effect_observations if "expected" in observation
    ]
    if not expected_effects:
        item["status"] = "no-observation"
        item["reason"] = (
            "scenario has no non-precondition effect observation "
            "with an expected value"
        )
        return item

    mismatches = [
        {
            "type": observation.get("type"),
            "match": observation.get("match", "exact"),
            "expected": observation.get("expected"),
            "actual": observation.get("actual"),
        }
        for observation in expected_effects
        if not _matches(observation)
    ]
    if mismatches:
        item["status"] = "mismatch"
        item["reason"] = "one or more expected effect observations do not match"
        item["mismatches"] = mismatches
        return item

    scenario_status = result.get("status")
    if scenario_status != "passed":
        item["status"] = "mismatch"
        item["reason"] = f"scenario result status is {scenario_status!r}"
        return item

    item["status"] = "pass"
    item["failed"] = False
    item["reason"] = (
        "all target commands are traced and an expected effect observation matches"
    )
    if exclusion_error is not None:
        item["failed"] = True
        item["failure_reasons"].append(
            f"invalid exclusion evidence: {exclusion_error}"
        )
    return item


def build_report(
    required_paths,
    ledger_paths,
    exclusions,
    artifacts_dir,
    repo_root,
    selected_scenarios=None,
):
    """Return path classifications, rollups, and failure state as JSON-safe data."""
    ledger_by_id = {path.get("id"): path for path in ledger_paths}
    exclusions_by_id = defaultdict(list)
    for exclusion in exclusions:
        exclusions_by_id[exclusion.get("id")].append(exclusion)
    for entries in exclusions_by_id.values():
        if len(entries) > 1:
            entries[:] = [
                {
                    **entries[0],
                    "evidence": None,
                    "reason": "multiple exclusions declare the same path ID",
                    "repo_root": repo_root,
                }
            ]
        else:
            entries[0] = {**entries[0], "repo_root": repo_root}

    artifacts_by_scenario = _load_results(artifacts_dir)
    selected = None if selected_scenarios is None else set(selected_scenarios)
    paths = []
    for required in required_paths:
        path_id = required.get("id")
        matching_ledger = ledger_by_id.get(path_id)
        exclusions_for_id = exclusions_by_id.get(path_id, [])
        exclusion = exclusions_for_id[0] if exclusions_for_id else None
        item = _classify_path(
            required,
            matching_ledger,
            exclusion,
            artifacts_by_scenario,
            artifacts_dir,
            selected,
        )
        paths.append(item)

    counts = _counts(paths)
    missing_paths = [
        {
            "id": item["id"],
            "rule": item["rule"],
            "lane": item["lane"],
            "commands": item["commands"],
            "scenario": item["scenario"],
            "status": item["status"],
            "reason": item["reason"],
            "failure_reasons": item["failure_reasons"],
        }
        for item in paths
        if item["failed"]
    ]
    report = {
        "paths": paths,
        "counts": counts,
        "by_rule": _group_counts(paths, "rule"),
        "by_lane": _group_counts(paths, "lane"),
        "missing_paths": missing_paths,
        "has_failures": any(item["failed"] for item in paths),
    }
    report["summary"] = render_summary(report)
    return report


def render_summary(report_dict):
    counts = report_dict["counts"]
    lines = [
        "Path coverage: "
        f"{counts['pass']} pass, {counts['excluded']} excluded, "
        f"{counts['failures']} failing of {counts['total']} required paths."
    ]
    lines.append("By rule:")
    for name, group in report_dict["by_rule"].items():
        lines.append(
            f"  {name}: pass={group['pass']} excluded={group['excluded']} "
            f"failures={group['failures']} total={group['total']}"
        )
    lines.append("By lane:")
    for name, group in report_dict["by_lane"].items():
        lines.append(
            f"  {name}: pass={group['pass']} excluded={group['excluded']} "
            f"failures={group['failures']} total={group['total']}"
        )
    if report_dict["missing_paths"]:
        lines.append("Missing or failing paths:")
        for item in report_dict["missing_paths"]:
            lines.append(
                f"  {item['id']} [{item['rule']} / {item['lane']}] "
                f"{item['status']}: {item['reason']}"
            )
            for reason in item["failure_reasons"]:
                lines.append(f"    failure: {reason}")
    return "\n".join(lines)


def write_report(report_dict, destination_path):
    destination = Path(destination_path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("w", encoding="utf-8") as handle:
        json.dump(report_dict, handle, ensure_ascii=False, sort_keys=True, indent=2)
        handle.write("\n")
