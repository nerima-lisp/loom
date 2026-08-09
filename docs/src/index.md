# loom

A terminal text editor for SBCL with Emacs-style keybindings, built on
`cl-tty-kit` for raw-mode terminal I/O and rendering, `cl-host-kit` for
filesystem access, `cl-boundary-kit` for the filesystem boundary,
`cl-history-kit` for minibuffer input recall, `cl-cli` for command-line
parsing, and `cl-concurrent-kit` for bounded concurrent file-tree prefetch.

```sh
nix run github:nerima-lisp/loom
```

!!! note "Status: early development (0.1.x, MVP)"

    Buffer editing, Emacs-style movement/kill-ring/yank/undo and numeric
    prefixes, window splits,
    file-tree create/rename/delete, syntax highlighting, Common Lisp
    evaluation, a user `init.lisp`, session persistence, and a minimal LSP
    client, named registers, and keyboard macros are implemented and tested.
    The file tree uses a bounded concurrent
    runtime: directory work is submitted to workers, while cache updates and
    rendering remain on the editor's render lane. See the
    [roadmap](project/roadmap.md) for the implemented surface and deferred
    Lem/Emacs-scale features.

## Where to go next

- [Getting started](getting-started.md) -- build loom and open a file.
- [API reference](reference/api.md) -- the selected public API; `src/package.lisp`
  is the authoritative complete export list.
- [Architecture](reference/architecture.md) -- the layered design and the
  toolkit family it builds on.
- [Roadmap](project/roadmap.md) -- what is implemented and what is not, yet.

The CLI accepts `--help`, `--version`, and one optional path; the default
keybindings and the `M-x` extended-command registry are documented in the
[README](https://github.com/nerima-lisp/loom/blob/main/README.md).
