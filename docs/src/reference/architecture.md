# Architecture

loom follows a domain-driven, layered design, mirroring nshell's `src/`
layering. Each layer depends only on the layers beneath it:

```
src/
├── domain/          Pure editor state and logic: buffer text/point/mark/
│                    undo, window-tree layout, keymap dispatch, file-tree
│                    visibility/selection -- no I/O.
├── infrastructure/  Adapters to the sibling toolkit libraries: the
│                    cl-tty-kit-backed terminal renderer, cl-host-kit-backed
│                    filesystem operations, and cl-history-kit-backed
│                    minibuffer history.
├── application/     Use cases: the EDITOR-STATE struct/`*editor-state*`
│                    every command reads and mutates, the minibuffer
│                    protocol, and the commands themselves (movement,
│                    editing, window, file-tree, quit).
└── presentation/    Composes domain/application/infrastructure output for
                     the screen (window layout plus file-tree sidebar).
```

Confining `cl-tty-kit`/`cl-host-kit`/`cl-history-kit` calls to
`infrastructure/` is what makes `domain/` testable without a terminal: a test
exercises a buffer, window tree, or keymap directly, with no process I/O.

Commands (`src/application/commands-*.lisp`, split by concern -- movement,
editing, search, file, window, misc, keybindings, plus the shared
`commands-internal.lisp`) are plain, ordinary functions of zero arguments
that read and mutate the single special variable `*editor-state*`, rather
than taking the editor state as an explicit argument -- this is what lets a
keymap binding be a bare function designator. `install-default-keybindings`
(`commands-keybindings.lisp`) binds each command to its Emacs-style key
sequence.

## Toolkit foundation

loom builds on five `nerima-lisp` toolkit libraries, each wired at the layer
where it fits the domain-driven design:

- **[cl-tty-kit](https://github.com/nerima-lisp/cl-tty-kit)** -- raw-mode
  terminal sessions, the double-buffered screen/renderer pair
  `loom-renderer` wraps, and key-event decoding. `src/main.lisp`'s event loop
  reads raw octets from stdin, decodes them via `cl-tty-kit:decode-input-chunk`,
  and dispatches each event to the minibuffer, `self-insert-command`, or the
  global keymap.
- **[cl-host-kit](https://github.com/nerima-lisp/cl-host-kit)** -- filesystem
  access backing `buffer-load`/`buffer-save`
  (`src/infrastructure/filesystem.lisp`) and the file-tree's directory
  listing and create/rename/delete operations.
- **[cl-history-kit](https://github.com/nerima-lisp/cl-history-kit)** -- the
  history object a minibuffer is created with, driving Up/Down recall while
  prompting (`find-file`, `save-buffer`, file-tree create/rename).
- **[cl-prolog](https://github.com/nerima-lisp/cl-prolog)** -- the logic-
  programming rulebase `define-extended-commands`
  (`src/application/commands-misc.lisp`) compiles down to, resolving M-x's
  typed command names to their command functions.
- **[cl-cli](https://github.com/nerima-lisp/cl-cli)** -- the declarative app
  spec `*loom-app*` (`src/main.lisp`) parses `argv` against: a single root
  positional (the file/directory to open) plus `--help`/`-h`/`--version`/`-V`
  for free.

## Test suite

`loom/test`, in `t/`, is the primary regression suite, run via
[cl-weave](https://github.com/nerima-lisp/cl-weave) and exposed as the
`checks.default` Nix check. It covers the buffer, window, keymap, minibuffer,
file-tree, filesystem, terminal-renderer, layout, and command protocols
directly, with no dependency on a real terminal.
