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
    {
        "screen_text",
        "cell_attrs",
        "cursor",
        "file_bytes",
        "external_state",
        "pty_output",
    }
)
_OBSERVATION_CLASSES = (
    "none",
    "effect-verified",
    "effect-unverified",
    "exit-code-only",
    "observations-only",
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

    commands = []
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
                    entry = record.get("entry")
                    if "entry" in record and not isinstance(entry, str):
                        return None, f"trace line {line_number} has an invalid entry"
                    commands.append((command, route, line_number, entry))
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


def _entry_trace_identity(entry):
    if not isinstance(entry, str):
        return None
    route_entry = entry.strip().split(";prompt:", 1)[0]
    prefix, separator, payload = route_entry.partition(":")
    if prefix.lower() == "key" and separator and payload:
        return route_entry
    return None


def _observe_types(path):
    return {
        observation.strip().lower().removeprefix(":")
        for observation in _as_list(path.get("observe"))
        if isinstance(observation, str) and observation.strip()
    }


def _observation_class(observations):
    if not isinstance(observations, list):
        observations = []
    observed = [
        observation
        for observation in observations
        if isinstance(observation, Mapping)
        and observation.get("purpose") != "precondition"
    ]
    if not observed:
        return "none"
    effects = [
        observation
        for observation in observed
        if observation.get("type") in _EFFECT_TYPES
    ]
    if effects:
        if all(
            "expected" in observation and observation.get("passed") is True
            for observation in effects
        ):
            return "effect-verified"
        return "effect-unverified"
    observed_types = {observation.get("type") for observation in observed}
    if observed_types and observed_types <= {"exit_code"}:
        return "exit-code-only"
    return "observations-only"


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


def _scenario_observation_counts(artifacts_by_scenario, selected_scenarios):
    counts = {name: 0 for name in _OBSERVATION_CLASSES}
    counts.update(missing=0, invalid=0)
    if selected_scenarios is None:
        scenario_names = sorted(
            name for name in artifacts_by_scenario if name is not None
        )
    else:
        scenario_names = sorted(selected_scenarios)

    for scenario in scenario_names:
        matches = artifacts_by_scenario.get(scenario, [])
        if not matches:
            counts["missing"] += 1
            continue
        if len(matches) != 1 or matches[0][1] is None:
            counts["invalid"] += 1
            continue
        result = matches[0][1]
        actual = result.get("observation_class")
        computed = _observation_class(result.get("observations"))
        if actual != computed or actual not in _OBSERVATION_CLASSES:
            counts["invalid"] += 1
        else:
            counts[actual] += 1

    if selected_scenarios is None:
        counts["invalid"] += len(artifacts_by_scenario.get(None, []))
    return counts


def _classify_path(
    required,
    ledger,
    exclusion,
    artifacts_by_scenario,
    artifacts_dir,
    expected_binary_realpath,
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

    targets = [
        command.strip()
        for command in item["commands"]
        if isinstance(command, str) and command.strip()
    ]
    actual_binary_realpath = result.get("binary_realpath")
    if (
        not isinstance(actual_binary_realpath, str)
        or not actual_binary_realpath
        or not isinstance(expected_binary_realpath, str)
        or not expected_binary_realpath
    ):
        item["status"] = "mismatch"
        item["reason"] = "scenario result does not identify the expected binary"
        return item
    try:
        actual_binary = Path(actual_binary_realpath)
        expected_binary = Path(expected_binary_realpath)
        binary_matches = (
            actual_binary.is_absolute()
            and expected_binary.is_absolute()
            and actual_binary.resolve() == expected_binary.resolve()
        )
    except (OSError, RuntimeError):
        binary_matches = False
    if not binary_matches:
        item["status"] = "mismatch"
        item["reason"] = "scenario result used a different binary"
        return item

    declared_commands = result.get("declared_commands")
    if not isinstance(declared_commands, list) or any(
        not isinstance(command, str) or not command
        for command in declared_commands
    ):
        item["status"] = "mismatch"
        item["reason"] = "scenario result has invalid declared_commands"
        return item
    missing_declared = sorted(set(targets) - set(declared_commands))
    if missing_declared:
        item["status"] = "mismatch"
        item["reason"] = "scenario does not declare every generated target command"
        item["missing_declared_commands"] = missing_declared
        return item

    scenario_status = result.get("status")
    if scenario_status != "passed":
        item["status"] = "mismatch"
        item["reason"] = f"scenario result status is {scenario_status!r}"
        return item

    observations = result.get("observations")
    if not isinstance(observations, list):
        observations = []
    actual_observation_class = result.get("observation_class")
    computed_observation_class = _observation_class(observations)
    item["scenario_observation_class"] = actual_observation_class
    if actual_observation_class != computed_observation_class:
        item["status"] = "mismatch"
        item["reason"] = (
            "scenario observation_class does not match its observations"
        )
        return item
    if actual_observation_class not in _OBSERVATION_CLASSES:
        item["status"] = "mismatch"
        item["reason"] = "scenario has an unknown observation_class"
        return item
    if actual_observation_class != "effect-verified":
        item["status"] = "no-observation"
        item["reason"] = (
            "scenario observation_class is "
            f"{actual_observation_class!r}, not 'effect-verified'"
        )
        return item

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

    if not targets:
        item["status"] = "no-trace"
        item["reason"] = "generated path has no traceable target command"
        return item

    trace_commands, trace_error = _read_trace(result_path, result, artifacts_dir)
    if trace_error is not None:
        item["status"] = "no-trace"
        item["reason"] = trace_error
        item["missing_commands"] = targets
        return item

    expected_route = _entry_route(generated_entry)
    expected_entry = _entry_trace_identity(generated_entry)
    effect_observations = [
        observation
        for observation in expected_effects
        if isinstance(observation.get("trace_lines"), int)
        and not isinstance(observation.get("trace_lines"), bool)
        and observation.get("trace_lines") >= 0
    ]
    if len(effect_observations) != len(expected_effects):
        item["status"] = "no-trace"
        item["reason"] = "effect observation has an invalid trace_lines count"
        item["missing_commands"] = targets
        return item

    def _before_observation(observation):
        trace_lines = observation["trace_lines"]
        return all(
            any(
                traced_command == command
                and (expected_route is None or route == expected_route)
                and (expected_entry is None or entry == expected_entry)
                and line_number <= trace_lines
                for traced_command, route, line_number, entry in trace_commands
            )
            for command in set(targets)
        )

    if not any(_before_observation(observation) for observation in effect_observations):
        item["status"] = "no-trace"
        item["reason"] = (
            "target command trace rows do not precede a matching effect observation"
        )
        item["missing_commands"] = sorted(
            command
            for command in set(targets)
            if not any(
                traced_command == command
                and (expected_route is None or route == expected_route)
                and (expected_entry is None or entry == expected_entry)
                and any(
                    line_number <= observation["trace_lines"]
                    for observation in effect_observations
                )
                for traced_command, route, line_number, entry in trace_commands
            )
        )
        return item

    item["status"] = "pass"
    item["failed"] = False
    item["reason"] = (
        "the expected binary, declared commands, prior trace rows, and effect "
        "observation are verified"
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
    expected_binary_realpath,
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
            expected_binary_realpath,
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
            "scenario_observation_class": item.get("scenario_observation_class"),
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
        "scenario_observation_classes": _scenario_observation_counts(
            artifacts_by_scenario, selected
        ),
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
    lines.append("Scenario observation classes:")
    for name, count in report_dict["scenario_observation_classes"].items():
        if count:
            lines.append(f"  {name}: {count}")
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
