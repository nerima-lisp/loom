"""Load scenarios stored with their owning feature slices."""

import hashlib
import importlib.util
import sys
from pathlib import Path


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
