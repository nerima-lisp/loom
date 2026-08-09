# Core Concepts

loom keeps the editor kernel small and puts user-facing behavior in feature
slices. The main concepts below explain how those pieces fit together before
you read the [API reference](../reference/api.md) or the
[architecture notes](../reference/architecture.md).

## Buffers and positions

A buffer owns editable text, its file identity, point, mark, modification
state, and undo boundaries. Commands operate on buffers through the shared
`loom` package, so editing behavior does not need to know how the terminal
draws the result.

Positions have both line/column and character-offset forms. The buffer API
provides conversion helpers and spans so features such as search, evaluation,
and diagnostics can refer to the same text without maintaining separate
coordinate systems.

## Windows and rendering

A window tree describes which buffers are visible and how the screen is split.
Window commands change that tree; the renderer turns the selected layout and
buffer contents into terminal output. This separation lets window operations
remain testable without a live terminal.

The editor state holds the selected window, buffers, minibuffer, keymap,
renderer, and feature state. Commands receive that shared state through the
application layer rather than reaching into presentation code directly.

## Keymaps and commands

Keymaps resolve single chords and multi-key sequences. A command specification
records the command name, callable action, and completion metadata. The command
catalogue is defined in
[`src/application/command-definitions.lisp`](https://github.com/nerima-lisp/loom/blob/main/src/application/command-definitions.lisp),
while the registry provides lookup and M-x completion.

Default bindings are installed by
[`src/application/commands-keybindings.lisp`](https://github.com/nerima-lisp/loom/blob/main/src/application/commands-keybindings.lisp).
Feature commands can therefore share the same dispatch path whether they are
invoked by a key sequence, M-x, or a user initialization file.

## Feature slices

Feature packages under `packages/feature/` own cohesive behavior such as
windows, the file tree, major modes, projects, evaluation, sessions, LSP,
registers, and keyboard macros. Their source is organized around domain,
application, infrastructure, and presentation responsibilities where those
layers are needed.

The root `loom` package exposes the editor kernel. Feature packages expose
their own domain and application APIs, which keeps optional behavior out of
the kernel while allowing the composition root to assemble the complete
editor. See the [API reference](../reference/api.md) for the public exports.

## Concurrent file-tree work

Directory discovery runs through a bounded concurrent runtime. Workers perform
filesystem work, while cache updates and rendering are drained on the
editor's render lane. A generation identifies the current request, allowing
stale results to be discarded when the user changes directory or refreshes the
tree.

This boundary keeps background I/O from mutating editor-visible state at
arbitrary times. The lifecycle is explicit: create the runtime, prime or
prefetch a directory, drain completed work, invalidate stale entries when
needed, and shut the runtime down during teardown.

## Reading the repository

Start with [Getting Started](../getting-started.md) to build and run loom.
Use the [architecture reference](../reference/architecture.md) for load order
and layer boundaries, and the [development guide](../project/development.md)
for tests, coverage, and local checks.
