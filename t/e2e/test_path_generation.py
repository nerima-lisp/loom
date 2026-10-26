import copy
import unittest

from loom_e2e.path_generation import (
    LANE_REGISTRY,
    CatalogError,
    _normalize_catalog,
    generate_required_paths,
)


_PATH_FIELDS = {
    "id",
    "commands",
    "rule",
    "lane",
    "entry",
    "state",
    "outcome",
    "observe",
    "scenario",
}


def _key(key_name, modifiers=(), keymap="global"):
    return {
        "keymap": keymap,
        "sequence": [{"modifiers": list(modifiers), "key": key_name}],
    }


def _row(command_id, **overrides):
    row = {
        "id": command_id,
        "name": command_id,
        "owner": "core/command",
        "keymap": "global",
        "keys": [],
        "group": "test",
        "mutates": False,
        "prompts": [],
        "needs-region": False,
        "external": [],
        "modes": ["all"],
        "mx-eligible": True,
    }
    row.update(overrides)
    return row


def _catalog():
    rows = [
        _row(
            "forward-char",
            owner="core/buffer",
            keys=[_key("f", ("control",)), _key("n", ("alt", "control"))],
        ),
        _row(
            "execute-extended-command",
            name=None,
            keys=[_key("x", ("alt",))],
            prompts=["completion"],
            **{"mx-eligible": False},
        ),
        _row(
            "replace-string",
            owner="feature/search",
            keys=[_key("%", ("alt",))],
            prompts=["free-string", "free-string", "completion", "yes-no", "numeric"],
        ),
        _row("delete-char", owner="core/buffer", keys=[_key("delete")], mutates=True),
        _row(
            "kill-region",
            owner="feature/kill-ring",
            keys=[_key("w", ("control",))],
            mutates=True,
            **{"needs-region": True},
        ),
        _row("pipe-command", owner="feature/shell", external=["shell", "sample-tool"]),
    ]
    fixed_names = {
        "save-buffer",
        "save-buffers-kill-terminal",
        "goto-line",
        "keyboard-quit",
        "split-window-below",
        "undo",
        "save-session",
        "load-session",
        "new-workspace",
        "switch-workspace",
    }
    rows.extend(_row(command_id) for command_id in sorted(fixed_names))
    return rows


def _by_id(paths):
    return {path["id"]: path for path in paths}


class GenerateRequiredPathsTests(unittest.TestCase):
    def setUp(self):
        self.catalog = _catalog()
        self.paths = generate_required_paths(self.catalog)
        self.paths_by_id = _by_id(self.paths)

    def test_catalog_routes_and_command_branches_have_expected_counts_and_lanes(self):
        rule_counts = {}
        for path in self.paths:
            rule_counts[path["rule"]] = rule_counts.get(path["rule"], 0) + 1
            self.assertEqual(set(path), _PATH_FIELDS)
            self.assertEqual(path["scenario"], "")

        self.assertEqual(
            rule_counts,
            {"r1": 21, "r2": 34, "r3": 14, "r4": 2, "r5": 8, "r6": 32, "r7": 7, "r8": 4},
        )
        self.assertEqual(len(self.paths), len(self.paths_by_id))
        self.assertEqual(
            sum(len(row["keys"]) for row in self.catalog)
            + sum(row["mx-eligible"] for row in self.catalog),
            rule_counts["r1"],
        )
        execute_command = next(
            row for row in self.catalog if row["id"] == "execute-extended-command"
        )
        self.assertIsNone(execute_command["name"])
        execute_paths = [
            path for path in self.paths if path["id"].startswith("r1:execute-extended-command:key:")
        ]
        self.assertEqual(len(execute_paths), 1)
        self.assertEqual(execute_paths[0]["lane"], "W3-1")
        self.assertEqual(self.paths_by_id["r1:delete-char:mx"]["lane"], "W3-4")
        self.assertEqual(self.paths_by_id["r1:kill-region:mx"]["lane"], "W3-8")
        self.assertEqual(self.paths_by_id["r1:pipe-command:mx"]["lane"], "W3-11")
        self.assertEqual(self.paths_by_id["r7:git-commit"]["lane"], "W3-2")
        self.assertEqual(self.paths_by_id["r8:session"]["lane"], "W3-10")

    def test_lane_registry_covers_every_w3_owner_slice_and_lane(self):
        self.assertEqual(
            LANE_REGISTRY,
            {
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
            },
        )
        self.assertEqual(
            set(LANE_REGISTRY.values()),
            {
                "W3-1",
                "W3-2",
                "W3-3",
                "W3-4",
                "W3-5",
                "W3-6",
                "W3-7a",
                "W3-7b",
                "W3-7c",
                "W3-7d",
                "W3-7e",
                "W3-8",
                "W3-9",
                "W3-10",
                "W3-11",
            },
        )
        normalized = next(
            row for row in _normalize_catalog(self.catalog)
            if row["id"] == "forward-char"
        )
        self.assertEqual(normalized["owner"], "core/buffer")
        self.assertEqual(normalized["lane"], "W3-4")

    def test_r1_generates_every_key_and_respects_mx_eligibility(self):
        key_paths = [path for path in self.paths if path["rule"] == "r1" and path["entry"].startswith("key:")]
        mx_paths = [path for path in self.paths if path["rule"] == "r1" and path["entry"] == "mx"]

        self.assertEqual(len(key_paths), sum(len(row["keys"]) for row in self.catalog))
        self.assertEqual(len(mx_paths), sum(row["mx-eligible"] for row in self.catalog))
        self.assertFalse(any(path["id"] == "r1:execute-extended-command:mx" for path in mx_paths))
        self.assertTrue(any(path["id"].startswith("r1:execute-extended-command:key:") for path in key_paths))
        self.assertEqual({path["lane"] for path in key_paths}, {"W3-1", "W3-4", "W3-6", "W3-8"})

    def test_space_is_a_valid_catalog_key(self):
        catalog = _catalog()
        row = next(row for row in catalog if row["id"] == "forward-char")
        row["keys"] = [_key(" ")]
        paths = generate_required_paths(catalog)
        path = next(path for path in paths if path["id"].startswith("r1:forward-char:key:"))
        self.assertIn('"key":" "', path["entry"])

    def test_paths_use_canonical_id_when_name_differs(self):
        catalog = _catalog()
        row = next(row for row in catalog if row["id"] == "forward-char")
        row["name"] = "legacy-forward"

        paths = _by_id(generate_required_paths(catalog))

        self.assertIn("r1:forward-char:mx", paths)
        self.assertEqual(paths["r1:forward-char:mx"]["commands"], ["forward-char"])
        self.assertEqual(paths["r1:forward-char:mx"]["lane"], "W3-4")
        self.assertNotIn("r1:legacy-forward:mx", paths)

    def test_command_ids_do_not_override_owner_lane(self):
        catalog = _catalog()
        catalog[2]["id"] = "git-status"
        catalog.append(_row("future-command", owner="feature/files"))

        paths = _by_id(generate_required_paths(catalog))
        self.assertEqual(paths["r1:git-status:mx"]["lane"], "W3-6")
        self.assertEqual(paths["r1:future-command:mx"]["lane"], "W3-3")

    def test_r2_generates_all_prompt_cases_once_per_kind(self):
        ids = set(self.paths_by_id)
        self.assertTrue(
            {
                f"r2:replace-string:prompt-1:free-string:{case}"
                for case in ("accept", "cancel", "empty", "tab", "history")
            }.issubset(ids)
        )
        self.assertTrue(
            {
                f"r2:replace-string:prompt-2:free-string:{case}"
                for case in ("accept", "cancel", "empty", "tab", "history")
            }.issubset(ids)
        )
        self.assertNotIn("r2:replace-string:prompt-1:free-string:invalid", ids)
        for index, kind in enumerate(("completion", "yes-no", "numeric"), start=3):
            self.assertTrue(
                {
                    f"r2:replace-string:prompt-{index}:{kind}:{case}"
                    for case in ("accept", "cancel", "empty", "tab", "history", "invalid")
                }.issubset(ids)
            )
        self.assertEqual(
            self.paths_by_id["r2:replace-string:prompt-2:free-string:accept"]["entry"],
            'key:{"keymap":"global","sequence":[{"key":"%","modifiers":["alt"]}]};prompt:2:free-string',
        )

    def test_r3_generates_each_mutation_case_and_marks_macro_route(self):
        cases = {path["id"].rsplit(":", 1)[1] for path in self.paths if path["rule"] == "r3"}
        self.assertEqual(
            cases,
            {"effect", "undo", "read-only", "narrow", "split-window", "macro-replay", "prefix-u4"},
        )
        self.assertEqual(self.paths_by_id["r3:kill-region:macro-replay"]["entry"], "macro")
        self.assertTrue(self.paths_by_id["r3:delete-char:undo"]["entry"].startswith("key:"))

    def test_r4_generates_region_present_and_absent(self):
        self.assertIn("r4:kill-region:region-present", self.paths_by_id)
        self.assertIn("r4:kill-region:region-absent", self.paths_by_id)

    def test_r5_generates_each_external_tool_outcome(self):
        for tool in ("shell", "sample-tool"):
            for outcome in ("success", "missing", "nonzero", "interrupted"):
                self.assertIn(f"r5:pipe-command:{tool}:{outcome}", self.paths_by_id)

    def test_r6_generates_text_operations_and_cross_input_paths(self):
        for dimension in ("fullwidth", "combining", "emoji", "wrap", "truncate"):
            for operation in ("move", "insert", "delete", "undo", "save"):
                self.assertIn(f"r6:text:{dimension}:{operation}", self.paths_by_id)
        for path_id in (
            "r6:resize",
            "r6:mouse",
            "r6:paste",
            "r6:suspend:c-z",
            "r6:signal:sigterm",
            "r6:signal:sighup",
            "r6:signal:sigtstp-cont",
        ):
            self.assertIn(path_id, self.paths_by_id)
        self.assertEqual(self.paths_by_id["r6:text:emoji:insert"]["commands"], [])

    def test_r7_generates_all_editor_invocation_paths(self):
        for path_id in (
            "r7:git-commit",
            "r7:interactive-rebase",
            "r7:crontab",
            "r7:xargs-non-tty",
            "r7:plus-n",
            "r7:new-file",
            "r7:interruption",
        ):
            self.assertIn(path_id, self.paths_by_id)
        self.assertEqual(self.paths_by_id["r7:xargs-non-tty"]["commands"], [])
        self.assertEqual(self.paths_by_id["r7:plus-n"]["commands"], [])

    def test_r8_generates_every_post_restart_restore_path(self):
        for path_id in ("r8:session", "r8:split-windows", "r8:workspace", "r8:history"):
            self.assertIn(path_id, self.paths_by_id)
            self.assertEqual(self.paths_by_id[path_id]["entry"], "new-process")

    def test_generation_is_independent_of_catalog_and_key_order(self):
        reversed_catalog = copy.deepcopy(self.catalog[::-1])
        forward_char = next(
            row for row in reversed_catalog if row["id"] == "forward-char"
        )
        forward_char["keys"] = forward_char["keys"][::-1]
        self.assertEqual(generate_required_paths(reversed_catalog), self.paths)

    def test_missing_keys_field_is_rejected(self):
        catalog = _catalog()
        del catalog[0]["keys"]
        with self.assertRaisesRegex(CatalogError, "missing fields: keys"):
            generate_required_paths(catalog)

    def test_missing_command_id_is_rejected(self):
        catalog = _catalog()
        del catalog[0]["id"]
        with self.assertRaisesRegex(CatalogError, "missing fields: id"):
            generate_required_paths(catalog)

    def test_command_without_any_entry_is_rejected(self):
        catalog = _catalog()
        row = next(row for row in catalog if row["id"] == "forward-char")
        row["keys"] = []
        row["mx-eligible"] = False
        with self.assertRaisesRegex(CatalogError, "no key or M-x entry"):
            generate_required_paths(catalog)

    def test_missing_fixed_path_command_is_rejected(self):
        catalog = [row for row in _catalog() if row["id"] != "save-buffer"]
        with self.assertRaisesRegex(CatalogError, "missing commands required by fixed paths"):
            generate_required_paths(catalog)

    def test_unknown_prompt_kind_and_command_owner_are_rejected(self):
        catalog = _catalog()
        catalog[0]["prompts"] = ["future-prompt"]
        with self.assertRaisesRegex(CatalogError, "unknown prompt kinds"):
            generate_required_paths(catalog)

        catalog = _catalog()
        catalog[0]["owner"] = "future/slice"
        with self.assertRaisesRegex(CatalogError, "unknown owner slice"):
            generate_required_paths(catalog)

    def test_duplicate_ids_and_malformed_key_sequences_are_rejected(self):
        catalog = _catalog()
        catalog.append(copy.deepcopy(catalog[0]))
        with self.assertRaisesRegex(CatalogError, "duplicate command ID"):
            generate_required_paths(catalog)

        catalog = _catalog()
        catalog[0]["keys"] = [{"keymap": "global", "sequence": []}]
        with self.assertRaisesRegex(CatalogError, "sequence must be a non-empty list"):
            generate_required_paths(catalog)


if __name__ == "__main__":
    unittest.main()
