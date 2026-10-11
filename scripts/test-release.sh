#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 2 ]]; then
  echo "Usage: bash scripts/test-release.sh ARCHIVE EXPECTED_VERSION" >&2
  exit 64
fi
expected_version=$2
if [[ ! $expected_version =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  echo "EXPECTED_VERSION must be strict numeric semver (MAJOR.MINOR.PATCH)." >&2
  exit 64
fi
archive=$(realpath "$1")
name=$(basename "$archive" .tar.gz)
[[ $name =~ ^loom-[a-zA-Z0-9._-]+$ ]]
scratch=$(mktemp -d "${TMPDIR:-/tmp}/loom-release-test.XXXXXX")
# Nix rejects store parents that are symlinks, including /tmp on macOS.
scratch=$(realpath "$scratch")
printf 'Release test scratch: %s\n' "$scratch"
# Validate a private copy so extraction uses the bytes whose digest was checked.
cp "$archive" "$scratch/$name.tar.gz"
cp "$archive.sha256" "$scratch/$name.tar.gz.sha256"
python3 "$(dirname "${BASH_SOURCE[0]}")/unpack-release.py" "$scratch/$name.tar.gz" "$scratch"
directory="$scratch/$name"
[[ $(wc -l < "$directory/store-path") -eq 1 ]]
package=$(< "$directory/store-path")
[[ $package =~ ^/nix/store/[a-z0-9]{32}-loom-[a-zA-Z0-9._+-]+$ ]]
store="$scratch/store"
nix path-info --store "$store" --all > "$scratch/before-import"
[[ ! -s $scratch/before-import ]]
nix-store --store "$store" --import < "$directory/loom.closure" > "$scratch/imported"
LC_ALL=C sort "$scratch/imported" > "$scratch/imported-sorted"
diff -u "$directory/closure-paths" "$scratch/imported-sorted"
nix-store --store "$store" --query --requisites "$package" \
  | LC_ALL=C sort > "$scratch/restored-closure"
diff -u "$directory/closure-paths" "$scratch/restored-closure"
nix-store --store "$store" --verify --check-contents
nix profile install --store "$store" --offline --profile "$scratch/profile" "$package"
[[ -L $scratch/profile ]]
nix-store --store "$store" --gc --print-live > "$scratch/live-paths"
grep -Fx "$package" "$scratch/live-paths"
printf 'Verified complete closure and profile GC root.\n'
if [[ $(uname -s) == Linux ]]; then
  # nix shell enters the isolated store's mount namespace, not the host store.
  nix shell --store "$store" --offline "$package" \
    --command "$package/bin/loom" --version > "$scratch/version"
  printf 'loom %s\n' "$expected_version" > "$scratch/expected-version"
  cmp "$scratch/expected-version" "$scratch/version"
  nix shell --store "$store" --offline "$package" \
    --command "$package/bin/loom" --help > "$scratch/help"
  grep -F 'Usage: loom [PATH]' "$scratch/help"
  printf 'Verified offline Linux startup from the restored archive.\n'
else
  printf 'Isolated-store execution requires Linux; startup is not checked here.\n'
fi
