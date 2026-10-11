import hashlib
from pathlib import Path
import re
import shutil
import sys
import tarfile


def unpack(archive: Path, destination: Path) -> None:
    if not re.fullmatch(r"loom-[a-zA-Z0-9._-]+\.tar\.gz", archive.name):
        raise ValueError("Invalid release archive name")
    checksum = Path(str(archive) + ".sha256").read_bytes()
    digest = hashlib.sha256()
    with archive.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    expected_checksum = f"{digest.hexdigest()}  {archive.name}\n".encode("ascii")
    if checksum != expected_checksum:
        raise ValueError("Checksum must match this archive and its filename")

    name = archive.name.removesuffix(".tar.gz")
    files = {"INSTALL.md", "LICENSE", "closure-paths", "loom.closure", "store-path"}
    expected = {name} | {f"{name}/{filename}" for filename in files}
    with tarfile.open(archive, "r:gz") as source:
        members = source.getmembers()
        if len(members) != len(expected) or {member.name for member in members} != expected:
            raise ValueError("Unexpected or duplicate release archive members")
        for member in members:
            if member.name == name:
                valid = member.isdir()
            else:
                valid = member.isreg() and not member.issparse()
            if not valid:
                raise ValueError("Release archives must contain only a directory and regular files")
        directory = destination / name
        directory.mkdir(mode=0o700)
        # Copy only fixed filenames; never restore archive links, modes, or ownership.
        for member in members:
            if member.name != name:
                with source.extractfile(member) as content:
                    with (directory / Path(member.name).name).open("xb") as target:
                        shutil.copyfileobj(content, target)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("Usage: python3 scripts/unpack-release.py ARCHIVE DESTINATION")
    try:
        unpack(Path(sys.argv[1]), Path(sys.argv[2]))
    except (OSError, ValueError, tarfile.TarError) as error:
        sys.exit(str(error))
