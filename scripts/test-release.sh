#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 1 ]]; then
  echo "Usage: bash scripts/test-release.sh ARCHIVE" >&2
  exit 64
fi
archive=$(realpath "$1")
name=$(basename "$archive" .tar.gz)
[[ $name =~ ^loom-[a-zA-Z0-9._-]+$ ]]
scratch=$(mktemp -d "${TMPDIR:-/tmp}/loom-release-test.XXXXXX")
# Nix rejects store parents that are symlinks, including /tmp on macOS.
scratch=$(realpath "$scratch")
printf 'Release test scratch: %s\n' "$scratch"
(
  cd "$(dirname "$archive")"
  shasum -a 256 -c "$name.tar.gz.sha256"
)
printf '%s\n' "$name/" "$name/INSTALL.md" "$name/LICENSE" \
  "$name/closure-paths" "$name/loom.closure" "$name/store-path" \
  | LC_ALL=C sort > "$scratch/expected-files"
tar -tzf "$archive" | LC_ALL=C sort > "$scratch/archive-files"
diff -u "$scratch/expected-files" "$scratch/archive-files"
tar -xzf "$archive" -C "$scratch"
directory="$scratch/$name"
[[ $(wc -l < "$directory/store-path") -eq 1 ]]
package=$(< "$directory/store-path")
[[ $package == /nix/store/*-loom-* ]]
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
  # nix run enters the isolated store's mount namespace, not the host store.
  nix run --store "$store" --offline "$package" -- --version > "$scratch/version"
  grep -Ex 'loom [0-9]+\.[0-9]+\.[0-9]+' "$scratch/version"
  nix run --store "$store" --offline "$package" -- --help > "$scratch/help"
  grep -F 'Usage: loom [PATH]' "$scratch/help"
  printf 'Verified offline Linux startup from the restored archive.\n'
else
  printf 'Isolated-store execution requires Linux; startup is not checked here.\n'
fi
