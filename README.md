# loom

[![CI](https://github.com/nerima-lisp/loom/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/nerima-lisp/loom/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

`loom` is a terminal text editor for SBCL with Emacs-style keybindings. It is
built on [`cl-tty-kit`](https://github.com/nerima-lisp/cl-tty-kit) for raw-mode
terminal I/O and double-buffered rendering,
[`cl-host-kit`](https://github.com/nerima-lisp/cl-host-kit) for filesystem
access, [`cl-history-kit`](https://github.com/nerima-lisp/cl-history-kit) for
minibuffer input recall, [`cl-prolog`](https://github.com/nerima-lisp/cl-prolog)
for the M-x extended-command registry, and
[`cl-cli`](https://github.com/nerima-lisp/cl-cli) for argv parsing (`--help`/
`--version`).

Implemented today: buffer editing (insert/delete/undo, Emacs-style
movement/kill-ring/yank), a working raw-mode terminal event loop, multiple
windows via horizontal/vertical splits (`C-x 2` / `C-x 3` / `C-x o`), and a
file-tree sidebar (`C-x C-t`) backed by real filesystem create/rename/delete.
See `install-default-keybindings` in `src/application/commands-keybindings.lisp` for the
full keybinding set. Not yet implemented: syntax highlighting, an LSP client,
extensibility via a user `init.lisp`, and session/layout persistence across
launches -- these are future phases, not part of this MVP.

## Quick start

The repository is built and tested with [Nix flakes](https://nixos.wiki/wiki/Flakes).

```sh
# Enter a development shell with SBCL and every sibling dependency
# (cl-tty-kit, cl-host-kit, cl-history-kit, cl-prolog, cl-cli, cl-weave) on
# CL_SOURCE_REGISTRY.
nix develop

# Inside the shell:
test          # run the full loom/test suite (alias for the command below)
sbcl --script run-tests.lisp

# Build the loom binary (dumps an SBCL image via save-lisp-and-die):
nix build
./result/bin/loom --help
./result/bin/loom --version
./result/bin/loom
# A directory opens the file tree; an existing file opens in the first window.
./result/bin/loom path/to/file.lisp

# Run every check (test suite, build, formatting) the way CI does:
nix flake check --print-build-logs
```

Without Nix: put `loom` alongside checkouts of `cl-tty-kit`, `cl-host-kit`,
`cl-history-kit`, `cl-prolog`, `cl-cli`, and `cl-weave` (e.g. all under the
same `ghq`-style parent directory), then either

```sh
sbcl --script run-tests.lisp
```

or, from a REPL:

```lisp
(push #P"/path/to/loom/" asdf:*central-registry*)
(asdf:load-system :loom)
(asdf:test-system :loom)
```

## Default keys

- `C-f` / `C-b`, `C-n` / `C-p`, `C-a` / `C-e`: move point.
- `Enter`, `C-d`, Backspace, `C-o`: insert a newline, delete, or open a line; `C-x u`: undo.
- `C-k`, `C-w`, `C-y`: kill line or region, then yank.
- `C-s`, `M-%`, `M-g g`: search, replace all matches, or go to a line.
- `C-x C-f`, `C-x C-s`, `C-x C-c`: open, save, or quit. Quit asks how to handle every modified buffer.
- `C-h` or `F1`: show the in-editor command reference.
- `C-x 2`, `C-x 3`, `C-x o`: split windows or move to the next window.

## Layout

- `loom.asd` -- the `loom` and `loom/test` ASDF systems.
- `src/package.lisp` -- the single `#:loom` package and its export list.
- `src/domain/` -- pure state/logic with no dependency on the sibling
  libraries: buffer text/undo, window-tree layout, keymap dispatch, and
  file-tree state.
- `src/infrastructure/` -- adapters to the sibling libraries: terminal
  rendering (`cl-tty-kit`) and filesystem access (`cl-host-kit`).
- `src/application/` -- orchestration: the shared `editor-state` struct and
  `*editor-state*` special variable every command operates on, the
  minibuffer, and the command/keybinding vocabulary, split by concern
  (`commands-internal`, `-movement`, `-editing`, `-search`, `-file`,
  `-window`, `-misc`, `-keybindings`).
- `src/presentation/` -- screen composition (`compose-frame`): what to draw
  where, given the current `editor-state`.
- `src/main.lisp` -- the `loom:main` entry point saved into the executable.
- `t/` -- the `loom/test` suite, using
  [`cl-weave`](https://github.com/nerima-lisp/cl-weave) (`describe`/`it`/`expect`).
- `run-tests.lisp` -- the single script entry point for running the suite,
  used both locally and by `flake.nix`'s `checks.default`.
- `flake.nix` -- Nix packaging: `packages.default` (the built binary),
  `checks.default` (the test suite), `checks.build`, `checks.formatting`, and
  `devShells.default`.
