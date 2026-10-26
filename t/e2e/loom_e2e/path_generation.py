"""Generate the required E2E paths from the command catalog."""

import json
from urllib.parse import quote


class CatalogError(ValueError):
    """The command catalog cannot be interpreted without dropping paths."""


_REQUIRED_FIELDS = {
    "id",
    "name",
    "owner",
    "keymap",
    "keys",
    "group",
    "mutates",
    "prompts",
    "needs-region",
    "external",
    "modes",
    "mx-eligible",
}
_PROMPT_KINDS = {"free-string", "completion", "yes-no", "numeric"}
_INVALID_PROMPT_KINDS = {"completion", "yes-no", "numeric"}
_PROMPT_CASES = ("accept", "cancel", "empty", "tab", "history")
_MUTATION_CASES = (
    ("effect", "editable-buffer", "buffer changes", ["file_bytes"]),
    ("undo", "after-one-change", "original bytes restored", ["file_bytes"]),
    ("read-only", "read-only-buffer", "rejected without byte changes", ["file_bytes"]),
    ("narrow", "narrowed-buffer", "outside range remains unchanged", ["file_bytes"]),
    ("split-window", "split-window", "both views reflect the change", ["screen_text"]),
    ("macro-replay", "macro-recording", "replay has the same effect", ["file_bytes"]),
    ("prefix-u4", "prefix-C-u-4", "specified prefix behavior is observed", ["file_bytes"]),
)

LANE_REGISTRY = {
    "core/command": "W3-1",
    "feature/lifecycle": "W3-2",
    "feature/user-init": "W3-2",
    "feature/files": "W3-3",
    "feature/buffers": "W3-3",
    "core/buffer": "W3-4",
    "renderer": "W3-4",
    "src/presentation/": "W3-4",
    "core/minibuffer": "W3-5",
    "feature/minibuffer-ui": "W3-5",
    "feature/completion": "W3-5",
    "feature/help": "W3-5",
    "feature/search": "W3-6",
    "feature/project": "W3-6",
    "feature/mode": "W3-7a",
    "feature/syntax-highlighting": "W3-7a",
    "feature/lang-lisp": "W3-7b",
    "feature/lisp-structure": "W3-7b",
    "feature/evaluation": "W3-7b",
    "feature/lang-nix": "W3-7c",
    "feature/lang-web": "W3-7d",
    "feature/lang-markup": "W3-7e",
    "feature/kill-ring": "W3-8",
    "feature/clipboard": "W3-8",
    "feature/mouse": "W3-8",
    "feature/lsp": "W3-9",
    "feature/file-tree": "W3-10",
    "feature/window": "W3-10",
    "feature/workspace": "W3-10",
    "feature/session": "W3-10",
    "feature/bookmark": "W3-10",
    "feature/register": "W3-10",
    "feature/keyboard-macro": "W3-10",
    "feature/shell": "W3-11",
    "feature/format": "W3-11",
    "feature/git": "W3-11",
    "feature/terminal": "W3-11",
    "feature/auto-save": "W3-11",
}


_FIXED_COMMANDS = {
    "forward-char",
    "delete-char",
    "undo",
    "save-buffer",
    "save-buffers-kill-terminal",
    "goto-line",
    "keyboard-quit",
    "split-window-below",
    "save-session",
    "load-session",
    "new-workspace",
    "switch-workspace",
    "execute-extended-command",
}


def _nonempty_string(value, location):
    if not isinstance(value, str) or not value.strip() or value != value.strip():
        raise CatalogError(f"{location} must be a non-empty trimmed string")
    return value


def _string_list(value, location, allow_duplicates=False):
    if not isinstance(value, list):
        raise CatalogError(f"{location} must be a list")
    normalized = [_nonempty_string(item, f"{location}[{index}]") for index, item in enumerate(value)]
    if not allow_duplicates and len(set(normalized)) != len(normalized):
        raise CatalogError(f"{location} contains duplicates")
    return normalized


def _normalize_key(key, command, index):
    location = f"catalog[{command}].keys[{index}]"
    if not isinstance(key, dict):
        raise CatalogError(f"{location} must be an object")
    keymap = _nonempty_string(key.get("keymap"), f"{location}.keymap")
    sequence = key.get("sequence")
    if not isinstance(sequence, list) or not sequence:
        raise CatalogError(f"{location}.sequence must be a non-empty list")
    normalized_sequence = []
    for step_index, step in enumerate(sequence):
        step_location = f"{location}.sequence[{step_index}]"
        if not isinstance(step, dict):
            raise CatalogError(f"{step_location} must be an object")
        modifiers = _string_list(step.get("modifiers"), f"{step_location}.modifiers")
        key_name = step.get("key")
        if not isinstance(key_name, str) or not key_name:
            raise CatalogError(f"{step_location}.key must be a non-empty string")
        normalized_sequence.append(
            {"modifiers": sorted(modifiers), "key": key_name}
        )
    return {"keymap": keymap, "sequence": normalized_sequence}


def _normalize_catalog(catalog):
    if not isinstance(catalog, list) or not catalog:
        raise CatalogError("catalog must be a non-empty JSON array")

    rows = []
    command_ids = set()
    for row_index, row in enumerate(catalog):
        if not isinstance(row, dict):
            raise CatalogError(f"catalog[{row_index}] must be an object")
        missing = _REQUIRED_FIELDS - row.keys()
        if missing:
            raise CatalogError(
                f"catalog[{row_index}] is missing fields: {', '.join(sorted(missing))}"
            )
        command_id = _nonempty_string(row["id"], f"catalog[{row_index}].id")
        if command_id in command_ids:
            raise CatalogError(f"duplicate command ID: {command_id}")
        command_ids.add(command_id)
        name = row["name"]
        if name is not None:
            _nonempty_string(name, f"catalog[{command_id}].name")
        owner = _nonempty_string(row["owner"], f"catalog[{command_id}].owner")
        lane = LANE_REGISTRY.get(owner)
        if lane is None:
            raise CatalogError(
                f"catalog[{command_id}] has unknown owner slice: {owner}"
            )
        _nonempty_string(row["keymap"], f"catalog[{command_id}].keymap")

        if row["group"] is not None:
            _nonempty_string(row["group"], f"catalog[{command_id}].group")
        for flag in ("mutates", "needs-region", "mx-eligible"):
            if type(row[flag]) is not bool:
                raise CatalogError(f"catalog[{command_id}].{flag} must be a boolean")

        prompts = _string_list(
            row["prompts"], f"catalog[{command_id}].prompts", allow_duplicates=True
        )
        unknown_prompts = set(prompts) - _PROMPT_KINDS
        if unknown_prompts:
            raise CatalogError(
                f"catalog[{command_id}] has unknown prompt kinds: {', '.join(sorted(unknown_prompts))}"
            )
        external = _string_list(row["external"], f"catalog[{command_id}].external")
        modes = _string_list(row["modes"], f"catalog[{command_id}].modes")
        keys = row["keys"]
        if not isinstance(keys, list):
            raise CatalogError(f"catalog[{command_id}].keys must be a list")
        normalized_keys = [
            _normalize_key(key, command_id, index)
            for index, key in enumerate(keys)
        ]
        normalized_keys.sort(
            key=lambda key: json.dumps(key, sort_keys=True, separators=(",", ":"))
        )
        signatures = [json.dumps(key, sort_keys=True, separators=(",", ":")) for key in normalized_keys]
        if len(set(signatures)) != len(signatures):
            raise CatalogError(f"catalog[{command_id}].keys contains duplicate sequences")

        rows.append(
            {
                "id": command_id,
                "owner": owner,
                "lane": lane,
                "keys": normalized_keys,
                "mutates": row["mutates"],
                "prompts": prompts,
                "needs-region": row["needs-region"],
                "external": external,
                "mx-eligible": row["mx-eligible"],
            }
        )

    rows.sort(key=lambda row: row["id"])
    for row in rows:
        if not row["keys"] and not row["mx-eligible"]:
            raise CatalogError(
                f"catalog[{row['id']}] has no key or M-x entry"
            )
    missing_fixed_commands = _FIXED_COMMANDS - command_ids
    if missing_fixed_commands:
        raise CatalogError(
            "catalog is missing commands required by fixed paths: "
            + ", ".join(sorted(missing_fixed_commands))
        )
    return rows


def _path(path_id, commands, rule, lane, entry, state, outcome, observe):
    return {
        "id": path_id,
        "commands": list(commands),
        "rule": rule,
        "lane": lane,
        "entry": entry,
        "state": state,
        "outcome": outcome,
        "observe": list(observe),
        "scenario": "",
    }


def _key_entry(key):
    signature = json.dumps(key, sort_keys=True, separators=(",", ":"))
    return f"key:{signature}"


def _primary_entry(row):
    if row["keys"]:
        return _key_entry(row["keys"][0])
    return "mx"


def _fixed_paths():
    paths = []
    dimensions = ("fullwidth", "combining", "emoji", "wrap", "truncate")
    operations = (
        ("move", ["forward-char"], ["cursor"]),
        ("insert", [], ["file_bytes"]),
        ("delete", ["delete-char"], ["file_bytes"]),
        ("undo", ["undo"], ["file_bytes"]),
        ("save", ["save-buffer"], ["file_bytes"]),
    )
    for dimension in dimensions:
        for operation, commands, observe in operations:
            paths.append(
                _path(
                    f"r6:text:{dimension}:{operation}",
                    commands,
                    "r6",
                    "W3-4",
                    operation,
                    f"text:{dimension}",
                    f"{operation} {dimension} text",
                    observe,
                )
            )

    paths.extend(
        [
            _path("r6:resize", [], "r6", "W3-4", "terminal-resize", "resized-terminal", "screen redraws", ["screen_text", "cursor"]),
            _path("r6:mouse", [], "r6", "W3-8", "mouse", "mouse-event", "event is handled", ["screen_text", "cursor"]),
            _path("r6:paste", [], "r6", "W3-8", "paste", "bracketed-paste", "pasted bytes are preserved", ["file_bytes"]),
            _path("r6:suspend:c-z", [], "r6", "W3-2", "C-z", "running-process", "process suspends and resumes", ["external_state"]),
            _path("r6:signal:sigterm", [], "r6", "W3-2", "SIGTERM", "running-process", "process exits and recovers state", ["external_state"]),
            _path("r6:signal:sighup", [], "r6", "W3-2", "SIGHUP", "running-process", "process exits and recovers state", ["external_state"]),
            _path("r6:signal:sigtstp-cont", [], "r6", "W3-2", "SIGTSTP then SIGCONT", "running-process", "terminal suspends and resumes", ["external_state"]),
        ]
    )

    editor_paths = (
        ("git-commit", ["save-buffer", "save-buffers-kill-terminal"], "git-commit"),
        ("interactive-rebase", ["save-buffer", "save-buffers-kill-terminal"], "git-rebase -i"),
        ("crontab", ["save-buffer", "save-buffers-kill-terminal"], "crontab-style editor"),
        ("xargs-non-tty", [], "xargs with non-TTY stdin"),
        ("plus-n", [], "+N FILE"),
        ("new-file", ["save-buffer"], "new file"),
        ("interruption", ["keyboard-quit"], "editor interruption"),
    )
    for path_name, commands, entry in editor_paths:
        paths.append(
            _path(
                f"r7:{path_name}",
                commands,
                "r7",
                "W3-2",
                entry,
                "$EDITOR invocation",
                f"{path_name} flow completes",
                ["file_bytes", "external_state"],
            )
        )

    persistence_paths = (
        ("session", ["save-session", "load-session"], "saved session"),
        ("split-windows", ["split-window-below", "save-session", "load-session"], "split windows"),
        ("workspace", ["new-workspace", "switch-workspace", "save-session", "load-session"], "workspace"),
        ("history", ["execute-extended-command"], "command history"),
    )
    for path_name, commands, state in persistence_paths:
        paths.append(
            _path(
                f"r8:{path_name}",
                commands,
                "r8",
                "W3-10",
                "new-process",
                f"{state} saved before process exit",
                f"{state} is restored after process restart",
                ["screen_text", "external_state"],
            )
        )
    return paths


def generate_required_paths(catalog):
    """Return normalized R1–R8 path dictionaries for a catalog JSON array."""
    rows = _normalize_catalog(catalog)
    paths = []

    for row in rows:
        command_id = row["id"]
        lane = row["lane"]
        for key in row["keys"]:
            signature = json.dumps(key, sort_keys=True, separators=(",", ":"))
            paths.append(
                _path(
                    f"r1:{command_id}:key:{quote(signature, safe='')}",
                    [command_id],
                    "r1",
                    lane,
                    f"key:{signature}",
                    "default",
                    "command runs from its key sequence",
                    ["screen_text"],
                )
            )
        if row["mx-eligible"]:
            paths.append(
                _path(
                    f"r1:{command_id}:mx",
                    [command_id],
                    "r1",
                    lane,
                    "mx",
                    "default",
                    "command runs from M-x",
                    ["screen_text"],
                )
            )

        for prompt_index, prompt in enumerate(row["prompts"], start=1):
            cases = list(_PROMPT_CASES)
            if prompt in _INVALID_PROMPT_KINDS:
                cases.append("invalid")
            for case in cases:
                paths.append(
                    _path(
                        f"r2:{command_id}:prompt-{prompt_index}:{prompt}:{case}",
                        [command_id],
                        "r2",
                        lane,
                        f"{_primary_entry(row)};prompt:{prompt_index}:{prompt}",
                        f"prompt:{prompt}",
                        case,
                        ["screen_text"],
                    )
                )

        if row["mutates"]:
            for case, state, outcome, observe in _MUTATION_CASES:
                paths.append(
                    _path(
                        f"r3:{command_id}:{case}",
                        [command_id],
                        "r3",
                        lane,
                        "macro" if case == "macro-replay" else _primary_entry(row),
                        state,
                        outcome,
                        observe,
                    )
                )

        if row["needs-region"]:
            for state, outcome in (
                ("region-present", "command operates on region"),
                ("region-absent", "command handles missing region"),
            ):
                paths.append(
                    _path(
                        f"r4:{command_id}:{state}",
                        [command_id],
                        "r4",
                        lane,
                        _primary_entry(row),
                        state,
                        outcome,
                        ["file_bytes", "screen_text"],
                    )
                )

        for tool in sorted(row["external"]):
            for outcome in ("success", "missing", "nonzero", "interrupted"):
                paths.append(
                    _path(
                        f"r5:{command_id}:{quote(tool, safe='')}:{outcome}",
                        [command_id],
                        "r5",
                        lane,
                        _primary_entry(row),
                        f"tool:{tool}",
                        outcome,
                        ["external_state"],
                    )
                )

    paths.extend(_fixed_paths())
    ids = [path["id"] for path in paths]
    if len(ids) != len(set(ids)):
        raise CatalogError("generated path IDs are not unique")
    return paths
