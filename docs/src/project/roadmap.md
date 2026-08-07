# Roadmap

loom is an MVP-stage terminal editor. This page separates what is
implemented today from what is deliberately deferred.

## Implemented today

- **Buffer editing** -- insert/delete, Emacs-style kill-ring/yank, multi-level
  undo grouped by command boundary.
- **Movement** -- character/line motion, beginning/end of line.
- **Emacs-style keybindings** -- `install-default-keybindings` binds the
  default `C-x`/`C-c` prefix sequences; see
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
- **`--help` / `--version` CLI flags** -- built on `cl-cli`; see `*loom-app*`
  in [`src/main.lisp`](https://github.com/nerima-lisp/loom/blob/main/src/main.lisp).
- **Measured test and coverage paths** -- the integrated tree currently
  reports 313 passed tests with no skips, todos, failures, or errors when the
  regression suite is run with
  `nix develop -c sbcl --script run-tests.lisp`. The cl-weave suite includes
  `it-each`, `it-property`, `it-fuzz`, continuation observations, soft
  assertions, function replacement, and a real-PTY smoke test. Unit tests are
  under `t/unit/`, integration tests are under `t/integration/`, and
  `t/e2e/loom-test.py` launches the built executable through a Unix PTY to
  verify the process-level CLI and edit/save/exit path. Measure coverage with
  `LOOM_COVERAGE_DIR=/tmp/loom-coverage nix develop -c sbcl --script
  scripts/coverage.lisp`; record SB-COVER expression and branch totals
  separately rather than treating branch coverage as a full-coverage
  guarantee.

## Not yet implemented

These are future phases, not part of the MVP, and are called out explicitly
so their absence does not read as a bug:

- **Syntax highlighting.**
- **An LSP client.**
- **Extensibility via a user `init.lisp`.**
- **Session/layout persistence** across launches.
- **A buffer-list registry** -- `switch-to-buffer` currently searches only
  the buffers already displayed in some window of the current window tree.
## Released changes

See the [GitHub Releases](https://github.com/nerima-lisp/loom/releases).
