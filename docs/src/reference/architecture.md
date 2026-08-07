# Architecture

loom uses a layered design, but the boundary is behavioral rather than a
rule that every package dependency must point only downward. The ASDF
component order is the load-order constraint; code calls a usable package
directly when that package owns the operation.

```
src/
├── domain/          Editor state and pure logic: buffer text/point/mark/undo,
│                    window-tree layout, keymap dispatch, and file-tree state.
├── infrastructure/  Terminal rendering and filesystem operations.
├── application/     Editor-state orchestration, minibuffer behavior, and
│                    commands split by concern.
├── presentation/    Screen composition from the current editor state.
└── main.lisp        CLI definition and the raw-terminal event loop.
```

## Boundaries

`src/domain/` owns editor invariants and does not perform terminal or
filesystem I/O. Its regular-expression search and replacement matching uses
the pure computation provided by `cl-regex-kit`.

`src/infrastructure/` owns terminal rendering and filesystem access. Normal
filesystem operations use the `cl-boundary-kit` filesystem object
`*loom-filesystem*`; tests rebind it to an in-memory fake. Two operations call
`cl-host-kit` directly because their correctness depends on behavior that the
boundary object does not provide: directory-entry classification and
symlink-safe recursive deletion.

`src/application/` owns the `editor-state` struct, the `*editor-state*`
special variable, minibuffer state, and command functions. Minibuffer code
calls `cl-tty-kit` and `cl-history-kit` directly, file commands use the
filesystem packages directly, and the M-x registry uses the local
`command-spec` table directly.
There is no wrapper layer whose only purpose is to hide a package that already
provides the required operation.

Commands in `src/application/commands-*.lisp` are zero-argument functions
that read and mutate `*editor-state*`, which lets keymaps store bare function
designators. `commands-internal.lisp` supplies the continuation-based
`with-prompts` flow used by prompts; the concern-specific command files and
`commands-keybindings.lisp` keep the public command vocabulary separate from
the prompt protocol.

`src/presentation/layout.lisp` composes the current state into screen
regions. `src/main.lisp` owns argv parsing, raw terminal setup, event decoding,
and dispatch to minibuffer, self-insert, or the global keymap.

## Toolkit Foundation

- **[cl-tty-kit](https://github.com/nerima-lisp/cl-tty-kit)** provides raw-mode
  terminal sessions, event decoding, and the double-buffered renderer used by
  the event loop and `infrastructure/terminal-renderer.lisp`.
- **[cl-boundary-kit](https://github.com/nerima-lisp/cl-boundary-kit)** provides
  the filesystem object used by buffer load/save and most file-tree mutations.
  Its test filesystem keeps those tests independent of a real directory.
- **[cl-host-kit](https://github.com/nerima-lisp/cl-host-kit)** is used directly
  for directory-entry classification and symlink-safe recursive deletion.
- **[cl-history-kit](https://github.com/nerima-lisp/cl-history-kit)** stores
  minibuffer history for find-file, save-buffer, and file-tree prompts.
- **[cl-prolog](https://github.com/nerima-lisp/cl-prolog)** evaluates the
  `with-prolog-query` rulebase used by quit-prompt resolution. The
  `define-command-specs` macro also emits an inspectable command rulebase, but
  runtime M-x name lookup intentionally uses its explicit registry.
- **[cl-regex-kit](https://github.com/nerima-lisp/cl-regex-kit)** supplies the
  regular-expression engine used by search-forward and replace-string,
  bounded by the editor's regex search timeout.
- **[cl-cli](https://github.com/nerima-lisp/cl-cli)** parses the root
  positional argument and the `--help`/`--version` options in `main.lisp`.

## Test Suite

The `loom/test` ASDF system is run by the same script locally and in Nix:

```sh
nix develop -c sbcl --script run-tests.lisp
```

The suite uses cl-weave's ordinary assertions and its advanced registrations:
`it-each`, `it-property`, `it-fuzz`, `with-continuation-values`,
`with-soft-assertions`, and `with-replaced-function`. `main-test.lisp` mostly
uses controlled terminal seams and also includes a real-PTY smoke test.

Coverage is measured separately and written outside the checkout when using
the documented command:

```sh
LOOM_COVERAGE_DIR=/tmp/loom-coverage nix develop -c sbcl --script scripts/coverage.lisp
```

The report's SB-COVER expression and branch totals are recorded separately.
Branch coverage does not establish full expression coverage; the generated
report is the source of truth for uncovered forms. `nix flake check
--print-build-logs` additionally runs the test, package, formatter, and strict
MkDocs documentation checks.
