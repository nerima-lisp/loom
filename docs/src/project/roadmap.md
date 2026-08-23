# Roadmap

loom is an MVP-stage terminal editor. This page separates what is
implemented today from what is deliberately deferred.

## Implemented today

- **Buffer editing** -- insert/delete, Emacs-style kill-ring/yank, numeric
  prefix arguments, multi-level undo grouped by command boundary, and
  restriction-aware narrowing/widening (`C-x n n` / `C-x n w`), plus
  read-only buffers with an interactive toggle (`C-x C-q`).
- **Movement** -- character/line motion, beginning/end of line.
- **Emacs-style keybindings** -- `install-default-keybindings` installs the
  command registry's movement, editing, search, file, window, file-tree,
  session, register, recent-file, bookmark, shell, help, keyboard-quit, and quit
  bindings, including the `C-x`/`C-c` prefix sequences. The bindings live in
  [`src/application/commands-keybindings.lisp`](https://github.com/nerima-lisp/loom/blob/main/src/application/commands-keybindings.lisp),
  and the declarative catalogue lives in
  [`src/application/command-definitions.lisp`](https://github.com/nerima-lisp/loom/blob/main/src/application/command-definitions.lisp).
- **Window management** -- horizontal/vertical splits (`C-x 2` / `C-x 3`),
  window selection (`C-x o`), per-window buffer switching (`C-x b`).
- **Named workspaces** -- create, switch, cycle, and kill independent window
  trees with `C-x t 2`, `C-x t o`, `C-x t n`, `C-x t p`, and `C-x t k`; the
  active workspace is shown in the shortcut line and persisted by sessions.
- **File-tree sidebar** (`C-x C-t`) -- navigate, and create/rename/delete
  files and directories on disk, using `cl-boundary-kit` for normal
  operations and direct `cl-host-kit` calls where filesystem guarantees
  require them.
- **File I/O** -- `find-file` (`C-x C-f`), `save-buffer` (`C-x C-s`).
- **Regular-expression search and replacement** -- `C-s`, `M-%`, and
  `M-g g`, using `cl-regex-kit` patterns with a bounded search operation.
- **M-x command registry and prompts** -- extended commands resolve through
  the declarative catalogue in
  [`src/application/command-definitions.lisp`](https://github.com/nerima-lisp/loom/blob/main/src/application/command-definitions.lisp)
  and the lookup implementation in
  [`src/application/command-registry.lisp`](https://github.com/nerima-lisp/loom/blob/main/src/application/command-registry.lisp);
  quit confirmation uses `cl-prolog-kit`, and minibuffer history uses
  `cl-history-kit` directly.
- **Raw-mode terminal event loop** -- built on `cl-tty-kit`, with a
  double-buffered renderer.
- **Interactive PTY terminals** -- `M-x terminal` starts a child process,
  translates editor key events into terminal input, polls output, handles
  resize, and exposes a read-only transcript plus a bounded ANSI screen model.
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
  before changing the index. All captured status and diff output, including
  stderr and exit status, remains visible in read-only result buffers, while
  staging commands report their exit status in the minibuffer.
- **Auto-save** -- `M-x auto-save-mode` enables global automatic saving and
  `M-x toggle-auto-save` enables it for the selected buffer; modified writable
  file-backed buffers are written to `#file-name#` sidecars from the event loop
  without clearing their normal modified state.
- **LSP client slice** -- `lsp-start`, `lsp-stop`, and `lsp-diagnostics` use a
  project-local `.loom-lsp` command when available (while allowing an
  explicit prompt override), negotiate initialization capabilities,
  synchronize file-backed buffers with UTF-8 percent-encoded URIs, render
  `publishDiagnostics` messages in `*Loom-Diagnostics*`, and perform the
  `shutdown`/`exit` handshake with a timeout fallback.
- **Line display** -- a window follows point horizontally in screen cells for a
  truncating buffer and wraps a long logical line across several rows for a
  wrapping one. The major mode picks the default -- code truncates, Markdown,
  Org, and plain text wrap -- and `M-x toggle-truncate-lines` overrides it per
  buffer. `next-line` and `previous-line` move by screen row.
- **User extension** -- `LOOM_INIT_FILE` or `~/.loom/init.lisp` can register
  commands and keybindings before the terminal loop starts.
- **Session and buffer lifecycle** -- explicit session save/load persists
  buffers, named workspace layouts, recent files, named bookmarks, and
  M-x/minibuffer command history in the canonical v5 format; the reader
  accepts only the v5 envelope and has no compatibility path for pre-v5
  session files.
  `switch-to-buffer`, `kill-buffer`, and case-insensitive minibuffer prefix
  completion manage the buffer registry.
- **Recent files and named bookmarks** -- `C-x r f` opens the bounded,
  canonical recent-file list; `C-x r m`, `C-x r b`, `C-x r d`, and M-x
  `list-bookmarks` set, jump to, delete, and list named bookmarks.
- **Registers and keyboard macros** -- named text/point registers and
  record/replay keyboard macros are available through the `C-x r` and `C-x`
  bindings.
- **CLI** -- built on `cl-cli`; `--help`/`-h`, `--version`/`-V`, and one
  optional positional path are supported. A file opens in the first window,
  a directory becomes the file-tree root, and no path defaults to `.`. See
  `*loom-app*` in
  [`src/application/startup.lisp`](https://github.com/nerima-lisp/loom/blob/main/src/application/startup.lisp).
- **Integrated test, coverage, and benchmark paths** -- the `loom/test` ASDF
  component order is declared in [`loom.asd`](https://github.com/nerima-lisp/loom/blob/main/loom.asd)
  and loads unit and integration coverage in serial order. It includes
  dedicated coverage for major modes and project navigation. The
  [development guide](development.md) documents the test runner, PTY checks,
  coverage, and benchmark commands.

## 2026 refactor status

The bounded concurrent file-tree runtime and its ASDF-integrated
`concurrent-runtime-test` are implemented in the current source. This marks
the runtime portion of the 2026 refactor objective as present; it does not
make the deferred editor features below complete.

## Not yet implemented

These are follow-up phases rather than claims that the current editor is a
complete Lem or Emacs replacement:

- **Richer LSP protocol surface.** The discovered or prompted server command
  remains trusted input; dynamic registration and requests beyond the current
  diagnostics/document-sync slice remain future work.
- **Broader editing surface.** A richer package/extension distribution story
  and editing commands beyond the current region-aware kill/yank slice remain
  future work.
- **Full VT terminal emulation and desktop/editor integrations.** Complete
  terminal compatibility beyond the bounded common-ANSI screen model,
  interactive terminal application integrations, richer Git staging and diff
  UI, and additional language modes remain future work.

## Released changes

### v0.1.0

The MVP release consolidates the 2026 editor modernization, bounded concurrent
file-tree runtime, integrated unit/integration/e2e test paths, and the
session-wide buffer registry with `switch-to-buffer` lookup.

Release artifacts and release notes are managed through [GitHub Releases](https://github.com/nerima-lisp/loom/releases).
