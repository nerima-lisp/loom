import hashlib
import importlib.util
import io
import os
from pathlib import Path
import stat
import subprocess
import tarfile
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
NAME = "loom-v0.1.0-x86_64-linux"
CONTENTS = {
    "INSTALL.md": b"Fixture installation instructions\n",
    "LICENSE": b"Fixture license\n",
    "closure-paths": b"/nix/store/fixture-loom\n",
    "loom.closure": b"fixture closure\x00\xff",
    "store-path": b"/nix/store/fixture-loom\n",
}
spec = importlib.util.spec_from_file_location("unpack_release", ROOT / "scripts/unpack-release.py")
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


def member(name, kind=tarfile.REGTYPE, data=b"", mode=0o644):
    info = tarfile.TarInfo(name)
    info.type = kind
    info.mode = mode
    info.uid = os.getuid() + 1000001
    info.gid = os.getgid() + 1000001
    info.uname = "fixture-owner"
    info.gname = "fixture-group"
    info.size = len(data) if kind in (tarfile.REGTYPE, tarfile.AREGTYPE) else 0
    return info, data


class ArchiveTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()

    def members(self, name=NAME):
        return [member(name, tarfile.DIRTYPE, mode=0o755)] + [
            member(f"{name}/{filename}", data=data) for filename, data in CONTENTS.items()
        ]

    def archive(self, members=None, filename=f"{NAME}.tar.gz", raw=None, format=tarfile.PAX_FORMAT):
        archive = self.root / filename
        if raw is None:
            with tarfile.open(archive, "w:gz", format=format) as output:
                for info, data in self.members() if members is None else members:
                    output.addfile(info, io.BytesIO(data) if info.isreg() else None)
        else:
            archive.write_bytes(raw)
        checksum = f"{hashlib.sha256(archive.read_bytes()).hexdigest()}  {archive.name}\n".encode()
        Path(str(archive) + ".sha256").write_bytes(checksum)
        return archive

    def destination(self):
        return Path(tempfile.mkdtemp(dir=self.root))

    def assert_rejected(self, archive, expected_error=ValueError):
        destination = self.destination()
        try:
            with self.assertRaises(expected_error) as raised:
                helper.unpack(archive, destination)
            self.assertIs(type(raised.exception), expected_error)
        finally:
            self.assertEqual(list(destination.iterdir()), [], "Invalid archives must not extract anything")
            self.assertFalse((self.root / "escaped").exists())

    def assert_contents(self, destination, name=NAME):
        directory = destination / name
        self.assertEqual(list(destination.iterdir()), [directory])
        self.assertEqual({path.name for path in directory.iterdir()}, set(CONTENTS))
        for filename, data in CONTENTS.items():
            self.assertEqual((directory / filename).read_bytes(), data)

    def test_known_good_formats_and_member_order(self):
        for format in (tarfile.GNU_FORMAT, tarfile.PAX_FORMAT):
            with self.subTest(format=format):
                archive = self.archive(list(reversed(self.members())), format=format)
                destination = self.destination()
                self.assertIsNone(helper.unpack(archive, destination))
                self.assert_contents(destination)

    def test_known_good_filename_characters(self):
        name = "loom-Az09._-"
        archive = self.archive(self.members(name), filename=f"{name}.tar.gz")
        destination = self.destination()
        self.assertIsNone(helper.unpack(archive, destination))
        self.assert_contents(destination, name)

    def test_invalid_archive_names(self):
        for filename in ("other.tar.gz", "loom-.tar.gz", "loom-a b.tar.gz", "loom-a\n.tar.gz", "loom-a.tgz", "loom-a.tar.gz.extra"):
            with self.subTest(filename=filename):
                self.assert_rejected(self.archive(filename=filename))

    def test_checksum_is_bound_to_exact_bytes_and_basename(self):
        archive = self.archive()
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        records = (
            f"{'0' * 64}  {archive.name}\n",
            f"{digest.upper()}  {archive.name}\n",
            f"{digest} {archive.name}\n",
            f"{digest}\t{archive.name}\n",
            f"{digest} *{archive.name}\n",
            f"{digest}  loom-other.tar.gz\n",
            f"{digest}  ./{archive.name}\n",
            f"{digest}  {archive}\n",
            f"{digest}  {archive.name}",
            f"{digest}  {archive.name}\r\n",
            f"{digest}  {archive.name}\n\n",
            f"{digest}  {archive.name}\n{digest}  {archive.name}\n",
        )
        for index, record in enumerate(records):
            with self.subTest(record=index):
                Path(str(archive) + ".sha256").write_bytes(record.encode())
                self.assert_rejected(archive)

    def test_changed_archive_bytes_fail_original_checksum(self):
        archive = self.archive()
        archive.write_bytes(archive.read_bytes() + b"tampered")
        self.assert_rejected(archive)

    def test_missing_checksum_is_invalid(self):
        archive = self.archive()
        Path(str(archive) + ".sha256").unlink()
        self.assert_rejected(archive, FileNotFoundError)

    def test_invalid_tar_is_invalid_even_with_matching_checksum(self):
        self.assert_rejected(self.archive(raw=b"not a gzip tar archive"), tarfile.ReadError)

    def test_missing_members(self):
        members = self.members()
        for index in range(len(members)):
            with self.subTest(missing=members[index][0].name):
                self.assert_rejected(self.archive(members[:index] + members[index + 1:]))

    def test_duplicate_members(self):
        members = self.members()
        for info, data in members:
            with self.subTest(duplicate=info.name):
                self.assert_rejected(self.archive(members + [(info, data)]))
        self.assert_rejected(self.archive(members[:-1] + [members[1]]))

    def test_extra_member(self):
        self.assert_rejected(self.archive(self.members() + [member(f"{NAME}/extra", data=b"extra")]))

    def test_unsafe_member_names(self):
        names = (
            "../escaped",
            str(self.root / "escaped"),
            f"{NAME}/../escaped",
            f"{NAME}/./store-path",
            f"{NAME}//store-path",
            f"{NAME}/sub/store-path",
            "loom-other/store-path",
        )
        for name in names:
            with self.subTest(name=name):
                self.assert_rejected(self.archive(self.members()[:-1] + [member(name, data=b"escape")]))

    def test_rejects_links_and_nonregular_file_types_before_extracting(self):
        kinds = (tarfile.SYMTYPE, tarfile.LNKTYPE, tarfile.DIRTYPE, tarfile.FIFOTYPE,
                 tarfile.CHRTYPE, tarfile.BLKTYPE, tarfile.GNUTYPE_SPARSE, b"Z")
        for kind in kinds:
            with self.subTest(kind=kind):
                info, data = member(f"{NAME}/store-path", kind)
                info.linkname = str(self.root / "escaped") if info.islnk() or info.issym() else ""
                archive = self.archive(self.members()[:-1] + [(info, data)], format=tarfile.GNU_FORMAT)
                with tarfile.open(archive, "r:gz") as source:
                    self.assertEqual(len(source.getmembers()), 6)
                    self.assertEqual(source.getmembers()[-1].type, kind)
                self.assert_rejected(archive)

    def test_root_must_be_a_directory(self):
        for kind in (tarfile.REGTYPE, tarfile.SYMTYPE, tarfile.LNKTYPE):
            with self.subTest(kind=kind):
                info, data = member(NAME, kind)
                info.linkname = str(self.root / "escaped") if kind != tarfile.REGTYPE else ""
                self.assert_rejected(self.archive([(info, data)] + self.members()[1:]))

    def test_archive_modes_and_owners_are_not_restored(self):
        members = self.members()
        for info, _ in members:
            info.mode = 0o7777
        archive = self.archive(members)
        with tarfile.open(archive, "r:gz") as source:
            for info in source.getmembers():
                self.assertEqual(info.mode, 0o7777)
                self.assertEqual((info.uid, info.gid), (os.getuid() + 1000001, os.getgid() + 1000001))
        destination = self.destination()
        helper.unpack(archive, destination)
        self.assert_contents(destination)
        directory = destination / NAME
        self.assertEqual(stat.S_IMODE(directory.lstat().st_mode), 0o700)
        for path in [directory, *directory.iterdir()]:
            with self.subTest(path=path.name):
                metadata = path.lstat()
                self.assertFalse(path.is_symlink())
                self.assertEqual(metadata.st_mode & 0o7000, 0)
                self.assertEqual(metadata.st_uid, os.getuid())
                # macOS and setgid parents can assign an inherited local group.
                self.assertNotEqual(metadata.st_gid, members[0][0].gid)
                if path != directory:
                    self.assertTrue(stat.S_ISREG(metadata.st_mode))
                    self.assertEqual(metadata.st_mode & 0o111, 0)
                    self.assertEqual(metadata.st_nlink, 1)


class PackageTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.package = self.root / "package"
        (self.package / "bin").mkdir(parents=True)
        executable = self.package / "bin/loom"
        executable.write_text("#!/usr/bin/env bash\nexit 0\n")
        executable.chmod(0o700)
        for filename in ("INSTALL.md", "LICENSE"):
            (self.root / filename).write_bytes(CONTENTS[filename])
        self.output = self.root / "dist"
        self.output.mkdir()
        stub_directory = self.root / "stub-bin"
        stub_directory.mkdir()
        stub = stub_directory / "nix-store"
        stub.write_text(
            '#!/usr/bin/env bash\nset -euo pipefail\n'
            'printf "%s\\n" "$*" >> "$LOOM_STUB_LOG"\n'
            'case "$1" in\n'
            '  --query) [[ $# == 3 && $2 == --requisites ]]; printf "%s\\n" "$3" ;;\n'
            '  --export) [[ $# == 2 ]]; printf "fixture closure\\n" ;;\n'
            '  *) exit 64 ;;\nesac\n'
        )
        stub.chmod(0o700)
        self.log = self.root / "nix-store.log"
        self.env = dict(os.environ, PATH=f"{stub_directory}{os.pathsep}{os.environ.get('PATH', '')}",
                        LOOM_STUB_LOG=str(self.log))
        self.script = Path(os.environ.get("LOOM_PACKAGE_SCRIPT", ROOT / "scripts/package-release.sh")).resolve()
        revision = os.environ.get("LOOM_PACKAGE_REVISION")
        if revision:
            # A revision overrides the script path without changing the working copy.
            baseline = subprocess.run(
                ["jj", "file", "show", "--ignore-working-copy", "-r", revision, "scripts/package-release.sh"],
                cwd=ROOT, capture_output=True, check=True,
            )
            self.assertTrue(baseline.stdout, "The selected revision must contain the packaging script")
            self.script = self.root / "package-release.sh"
            self.script.write_bytes(baseline.stdout)

    def run_package(self, name=NAME):
        return subprocess.run(
            ["bash", str(self.script), str(self.package), name, str(self.output)],
            cwd=self.root, env=self.env, capture_output=True, text=True,
        )

    def assert_blocked(self, suffix, kind):
        artifact = self.output / f"{NAME}{suffix}"
        target = self.root / "link-target"
        if kind == "directory":
            artifact.mkdir()
            (artifact / "sentinel").write_bytes(b"preserve")
        elif kind == "file":
            artifact.write_bytes(b"preserve")
        else:
            if kind == "symlink":
                target.write_bytes(b"preserve target")
            artifact.symlink_to(target, target_is_directory=not suffix)
        result = self.run_package()
        if kind == "dangling":
            self.assertFalse(target.exists(), "A dangling target must not be created")
        self.assertNotEqual(result.returncode, 0, "Existing artifacts must be rejected")
        self.assertFalse(self.log.exists(), "Rejection must precede closure export")
        self.assertEqual(list(self.output.iterdir()), [artifact], "No partial artifacts may be created")
        if kind == "directory":
            self.assertEqual((artifact / "sentinel").read_bytes(), b"preserve")
        elif kind == "file":
            self.assertEqual(artifact.read_bytes(), b"preserve")
        else:
            self.assertTrue(artifact.is_symlink())
            self.assertEqual(os.readlink(artifact), str(target))
            if kind == "symlink":
                self.assertEqual(target.read_bytes(), b"preserve target")

    def test_known_good_package(self):
        result = self.run_package()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text().splitlines(), [
            f"--query --requisites {self.package}", f"--export {self.package}",
        ])
        archive = self.output / f"{NAME}.tar.gz"
        self.assertEqual(Path(str(archive) + ".sha256").read_text(),
                         f"{hashlib.sha256(archive.read_bytes()).hexdigest()}  {archive.name}\n")
        destination = self.root / "unpacked"
        destination.mkdir(mode=0o700)
        self.assertIsNone(helper.unpack(archive, destination))
        directory = destination / NAME
        self.assertEqual({path.name for path in directory.iterdir()}, set(CONTENTS))
        for filename in ("INSTALL.md", "LICENSE"):
            self.assertEqual((directory / filename).read_bytes(), CONTENTS[filename])
        for filename in ("store-path", "closure-paths"):
            self.assertEqual((directory / filename).read_text(), f"{self.package}\n")
        self.assertEqual((directory / "loom.closure").read_bytes(), b"fixture closure\n")

    def test_existing_directory(self):
        self.assert_blocked("", "directory")

    def test_existing_archive(self):
        self.assert_blocked(".tar.gz", "file")

    def test_existing_checksum(self):
        self.assert_blocked(".tar.gz.sha256", "file")

    def test_dangling_directory(self):
        self.assert_blocked("", "dangling")

    def test_dangling_archive(self):
        self.assert_blocked(".tar.gz", "dangling")

    def test_dangling_checksum(self):
        self.assert_blocked(".tar.gz.sha256", "dangling")

    def test_existing_directory_symlink(self):
        self.assert_blocked("", "symlink")

    def test_existing_archive_symlink(self):
        self.assert_blocked(".tar.gz", "symlink")

    def test_existing_checksum_symlink(self):
        self.assert_blocked(".tar.gz.sha256", "symlink")

    def test_invalid_package_names(self):
        for name in ("loom-", "other", "loom-a b", "loom-a\n", "loom-../escaped", "../escaped"):
            with self.subTest(name=name):
                result = self.run_package(name)
                self.assertEqual(result.returncode, 64)
                self.assertFalse(self.log.exists())
                self.assertEqual(list(self.output.iterdir()), [])
                self.assertFalse((self.root / "escaped").exists())


if __name__ == "__main__":
    unittest.main()
