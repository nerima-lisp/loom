# loom

A terminal text editor for SBCL with Emacs-style keybindings, built on
`cl-tty-kit` for raw-mode terminal I/O and rendering, `cl-host-kit` for
filesystem access, and `cl-history-kit` for minibuffer input recall.

```sh
nix run github:nerima-lisp/loom
```

!!! note "Status: early development (0.1.x, MVP)"

    Buffer editing, Emacs-style movement/kill-ring/yank/undo, window splits,
    and a file-tree sidebar with real filesystem create/rename/delete are
    implemented and tested. Syntax highlighting, an LSP client, extensibility
    via a user `init.lisp`, and session/layout persistence are future phases
    -- see the [roadmap](project/roadmap.md).

## Where to go next

- [Getting started](getting-started.md) -- build loom and open a file.
- [API reference](reference/api.md) -- every exported symbol.
- [Architecture](reference/architecture.md) -- the layered design and the
  toolkit family it builds on.
- [Roadmap](project/roadmap.md) -- what is implemented and what is not, yet.
