# Architecture

loom follows a domain-driven, layered design, mirroring nshell's `src/`
layering. Each layer depends only on the layers beneath it:

```
src/
├── domain/          Pure editor state and logic: buffer text/point/mark/
│                    undo (including cl-regex-kit-backed search/replace
│                    matching), window-tree layout, keymap dispatch,
│                    file-tree visibility/selection -- no I/O.
├── infrastructure/  Adapters to the I/O-touching sibling toolkit libraries:
│                    the cl-tty-kit-backed terminal renderer and filesystem
│                    operations, mostly through a cl-boundary-kit boundary
│                    except two that stay on cl-host-kit directly (see that
│                    file's header comment).
├── application/     Use cases: the EDITOR-STATE struct/`*editor-state*`
│                    every command reads and mutates, the minibuffer
│                    protocol, and the commands themselves (movement,
│                    editing, window, file-tree, quit).
└── presentation/    Composes domain/application/infrastructure output for
                     the screen (window layout plus file-tree sidebar).
```

Confining I/O-touching sibling calls (`cl-tty-kit`, `cl-host-kit`,
`cl-boundary-kit`) to `infrastructure/` is what makes `domain/` testable
without a terminal or a disk: a test exercises a buffer, window tree, or
keymap directly, with no process I/O. `cl-history-kit` is the one documented
exception: `application/minibuffer.lisp` calls it directly rather than
through an `infrastructure/history.lisp` adapter, since a minibuffer's
history object is part of its own application-layer state, not a boundary
`domain/` needs isolating from (see that file's header comment).

Commands (`src/application/commands-*.lisp`, split by concern -- movement,
editing, search, file, window, misc, keybindings, plus the shared
`commands-internal.lisp`) are plain, ordinary functions of zero arguments
that read and mutate the single special variable `*editor-state*`, rather
than taking the editor state as an explicit argument -- this is what lets a
keymap binding be a bare function designator. `install-default-keybindings`
(`commands-keybindings.lisp`) binds each command to its Emacs-style key
sequence.

## Toolkit foundation

loom builds on seven `nerima-lisp` toolkit libraries, each wired at the layer
where it fits the domain-driven design:

- **[cl-tty-kit](https://github.com/nerima-lisp/cl-tty-kit)** -- raw-mode
  terminal sessions, the double-buffered screen/renderer pair
  `loom-renderer` wraps, and key-event decoding. `src/main.lisp`'s event loop
  reads raw octets from stdin, decodes them via `cl-tty-kit:decode-input-chunk`,
  and dispatches each event to the minibuffer, `self-insert-command`, or the
  global keymap.
- **[cl-boundary-kit](https://github.com/nerima-lisp/cl-boundary-kit)** --
  the filesystem boundary (`*loom-filesystem*`,
  `src/infrastructure/filesystem.lisp`) backing `buffer-load`/`buffer-save`
  and most of the file-tree's create/rename/delete operations; tests rebind
  it to `cl-boundary-kit:make-test-filesystem`'s in-memory fake instead of
  touching a real temporary directory.
- **[cl-host-kit](https://github.com/nerima-lisp/cl-host-kit)** -- used
  directly (not through the `cl-boundary-kit` boundary above) for the two
  filesystem operations that need a guarantee `cl-boundary-kit` doesn't make:
  `loom-fs-list-directory`'s per-entry file/directory classification, and
  `file-tree-delete`'s symlink-safe recursive directory delete (see
  `src/infrastructure/filesystem.lisp`'s header comment for why routing
  either through the boundary would cost correctness).
- **[cl-history-kit](https://github.com/nerima-lisp/cl-history-kit)** -- the
  history object a minibuffer is created with, driving Up/Down recall while
  prompting (`find-file`, `save-buffer`, file-tree create/rename).
- **[cl-prolog](https://github.com/nerima-lisp/cl-prolog)** -- the logic-
  programming rulebases `src/application/commands-misc.lisp` queries via its
  `CL-PROLOG:WITH-PROLOG-QUERY` rule DSL: the `define-extended-commands`
  rulebase resolving M-x's typed command names to their command functions,
  and `*quit-answer-rulebase*`'s guarded clauses resolving a quit prompt's
  s/d/c answer to the action `%continue-quit` takes.
- **[cl-regex-kit](https://github.com/nerima-lisp/cl-regex-kit)** -- the
  Thompson-NFA/Pike-VM regular-expression engine `search-forward` and
  `replace-string` (`src/domain/buffer.lisp`'s `%find-next-occurrence`/
  `%replacement-match-spans`) compile the typed pattern against, bounded by
  `+regex-search-timeout-seconds+` so a pathological pattern cannot hang the
  event loop.
- **[cl-cli](https://github.com/nerima-lisp/cl-cli)** -- the declarative app
  spec `*loom-app*` (`src/main.lisp`) parses `argv` against: a single root
  positional (the file/directory to open) plus `--help`/`-h`/`--version`/`-V`
  for free.

## Test suite

`loom/test`, in `t/`, is the primary regression suite, run via
[cl-weave](https://github.com/nerima-lisp/cl-weave) and exposed as the
`checks.default` Nix check. It covers the buffer, window, keymap, minibuffer,
file-tree, filesystem, terminal-renderer, layout, command, and main-entry-point
protocols directly, with no dependency on a real terminal, plus a one-spec
smoke test (`t/protocol-test.lisp`) confirming the `#:loom` package loads at
all -- a canary distinct from every other file's feature-level coverage.
