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

The buffer protocol keeps the existing Emacs-style undo ring and an explicit
redo history. Undo/redo replay uses storage primitives without clearing redo;
ordinary edits clear redo so a new edit starts a new branch.

Read-only state is owned by the buffer domain. Public mutation methods and
undo/redo pass through the same writable guard, while the file infrastructure
marks buffers loaded from non-writable real files read-only and refuses to save
read-only buffers. `C-x C-q` changes the state explicitly at the command layer.

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
Session persistence also uses cl-host-kit's overwrite-safe move after a
temporary sibling is complete, and user-init configuration reads the
environment through the same package. The native pathname helpers, native
mutations, native file I/O, and symlink-safe native deletion are isolated in
`infrastructure-filesystem-native-{paths,mutations,io,delete}.lisp`; the
disk-backed file-tree child lister lives in
`infrastructure-file-tree-directory-listing.lisp`, the file-tree mutation
methods live in `infrastructure-file-tree-filesystem.lisp`, and the
buffer-facing boundary methods live in
`infrastructure-buffer-filesystem.lisp`.

`src/application/` owns the shared `editor-state` struct, the
`*editor-state*` special variable, minibuffer state, command registry, and
keybinding composition. The editor state also owns the bounded canonical
recent-file list and the named-bookmark table: file-tree commands update the
recent-file list when files are opened or saved, while the shared misc
commands create, resolve, list, and delete bookmarks. Feature application
files orchestrate their own domain and infrastructure boundaries. Minibuffer code calls `cl-tty-kit` and
`cl-history-kit` directly, and the M-x registry uses the local command
specifications directly. There is no wrapper layer whose only purpose is to
hide a package that already provides the required operation. `make-editor-state`
also establishes the workspace invariant: when a caller does not supply a
manager, the initial window tree is installed as the named `main` workspace.
Commands therefore require a manager instead of reconstructing one through a
legacy fallback.

The session feature serializes those editor-state collections alongside
buffers, named workspaces, and each workspace's window layout and selection.
Its canonical v5 format preserves recent paths, bookmark positions, and
M-x/minibuffer command history. The reader accepts only the v5 envelope and
does not provide a compatibility reader for pre-v5 session layouts.

The LSP slice deliberately keeps its dependency boundary small:
`application-commands-lsp.lisp` owns interactive commands,
`application-commands-lsp-navigation.lisp` owns completion and definition
navigation, `application-lsp-session-state.lisp` owns session state,
pending requests, and URI/language helpers, and
`application-lsp-session-sync.lisp` owns document synchronization and
diagnostic lookup. `application-lsp-session-lifecycle.lisp` owns startup,
refresh, and shutdown orchestration, `application-lsp-protocol-send.lisp`
owns JSON-RPC encoding, `application-lsp-protocol-initialize.lisp` owns
initialize/capability messages, `application-lsp-request-decode.lisp` parses
completion and definition results, `application-lsp-requests.lisp` builds
capability-gated requests and registers callbacks, and
`application-lsp-protocol-routing.lisp` dispatches pending responses.
The helper/receive slices own diagnostic parsing and nonblocking dispatch.
`infrastructure-lsp-transport.lisp` owns child-process lifecycle and stdio
transport. Pure UTF-8 and `Content-Length` framing is isolated in
`infrastructure-lsp-framing.lisp`, and JSON messages are parsed and
constructed through `cl-json-kit`.
The editor-agnostic candidate state and key handling live in
`src/application/completion-popup.lisp` and
`src/application/completion-popup-input.lisp`; presentation only draws the
bounded popup around its buffer anchor.
`lsp-discover-command`, in `infrastructure-lsp-discovery.lisp`, searches the
current path's ancestor directories for the nearest `.loom-lsp`; its first
non-empty, non-comment line is the trusted server command. `lsp-start` presents that command as the default, while an
explicit prompt value overrides it. Dynamic registration and requests beyond
the current completion/definition/diagnostics/document-sync slice remain
outside this boundary.

The shell feature keeps process execution and presentation data separate:
`domain-shell.lisp` defines the captured command result,
`infrastructure-shell.lisp` runs a command through UIOP while preserving
standard output, standard error, the working directory, and the exit code, and
`application-commands-shell.lisp` implements `M-!`/`M-x pipe-command`. The
interactive command runs in the selected file's parent directory and appends
the rendered result to `*Loom-Pipe-Command*`; a non-zero exit status is
displayed as result data rather than treated as an editor error.

The format feature builds on the shell result boundary without coupling the
buffer domain to process execution. `format-buffer-with-command` sends the
complete buffer text to an external command and commits stdout only after a
zero exit status. The command runs in the file's directory when available and
preserves point and mark offsets; read-only and narrowed buffers are rejected
before process execution. The replacement is recorded as one undo group.

The Git feature reuses project-root discovery and the shell result boundary.
`C-x g` runs concise branch-aware status at the current project root and
renders the captured output in a generated read-only `*Loom-Git-Status*` buffer.
`M-x git-diff` and `M-x git-diff-staged` use the same boundary for working-tree
and index patches, rendering both in the read-only `*Loom-Git-Diff*` buffer.
`M-x git-stage-file` and `M-x git-unstage-file` reuse the same project-root
lookup to run index mutations after a minibuffer path prompt. Paths are quoted
as POSIX shell words before they reach the shell command boundary. Non-zero Git
exits remain visible as result data or minibuffer status, so an uncommitted or
non-repository directory does not turn process status into an editor failure.

The terminal feature owns PTY-backed child-process sessions. Its domain object
`domain-terminal.lisp` owns the bounded `terminal-screen` model and ANSI
rendering parser, while `domain-terminal-session.lisp` owns the running PTY
process, selected buffer, raw output, liveness, and exit state. The
infrastructure layer starts, reads, writes, resizes, and closes the PTY; the
application layer translates key events and exposes `terminal` and
`terminal-stop`. The event loop polls output and resize state alongside normal
rendering. The presentation renders the screen model, which covers common
cursor movement, erasure, cursor save/restore, and minimal alternate-screen
switching; it is not a full VT terminal emulator.

The auto-save feature keeps its sidecar naming and eligibility rules in
`domain-auto-save.lisp`; `infrastructure-auto-save.lisp` writes the complete
buffer text without changing the buffer's normal modified state, and
`application-commands-auto-save.lisp` owns global/per-buffer mode and interval
gating. The event loop invokes the pass after input dispatch, so auto-save does
not introduce a second writer thread into the editor state.

The bounded asynchronous directory-listing runtime is split across
`packages/feature/file-tree/src/infrastructure-concurrent-runtime-state.lisp`
(the runtime struct, directory cache, and generation bookkeeping),
`infrastructure-concurrent-runtime-prefetch.lisp` (submitting uncached
directories to `cl-concurrent-kit` workers), and
`infrastructure-concurrent-runtime-results.lisp` (draining and applying
worker results, plus shutdown). It uses `cl-concurrent-kit` workers, a bounded
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

`packages/feature/mode/src/domain-major-mode-definitions.lisp` keeps built-in
mode metadata alongside the extension-defined mode registry state;
`domain-major-mode.lisp` holds the read-side lookup API over that state, and
`domain-major-mode-registry.lisp` holds registration and validation. The pure
`domain-major-mode-path.lisp` module normalizes paths and performs basename,
extension, registry, and default matching without filesystem access.
Extensions register file associations, syntax metadata, parent modes, and
local keybindings with `register-major-mode`. `application-major-mode.lisp`
materializes those local bindings as keymaps whose parents are the registered
parent mode and then the editor's global keymap. `input-dispatch.lisp` refreshes
this layered map when dispatching, so changing a buffer's mode reroutes
subsequent input while preserving global fallback. A local first chord shadows
the matching parent subtree; unrelated parent bindings continue to resolve.

The workspace feature keeps an ordered `workspace-manager` in editor state.
Each named workspace owns an independent window tree while buffers remain in
the session-wide registry. Workspace commands synchronize the active tree
before switching or deletion; creation appends a named workspace in the domain
layer and the application layer explicitly activates it afterward. The
presentation layer includes the active workspace name in the shortcut/status
line. Session v5 persists every workspace's layout and selected window.

`src/presentation/layout.lisp` composes the current state into screen regions;
`src/presentation/layout-minibuffer.lisp` owns minibuffer and completion-popup
rendering so the main layout module remains focused on geometry and region
composition.
A buffer position is a character count while a screen position is a cell
count, and a full-width character occupies two cells, so
`%layout-screen-column` is the single conversion between them: cursor
placement, the `Ln`/`Col` indicator, and horizontal viewport following all go
through it rather than each measuring the line again. Each window carries a
`window-scroll-column` in cells alongside its `window-scroll-line` in lines;
`%layout-keep-point-visible` maintains both, and drawing clips through
`loom-renderer-clip-index` so a scrolled line never begins inside a
full-width character. That column stays out of `window-tree-layout`, so
session v5 is unaffected.

A buffer chooses between truncating and wrapping through
`loom:buffer-truncate-lines`, which is `t`, `nil`, or `:default`;
`loom/feature/mode:buffer-truncate-lines-p` resolves `:default` from the mode's
own `:truncate-lines`, so code modes truncate and `markdown`, `org`, and `text`
wrap. The setting is on the buffer rather than the window, which is what keeps
one file shown in two windows from disagreeing with itself, and it is not
persisted into a session. A wrapping window's viewport is a
(`window-scroll-line`, `window-scroll-sub-row`) pair rather than a line, and a
wrapped row is drawn as the same logical line offset to the screen column its
segment begins on -- the truncating path's clipping rule, reused rather than
restated. Because point can be far from the viewport, the follower walks back
from point by the window height instead of forward from the old position, which
is what keeps a jump costing the window's height rather than the distance
(NFR-001). `next-line` and `previous-line` move by screen row, matching Emacs's
`line-move-visual` default, and carry their goal column in cells so a
full-width character does not shift it.

Structural motion needs to know which parentheses are structure.
`packages/core/editor/src/application-sexp-motion.lisp` classifies the whole
visible text in one left-to-right pass -- reader state is what decides a
character's class, so there is no reading one in isolation -- and marks strings,
`;` and `#| |#` comments, and the payload of a `#\` character literal as
something other than code. `forward-sexp` and its siblings, `kill-sexp`, and
`%layout-draw-matching-paren` all work against that classification, which is why
a parenthesis inside a string is stepped over as part of its atom rather than
counted, and why an unbalanced form is shown no partner at all instead of a
wrong one. `C-M-` chords made the key-form shape variable-length, so
`defkeys-chord` validates modifiers and code explicitly rather than relying on
a fixed arity, and `%key-event->descriptor` keeps the `:alt` an ESC-prefixed
Ctrl+letter carries instead of discarding it.

The structural editing commands in
`packages/core/editor/src/application-structural-editing.lisp` are expressed as
lists of edits against the visible text rather than as a rewritten region: a
whole-region replacement would move every mark in the buffer, and moving a
single delimiter is what keeps parentheses balanced by construction. The edits
are applied highest-offset-first, so each one runs while the offsets still
ahead of it describe the text they were computed against, and they land in one
undo group because the dispatcher records the only boundary before the command
starts. An operation that finds nothing to act on returns no edits and leaves
the buffer alone rather than half-applying.

Incremental search is the one prompt that acts while it is still being typed.
`minibuffer-activate`'s `on-change` hook fires after every edit to the input and
`on-key` gets first refusal on each key event, which is what keeps `C-s` inside
an active prompt from being typed into the pattern; both normalize the two
terminal encodings of Ctrl+letter through the same `%key-event->descriptor` the
global keymap routes through. The session itself lives in
`editor-state-isearch` rather than in the command's closure, because the
renderer has to read it: `%layout-draw-isearch` repaints every match, and the
one point sits on in a second style, using the same row and column geometry the
buffer text was drawn with. It is transient and never reaches session v5.

`src/application/startup.lisp` is the composition root for argv parsing,
editor-state construction, terminal-session setup, and asynchronous resource
shutdown. `src/application/event-loop.lisp` owns frame rendering, resize
polling, and the event-loop boundary. `src/application/input-dispatch.lisp`
owns raw-octet reading, event decoding, and dispatch to minibuffer,

Startup failures cross the application boundary through `cl-log-kit` directly.
The logger emits a human-readable error on `*error-output*` while retaining the
logger name and condition type as structured fields, so command-line failures
remain useful in a terminal and are also identifiable by process supervisors.
The dependency is declared in both `loom.asd` and the flake's runtime
`lispDependencies`; the dependency contract test keeps those declarations in
sync.
self-insert, or the global keymap. `src/main.lisp` is only the executable
trampoline.

## Toolkit Foundation

- **[cl-tty-kit](https://github.com/nerima-lisp/cl-tty-kit)** provides raw-mode
  terminal sessions, event decoding, and the double-buffered renderer used by
  the event loop and the terminal-renderer infrastructure files.
- **[cl-boundary-kit](https://github.com/nerima-lisp/cl-boundary-kit)** provides
  the filesystem object used by buffer load/save and most file-tree mutations.
  Its test filesystem keeps those tests independent of a real directory.
- **[cl-host-kit](https://github.com/nerima-lisp/cl-host-kit)** is used directly
  for directory-entry classification, symlink-safe recursive deletion,
  overwrite-safe session-file moves, and user-init environment lookup.
- **[cl-history-kit](https://github.com/nerima-lisp/cl-history-kit)** stores
  minibuffer history for find-file, save-buffer, and file-tree prompts.
- **[cl-prolog-kit](https://github.com/nerima-lisp/cl-prolog-kit)** evaluates the
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
`cl-host-kit`, `cl-history-kit`, `cl-prolog-kit`, `cl-cli`, `cl-regex-kit`,
`cl-boundary-kit`, `cl-json-kit`, `cl-concurrent-kit`, `cl-log-kit`, and
`cl-vcs-kit`. The
test system adds `cl-weave`, `cl-date-kit`, `cl-codec-kit`, `cl-parser-kit`,
`cl-regex-kit`, `cl-boundary-kit`, `cl-concurrent-kit`, `cl-process-kit`, and
`cl-vcs-kit`; these are explicit because the tests exercise their public
protocols and test fixtures. The Nix flake pins the runtime and test inputs and supplies
the development shell used by the commands below.

The development shell also supplies `paredit`, the structural Common Lisp
inspector and rewriter. Its `paredit-lint` flake check parses the source set
before packaging, keeping syntax validation separate from formatter and
behavioral test checks.

The LSP process transport intentionally uses UIOP and Common Lisp binary stream
primitives directly because it needs unsigned-byte `Content-Length` framing;
`cl-json-kit` supplies only the message representation and JSON boundary. This
keeps the process boundary explicit instead of introducing a character-stream
wrapper that cannot represent the protocol's framing bytes safely.

## Test Suite

The `loom/test` ASDF system is run by the same script locally and in Nix:

```sh
nix develop -c sbcl --script run-tests.lisp
```

The `loom/test` ASDF component order is declared in `loom.asd`, which is the
source of truth as unit and integration coverage evolves. The current suite
includes focused tests for buffers, keymaps, rendering, filesystems,
minibuffers, syntax highlighting, major modes, projects, evaluation, shell
command results, formatting, Git status and diff, terminal sessions, auto-save, the CLI,
registers, keyboard macros, prefixes, and the file tree.
Integration coverage includes commands, LSP, editing and movement, major
modes, projects, layout, sessions, user
initialization, shell command registration, the concurrent runtime, and editor
flows.

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

The cl-weave runner writes `coverage.data` and an HTML report under the selected
coverage directory. It rejects a no-test run and an empty source-expression
selection. The report's SB-COVER expression and branch totals are recorded
separately. The report is restricted to Loom's `src/` and `packages/` trees, so
the package-by-feature implementation is included in the measurement. Branch
coverage does not establish full expression coverage; the generated report is
the source of truth for uncovered forms. SB-COVER is process-local,
so top-level declarations and the child-process-only `loom:main` path can
remain unexecuted in the report; those forms are reported rather than hidden.
`nix flake check --all-systems --print-build-logs` additionally runs the test
(`checks.default`), package (`checks.build`), formatter (`checks.formatting`),
paredit structural syntax (`checks.paredit-lint`), coverage (`checks.coverage`),
and strict MkDocs documentation (`checks.docs`) checks.

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
