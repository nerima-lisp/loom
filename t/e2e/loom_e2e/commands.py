"""Read the runtime command catalogue through the E2E session API."""

import json

from .session import Session


def catalog_command_ids(catalog):
    """Return unique canonical command IDs from a catalog."""
    command_ids = set()
    for index, item in enumerate(catalog):
        if not isinstance(item, dict):
            raise RuntimeError("--dump-catalog returned an invalid command entry")
        command_id = item.get("id")
        if (
            not isinstance(command_id, str)
            or not command_id.strip()
            or command_id != command_id.strip()
        ):
            raise RuntimeError(
                f"--dump-catalog returned an invalid command ID at entry {index}"
            )
        if command_id in command_ids:
            raise RuntimeError(f"--dump-catalog returned duplicate command ID: {command_id}")
        command_ids.add(command_id)
    return command_ids


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
    for item in catalog:
        if not isinstance(item, dict):
            raise RuntimeError("--dump-catalog returned an invalid command entry")
        name = item.get("name")
        if "name" not in item or (
            name is not None
            and (
                not isinstance(name, str)
                or not name.strip()
                or name != name.strip()
            )
        ):
            raise RuntimeError("--dump-catalog returned an invalid command name")
        if any(
            not isinstance(item.get(field), str)
            or not item[field].strip()
            or item[field] != item[field].strip()
            for field in ("owner", "keymap")
        ):
            raise RuntimeError("--dump-catalog returned an invalid command owner or keymap")
        if type(item.get("mx-eligible")) is not bool:
            raise RuntimeError("--dump-catalog returned an invalid mx-eligible value")
    catalog_command_ids(catalog)
    return catalog
