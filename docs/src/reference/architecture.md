# Architecture

loom uses a layered design, but the boundary is behavioral rather than a
rule that every package dependency must point only downward. The ASDF
component order is the load-order constraint; code calls a usable package
directly when that package owns the operation.

```text
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
order. Feature-owned operations are exported from their `loom/feature/<name>`
packages; `loom` contains only the editor kernel and composition-root API. No
compatibility facade is maintained.

The piece-table representation and pure mutation/range helpers live in
`packages/core/editor/src/domain-buffer-storage.lisp`;
`packages/core/editor/src/domain-buffer.lisp` exposes the buffer protocol and
position/span types over that state. Keeping these responsibilities separate
makes the representation invariants independently testable without introducing
an I/O boundary into the domain layer.

The window feature follows the same split: `domain-window.lisp` contains the
tree model, layout calculation, and serialization, while
`domain-window-operations.lisp` contains split, selection, buffer assignment,
and resize mutations. The operation file depends on the model but not on the
terminal renderer.

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
The native pathname helpers are isolated in
`infrastructure-filesystem-native.lisp`; `infrastructure-filesystem.lisp`
retains the file-tree and buffer-facing boundary methods.

`src/application/` owns the shared `editor-state` struct, the
`*editor-state*` special variable, minibuffer state, command registry, and
keybinding composition. Feature application files orchestrate their own
domain and infrastructure boundaries. Minibuffer code calls `cl-tty-kit` and
`cl-history-kit` directly, and the M-x registry uses the local command
specifications directly. There is no wrapper layer whose only purpose is to
hide a package that already provides the required operation.

The LSP slice deliberately keeps its dependency boundary small:
`application-commands-lsp.lisp` owns interactive commands,
`application-lsp-service.lisp` handles initialize, `didOpen`/`didChange`, and
`publishDiagnostics`, and `infrastructure-lsp-process.lisp` owns framed stdio
transport. Pure UTF-8 and `Content-Length` framing is isolated in
`infrastructure-lsp-framing.lisp`, so the process adapter only owns child
process lifecycle and asynchronous stream reading. JSON messages are parsed
and constructed through `cl-json-kit`.
URI escaping, capability negotiation, and the graceful shutdown/exit handshake
are explicit follow-up work; the prompted server command is trusted input.

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
function designators. `src/application/command-definitions.lisp` is the
declarative command catalogue; `src/application/command-registry.lisp` owns
specification storage, completion candidates, and M-x lookup.
`commands-internal.lisp` supplies the continuation-based `with-prompts` flow
used by prompts, while `commands-keybindings.lisp` installs the default
bindings separately from the prompt protocol.

`src/presentation/layout.lisp` composes the current state into screen regions.
`src/application/startup.lisp` is the composition root for argv parsing,
editor-state construction, terminal-session setup, and asynchronous resource
shutdown. `src/application/event-loop.lisp` owns frame rendering, resize
polling, and the event-loop boundary. `src/application/input-dispatch.lisp`
owns raw-octet reading, event decoding, and dispatch to minibuffer,
self-insert, or the global keymap. `src/main.lisp` is only the executable
trampoline.

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
- **[cl-json-kit](https://github.com/nerima-lisp/cl-json-kit)** parses and
  constructs the JSON objects exchanged by the LSP service.
- **[cl-concurrent-kit](https://github.com/nerima-lisp/cl-concurrent-kit)**
  supplies the executor, bounded channel, promises, and non-blocking submit
  operation used by the concurrent file-tree runtime.

The main ASDF system declares these direct runtime dependencies: `cl-tty-kit`,
`cl-host-kit`, `cl-history-kit`, `cl-prolog`, `cl-cli`, `cl-regex-kit`,
`cl-boundary-kit`, `cl-json-kit`, and `cl-concurrent-kit`. The test system adds
`cl-weave` and `cl-date-kit`; the latter is used by the concurrency tests and
benchmark timeouts. The Nix flake pins the runtime and test inputs and supplies
the development shell used by the commands below.

The LSP process transport uses UIOP and Common Lisp stream primitives directly;
`cl-json-kit` supplies only the message representation and JSON boundary.

## Test Suite

The `loom/test` ASDF system is run by the same script locally and in Nix:

```sh
nix develop -c sbcl --script run-tests.lisp
```

The `loom/test` ASDF component order is declared in `loom.asd`, which is the
source of truth as unit and integration coverage evolves. The current suite
includes focused tests for buffers, keymaps, rendering, filesystems,
minibuffers, syntax highlighting, major modes, projects, evaluation, the CLI,
registers, keyboard macros, prefixes, and the file tree. Integration coverage
includes commands, LSP, editing and movement, major modes, projects, layout,
sessions, user initialization, the concurrent runtime, and editor flows.

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
`nix flake check --print-build-logs` additionally runs the test, package,
formatter, and strict MkDocs documentation checks.

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
