# Roadmap

loom is an MVP-stage terminal editor. This page separates what is
implemented today from what is deliberately deferred.

## Implemented today

- **Buffer editing** -- insert/delete, Emacs-style kill-ring/yank, multi-level
  undo grouped by command boundary.
- **Movement** -- character/line motion, beginning/end of line.
- **Emacs-style keybindings** -- `install-default-keybindings` installs the
  command registry's movement, editing, search, file, window, file-tree,
  help, keyboard-quit, and quit bindings, including the `C-x`/`C-c` prefix
  sequences; see
  [`src/application/commands-keybindings.lisp`](https://github.com/nerima-lisp/loom/blob/main/src/application/commands-keybindings.lisp).
- **Window management** -- horizontal/vertical splits (`C-x 2` / `C-x 3`),
  window selection (`C-x o`), per-window buffer switching (`C-x b`).
- **File-tree sidebar** (`C-x C-t`) -- navigate, and create/rename/delete
  files and directories on disk, using `cl-boundary-kit` for normal
  operations and direct `cl-host-kit` calls where filesystem guarantees
  require them.
- **File I/O** -- `find-file` (`C-x C-f`), `save-buffer` (`C-x C-s`).
- **Regular-expression search and replacement** -- `C-s`, `M-%`, and
  `M-g g`, using `cl-regex-kit` patterns with a bounded search operation.
- **M-x command registry and prompts** -- extended commands resolve through
  the declarative `command-spec` table; quit confirmation uses `cl-prolog`, and
  minibuffer history uses `cl-history-kit` directly.
- **Raw-mode terminal event loop** -- built on `cl-tty-kit`, with a
  double-buffered renderer.
- **Bounded concurrent file-tree runtime** -- `cl-concurrent-kit` workers
  prefetch uncached directory listings, while generation checks, cache
  invalidation, and render-lane draining prevent stale results from changing
  editor state. The default is four workers with a queue capacity of 64.
- **CLI** -- built on `cl-cli`; `--help`/`-h`, `--version`/`-V`, and one
  optional positional path are supported. A file opens in the first window,
  a directory becomes the file-tree root, and no path defaults to `.`. See
  `*loom-app*` in
  [`src/main.lisp`](https://github.com/nerima-lisp/loom/blob/main/src/main.lisp).
- **Integrated test, coverage, and benchmark paths** -- the `loom/test` ASDF
  system loads these components in order:

  ```text
  package, protocol-test, buffer-test, terminal-renderer-test,
  filesystem-test, window-test, keymap-test, file-tree-test,
  minibuffer-test, commands-test, commands-movement-test,
  commands-editing-test, commands-misc-test, commands-keybindings-test,
  layout-test, main-test, concurrent-runtime-test, advanced-test,
  unit/cli-test, integration/editor-flow-test
  ```

  Run the integrated suite with
  `nix develop -c sbcl --script run-tests.lisp`. The process-level CLI/edit/
  save/exit checks remain in `t/e2e/loom-test.py` and run against the built
  executable:

  ```sh
  nix build
  LOOM_BINARY="$PWD/result/bin/loom" python3 t/e2e/loom-test.py
  ```

  Measure coverage with
  `LOOM_COVERAGE_DIR=/tmp/loom-coverage nix develop -c sbcl --script
  scripts/coverage.lisp`; record SB-COVER expression and branch totals
  separately. SB-COVER is process-local, so top-level declarations and the
  child-process-only `loom:main` path can remain unexecuted; inspect and report
  those forms rather than hiding them. Compare synchronous listing with the
  concurrent runtime using
  `nix develop -c sbcl --script scripts/benchmark-concurrency.lisp`, which
  reports timings, accepted tasks, and derived speedup.

## 2026 refactor status

The bounded concurrent file-tree runtime and its ASDF-integrated
`concurrent-runtime-test` are implemented in the current source. This marks
the runtime portion of the 2026 refactor objective as present; it does not
make the deferred editor features below complete.

## Not yet implemented

These are future phases, not part of the MVP, and are called out explicitly
so their absence does not read as a bug:

- **Syntax highlighting.**
- **An LSP client.**
- **Extensibility via a user `init.lisp`.**
- **Session/layout persistence** across launches.
- **Buffer lifecycle management.** A session-wide buffer registry and
  `switch-to-buffer` lookup are implemented; unregistering/`kill-buffer` and
  completion UI remain future work.

## Released changes

### v0.1.0

The MVP release consolidates the 2026 editor modernization, bounded concurrent
file-tree runtime, integrated unit/integration/e2e test paths, and the
session-wide buffer registry with `switch-to-buffer` lookup.

Release artifacts and release notes are managed through [GitHub Releases](https://github.com/nerima-lisp/loom/releases).
