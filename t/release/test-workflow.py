import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
COMMIT = "a" * 40


def step_script(name):
    lines = (ROOT / ".github/workflows/release.yml").read_text().splitlines()
    start = lines.index(f"      - name: {name}")
    end = next(
        (index for index in range(start + 1, len(lines)) if lines[index].startswith("      - ")),
        len(lines),
    )
    run = next(index for index in range(start + 1, end) if lines[index] == "        run: |")
    body = []
    for line in lines[run + 1 :]:
        if line and not line.startswith("          "):
            break
        body.append(line[10:])
    if not body:
        raise ValueError(f"No shell body for {name}")
    return "\n".join(body) + "\n"


class ReleaseWorkflowTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.output = self.root / "output"
        self.output.touch()
        self.log = self.root / "gh.log"
        (self.root / "loom.asd").write_text('  :version "0.1.0"\n')
        self.env = {
            **os.environ,
            "PATH": f"{self.bin}{os.pathsep}{os.environ['PATH']}",
            "PACKAGE": "loom",
            "RELEASE_REF": "v0.1.0",
            "EVENT_NAME": "push",
            "EVENT_COMMIT": COMMIT,
            "GITHUB_OUTPUT": str(self.output),
            "VERIFIED_COMMIT": COMMIT,
            "GH_REPO": "fixture/loom",
            "STUB_COMMIT": COMMIT,
            "STUB_REFS": f"{COMMIT}\trefs/tags/v0.1.0\n",
            "STUB_LOG": str(self.log),
            "STUB_RELEASES": "",
            "STUB_GIT_STATUS": "0",
            "STUB_API_STATUS": "0",
            "STUB_CREATE_STATUS": "0",
        }
        self.stub(
            "git",
            'case "$1" in\n'
            '  rev-parse) printf "%s\\n" "$STUB_COMMIT" ;;\n'
            '  ls-remote) printf "%s" "$STUB_REFS"; exit "$STUB_GIT_STATUS" ;;\n'
            "  *) exit 64 ;;\n"
            "esac\n",
        )
        self.stub(
            "gh",
            'printf "%s\\n" "$*" >> "$STUB_LOG"\n'
            'case "$1 $2" in\n'
            '  "api repos/fixture/loom/releases") printf "%s" "$STUB_RELEASES"; exit "$STUB_API_STATUS" ;;\n'
            '  "release create") exit "$STUB_CREATE_STATUS" ;;\n'
            "  *) exit 64 ;;\n"
            "esac\n",
        )

    def stub(self, name, body):
        path = self.bin / name
        path.write_text("#!/usr/bin/env bash\nset -euo pipefail\n" + body)
        path.chmod(0o700)

    def run_step(self, name, **overrides):
        return subprocess.run(
            ["bash", "-c", step_script(name)],
            cwd=self.root,
            env={**self.env, **overrides},
            capture_output=True,
            text=True,
        )

    def test_push_records_exact_event_commit(self):
        result = self.run_step("Verify tag matches .asd version")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.output.read_text(), f"commit={COMMIT}\n")

    def test_push_rejects_different_checkout(self):
        result = self.run_step("Verify tag matches .asd version", STUB_COMMIT="b" * 40)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.output.read_bytes(), b"")

    def test_manual_run_records_tag_checkout_not_workflow_commit(self):
        result = self.run_step(
            "Verify tag matches .asd version", EVENT_NAME="workflow_dispatch", EVENT_COMMIT="b" * 40
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.output.read_text(), f"commit={COMMIT}\n")

    def test_rejects_asd_tag_version_mismatch(self):
        result = self.run_step("Verify tag matches .asd version", RELEASE_REF="v0.2.0")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.output.read_bytes(), b"")

    def test_accepts_lightweight_remote_tag(self):
        result = self.run_step("Verify the release tag has not moved")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_accepts_annotated_remote_tag_commit(self):
        result = self.run_step(
            "Verify the release tag has not moved",
            STUB_REFS=f"{'b' * 40}\trefs/tags/v0.1.0\n{COMMIT}\trefs/tags/v0.1.0^{{}}\n",
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_changed_deleted_and_unreadable_remote_tag(self):
        for overrides in (
            {"STUB_REFS": f"{'b' * 40}\trefs/tags/v0.1.0\n"},
            {"STUB_REFS": ""},
            {"STUB_GIT_STATUS": "1"},
        ):
            with self.subTest(overrides=overrides):
                result = self.run_step("Verify the release tag has not moved", **overrides)
                self.assertNotEqual(result.returncode, 0)

    def test_creates_only_new_draft_with_exact_assets(self):
        result = self.run_step("Create draft release", STUB_RELEASES="v0.0.1\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            self.log.read_text().splitlines(),
            [
                "api repos/fixture/loom/releases --paginate --jq .[].tag_name",
                "release create v0.1.0 dist/loom-v0.1.0-x86_64-linux.tar.gz "
                "dist/loom-v0.1.0-x86_64-linux.tar.gz.sha256 --draft --verify-tag --title v0.1.0 --notes ",
            ],
        )

    def test_refuses_existing_release_without_mutation(self):
        result = self.run_step("Create draft release", STUB_RELEASES="v0.0.1\nv0.1.0\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(self.log.read_text().splitlines()), 1)

    def test_release_list_failure_does_not_create(self):
        result = self.run_step("Create draft release", STUB_API_STATUS="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(self.log.read_text().splitlines()), 1)

    def test_create_failure_is_not_retried_or_hidden(self):
        result = self.run_step("Create draft release", STUB_CREATE_STATUS="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(self.log.read_text().splitlines()), 2)


if __name__ == "__main__":
    unittest.main()
