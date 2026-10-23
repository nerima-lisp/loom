"""Collect typed runtime observations and per-scenario PTY artifacts."""

import base64
from contextlib import contextmanager
from contextvars import ContextVar
import hashlib
import json
import os
import re


_ACTIVE_RESULT = ContextVar("loom_e2e_active_result", default=None)
_ACTIVE_TRACE_LINE_COUNTER = ContextVar(
    "loom_e2e_active_trace_line_counter", default=None
)
UNSET = object()
_EFFECT_OBSERVATION_TYPES = {
    "screen_text",
    "cell_attrs",
    "cursor",
    "file_bytes",
    "external_state",
    "pty_output",
}


def _json_value(value):
    if isinstance(value, bytes):
        return {
            "encoding": "base64",
            "data": base64.b64encode(value).decode("ascii"),
            "length": len(value),
        }
    if isinstance(value, tuple):
        return [_json_value(item) for item in value]
    if isinstance(value, list):
        return [_json_value(item) for item in value]
    if isinstance(value, dict):
        return {str(key): _json_value(item) for key, item in value.items()}
    if value is None or isinstance(value, (str, int, float, bool)):
        return value
    raise TypeError(f"observation value is not JSON-safe: {type(value).__name__}")


class ScenarioResult:
    def __init__(self, name, binary_realpath=None, declared_commands=()):
        self.name = name
        self.binary_realpath = binary_realpath
        self.declared_commands = list(declared_commands)
        self.status = "running"
        self.error = None
        self.observations = []
        self.sessions = []
        self.pty_output = bytearray()
        self.trace_output = bytearray()

    def observe(
        self,
        kind,
        actual,
        expected=UNSET,
        passed=None,
        trace_lines=0,
        purpose="scenario",
        **details,
    ):
        observation = {
            "sequence": len(self.observations),
            "type": kind,
            "actual": _json_value(actual),
            "trace_lines": trace_lines,
            "purpose": purpose,
        }
        if expected is not UNSET:
            observation["expected"] = _json_value(expected)
            observation["passed"] = None if passed is None else bool(passed)
        elif passed is not None:
            observation["passed"] = bool(passed)
        for key, value in details.items():
            observation[key] = _json_value(value)
        self.observations.append(observation)
        return observation

    def add_session(self, pty_output, trace_output):
        pty_start = len(self.pty_output)
        trace_start = len(self.trace_output)
        self.pty_output.extend(pty_output)
        self.trace_output.extend(trace_output)
        self.sessions.append(
            {
                "pty_offset": pty_start,
                "pty_length": len(pty_output),
                "trace_offset": trace_start,
                "trace_length": len(trace_output),
            }
        )

    def _classification(self):
        observations = [
            item
            for item in self.observations
            if item.get("purpose") != "precondition"
        ]
        if not observations:
            return "none"
        effects = [
            item
            for item in observations
            if item["type"] in _EFFECT_OBSERVATION_TYPES
        ]
        if effects and all(
            "expected" in item and item.get("passed") is True
            for item in effects
        ):
            return "effect-verified"
        if effects:
            return "effect-unverified"
        observed_types = {item["type"] for item in observations}
        if observed_types and observed_types <= {"exit_code"}:
            return "exit-code-only"
        return "observations-only"

    def to_dict(self, artifacts):
        classification = self._classification()
        result = {
            "scenario": self.name,
            "status": self.status,
            "observation_class": classification,
            "binary_realpath": self.binary_realpath,
            "declared_commands": self.declared_commands,
            "observed_types": sorted({item["type"] for item in self.observations}),
            "observations": self.observations,
            "sessions": self.sessions,
            "artifacts": artifacts,
        }
        if self.error is not None:
            result["error"] = self.error
        return result

    def save(self, artifacts_dir):
        slug = re.sub(r"[^A-Za-z0-9._-]+", "-", self.name).strip("-._") or "scenario"
        suffix = hashlib.sha256(self.name.encode("utf-8")).hexdigest()[:10]
        scenario_dir = os.path.join(artifacts_dir, f"{slug}-{suffix}")
        os.makedirs(scenario_dir, exist_ok=True)

        pty_name = "output.pty"
        trace_name = "trace.jsonl"
        result_name = "result.json"
        with open(os.path.join(scenario_dir, pty_name), "wb") as handle:
            handle.write(self.pty_output)
        with open(os.path.join(scenario_dir, trace_name), "wb") as handle:
            handle.write(self.trace_output)

        result_path = os.path.join(scenario_dir, result_name)
        result = self.to_dict(
            {"pty": pty_name, "trace": trace_name, "result": result_name}
        )
        with open(result_path, "w", encoding="utf-8") as handle:
            json.dump(result, handle, ensure_ascii=False, sort_keys=True, indent=2)
            handle.write("\n")
        return result_path


@contextmanager
def capture_scenario(result):
    token = _ACTIVE_RESULT.set(result)
    try:
        yield result
    finally:
        _ACTIVE_RESULT.reset(token)


def current_result():
    return _ACTIVE_RESULT.get()


def set_trace_line_counter(counter):
    return _ACTIVE_TRACE_LINE_COUNTER.set(counter)


def reset_trace_line_counter(token):
    _ACTIVE_TRACE_LINE_COUNTER.reset(token)


def count_trace_lines(data):
    return data.count(b"\n")


def record_observation(
    kind, actual, expected=UNSET, passed=None, *, trace_lines=UNSET, **details
):
    result = current_result()
    if result is None:
        return None
    if trace_lines is UNSET:
        counter = _ACTIVE_TRACE_LINE_COUNTER.get()
        trace_lines = (
            count_trace_lines(result.trace_output)
            if counter is None
            else counter()
        )
    return result.observe(
        kind, actual, expected, passed, trace_lines=trace_lines, **details
    )
