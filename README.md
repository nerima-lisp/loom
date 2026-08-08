# loom

[![CI](https://github.com/nerima-lisp/loom/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/nerima-lisp/loom/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

`loom` is a terminal text editor for SBCL with Emacs-style keybindings. It
calls the usable APIs from these packages directly at their actual boundaries:
[`cl-tty-kit`](https://github.com/nerima-lisp/cl-tty-kit) for raw-mode terminal
I/O and double-buffered rendering,
[`cl-host-kit`](https://github.com/nerima-lisp/cl-host-kit) and
[`cl-boundary-kit`](https://github.com/nerima-lisp/cl-boundary-kit) for
filesystem access, [`cl-history-kit`](https://github.com/nerima-lisp/cl-history-kit) for
minibuffer input recall, [`cl-prolog`](https://github.com/nerima-lisp/cl-prolog)
for quit-prompt resolution,
[`cl-regex-kit`](https://github.com/nerima-lisp/cl-regex-kit) for regular-
expression search and replace, and
[`cl-cli`](https://github.com/nerima-lisp/cl-cli) for argv parsing (`--help`/
`--version`). [`cl-concurrent-kit`](https://github.com/nerima-lisp/cl-concurrent-kit)
provides the executor, channel, and promise primitives used by the bounded
concurrent file-tree runtime.

Implemented today: buffer editing (insert/delete/undo, Emacs-style
movement/kill-ring/yank), regular-expression search and replace, a working
raw-mode terminal event loop, multiple windows via horizontal/vertical splits
(`C-x 2` / `C-x 3` / `C-x o`), and a file-tree sidebar (`C-x C-t`) backed by
real filesystem create/rename/delete. See `install-default-keybindings` in
`src/application/commands-keybindings.lisp` for the full keybinding set, and
the `command-spec` and `define-command-specs` forms in
`src/application/commands-misc.lisp` for the M-x registry (every keybound
command is M-x-reachable; a regression test enforces this). Not yet implemented:
syntax highlighting, an LSP client,
extensibility via a user `init.lisp`, and session/layout persistence across
launches -- these are future phases, not part of this MVP.

## Quick start

The repository is built and tested with [Nix flakes](https://nixos.wiki/wiki/Flakes).

```sh
# Enter a development shell with SBCL and the runtime/test dependencies
# (cl-tty-kit, cl-host-kit, cl-history-kit, cl-prolog, cl-cli, cl-regex-kit,
# cl-boundary-kit, cl-concurrent-kit) on CL_SOURCE_REGISTRY.
# The test system additionally needs cl-weave and cl-date-kit.
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

# Run every check (test suite, build, formatting, and strict docs) the way CI does:
nix flake check --print-build-logs

# Verify the Nix formatter without rewriting files:
nix fmt -- --ci

# Measure coverage; keep the generated report outside the checkout:
LOOM_COVERAGE_DIR=/tmp/loom-coverage nix develop -c sbcl --script scripts/coverage.lisp

# Compare synchronous directory listing with the concurrent file-tree runtime:
nix develop -c sbcl --script scripts/benchmark-concurrency.lisp
```

Without Nix: put `loom` alongside checkouts of `cl-tty-kit`, `cl-host-kit`,
`cl-history-kit`, `cl-prolog`, `cl-cli`, `cl-regex-kit` (and its own
`cl-parser-kit` dependency), `cl-boundary-kit`, `cl-concurrent-kit`, and
`cl-weave` plus `cl-date-kit` for the test system (e.g. all under the same
`ghq`-style parent directory), then either

```sh
sbcl --script run-tests.lisp
```

or, from a REPL:

```lisp
(push #P"/path/to/loom/" asdf:*central-registry*)
(asdf:load-system "loom/test")
(funcall (symbol-function (find-symbol "RUN-TESTS" :loom/test)))
```

## Default keys

- `C-f` / `C-b`, `C-n` / `C-p`, `M-f` / `M-b`, `C-a` / `C-e`, `M-<` / `M->`,
  `C-v` / `M-v`: move point, by word, by line, to a buffer boundary, or scroll.
- `Enter`, `C-d`, Backspace, `C-o`: insert a newline, delete, or open a line;
  `C-x u`: undo.
- `C-k`, `M-d`, `M-Backspace`, `C-w`: kill a line, word, backward word, or
  region; `C-y`: yank.
- `C-Space`, `C-x C-x`, `C-x h`: set the mark, exchange point and mark, or mark
  the whole buffer.
- `C-s`, `M-%`, `M-g g`: search, replace all matches, or go to a line. Search
  and replace text is a `cl-regex-kit` regular expression, not a literal
  substring; the replacement text itself stays literal.
- `C-r`: search backward.
- `C-x C-f`, `C-x C-s`, `C-x C-w`: open, save, or write the current buffer to a
  path.
- `C-x 2`, `C-x 3`, `C-x o`, `C-x 0`, `C-x 1`, `C-x b`: split, move between,
  delete, delete-other, or switch windows.
- `C-x C-t`, `C-c n`, `C-c p`, `C-c o`, `C-c c`, `C-c d`: open the file tree,
  move to the next/previous entry, open, create, or delete an entry.
- `C-g`: keyboard quit; `C-x C-c`: quit. Quit asks how to handle every
  modified buffer.
- `C-h` or `F1`: show the in-editor command reference.
- `M-x`: run a command by its name through `execute-extended-command`; it is
  registered by the same command-spec table as the default keybindings.

The CLI accepts `--help`, `--version`, and one optional positional path. A file
opens in the first window, a directory becomes the file-tree root, and no path
defaults to `.`. `loom:main` delegates argument parsing to `cl-cli`, then runs
the raw-terminal event loop until `C-x C-c` or end-of-input.

## Layout

- `loom.asd` -- the `loom` and `loom/test` ASDF systems.
- `src/package.lisp` -- the single `#:loom` package and its export list.
- `src/domain/` -- pure state/logic: buffer text/undo (including
  `cl-regex-kit`-backed search/replace matching), window-tree layout, keymap
  dispatch, and file-tree state. Domain code does not perform terminal or
  filesystem I/O.
- `src/infrastructure/` -- terminal rendering, filesystem access, and the
  concurrent file-tree runtime. The runtime caches directory entries, bounds
  submitted work, and applies worker results on the render lane.
  `cl-boundary-kit` supplies the filesystem boundary used by the normal
  operations (`*loom-filesystem*` is rebound to an in-memory fake in tests),
  while `cl-host-kit` is called directly for directory-entry classification
  and symlink-safe recursive deletion.
- `src/application/` -- orchestration: the shared `editor-state` struct and
  `*editor-state*` special variable every command operates on, the
  minibuffer, and the command/keybinding vocabulary, split by concern
  (`commands-internal`, `-movement`, `-editing`, `-search`, `-file`,
  `-window`, `-misc`, `-keybindings`). Commands call the usable
  `cl-tty-kit`, `cl-history-kit`, and `cl-host-kit` APIs directly
  where those operations belong; there is no wrapper layer that only hides a
  package that already provides the needed operation.
- `src/presentation/` -- screen composition (`compose-frame`): what to draw
  where, given the current `editor-state`.
- `src/main.lisp` -- the `loom:main` entry point saved into the executable.
- `t/` -- the ASDF `loom/test` suite, using
  [`cl-weave`](https://github.com/nerima-lisp/cl-weave) and `cl-date-kit`.
  `loom.asd` loads `package`, `protocol-test`, `buffer-test`,
  `terminal-renderer-test`, `filesystem-test`, `window-test`, `keymap-test`,
  `file-tree-test`, `minibuffer-test`, `commands-test`,
  `commands-movement-test`, `commands-editing-test`, `commands-misc-test`,
  `commands-keybindings-test`, `layout-test`, `main-test`,
  `concurrent-runtime-test`, `advanced-test`, `unit/cli-test`, and
  `integration/editor-flow-test` in serial order. `run-tests.lisp` loads this
  same `loom/test` system before calling `loom/test:run-tests`.
  `main-test` includes a real-PTY smoke test in addition to fake-terminal tests.
  `t/e2e/loom-test.py` is outside ASDF and separately launches the built
  executable through a Unix PTY to cover the process-level CLI and edit/save/exit
  path:

  ```sh
  nix build
  LOOM_BINARY="$PWD/result/bin/loom" python3 t/e2e/loom-test.py
  ```
- `docs/` -- the `mkdocs`-built documentation site (this file included),
  built with `--strict` as `flake.nix`'s `checks.docs`.
- `run-tests.lisp` -- the single script entry point for running the suite,
  used both locally and by `flake.nix`'s `checks.default`; bounded by an
  in-script 600s `sb-ext:with-timeout` in addition to `checks.default`'s own
  Nix-level timeout, so a plain local run cannot hang forever.
- `scripts/coverage.lisp` -- runs the suite under `sb-cover` and writes an
  HTML report to `coverage/` (override with `LOOM_COVERAGE_DIR`); bounded by
  its own 1800s `sb-ext:with-timeout`, since it force-recompiles loom and
  every sibling dependency under `sb-cover` instrumentation. Report the
  measured expression and branch totals separately; branch coverage is not a
  substitute for expression coverage. SB-COVER is process-local, so the raw
  report can retain top-level declaration forms and the child-process-only
  `loom:main` path; those forms are reported rather than hidden. Generated
  reports are not tracked.
- `scripts/benchmark-concurrency.lisp` -- loads `loom`, submits eight directory
  paths to the bounded runtime, drains worker results, and prints synchronous,
  asynchronous, accepted-count, and speedup measurements. Run it with
  `nix develop -c sbcl --script scripts/benchmark-concurrency.lisp`.
- `flake.nix` -- Nix packaging: `packages.default` (the built binary),
  `checks.default` (the test suite), `checks.build`, `checks.formatting`,
  `checks.docs`, and `devShells.default`. It materializes the source root
  before the cl-nix-forge fileset filter so newly split files under
  `src/application/` remain in the archive even when the Git source omits
  untracked worktree files.
