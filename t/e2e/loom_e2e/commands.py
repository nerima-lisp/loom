"""Read the runtime command catalogue through the E2E session API."""

import json

from .session import Session


def load_command_catalog(binary):
    """Return command metadata emitted by the executable under test."""
    with Session(binary, ["--dump-catalog"]) as session:
        output, code = session.process.wait()
    if code != 0:
        raise RuntimeError(f"--dump-catalog exited with {code}: {output!r}")
    try:
        catalog = json.loads(output.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise RuntimeError("--dump-catalog did not return valid UTF-8 JSON") from error
    if not isinstance(catalog, list) or not catalog:
        raise RuntimeError("--dump-catalog returned an empty or invalid catalogue")
    if any(not isinstance(item, dict) or not isinstance(item.get("name"), str)
           for item in catalog):
        raise RuntimeError("--dump-catalog returned an invalid command entry")
    return catalog
