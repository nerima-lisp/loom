# loom

A terminal text editor for SBCL with Emacs-style keybindings. Its direct
runtime dependencies include `cl-tty-kit`, `cl-host-kit`, `cl-history-kit`,
`cl-prolog-kit`, `cl-cli`, `cl-regex-kit`, `cl-boundary-kit`,
`cl-concurrent-kit`, `cl-date-kit`, `cl-json-kit`, `cl-log-kit`, `cl-process-kit`,
`cl-vcs-kit`, `cl-resilience-kit`, `cl-markdown-kit`, and `cl-org-kit`.

```sh
nix run github:nerima-lisp/loom
```

The current source includes buffer editing, Emacs-style movement, the kill
ring, undo and numeric prefixes, window splits, file-tree operations, syntax
highlighting, Common Lisp evaluation, user initialization, session persistence,
named registers, and keyboard macros. LSP support covers diagnostics,
completion, and definition navigation. Hover, references, rename, and LSP
formatting are not implemented.

## Where to go next

- [Getting started](getting-started.md) -- build loom and open a file.
- [Core concepts](guide/core-concepts.md) -- commands and workflows for search,
  clipboard, windows, language modes, sessions, and LSP.
- [API reference](reference/api.md) -- selected editor APIs and the public
  feature APIs. Core exports are defined in
  `src/package-exports.lisp`, and feature
  exports in each `packages/feature/<name>/src/package.lisp`.
- [Architecture](reference/architecture.md) -- the layered design and the
  toolkit family it builds on.
- [Roadmap](project/roadmap.md) -- current implementation and planned work.
- [Development](project/development.md) -- source builds, tests, coverage, and
  process-level checks.

The built-in CLI accepts `--help`/`-h`, `--version`/`-V`, and
`loom [+LINE[:COL]] FILE...`. Features can register additional long options;
the current feature set registers none.
