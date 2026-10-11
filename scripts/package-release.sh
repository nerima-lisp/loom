#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 3 ]]; then
  echo "Usage: bash scripts/package-release.sh STORE_PATH NAME OUTPUT_DIRECTORY" >&2
  exit 64
fi

package=$(realpath "$1")
name=$2
output=$3
if [[ ! $name =~ ^loom-[a-zA-Z0-9._-]+$ || ! -x $package/bin/loom ]]; then
  echo "Expected a Loom package and a safe archive name." >&2
  exit 64
fi
mkdir -p "$output"
output=$(realpath "$output")
directory="$output/$name"
if [[ -e $directory || -e $output/$name.tar.gz || -e $output/$name.tar.gz.sha256 ]]; then
  echo "Refusing to overwrite release artifacts." >&2
  exit 1
fi
mkdir "$directory"
printf '%s\n' "$package" > "$directory/store-path"
nix-store --query --requisites "$package" | LC_ALL=C sort > "$directory/closure-paths"
paths=()
while IFS= read -r path; do
  paths+=("$path")
done < "$directory/closure-paths"
[[ ${#paths[@]} -gt 0 ]]
# Export does not include references automatically; pass the entire closure.
nix-store --export "${paths[@]}" > "$directory/loom.closure"
cp INSTALL.md LICENSE "$directory/"
tar -czf "$output/$name.tar.gz" -C "$output" "$name"
(
  cd "$output"
  shasum -a 256 "$name.tar.gz" > "$name.tar.gz.sha256"
)
printf 'Packaged %s store paths: %s/%s.tar.gz\n' "${#paths[@]}" "$output" "$name"
