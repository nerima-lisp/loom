import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
ACTION_PATH = REPOSITORY_ROOT / ".github/actions/nix-setup/action.yml"


def _steps(action_text):
    steps = []
    current = []
    for line in action_text.splitlines():
        if line.startswith("    - "):
            if current:
                steps.append("\n".join(current))
            current = [line]
        elif current:
            current.append(line)
    if current:
        steps.append("\n".join(current))
    return steps


class NixSetupActionTests(unittest.TestCase):
    def test_only_cachix_post_run_push_is_non_blocking(self):
        steps = _steps(ACTION_PATH.read_text())
        push_step = next(
            step
            for step in steps
            if step.startswith("    - name: Configure Cachix (push-enabled)")
        )
        installer_step = next(
            step
            for step in steps
            if "DeterminateSystems/nix-installer-action@" in step
        )
        pull_step = next(
            step
            for step in steps
            if step.startswith("    - name: Configure Cachix (pull-only)")
        )
        setup_guard = next(
            step
            for step in steps
            if step.startswith("    - name: Require Cachix setup")
        )

        self.assertRegex(push_step, r"(?m)^      id: cachix-push$")
        self.assertRegex(push_step, r"(?m)^      continue-on-error: true$")
        self.assertIn("steps.cachix-push.outcome == 'failure'", setup_guard)
        self.assertIn("exit 1", setup_guard)
        self.assertNotRegex(installer_step, r"(?m)^      continue-on-error:")
        self.assertNotRegex(pull_step, r"(?m)^      continue-on-error:")
        self.assertNotRegex(setup_guard, r"(?m)^      continue-on-error:")


if __name__ == "__main__":
    unittest.main()
