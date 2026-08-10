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
windows, the file tree, major modes, projects, evaluation, shell commands,
formatting, auto-save, Git status and diff views, sessions, LSP, registers, and keyboard
macros. Their source is organized around domain, application, infrastructure,
and presentation responsibilities where those layers are needed.

The root `loom` package exposes the editor kernel. Feature packages expose
their own domain and application APIs, which keeps optional behavior out of
the kernel while allowing the composition root to assemble the complete
editor. See the [API reference](../reference/api.md) for the public exports.

## Shell commands

`M-!` and `M-x pipe-command` prompt for a shell command, run it in the
selected file's directory, and show its standard output, standard error, and
exit code in `*Loom-Pipe-Command*`. The result buffer is reused and appended
to, so successive commands remain available for inspection.

## Code formatting

`M-x format-current-buffer` prompts for an external formatter command and
sends the complete buffer through its standard input. Successful output replaces
the buffer as one undoable edit; failed commands, read-only buffers, and
narrowed buffers leave the original text unchanged.

## Git status, staging, and diff

`C-x g` and `M-x git-status` run `git status --short --branch` from the current
project root and show standard output, standard error, and the exit status in
the read-only `*Loom-Git-Status*` buffer. `M-x git-diff` displays the
working-tree patch and `M-x git-diff-staged` displays the index patch in the
read-only `*Loom-Git-Diff*` buffer. Git's standard output, standard error, and
non-zero exit status remain visible in the result buffer. `M-x git-stage-file`
prompts for a repository path and runs `git add` from the project root;
`M-x git-unstage-file` removes that path from the index with
`git restore --staged`. Paths are shell-quoted before execution, and each
command reports its Git exit status in the minibuffer.

## Terminal sessions

`M-x terminal` starts a child process in a PTY and selects its read-only
terminal buffer. While that buffer is selected, ordinary characters, paste
events, control keys, and supported special keys are sent to the child process;
editor commands such as `C-x` prefixes and `M-x` remain available. `M-x
terminal-stop` closes the selected session. The event loop polls PTY output and
propagates terminal-size changes without a second editor-state writer thread.

The terminal keeps both a raw transcript and a bounded ANSI screen model. The
screen model handles common cursor-addressed movement, line/character erasure,
cursor save/restore, and the minimal alternate-screen modes used by many
full-screen programs. It is not a full VT compatibility layer, so richer
terminal capabilities remain a follow-up concern.

## Auto-save

`M-x auto-save-mode` enables or disables automatic saving for all registered
buffers, while `M-x toggle-auto-save` controls the selected buffer. The event
loop periodically writes modified, writable file-backed buffers to a
`#file-name#` sidecar without clearing their modified state. Unmodified and
read-only buffers are skipped. A normal buffer save runs the editor state's
after-save hooks, which can remove the sidecar or trigger other save-follow-up
work.

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
