import tempfile
import unittest
from pathlib import Path

from loom_e2e.path_ledger import PathLedgerError, read_path_ledgers


_PATH = '''(:id "sample"
 :commands (:save-buffer)
 :rule :r1
 :entry "key"
 :state "writable buffer"
 :outcome "saved"
 :observe (:file_bytes)
 :scenario "save-buffer")'''


class PathLedgerTests(unittest.TestCase):
    def _write(self, root, relative, text):
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return path

    def test_reads_comments_escaped_strings_keywords_and_lists(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self._write(
                root,
                "t/paths.sexp",
                r''' ; file comment
((:id "quoted"
  :commands (:SAVE-BUFFER "custom-command" bare-command) ; inline comment
  :rule :R2
  :entry "M-x"
  :state "quote: \"save\"; path: C:\\tmp"
  :outcome "completed"
  :observe (:SCREEN_TEXT "file_bytes")
  :scenario "sample"))
''',
            )

            paths, exclusions = read_path_ledgers(root)

        self.assertEqual(exclusions, [])
        self.assertEqual(
            paths,
            [
                {
                    "id": "quoted",
                    "commands": ["save-buffer", "custom-command", "bare-command"],
                    "rule": "r2",
                    "entry": "M-x",
                    "state": 'quote: "save"; path: C:\\tmp',
                    "outcome": "completed",
                    "observe": ["screen_text", "file_bytes"],
                    "scenario": "sample",
                    "lane": "",
                }
            ],
        )

    def test_reads_root_and_future_package_files_and_exclusions(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self._write(root, "t/paths.sexp", _PATH)
            self._write(
                root,
                "packages/editor/t/paths.sexp",
                '''((:exclude :id "future" :reason "not applicable"
                   :evidence "src/editor.lisp:12")
                  (:id "package-sample" :commands () :rule :r8
                   :entry "restart" :state "saved session"
                   :outcome "restored" :observe (:external-state)
                   :scenario "restore-session" :lane "W3-10"))''',
            )

            paths, exclusions = read_path_ledgers(root)

        self.assertEqual([path["id"] for path in paths], ["sample", "package-sample"])
        self.assertEqual(paths[1]["lane"], "W3-10")
        self.assertEqual(
            exclusions,
            [
                {
                    "id": "future",
                    "reason": "not applicable",
                    "evidence": "src/editor.lisp:12",
                }
            ],
        )

    def test_defaults_lane_and_returns_the_canonical_path_keys(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self._write(root, "t/paths.sexp", _PATH)

            paths, exclusions = read_path_ledgers(root)

        self.assertEqual(exclusions, [])
        self.assertEqual(
            set(paths[0]),
            {
                "id",
                "commands",
                "rule",
                "entry",
                "state",
                "outcome",
                "observe",
                "scenario",
                "lane",
            },
        )
        self.assertEqual(paths[0]["lane"], "")
        self.assertEqual(paths[0]["commands"], ["save-buffer"])
        self.assertEqual(paths[0]["observe"], ["file_bytes"])

    def test_empty_and_missing_ledgers_return_no_records(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.assertEqual(read_path_ledgers(root), ([], []))
            self._write(root, "t/paths.sexp", "; no ledger records\n()\n")

            self.assertEqual(read_path_ledgers(root), ([], []))

    def test_rejects_malformed_records_with_source_location(self):
        malformed = {
            "unclosed list": '(:id "sample"',
            "odd plist": '(:id "sample" :commands)',
            "missing fields": '(:id "sample")',
            "duplicate key": _PATH.replace(
                ":rule :r1", ":id \"other\" :rule :r1"
            ),
            "unknown key": _PATH[:-1] + ' :unexpected "value")',
            "wrong commands type": _PATH.replace(
                ":commands (:save-buffer)", ":commands :save-buffer"
            ),
        }
        for label, text in malformed.items():
            with self.subTest(label=label), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                self._write(root, "t/paths.sexp", text)

                with self.assertRaises(PathLedgerError) as caught:
                    read_path_ledgers(root)

                self.assertIn("t/paths.sexp:1:", str(caught.exception))

    def test_rejects_duplicate_ids_across_ledger_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self._write(root, "t/paths.sexp", _PATH)
            self._write(root, "packages/editor/t/paths.sexp", _PATH)

            with self.assertRaises(PathLedgerError) as caught:
                read_path_ledgers(root)

        message = str(caught.exception)
        self.assertIn("duplicate id 'sample'", message)
        self.assertIn("packages/editor/t/paths.sexp:1:", message)
        self.assertIn("first declared at t/paths.sexp:1:", message)

    def test_rejects_duplicate_exclusion_ids(self):
        exclusion = '(:exclude :id "omitted" :reason "reason" :evidence "file.lisp:1")'
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self._write(root, "t/paths.sexp", f"({exclusion} {exclusion})")

            with self.assertRaisesRegex(PathLedgerError, "duplicate id 'omitted'"):
                read_path_ledgers(root)


if __name__ == "__main__":
    unittest.main()
