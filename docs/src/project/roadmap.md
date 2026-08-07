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
  files and directories on disk, backed by `cl-host-kit`.
- **File I/O** -- `find-file` (`C-x C-f`), `save-buffer` (`C-x C-s`).
- **Raw-mode terminal event loop** -- built on `cl-tty-kit`, with a
  double-buffered renderer.
- **`--help` / `--version` CLI flags** -- built on `cl-cli`; see `*loom-app*`
  in [`src/main.lisp`](https://github.com/nerima-lisp/loom/blob/main/src/main.lisp).

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
