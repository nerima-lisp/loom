# Release archive installation

Release archives require Nix with flakes enabled. They contain the complete Nix
runtime closure, including SBCL and the editor image, not a standalone executable.
Use the archive for your operating system and architecture. The release workflow
currently packages `x86_64-linux`; other supported systems can build from the flake.

Only import an archive from a release you trust. A checksum detects corruption;
it does not authenticate the publisher. Download the archive and its matching
`.sha256` file from the same reviewed release, then verify before extraction:

```sh
shasum -a 256 -c loom-v0.1.0-x86_64-linux.tar.gz.sha256
tar -xzf loom-v0.1.0-x86_64-linux.tar.gz
cd loom-v0.1.0-x86_64-linux
nix-store --import < loom.closure
nix profile install "$(< store-path)"
loom --version
loom
```

Substitute the chosen release's version in the filenames. The commands use Bash.
The profile keeps the imported runtime alive across Nix garbage collection and
makes `loom` available through the usual Nix profile `bin` directory.

On a multi-user Nix installation, importing locally exported store objects may
require a trusted Nix user. If the daemon rejects the import, ask the administrator
to import the reviewed archive. Do not disable signature verification globally.
Alternatively, install the reviewed release tag or commit from the flake:

```sh
nix profile install github:nerima-lisp/loom/<reviewed-tag-or-commit>
```
