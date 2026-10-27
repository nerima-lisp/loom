# Architecture

`loom.asd` composes the application from core and feature ASDF systems. The
application entry point and terminal composition live under `src/`; reusable
editor APIs and feature implementations live under `packages/`.

## Source and system boundaries

The root source tree contains application orchestration, terminal
infrastructure, and presentation:

```text
src/
├── application/     startup, input dispatch, and event loop
├── infrastructure/  terminal renderer adapter
├── presentation/    frame and screen layout
└── main.lisp         executable entry point

packages/
├── core/             shared editor APIs, each in its own ASDF system
└── feature/          editor features, each in its own ASDF system
```

The core APIs are separated by responsibility:

| ASDF system | API package | Responsibility | Direct Loom dependencies |
|---|---|---|---|
| `loom-core-buffer` | `loom/core/buffer` | Buffer text, positions, regions, undo, narrowing, and read-only state | none |
| `loom-core-window-tree` | `loom/core/window-tree` | Window tree, selection, layout, geometry, and scroll state | none |
| `loom-core-editor-session` | `loom/core/editor-session` | Session envelope, slice state, editor-state composition, and extension registries | `loom-core-buffer`, `loom-core-window-tree` |
| `loom-core-minibuffer` | `loom/core/minibuffer` | Prompt, completion, message, and history operations | none |
| `loom-core-command` | `loom/core/command` | Keymaps, prefix arguments, command registry, and dispatch | `loom-core-package-bootstrap`, `loom-core-buffer`, `loom-core-window-tree`, `loom-core-editor-session`, `loom-core-minibuffer` |

`loom-core-package-bootstrap` is an ASDF system rather than a sixth API
package. It loads package declarations for the command, buffer, files,
bookmark, root `loom`, and `loom/application` packages. It depends on
`loom-core-buffer`, `loom-core-window-tree`, `loom-core-editor-session`, and
`loom-core-minibuffer`. The core command system depends on it before loading
the command implementation.

Feature systems depend on the core APIs and may depend on other feature
systems. For example, `loom-feature-files` uses the buffer registry and major
modes; `loom-feature-file-tree` uses file operations; and `loom-feature-lsp`
uses buffers, file-tree, project discovery, and major-mode language IDs. Their
ASDF definitions declare these edges. A dependency is allowed only when it is
listed in the system's `:depends-on`; feature-to-feature edges must remain
acyclic. The root `loom` system depends on the core and feature systems and
provides the executable composition.

The root `loom` package is a convenience facade. It re-exports selected core
APIs and selected helpers from bookmark, files, and completion. The
`loom/application` package re-exports selected command-specification,
completion, prompt, and keybinding helpers. Feature packages remain the
canonical owners of feature APIs; see the [API reference](api.md) and
[feature API reference](api/features.md).

## Session state

`loom/core/editor-session` provides an opaque session envelope keyed by slice
name. A feature registers a state constructor with `register-slice-state` when
its ASDF component loads. `make-editor-session` receives the requested slice
names from its caller and constructs state in that order. Initial state entries
are installed before constructors run. A constructor can depend on an initial
state or a slice requested earlier; the ASDF load order does not impose a
separate global constructor order.

Stateful feature slices include buffers, keyboard macros, LSP, projects,
search, and workspaces. `editor-session-slice` reads a slice's state, while
`editor-session-slice-names` returns a copy of the session's names. `nil` is a
valid state value and is distinct from a slice absent from the session.

The buffer registry is owned by `loom/feature/buffers` under
`:feature/buffers`. Its query returns a copy; unregistering a buffer runs the
buffer-close hook before removal. `switch-to-buffer` and `kill-buffer` are
buffer-feature commands. File visits, saves, recent-file tracking, and file
snapshots are owned by `loom/feature/files`. The file-tree package re-exports
some file command names, but the canonical file API belongs to `files`.
Window data and layout belong to `loom/core/window-tree`; interactive window
commands belong to `loom/feature/window`.

The root `editor-state` groups application services and references the
`editor-session`. It requires a session, and its window tree must be the same
object as the session's `:core/window-tree` slice. Slice state is read through
the session API rather than a root buffer-registry accessor.

## Command registration and dispatch

`command-spec` is a macro for building declarative command data. Its required
classification fields are `:mutates`, `:prompts`, `:needs-region`, `:external`,
and `:modes`; the data form is not a registered runtime command.

Core and feature command components register runtime specs while their ASDF
components load. `register-command-spec` records an owner, stable string ID,
optional M-x name, function, key bindings, and metadata. Registration checks
ID, name, and key conflicts. Keymaps store command IDs. Dispatch resolves the
ID and routes the call through `invoke-command(id, route, &rest arguments)`,
which records the route before invoking the function. Routes include `:key`,
`:mx`, `:macro`, `:paste`, and `:mouse`.

`keymap-state-dispatch` passes a resolved command ID, normalized key sequence,
and keymap name to its caller-supplied invoker for registry dispatch. The
`loom/application` facade exposes command-data and
keybinding helpers; the canonical registry and dispatch APIs are in
`loom/core/command`.

## Session hooks

`register-session-hook(kind, owner, function)` adds an extension callback;
`run-session-hooks` dispatches callbacks in the registered owner order and
preserves registration order within an owner. The hook kinds are `:tick`,
`:resize`, `:key-input`, `:input-event`, `:render`, `:terminal-modes`,
`:before-save`, `:after-save`, `:buffer-close`, `:startup`, `:signal`,
`:suspend`, `:resume`, `:shutdown`, and `:exit-status`.

The lifecycle hooks `:startup`, `:signal`, `:suspend`, `:resume`, `:shutdown`,
and `:exit-status` require owner `:feature/lifecycle`. Key and input-event hooks
return `:pass` or `:handled`. Render hooks return render operations, while
terminal-mode hooks return supported mode keywords. Signal hooks return
`:continue` or `:terminate`; exit-status hooks return an integer from 0 through
255. Terminal-mode hooks can request `:mouse-sgr`, `:mouse-button-event`, and
`:bracketed-paste`. A resize dispatch receives the session, width, and height.

## Language server integration

The LSP registry is scoped to the editor session and selects a server by
canonical project root and language ID. The language ID comes from the
selected buffer's major mode. The editor supports diagnostics; completion,
definition navigation, and hover are available when the server advertises the
corresponding capabilities. It also supports popping the most recent definition
jump.

`lsp-discover-command` reads the first usable line from the nearest ancestor
`.loom-lsp` file. For a usable entry it returns argv, project root,
configuration pathname, a configuration identity, and the source line for
review. A missing or unusable entry returns three `nil` values. Discovery
splits arguments without a shell and rejects shell operators and quoting
syntax. Starting a discovered command requires the user to review it and enter
exactly `yes`; the configuration identity is checked again before process
creation. A manually entered command is parsed into argv without the discovery
trust prompt.

The LSP process transport and protocol code live in `packages/feature/lsp/`.
Project discovery and language IDs are provided by `packages/feature/project/`
and `packages/feature/mode/` respectively.
