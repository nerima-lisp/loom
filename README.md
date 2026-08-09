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
movement/kill-ring/yank, numeric prefix arguments), regular-expression search and replace, a working
raw-mode terminal event loop, multiple windows via horizontal/vertical splits
(`C-x 2` / `C-x 3` / `C-x o`), and a file-tree sidebar (`C-x C-t`) backed by
real filesystem create/rename/delete. See `install-default-keybindings` in
`src/application/commands-keybindings.lisp` for the full keybinding set, and
the `command-spec` and `define-command-specs` forms in
`src/application/commands-misc.lisp` for the M-x registry (every keybound
command is M-x-reachable; a regression test enforces this). The session also
maintains a buffer registry with `switch-to-buffer`, `kill-buffer`, and
case-insensitive minibuffer prefix completion, plus line-local Common Lisp
syntax highlighting rendered through the presentation layer. Explicit session
save/load (`C-x r S` / `C-x r l`) persists buffers, cursor/mark state, modified
flags, window layout, and the selected window. A user `init.lisp` can extend
the command registry and active keymap at startup. Common Lisp evaluation is
available through `M-:` (forms) and `C-x C-e` (the selected buffer), with
results appended to `*Loom-Eval*`; evaluation is trusted code in `LOOM-USER`,
like the user-init extension. A minimal LSP client is available through
`M-x lsp-start`, `M-x lsp-stop`, and `M-x lsp-diagnostics`: it starts a prompted
external server over stdio, synchronizes the selected file-backed buffer, and
renders `publishDiagnostics` messages in `*Loom-Diagnostics*`. URI escaping,
capability negotiation, and the graceful shutdown/exit handshake are deferred;
the server command is trusted input.

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

## User init

Loom loads an optional Common Lisp startup file after creating the editor
state and before entering the terminal loop. Set `LOOM_INIT_FILE` to an
explicit path; otherwise Loom checks `~/.loom/init.lisp`. The file is
evaluated in the `loom-user` package, which uses both `cl` and `loom`, so
exported editor APIs are available without an `in-package` form.

The file is trusted Common Lisp code. If it signals an error, startup reports
the error and exits. `define-command` adds a command to M-x and, when Loom is
active, binds its `:keys` in the current keymap. `bind-key` changes only the
current keymap:

```lisp
(defun hello-from-init ()
  (minibuffer-message
   (editor-state-minibuffer *editor-state*)
   "Hello from init"))

(define-command "hello-from-init" #'hello-from-init
  :keys '(((:control #\c) #\i)))

(bind-key '((:control #\x) (:control #\s)) "save-buffer")
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
- `C-u`, `M-0` … `M-9`, `M--`: repeat the next command with a universal or
  explicit numeric prefix, including movement, editing, and self-insert.
- `C-x C-f`, `C-x C-s`, `C-x C-w`: open, save, or write the current buffer to a
  path.
- `C-x r S`, `C-x r l`: save or load the complete editor session.
- `C-x r s`, `C-x r i`, `C-x r SPC`, `C-x r j`: copy or insert text and save
  or jump to named registers.
- `C-x (`, `C-x )`, `C-x e`: start, stop, or replay a keyboard macro.
- `M-:`, `C-x C-e`: evaluate forms or the selected buffer in `LOOM-USER`.
- `M-x lsp-start`, `M-x lsp-stop`, `M-x lsp-diagnostics`: start or stop the
  prompted LSP server and refresh diagnostics for the selected file-backed
  buffer.
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
- `src/<DDD>/` -- the composition root and shared editor route. It contains
  the remaining cross-feature domain, application, infrastructure, and
  presentation code (`keymap`, `editor-state`, `minibuffer`, terminal
  renderer, layout, and `main`).
- `packages/README.md` -- the package-by-feature map and the rule for keeping
  DDD roles explicit in package-local filenames.
- `packages/core/editor/` -- reusable editing vocabulary: the buffer
  piece-table/storage domain and the movement/editing application commands.
- `packages/feature/<feature>/` -- complete feature slices for `file-tree`,
  `search`, `window`, `session`, `evaluation`, `lsp`, `user-init`,
  `syntax-highlighting`, `register`, and `keyboard-macro`. Each slice keeps
  `domain-*`, `application-*`,
  `infrastructure-*`, and `presentation-*` files together; `loom.asd` is the
  composition boundary that loads them in dependency order. The files keep
  the existing `#:loom` public API while the filesystem/build boundary is
  package-by-feature.
- `src/infrastructure/` -- the remaining shared infrastructure: terminal
  rendering. Feature-owned infrastructure lives under its feature package;
  the same applies to feature-owned application and presentation code.
  `cl-boundary-kit` supplies the filesystem boundary used by normal file
  operations (`*loom-filesystem*` is rebound to an in-memory fake in tests),
  while `cl-host-kit` is called directly where directory-entry classification
  and symlink-safe recursive deletion require it.
- `src/application/` -- shared orchestration: the `editor-state` struct,
  `*editor-state*`, minibuffer, command registry, and keybinding composition.
  Commands call usable toolkit APIs directly where those operations belong;
  there is no wrapper layer that only hides a package that already provides
  the needed operation.
- `src/presentation/` -- screen composition (`compose-frame`): what to draw
  where, given the current `editor-state`.
- `src/main.lisp` -- the `loom:main` entry point saved into the executable.
- `t/unit/` -- focused domain, boundary, renderer, keymap, minibuffer, and
  CLI tests; `t/integration/` -- command, feature, layout, session,
  concurrent-runtime, and editor-flow tests; `t/e2e/` -- process-level tests.
  The ASDF `loom/test` suite uses [`cl-weave`](https://github.com/nerima-lisp/cl-weave)
  and `cl-date-kit`, and loads the unit and integration directories in serial
  order. `run-tests.lisp` loads the same system before calling
  `loom/test:run-tests`. `main-test` includes a real-PTY smoke test in addition
  to fake-terminal tests. `t/e2e/loom-test.py` separately launches the built
  executable through a Unix PTY to cover the external CLI and edit/save/exit
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
  every sibling dependency under `sb-cover` instrumentation. The report is
  restricted to Loom's `src/` and `packages/` trees, so package-by-feature
  code is included. Report the measured expression and branch totals
  separately; branch coverage is not a substitute for expression coverage.
  SB-COVER is process-local, so the raw report can retain top-level
  declaration forms and the child-process-only `loom:main` path; those forms
  are reported rather than hidden. Generated reports are not tracked.
- `scripts/benchmark-concurrency.lisp` -- loads `loom`, submits eight directory
  paths to the bounded runtime, drains worker results, and prints synchronous,
  asynchronous, accepted-count, and speedup measurements. Run it with
  `nix develop -c sbcl --script scripts/benchmark-concurrency.lisp`.
- `flake.nix` -- Nix packaging: `packages.default` (the built binary),
  `checks.default` (the test suite), `checks.build`, `checks.formatting`,
  `checks.docs`, and `devShells.default`. It materializes the source root
  before the cl-nix-forge fileset filter so newly split files under
  `src/` and `packages/` remain in the archive even when the Git source omits
  untracked worktree files.
