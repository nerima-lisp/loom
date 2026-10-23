"""Scenario registration: each e2e scenario declares the command-spec names
it exercises, so the runner can report coverage against the full catalogue."""

_scenarios = []


def scenario(name, commands=None):
    """Decorator registering FN as a scenario named NAME.

    COMMANDS lists the command-spec names (as in commands.parse_command_names)
    the scenario exercises through the real key/M-x path.
    """
    def decorator(fn):
        if any(existing_name == name for existing_name, _commands, _fn in _scenarios):
            raise ValueError(f"duplicate scenario name: {name!r}")
        _scenarios.append((name, list(commands or []), fn))
        return fn
    return decorator


def all_scenarios():
    return list(_scenarios)
