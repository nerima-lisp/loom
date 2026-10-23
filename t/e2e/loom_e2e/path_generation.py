"""Generate the required E2E paths from the command catalog."""

import json
import re
from urllib.parse import quote


class CatalogError(ValueError):
    """The command catalog cannot be interpreted without dropping paths."""


_REQUIRED_FIELDS = {
    "name",
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

_W3_1 = {"universal-argument", "execute-extended-command"}
_W3_2 = {"keyboard-quit", "save-buffers-kill-terminal"}
_W3_3 = {"find-file", "save-buffer", "write-file", "recent-file", "toggle-read-only"}
_W3_7A = {"set-major-mode", "indent-for-tab-command", "comment-line"}
_W3_8 = {
    "kill-line",
    "kill-word",
    "backward-kill-word",
    "kill-region",
    "kill-ring-save",
    "yank",
    "yank-pop",
}
_W3_10 = {
    "other-window",
    "delete-window",
    "delete-other-windows",
    "switch-to-buffer",
    "kill-buffer",
    "new-workspace",
    "switch-workspace",
    "kill-workspace",
    "next-workspace",
    "previous-workspace",
    "save-session",
    "load-session",
    "set-bookmark",
    "jump-to-bookmark",
    "delete-bookmark",
    "list-bookmarks",
    "copy-to-register",
    "insert-register",
    "point-to-register",
    "jump-to-register",
    "start-kbd-macro",
    "end-kbd-macro",
    "call-last-kbd-macro",
    "toggle-file-tree",
}
_W3_11 = {
    "pipe-command",
    "terminal",
    "terminal-stop",
    "format-current-buffer",
    "format-on-save-mode",
    "set-format-command",
    "auto-save-mode",
    "toggle-auto-save",
    "auto-save-current-buffer",
}
_W3_4 = {
    "forward-char",
    "backward-char",
    "next-line",
    "previous-line",
    "forward-word",
    "backward-word",
    "move-beginning-of-line",
    "move-end-of-line",
    "beginning-of-buffer",
    "end-of-buffer",
    "scroll-up-command",
    "scroll-down-command",
    "goto-line",
    "delete-char",
    "delete-backward-char",
    "newline",
    "open-line",
    "toggle-truncate-lines",
    "set-mark-command",
    "exchange-point-and-mark",
    "mark-whole-buffer",
    "narrow-to-region",
    "widen",
    "undo",
    "redo",
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
    names = set()
    for row_index, row in enumerate(catalog):
        if not isinstance(row, dict):
            raise CatalogError(f"catalog[{row_index}] must be an object")
        missing = _REQUIRED_FIELDS - row.keys()
        if missing:
            raise CatalogError(
                f"catalog[{row_index}] is missing fields: {', '.join(sorted(missing))}"
            )
        name = _nonempty_string(row["name"], f"catalog[{row_index}].name")
        if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", name):
            raise CatalogError(f"catalog[{row_index}].name is not a command identifier: {name!r}")
        if name in names:
            raise CatalogError(f"duplicate command name: {name}")
        names.add(name)

        if row["group"] is not None:
            _nonempty_string(row["group"], f"catalog[{name}].group")
        for flag in ("mutates", "needs-region", "mx-eligible"):
            if type(row[flag]) is not bool:
                raise CatalogError(f"catalog[{name}].{flag} must be a boolean")

        prompts = _string_list(
            row["prompts"], f"catalog[{name}].prompts", allow_duplicates=True
        )
        unknown_prompts = set(prompts) - _PROMPT_KINDS
        if unknown_prompts:
            raise CatalogError(
                f"catalog[{name}] has unknown prompt kinds: {', '.join(sorted(unknown_prompts))}"
            )
        external = _string_list(row["external"], f"catalog[{name}].external")
        modes = _string_list(row["modes"], f"catalog[{name}].modes")
        keys = row["keys"]
        if not isinstance(keys, list):
            raise CatalogError(f"catalog[{name}].keys must be a list")
        normalized_keys = [_normalize_key(key, name, index) for index, key in enumerate(keys)]
        normalized_keys.sort(
            key=lambda key: json.dumps(key, sort_keys=True, separators=(",", ":"))
        )
        signatures = [json.dumps(key, sort_keys=True, separators=(",", ":")) for key in normalized_keys]
        if len(set(signatures)) != len(signatures):
            raise CatalogError(f"catalog[{name}].keys contains duplicate sequences")

        rows.append(
            {
                "name": name,
                "keys": normalized_keys,
                "mutates": row["mutates"],
                "prompts": prompts,
                "needs-region": row["needs-region"],
                "external": external,
                "mx-eligible": row["mx-eligible"],
            }
        )

    rows.sort(key=lambda row: row["name"])
    for row in rows:
        row["lane"] = _command_lane(row["name"])
        if not row["keys"] and not row["mx-eligible"]:
            raise CatalogError(
                f"catalog[{row['name']}] has no key or M-x entry"
            )
    missing_fixed_commands = _FIXED_COMMANDS - names
    if missing_fixed_commands:
        raise CatalogError(
            "catalog is missing commands required by fixed paths: "
            + ", ".join(sorted(missing_fixed_commands))
        )
    return rows


def _command_lane(name):
    if name in _W3_1:
        return "W3-1"
    if name in _W3_2 or name.startswith("lifecycle-"):
        return "W3-2"
    if name in _W3_3:
        return "W3-3"
    if name == "help":
        return "W3-5"
    if name.startswith(("isearch-", "search-", "project-")) or name == "replace-string":
        return "W3-6"
    if name in _W3_7A:
        return "W3-7a"
    if (
        name.startswith("eval-")
        or name.endswith(("-sexp", "-list"))
        or name in {"wrap-round", "splice-sexp", "raise-sexp"}
    ):
        return "W3-7b"
    if name in _W3_8:
        return "W3-8"
    if name.startswith("lsp-"):
        return "W3-9"
    if name in _W3_10 or name.startswith("file-tree-") or name.startswith("split-window-"):
        return "W3-10"
    if (
        name in _W3_11
        or name.startswith(("git-", "terminal-", "format-", "auto-save-"))
        or name == "terminal"
    ):
        return "W3-11"
    if name in _W3_4:
        return "W3-4"
    raise CatalogError(f"no lane mapping for catalog command: {name}")


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
        name = row["name"]
        lane = row["lane"]
        for key in row["keys"]:
            signature = json.dumps(key, sort_keys=True, separators=(",", ":"))
            paths.append(
                _path(
                    f"r1:{name}:key:{quote(signature, safe='')}",
                    [name],
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
                    f"r1:{name}:mx",
                    [name],
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
                        f"r2:{name}:prompt-{prompt_index}:{prompt}:{case}",
                        [name],
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
                        f"r3:{name}:{case}",
                        [name],
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
                        f"r4:{name}:{state}",
                        [name],
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
                        f"r5:{name}:{quote(tool, safe='')}:{outcome}",
                        [name],
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
