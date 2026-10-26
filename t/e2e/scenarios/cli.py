"""Command-line handling for accepted and rejected startup inputs."""

import json
import os
import re
import tempfile
from pathlib import Path

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


def _assert_exit_zero(name, output, code):
    if code != 0:
        raise AssertionError(f"{name} exited with {code}: {output!r}")


def _assert_exit_code(name, output, code, expected):
    if code != expected:
        raise AssertionError(f"{name} exited with {code}, expected {expected}: {output!r}")


def _real_slice_directory(packages, owner):
    parts = owner.split("/")
    if (
        len(parts) != 2
        or parts[0] not in {"core", "feature"}
        or re.fullmatch(r"[a-z0-9-]+", parts[1]) is None
    ):
        return None

    slice_directory = packages.joinpath(*parts)
    system_file = slice_directory / f"loom-{parts[0]}-{parts[1]}.asd"
    if not slice_directory.is_dir() or not system_file.is_file():
        return None
    return slice_directory


def _manifest_command_owners(repo_root):
    packages = repo_root / "packages"
    expected = {}
    for manifest in sorted(packages.glob("*/*/t/command-ids.lisp")):
        category, slice_name, test_directory, filename = (
            manifest.relative_to(packages).parts
        )
        owner = f"{category}/{slice_name}"
        if test_directory != "t" or filename != "command-ids.lisp":
            raise AssertionError(f"unexpected command ID manifest path: {manifest}")
        if _real_slice_directory(packages, owner) is None:
            raise AssertionError(f"command ID manifest has no real slice system: {owner!r}")

        source = manifest.read_text(encoding="utf-8")
        if re.fullmatch(r'\s*\(\s*(?:"[^"\\]+"\s*)*\)\s*', source) is None:
            raise AssertionError(f"invalid flat command ID list: {manifest}")
        for command_id in re.findall(r'"([^"\\]+)"', source):
            if command_id in expected:
                raise AssertionError(
                    f"command ID {command_id!r} is listed by both "
                    f"{expected[command_id]!r} and {owner!r}"
                )
            expected[command_id] = owner
    return expected


def _assert_catalog_matches_manifests(catalog, repo_root):
    packages = repo_root / "packages"
    expected = _manifest_command_owners(repo_root)
    actual = {}
    for command in catalog:
        command_id = command.get("id")
        owner = command.get("owner")
        if not isinstance(command_id, str) or not isinstance(owner, str):
            raise AssertionError(f"catalog entry has a non-string ID or owner: {command!r}")
        if _real_slice_directory(packages, owner) is None:
            raise AssertionError(f"catalog command {command_id!r} has unknown owner {owner!r}")
        if command_id in actual:
            raise AssertionError(f"catalog repeats command ID {command_id!r}")
        actual[command_id] = owner

    if actual == expected:
        return

    missing = sorted(set(expected) - set(actual))
    extra = sorted(set(actual) - set(expected))
    misowned = sorted(
        (command_id, expected[command_id], actual[command_id])
        for command_id in set(expected) & set(actual)
        if expected[command_id] != actual[command_id]
    )
    raise AssertionError(
        "--dump-catalog does not match slice command ID manifests: "
        f"missing={missing!r}, extra={extra!r}, misowned={misowned!r}"
    )


@scenario("--help", commands=[])
def help_flag(binary):
    with Session(binary, ["--help"]) as session:
        output, code = session.process.wait()
        session.observe_exit_code(code, expected=0)
        session.assert_pty_output(output, b"Usage: loom [PATH]")
    _assert_exit_zero("--help", output, code)


@scenario("--version", commands=[])
def version_flag(binary):
    with Session(binary, ["--version"]) as session:
        output, code = session.process.wait()
        session.observe_exit_code(code, expected=0)
        session.assert_pty_output(output, b"loom 0.1.0")
    _assert_exit_zero("--version", output, code)


@scenario("--dump-catalog", commands=[])
def dump_catalog(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        alias = os.path.join(directory, "loom-alias")
        os.symlink(os.path.abspath(binary), alias)
        with Session(alias, ["--dump-catalog"]) as session:
            output, code = session.process.wait()

    _assert_exit_zero("--dump-catalog", output, code)
    catalog = json.loads(output.decode("utf-8"))
    _assert_catalog_matches_manifests(catalog, Path(__file__).resolve().parents[3])
    dispatcher = [
        command
        for command in catalog
        if command["name"] == "execute-extended-command"
    ]
    if len(dispatcher) != 1 or dispatcher[0]["mx-eligible"]:
        raise AssertionError(f"unexpected M-x dispatcher catalog entry: {dispatcher!r}")


@scenario("invalid option", commands=[])
def invalid_option(binary):
    with Session(binary, ["--definitely-invalid"]) as session:
        output, code = session.process.wait()
        session.observe_exit_code(code, expected=64)
        session.assert_pty_output(output, b"Unknown option")
    _assert_exit_code("invalid option", output, code, 64)


@scenario("missing path", commands=["save-buffer", "save-buffers-kill-terminal"])
def missing_path(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-") as directory:
        path = os.path.join(directory, "missing.txt")
        with Session(binary, [path]) as session:
            session.wait_ready()
            session.wait_for_region_exact_text("body", "", index=0)
            session.type("created")
            session.wait_for_region_exact_text("body", "created", index=0)

            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, b"created")
            session.assert_file_bytes(path, b"created")
            session.wait_for_region_exact_text("minibuffer", f"Wrote {path}")

            output, code = session.quit()
    _assert_exit_zero("missing path", output, code)


@scenario("startup file positions and multiple paths", commands=["switch-to-buffer"])
def startup_file_positions_and_multiple_paths(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-startup-") as directory:
        first_path = os.path.join(directory, "first.txt")
        second_path = os.path.join(directory, "second.txt")
        with open(first_path, "wb") as handle:
            handle.write(b"first top\nfirst middle\nfirst bottom\n")
        with open(second_path, "wb") as handle:
            handle.write(b"second buffer\nsecond end\n")

        with Session(binary, ["+2:3", first_path, second_path]) as session:
            session.wait_ready()
            session.wait_for_region_exact_text("body", "first top", index=0)
            session.wait_for_region_exact_text("body", "first middle", index=1)
            session.wait_for_region_exact_text("body", "first bottom", index=2)
            session.wait_for_region_cursor("body", 2, index=1)

            session.extended_command("switch-to-buffer")
            session.wait_for_region_text("minibuffer", "Switch to buffer: ")
            session.type("second.txt")
            session.key("RET")
            session.wait_for_region_exact_text("body", "second buffer", index=0)
            session.wait_for_region_exact_text("body", "second end", index=1)

            output, code = session.quit()
    _assert_exit_zero("startup file positions and multiple paths", output, code)
