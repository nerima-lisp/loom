# Architecture

loom uses a layered design, but the boundary is behavioral rather than a
rule that every package dependency must point only downward. The ASDF
component order is the load-order constraint; code calls a usable package
directly when that package owns the operation.

```
src/
├── domain/          Shared editor vocabulary and invariants, such as keymaps.
├── application/     Shared editor-state, minibuffer, command registry, and
│                    keybinding composition.
├── infrastructure/  Shared terminal rendering boundary.
├── presentation/    Shared screen composition from editor state.
└── main.lisp        Composition root: CLI definition and raw-terminal loop.

packages/
├── core/editor/     Reusable buffer storage and movement/editing vocabulary.
└── feature/<name>/  Complete feature slices, each with DDD-role filenames:
                     domain-*, application-*, infrastructure-*, and
                     presentation-*.
```

The root `src/<DDD>` directories are the shared composition route. The
package-by-feature slices under `packages/` hold the feature-owned code, while
`loom.asd` is the explicit composition root that loads the files in dependency
order. The Common Lisp public surface remains `#:loom` for compatibility; the
filesystem and ASDF boundaries provide the package-by-feature organization.

The piece-table representation and pure mutation/range helpers live in
`packages/core/editor/src/domain-buffer-storage.lisp`;
`packages/core/editor/src/domain-buffer.lisp` exposes the buffer protocol and
position/span types over that state. Keeping these responsibilities separate
makes the representation invariants independently testable without introducing
an I/O boundary into the domain layer.

## Boundaries

`src/domain/` owns shared editor invariants and does not perform terminal or
filesystem I/O. Feature-specific domain invariants live beside their use cases
under `packages/feature/<feature>/src/`. Search and replacement matching uses
the pure computation provided by `cl-regex-kit`.

`src/infrastructure/` owns the shared terminal-rendering boundary. Filesystem
access, trusted Lisp evaluation in `LOOM-USER`, session persistence, and the LSP
process boundary live in their feature packages. Normal filesystem operations
use the `cl-boundary-kit` filesystem object `*loom-filesystem*`; tests rebind it
to an in-memory fake. Two operations call `cl-host-kit` directly because their
correctness depends on behavior that the boundary object does not provide:
directory-entry classification and symlink-safe recursive deletion.

`src/application/` owns the shared `editor-state` struct, the
`*editor-state*` special variable, minibuffer state, command registry, and
keybinding composition. Feature application files orchestrate their own
domain and infrastructure boundaries. Minibuffer code calls `cl-tty-kit` and
`cl-history-kit` directly, and the M-x registry uses the local `command-spec`
table directly. There is no wrapper layer whose only purpose is to hide a
package that already provides the required operation.

The LSP slice deliberately keeps its dependency boundary small: `lsp-json.lisp`
implements JSON values/parser and `lsp-process.lisp` implements framed stdio
transport without adding a third-party JSON dependency. `lsp-service.lisp`
handles initialize, `didOpen`/`didChange`, and `publishDiagnostics`. URI
escaping, capability negotiation, and the graceful shutdown/exit handshake are
explicit follow-up work; the prompted server command is trusted input.

`packages/feature/file-tree/src/infrastructure-concurrent-runtime.lisp` owns the bounded asynchronous
directory-listing runtime. It uses `cl-concurrent-kit` workers, a bounded
result channel, cache/pending/error tables, and per-directory generations.
Workers perform listing only; `loom-concurrent-runtime-drain` applies results
on the render/event-loop lane, and invalidation advances a generation so stale
results cannot overwrite newer state. The default runtime is four workers with
a queue capacity of 64, so the in-flight bound is 68.

Commands in the shared application route and in
`packages/feature/<feature>/src/application-*.lisp` are zero-argument
functions that read and mutate `*editor-state*`, which lets keymaps store bare
function designators. `commands-internal.lisp` supplies the
continuation-based `with-prompts` flow used by prompts;
`commands-keybindings.lisp` keeps the public keybinding vocabulary separate
from the prompt protocol.

`src/presentation/layout.lisp` composes the current state into screen regions.
`src/main.lisp` owns argv parsing, raw terminal setup, event decoding, and
dispatch to minibuffer, self-insert, or the global keymap.

## Toolkit Foundation

- **[cl-tty-kit](https://github.com/nerima-lisp/cl-tty-kit)** provides raw-mode
  terminal sessions, event decoding, and the double-buffered renderer used by
  the event loop and `src/infrastructure/terminal-renderer.lisp`.
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
- **[cl-concurrent-kit](https://github.com/nerima-lisp/cl-concurrent-kit)**
  supplies the executor, bounded channel, promises, and non-blocking submit
  operation used by the concurrent file-tree runtime.

The main ASDF system declares these direct runtime dependencies: `cl-tty-kit`,
`cl-host-kit`, `cl-history-kit`, `cl-prolog`, `cl-cli`, `cl-regex-kit`,
`cl-boundary-kit`, and `cl-concurrent-kit`. The test system adds `cl-weave` and
`cl-date-kit`; the latter is used by the concurrency tests and benchmark
timeouts. The Nix flake pins the runtime and test inputs and supplies the
development shell used by the commands below.

The LSP process transport uses UIOP and Common Lisp stream primitives directly,
so it does not add a runtime JSON or process dependency to the toolkit
foundation.

## Test Suite

The `loom/test` ASDF system is run by the same script locally and in Nix:

```sh
nix develop -c sbcl --script run-tests.lisp
```

The `loom/test` ASDF component order is:

```text
package, unit/protocol-test, unit/buffer-test,
unit/syntax-highlighting-test, unit/terminal-renderer-test,
unit/filesystem-test, unit/window-test, unit/keymap-test,
unit/file-tree-test, unit/minibuffer-test, unit/evaluation-test,
  unit/cli-test, unit/register-test, unit/keyboard-macro-test,
  unit/prefix-argument-test,
  integration/commands-test, integration/lsp-test,
integration/commands-movement-test, integration/commands-editing-test,
  integration/commands-misc-test, integration/commands-keybindings-test,
  integration/register-test, integration/keyboard-macro-test,
  integration/prefix-argument-test,
integration/user-init-test, integration/layout-test, integration/session-test,
integration/main-test, integration/concurrent-runtime-test,
integration/advanced-test, integration/editor-flow-test
```

The suite uses cl-weave's ordinary assertions and its advanced registrations:
`it-each`, `it-property`, `it-fuzz`, `with-continuation-values`,
`with-soft-assertions`, and `with-replaced-function`. The process-level CLI/PTY
E2E suite remains separate because it launches the built executable as an
external process:

```sh
nix build
LOOM_BINARY="$PWD/result/bin/loom" python3 t/e2e/loom-test.py
```

Coverage is measured separately and written outside the checkout when using
the documented command:

```sh
LOOM_COVERAGE_DIR=/tmp/loom-coverage nix develop -c sbcl --script scripts/coverage.lisp
```

The report's SB-COVER expression and branch totals are recorded separately.
The report is restricted to Loom's `src/` and `packages/` trees, so the
package-by-feature implementation is included in the measurement.
Branch coverage does not establish full expression coverage; the generated
report is the source of truth for uncovered forms. SB-COVER is process-local,
so top-level declarations and the child-process-only `loom:main` path can
remain unexecuted in the report; those forms are reported rather than hidden.
`nix flake check
--print-build-logs` additionally runs the test, package, formatter, and strict
MkDocs documentation checks.

The concurrency benchmark compares synchronous directory listing with the
runtime's bounded prefetch/drain path over eight synthetic directory paths. It
prints synchronous time, asynchronous submit time, asynchronous total time,
accepted task count, and the derived speedup:

```sh
nix develop -c sbcl --script scripts/benchmark-concurrency.lisp
```

The benchmark is observational and does not establish a performance target;
the 2026 refactor objective is the bounded, race-safe file-tree runtime and
its test coverage, not an unimplemented feature claim.
