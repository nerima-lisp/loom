# Roadmap

loom is an MVP-stage terminal editor. This page separates what is
implemented today from what is deliberately deferred.

## Implemented today

- **Buffer editing** -- insert/delete, Emacs-style kill-ring/yank, numeric
  prefix arguments, and multi-level undo grouped by command boundary.
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
- **Syntax highlighting** -- line-local Common Lisp highlighting is modeled as
  a pure feature domain and rendered through the presentation boundary.
- **Major modes and project navigation** -- buffers infer a mode from their
  path, `M-x set-major-mode` can override it, and `C-x p f`, `C-x p s`, and
  `C-x p r` find files, search project contents, and show the project root.
- **Common Lisp evaluation** -- `M-:` and `C-x C-e` evaluate trusted forms in
  `LOOM-USER` and append structured results or errors to `*Loom-Eval*`.
- **LSP client slice** -- `lsp-start`, `lsp-stop`, and `lsp-diagnostics` use a
  prompted stdio server, synchronize file-backed buffers, and render
  `publishDiagnostics` messages in `*Loom-Diagnostics*`.
- **User extension** -- `LOOM_INIT_FILE` or `~/.loom/init.lisp` can register
  commands and keybindings before the terminal loop starts.
- **Session and buffer lifecycle** -- explicit session save/load persists
  buffers and window layout; `switch-to-buffer`, `kill-buffer`, and
  case-insensitive minibuffer prefix completion manage the buffer registry.
- **Registers and keyboard macros** -- named text/point registers and
  record/replay keyboard macros are available through the `C-x r` and `C-x`
  bindings.
- **CLI** -- built on `cl-cli`; `--help`/`-h`, `--version`/`-V`, and one
  optional positional path are supported. A file opens in the first window,
  a directory becomes the file-tree root, and no path defaults to `.`. See
  `*loom-app*` in
  [`src/main.lisp`](https://github.com/nerima-lisp/loom/blob/main/src/main.lisp).
- **Integrated test, coverage, and benchmark paths** -- the `loom/test` ASDF
  system loads these components in order:

  ```text
  package, unit/protocol-test, unit/buffer-test,
  unit/syntax-highlighting-test, unit/terminal-renderer-test,
  unit/filesystem-test, unit/window-test, unit/keymap-test,
  unit/file-tree-test, unit/minibuffer-test, unit/evaluation-test,
  unit/cli-test, unit/register-test, unit/keyboard-macro-test,
  unit/prefix-argument-test,
  integration/commands-test, integration/lsp-test,
  integration/commands-movement-test, integration/commands-editing-test,
  integration/commands-misc-test, integration/commands-keybindings-test,
  integration/register-test, integration/keyboard-macro-test,
  integration/prefix-argument-test,
  integration/user-init-test, integration/layout-test, integration/session-test,
  integration/main-test, integration/concurrent-runtime-test,
  integration/advanced-test, integration/editor-flow-test
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
  separately. The report covers Loom's `src/` and `packages/` trees, including
  package-by-feature code. SB-COVER is process-local, so top-level declarations
  and the child-process-only `loom:main` path can remain unexecuted; inspect
  and report those forms rather than hiding them. Compare synchronous listing
  with the concurrent runtime using
  `nix develop -c sbcl --script scripts/benchmark-concurrency.lisp`, which
  reports timings, accepted tasks, and derived speedup.

## 2026 refactor status

The bounded concurrent file-tree runtime and its ASDF-integrated
`concurrent-runtime-test` are implemented in the current source. This marks
the runtime portion of the 2026 refactor objective as present; it does not
make the deferred editor features below complete.

## Not yet implemented

These are follow-up phases rather than claims that the current editor is a
complete Lem or Emacs replacement:

- **Richer LSP protocol support.** URI escaping, capability negotiation, and
  the graceful shutdown/exit handshake are still deferred; the prompted server
  command is trusted input.
- **Broader editing surface.** Narrowing, region-aware kill/yank variants,
  and a richer package/extension distribution story remain future work.
- **Feature package isolation.** The filesystem and ASDF boundaries are now
  package-by-feature, while the public Common Lisp symbols remain in `#:loom`
  for compatibility. Splitting those symbols into independently loadable
  namespaces is a later compatibility-sensitive step.

## Released changes

### v0.1.0

The MVP release consolidates the 2026 editor modernization, bounded concurrent
file-tree runtime, integrated unit/integration/e2e test paths, and the
session-wide buffer registry with `switch-to-buffer` lookup.

Release artifacts and release notes are managed through [GitHub Releases](https://github.com/nerima-lisp/loom/releases).
