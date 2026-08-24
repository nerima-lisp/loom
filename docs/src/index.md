# loom

A terminal text editor for SBCL with Emacs-style keybindings. Its direct
runtime dependencies include `cl-tty-kit`, `cl-host-kit`, `cl-history-kit`,
`cl-prolog-kit`, `cl-cli`, `cl-regex-kit`, `cl-boundary-kit`,
`cl-concurrent-kit`, and `cl-json-kit`.

```sh
nix run github:nerima-lisp/loom
```

!!! note "Status: early development (0.1.x, MVP)"

    Buffer editing, Emacs-style movement/kill-ring/yank/undo and numeric
    prefixes, window splits,
    file-tree create/rename/delete, syntax highlighting, Common Lisp
    evaluation, a user `init.lisp`, session persistence, a minimal LSP client
    with diagnostics, completion, and definition navigation, named registers,
    and keyboard macros are implemented in the current source.
    The file tree uses a bounded concurrent
    runtime: directory work is submitted to workers, while cache updates and
    rendering remain on the editor's render lane. See the
    [roadmap](project/roadmap.md) for the implemented surface and deferred
    Lem/Emacs-scale features.

## Where to go next

- [Getting started](getting-started.md) -- build loom and open a file.
- [API reference](reference/api.md) -- the complete public export contract;
  `src/package.lisp` remains authoritative when the package surface changes.
- [Architecture](reference/architecture.md) -- the layered design and the
  toolkit family it builds on.
- [Roadmap](project/roadmap.md) -- what is implemented and what is not, yet.
- [Development](project/development.md) -- source builds, tests, coverage, and
  process-level checks.

The CLI accepts `--help`, `--version`, and one optional path. The default
keybindings are installed by
[`src/application/commands-keybindings.lisp`](https://github.com/nerima-lisp/loom/blob/main/src/application/commands-keybindings.lisp);
the command catalogue and M-x registry live in
[`src/application/command-definitions.lisp`](https://github.com/nerima-lisp/loom/blob/main/src/application/command-definitions.lisp)
and [`src/application/command-registry.lisp`](https://github.com/nerima-lisp/loom/blob/main/src/application/command-registry.lisp).
