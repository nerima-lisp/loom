"""Load scenarios stored with their owning feature slices."""

import hashlib
import importlib.util
import sys
from pathlib import Path


from .command_path_scenarios import (
    load_command_path_scenarios,
    run_command_path_scenario,
)
from .registry import scenario


_loaded_command_path_sidecars = set()


def _command_path_scenario(case):
    def run(binary):
        return run_command_path_scenario(binary, case)

    return run


def load_slice_scenarios(repository_root):
    packages_root = Path(repository_root) / "packages"
    scenario_files = sorted(
        path
        for path in packages_root.glob("**/t/e2e/scenarios/**/*.py")
        if path.name != "__init__.py"
    )
    for path in scenario_files:
        module_name = "_loom_slice_scenario_" + hashlib.sha256(
            str(path.resolve()).encode("utf-8")
        ).hexdigest()
        if module_name in sys.modules:
            continue
        spec = importlib.util.spec_from_file_location(module_name, path)
        if spec is None or spec.loader is None:
            raise ImportError(f"cannot load E2E scenario module: {path}")
        module = importlib.util.module_from_spec(spec)
        sys.modules[module_name] = module
        try:
            spec.loader.exec_module(module)
        except Exception:
            del sys.modules[module_name]
            raise

    for path in sorted(
        packages_root.glob("feature/**/t/e2e/scenarios/**/command-paths.json")
    ):
        # Slice modules may register their adjacent sidecar with a custom runner.
        if path.with_name("command_path_scenarios.py").exists():
            continue
        sidecar_id = str(path.resolve())
        if sidecar_id in _loaded_command_path_sidecars:
            continue
        for case in load_command_path_scenarios(path):
            scenario(case["name"], commands=case["commands"])(
                _command_path_scenario(case)
            )
        _loaded_command_path_sidecars.add(sidecar_id)


def format_scenario_listing(registered):
    return [
        f"{name}\tcommands={','.join(scenario_commands) or '(none)'}"
        for name, scenario_commands, _function in registered
    ]


def select_scenarios(registered, fragment):
    return [
        entry
        for entry in registered
        if fragment is None or fragment in entry[0]
    ]
