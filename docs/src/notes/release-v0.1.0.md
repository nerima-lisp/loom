# loom v0.1.0

loom is a terminal text editor written in Common Lisp that runs on SBCL,
with Emacs-style keybindings.

## Features

- Edit text with incremental search and replacement, the kill ring, and Lisp
  structural editing and indentation.
- Manage windows, save and restore editor sessions, select language modes,
  navigate the file tree, and enable auto-save for modified file-backed buffers.
- Run terminal sessions backed by a pseudo-terminal (PTY) and shell commands;
  inspect Git status and diffs, and stage changes.
- Use external formatters and configured language servers for diagnostics,
  completion, definition navigation, hover, references, rename, and formatting.
  The available language-server features depend on the server. See
  `docs/src/guide/core-concepts.md` for setup details.

## Installation

Nix with flakes enabled is required.

### Nix

Run v0.1.0 with a file:

```sh
nix run github:nerima-lisp/loom/v0.1.0 -- path/to/file.lisp
```

Without a file path, loom opens the current directory in the file tree.
To install v0.1.0 into a Nix profile:

```sh
nix profile install github:nerima-lisp/loom/v0.1.0
```

The Nix flake supports `x86_64-linux` and `aarch64-darwin`.

### Linux release archive

The release archive targets `x86_64-linux` only. It includes the Nix runtime
closure, including SBCL and the editor image. It is not a standalone executable.
Download the archive and its matching `.sha256` file from this release, then
verify and install it:

```sh
shasum -a 256 -c loom-v0.1.0-x86_64-linux.tar.gz.sha256
tar -xzf loom-v0.1.0-x86_64-linux.tar.gz
cd loom-v0.1.0-x86_64-linux
nix-store --import < loom.closure
nix profile install "$(< store-path)"
loom --version
loom
```

The archive also contains a `store-path` file. The Nix profile command uses the
store path it lists. On a multi-user Nix installation, if the daemon rejects the
import, ask an administrator to import the archive. Do not disable signature
verification.

## Verification

Release CI runs Nix flake checks and the complete PTY interaction suite on
`x86_64-linux` and Apple Silicon (`aarch64-darwin`). CI exercises every recorded
interaction route on both systems.

The path-coverage gate fails CI when a required interaction path is missing or
an excluded path has no reason. In the full run, both systems reported 1,057
passed paths, 2 documented exclusions, and 0 failures out of 1,059 required
paths.

The PTY performance gate checks these CI thresholds:

- First screen within 0.3 seconds.
- Display the first row of a 100,000-line, 5 MB file within 1.0 second after
  pressing Enter on the filename.
- Keep input-to-redraw p95 within 50 ms across 100 key-movement samples.
- In a 20,000-line buffer, update the cursor after one `C-f` keypress within
  50 ms.

These are CI thresholds, not measured timings for every system.

## Known limitations

The PTY screen model handles common cursor movement and erasure, cursor
save/restore, and the minimal alternate-screen mode used by many full-screen
programs. It does not implement full VT compatibility, so programs that need
richer terminal features may not display correctly.

The author chose to release v0.1.0 before manually validating Japanese text
entry with a real IME, OSC 52 clipboard transfer through the terminal emulator,
mouse input, bracketed paste, or a representative daily editing task. The
corresponding `Author result` cells in
`docs/src/notes/daily-driver-checklist.md` remain blank.
