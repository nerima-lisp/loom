# Roadmap

This page separates the current implementation from deliberately deferred
work. Deferred items are not production-readiness claims.

## Implemented today

- **Buffer editing** -- insert/delete, Emacs-style kill-ring/yank, numeric
  prefix arguments, multi-level undo grouped by command boundary, and
  restriction-aware narrowing/widening (`C-x n n` / `C-x n w`), plus
  read-only buffers with an interactive toggle (`C-x C-q`).
- **Movement** -- character/line motion, beginning/end of line, and go-to-line
  (`M-g g`).
- **Emacs-style keybindings** -- `install-default-keybindings` installs the
  command registry's movement, editing, search, file, window, file-tree,
  session, register, recent-file, bookmark, shell, help, keyboard-quit, and quit
  bindings, including the `C-x`/`C-c` prefix sequences. Feature bindings are
  declared in their `command-specs-*.lisp` files and installed by
  `packages/core/command/src/commands-keybindings.lisp`.
- **Window management** -- horizontal/vertical splits (`C-x 2` / `C-x 3`),
  window selection (`C-x o`), per-window buffer switching (`C-x b`).
- **Named workspaces** -- create, switch, cycle, and kill independent window
  trees with `C-x t 2`, `C-x t o`, `C-x t n`, `C-x t p`, and `C-x t k`; the
  active workspace is shown in the shortcut line and persisted by sessions.
- **File-tree sidebar** (`C-x d`) -- navigate, and create/rename/delete
  files and directories on disk, using `cl-boundary-kit` for normal and
  testable operations. The direct native path is limited to the real
  filesystem with wild pathnames; `cl-host-kit` covers host-level filesystem
  paths that require it.
- **File I/O** -- `find-file` (`C-x C-f`), `save-buffer` (`C-x C-s`).
- **Search and replacement** -- `C-s` / `C-r` search literal text
  incrementally; `C-M-s` / `C-M-r` search regular expressions incrementally.
  `M-%` starts literal query replacement and `C-M-%` starts regular-expression
  query replacement. `M-x search-forward` and `M-x search-backward` perform
  non-incremental regular-expression searches with bounded operations.
- **M-x command registry and prompts** -- extended commands resolve through
  registered command specs. `packages/core/command/src/command-registry-build.lisp`
  validates declarative specs, and
  `packages/core/command/src/application-commands-extended-command.lisp` handles
  M-x lookup. Quit confirmation uses `cl-prolog-kit`, and minibuffer history
  uses `cl-history-kit` directly.
- **Raw-mode terminal event loop** -- built on `cl-tty-kit`, with a
  double-buffered renderer.
- **Interactive PTY terminals** -- `M-x terminal` starts a child process,
  translates editor key events into terminal input, polls output, handles
  resize, and displays the current bounded ANSI screen in a read-only buffer.
  The session retains cumulative raw output separately.
- **Bounded concurrent file-tree runtime** -- `cl-concurrent-kit` workers
  prefetch uncached directory listings, while generation checks, cache
  invalidation, and render-lane draining prevent stale results from changing
  editor state. The default is four workers with a queue capacity of 64.
- **Syntax highlighting** -- Common Lisp uses a reader-aware, line-local
  tokenizer; other modes use a lightweight tokenizer with mode-specific
  keywords and comment prefixes. Tokens are rendered through the presentation
  boundary. Multiline reader state is not retained.
- **Major modes and project navigation** -- buffers infer a mode from their
  path, `M-x set-major-mode` can override it, and `C-x p f`, `C-x p s`, and
  `C-x p r` find files, search project contents, and show the project root.
- **Common Lisp evaluation** -- `M-:` and `C-x C-e` evaluate trusted forms in
  `LOOM-USER` and append structured results or errors to `*Loom-Eval*`.
- **Shell command integration** -- `M-!` and `M-x pipe-command` run a command
  in the selected file's directory and append captured standard output,
  standard error, and the exit code to `*Loom-Pipe-Command*`.
- **Code formatting** -- `M-x format-current-buffer` sends the complete buffer
  to an external command and applies successful output as one undoable edit,
  preserving point and mark offsets.
- **Git status, staging, and diff integration** -- `C-x g` runs concise
  branch-aware status from the current project root; `M-x git-diff` and
  `M-x git-diff-staged` display working-tree and index patches; and
  `M-x git-stage-file` / `M-x git-unstage-file` prompt for a repository path
  before changing the index. Read-only result buffers show standard output,
  falling back to standard error when standard output is empty. Failed commands
  report their exit status in the minibuffer; staging commands report their
  outcome there as well.
- **Auto-save** -- `M-x auto-save-mode` enables global automatic saving and
  `M-x toggle-auto-save` enables it for the selected buffer; modified writable
  file-backed buffers are written to `#file-name#` sidecars from the event loop
  without clearing their normal modified state.
- **LSP client slice** -- `lsp-start`, `lsp-stop`, and `lsp-diagnostics` use a
  project-local `.loom-lsp` command when available (while allowing an
  explicit prompt override). A discovered command requires review of its
  configuration path, directory, and command, followed by the exact answer
  `yes` before execution. The client negotiates initialization capabilities,
  synchronize file-backed buffers with UTF-8 percent-encoded URIs, render
  `publishDiagnostics` messages in `*Loom-Diagnostics*`, and perform the
  `shutdown`/`exit` handshake with a timeout fallback. `lsp-completion-at-point`
  (`C-M-i`) requests completion and presents a capability-gated candidate
  popup; `lsp-hover-at-point` displays supported hover text in the minibuffer;
  `lsp-find-definition` (`M-.`) jumps to a returned local file and
  `lsp-pop-definition` (`M-,`) returns to the jump origin.
- **S-expression motion** -- `C-M-f` and `C-M-b` move by expression, `C-M-u`
  and `C-M-d` cross the enclosing parentheses, and `C-M-k` kills the expression
  after point. Parentheses inside a string, a comment, or a `#\` character
  literal are text rather than structure, and the parenthesis beside point is
  marked together with its partner -- or with nothing at all when the form does
  not balance.
- **Structural editing** -- `C-<right>` and `C-<left>` slurp and barf forward,
  `C-M-<left>` and `C-M-<right>` do the same backward, `M-(` wraps the next
  expression, `M-s` splices the enclosing list away and `M-r` raises the
  expression at point out of it. These commands transform delimiters and group
  each successful edit into a single undo step.
- **Incremental search** -- `C-s` and `C-r` move point to the next match on
  every keystroke, highlight all matches with the current one distinguished,
  advance or turn around on a further `C-s`/`C-r`, keep point on RET while
  filing the pattern in the minibuffer history, and return point to where the
  search began on `C-g`. `M-x search-forward` keeps the non-incremental form.
- **Line display** -- a window follows point horizontally in screen cells for a
  truncating buffer and wraps a long logical line across several rows for a
  wrapping one. The major mode picks the default -- code truncates, Markdown,
  Org, and plain text wrap -- and `M-x toggle-truncate-lines` overrides it per
  buffer. `next-line` and `previous-line` move by screen row.
- **User extension** -- `LOOM_INIT_FILE` or `~/.loom/init.lisp` can register
  commands and keybindings before the terminal loop starts.
- **Session and buffer lifecycle** -- explicit session save/load persists
  buffers, named workspace layouts, recent files, named bookmarks, and
  M-x/minibuffer command history in the canonical v6 format. The reader accepts
  legacy v5 and current v6 sessions; session files older than v5 are unsupported.
  `switch-to-buffer`, `kill-buffer`, and case-insensitive minibuffer prefix
  completion manage the buffer registry.
- **Recent files and named bookmarks** -- `C-x r f` opens the bounded,
  canonical recent-file list; `C-x r m`, `C-x r b`, `C-x r d`, and `C-x r l`
  set, jump to, delete, and list named bookmarks.
- **Registers and keyboard macros** -- named text/point registers and
  record/replay keyboard macros are available through the `C-x r` and `C-x`
  bindings.
- **CLI** -- built on `cl-cli`; `--help`/`-h`, `--version`/`-V`, and zero or
  more positional paths are supported. `+LINE[:COL]` sets the starting
  position in the first file; later files open at line 1, column 1. A directory
  becomes the file-tree root, and no path defaults to `.`. Features can register
  additional long options, but the current feature set registers none. See
  `*loom-app*` in
  [`src/application/startup-cli.lisp`](https://github.com/nerima-lisp/loom/blob/main/src/application/startup-cli.lisp).

## Verification scope

The Nix checks expose the package build, in-process tests, coverage, and
paredit syntax lint as separate checks. `checks.default` and `checks.coverage`
set `LOOM_SANDBOXED_CHECK=1`; child-process tests that require a usable PTY or
pipe skip in that sandbox. `nix run .#e2e` is a separate PTY app and runs
outside the Nix build sandbox. Assess both gates independently.

## Not yet implemented

- **LSP server-initiated capability registration.** The client advertises
  dynamic registration, but it does not handle `client/registerCapability` or
  `client/unregisterCapability` requests. Add and verify those routes before
  claiming support for server-initiated registration.
- **Full VT terminal emulation.** The interactive PTY terminal uses a bounded
  ANSI screen model. Emulation beyond that model remains future work.

## Release status

Release readiness for the implemented feature set requires recorded results
from both verification gates and the author's completed
[manual checklist](../notes/daily-driver-checklist.md). Unperformed checks are
not passes. The deferred features above are outside that release scope.

The Nix build patches the pinned renderer's wide-character output. Regression
tests check ANSI text placement as well as cursor geometry, including replacement
of wide characters by narrow ones. The
[verification ledger](../notes/verification-ledger.md) records the observed
checks and remaining acceptance criteria.
