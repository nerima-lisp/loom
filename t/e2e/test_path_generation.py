import copy
import unittest

from loom_e2e.path_generation import CatalogError, generate_required_paths


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


def _row(name, **overrides):
    row = {
        "name": name,
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
            keys=[_key("f", ("control",)), _key("n", ("alt", "control"))],
        ),
        _row(
            "execute-extended-command",
            keys=[_key("x", ("alt",))],
            prompts=["completion"],
            **{"mx-eligible": False},
        ),
        _row(
            "replace-string",
            keys=[_key("%", ("alt",))],
            prompts=["free-string", "free-string", "completion", "yes-no", "numeric"],
        ),
        _row("delete-char", keys=[_key("delete")], mutates=True),
        _row("kill-region", keys=[_key("w", ("control",))], mutates=True, **{"needs-region": True}),
        _row("pipe-command", external=["shell", "sample-tool"]),
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
    rows.extend(_row(name) for name in sorted(fixed_names))
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
        row = next(row for row in catalog if row["name"] == "forward-char")
        row["keys"] = [_key(" ")]
        paths = generate_required_paths(catalog)
        path = next(path for path in paths if path["id"].startswith("r1:forward-char:key:"))
        self.assertIn('"key":" "', path["entry"])

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
        forward_char = next(row for row in reversed_catalog if row["name"] == "forward-char")
        forward_char["keys"] = forward_char["keys"][::-1]
        self.assertEqual(generate_required_paths(reversed_catalog), self.paths)

    def test_missing_keys_field_is_rejected(self):
        catalog = _catalog()
        del catalog[0]["keys"]
        with self.assertRaisesRegex(CatalogError, "missing fields: keys"):
            generate_required_paths(catalog)

    def test_command_without_any_entry_is_rejected(self):
        catalog = _catalog()
        row = next(row for row in catalog if row["name"] == "forward-char")
        row["keys"] = []
        row["mx-eligible"] = False
        with self.assertRaisesRegex(CatalogError, "no key or M-x entry"):
            generate_required_paths(catalog)

    def test_missing_fixed_path_command_is_rejected(self):
        catalog = [row for row in _catalog() if row["name"] != "save-buffer"]
        with self.assertRaisesRegex(CatalogError, "missing commands required by fixed paths"):
            generate_required_paths(catalog)

    def test_unknown_prompt_kind_and_command_owner_are_rejected(self):
        catalog = _catalog()
        catalog[0]["prompts"] = ["future-prompt"]
        with self.assertRaisesRegex(CatalogError, "unknown prompt kinds"):
            generate_required_paths(catalog)

        catalog = _catalog()
        catalog.append(_row("future-command"))
        with self.assertRaisesRegex(CatalogError, "no lane mapping"):
            generate_required_paths(catalog)

    def test_duplicate_names_and_malformed_key_sequences_are_rejected(self):
        catalog = _catalog()
        catalog.append(copy.deepcopy(catalog[0]))
        with self.assertRaisesRegex(CatalogError, "duplicate command name"):
            generate_required_paths(catalog)

        catalog = _catalog()
        catalog[0]["keys"] = [{"keymap": "global", "sequence": []}]
        with self.assertRaisesRegex(CatalogError, "sequence must be a non-empty list"):
            generate_required_paths(catalog)


if __name__ == "__main__":
    unittest.main()
