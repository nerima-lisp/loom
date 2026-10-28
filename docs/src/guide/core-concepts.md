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
Use `C-x 2` to split below, `C-x 3` to split right, and `C-x o` to select the
next window. `C-x 0` deletes the selected window; `C-x 1` keeps only that
window. Window commands change the tree; the renderer turns the selected layout
and buffer contents into terminal output. This separation lets window
operations remain testable without a live terminal.

The editor state holds the selected window, buffers, minibuffer, keymap,
renderer, and feature state. Commands receive that shared state through the
application layer rather than reaching into presentation code directly.

## Keymaps and commands

Keymaps resolve single chords and multi-key sequences. A command specification
records the command name, callable action, and completion metadata. Feature-
owned command specification files register commands through the shared
registry. The registration code is in
`packages/core/command/src/command-registry-registration.lisp`; a file-tree
command specification is in
`packages/feature/file-tree/src/command-specs-file-tree.lisp`. The registry
provides lookup and M-x completion.

Default bindings are declared in
`packages/core/command/src/application-commands-emacs-defaults.lisp`.
Feature commands share the same dispatch path whether they are invoked by a key
sequence, M-x, or a user initialization file.

## Search, kill ring, and clipboard

Use `C-s` and `C-r` for forward and backward search. `C-M-s` and `C-M-r` search
with regular expressions.

After setting a region, `C-w` removes it and adds it to the kill ring; `M-w`
copies it to the kill ring without changing the buffer. `C-y` inserts the most
recent entry, and `M-y` cycles through earlier entries after a yank. Run
`M-x clipboard-yank` to insert text from the system clipboard when a local
clipboard provider is available. If reading the clipboard fails or no provider
is available, the command falls back to the kill ring.

## Language modes

When a file is opened, loom selects a registered major mode from its path when
one matches. The mode controls language-specific behavior such as syntax
highlighting and local keybindings. Run `M-x set-major-mode` to choose a
registered mode for the selected buffer.

## Sessions

Run `C-x r S` to save the current editor session to a chosen path. Run
`M-x load-session` and choose a saved path to restore a session.

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

`M-x lsp-format-buffer` asks the language server to format the selected file's
full document when it advertises `documentFormattingProvider`. The returned
edits are validated and applied as one undoable change. If the buffer changes or
closes while the request is pending, loom discards the response. If the server
does not support formatting, loom reports that in the minibuffer.

## Language server support

Run `M-x lsp-start` in a file-backed buffer to start a language server. loom
searches the current path's ancestor directories for the nearest `.loom-lsp`
file. Its first non-empty, non-comment line supplies the server command. loom
shows a discovered command, its configuration path, and directory for review;
type `yes` at the confirmation prompt to start it. If no command is discovered,
enter a server command at the prompt.

The current LSP commands provide diagnostics, completion, navigation, hover,
rename, references, and formatting:

- Run `M-x lsp-diagnostics` to refresh and display diagnostics for the selected
  file-backed buffer.
- Use `C-M-i` to request completion at point.
- Use `M-.` to jump to a definition and `M-,` to return to the saved location.
- Run `M-x lsp-hover-at-point` to show hover information in the minibuffer when
  the server advertises hover support.
- Run `M-x lsp-find-references` to show local references in a result list.
- Run `M-x lsp-rename` to apply the server's validated WorkspaceEdit.
- Run `M-x lsp-format-buffer` to format the selected file when the server
  advertises formatting support.

## Git status, staging, and diff

`C-x g` and `M-x git-status` run `git status --short --branch` from the current
project root and show standard output in the read-only `*Loom-Git-Status*`
buffer, falling back to standard error when standard output is empty.
`M-x git-diff` displays the
working-tree patch and `M-x git-diff-staged` displays the index patch in the
read-only `*Loom-Git-Diff*` buffer, with the same output selection.
Non-zero exit statuses are reported in the minibuffer. `M-x git-stage-file`
prompts for a repository path and runs `git add` from the project root;
`M-x git-unstage-file` removes that path from the index with
`git restore --staged`. Paths are passed as arguments after `--`, not as shell
command text. Both index commands report their outcome in the minibuffer.

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

`M-x auto-save-mode` toggles the global mode, while `M-x toggle-auto-save`
toggles the selected buffer's individual registration. Auto-save is enabled
when either is active: removing an individual registration does not disable it
while global mode is active, and disabling global mode preserves individual
registrations. The event loop periodically writes modified, writable file-backed
buffers to a `#file-name#` sidecar without clearing their modified state. Unmodified and
read-only buffers are skipped. A normal buffer save runs the editor state's
after-save hooks, which can remove the sidecar or trigger other save-follow-up
work.

## Concurrent file-tree work

Directory discovery runs through a bounded concurrent runtime. Workers perform
filesystem work, while cache updates and rendering are drained on the
editor's render lane. Each directory has its own generation. Priming or
invalidating that directory advances its generation, so results from an older
generation are discarded. Navigating to or expanding a directory does not by
itself advance the generation.

This boundary keeps background I/O from mutating editor-visible state at
arbitrary times. The lifecycle is explicit: create the runtime, prime or
prefetch a directory, drain completed work, invalidate stale entries when
needed, and shut the runtime down during teardown.

## Reading the repository

Start with [Getting Started](../getting-started.md) to build and run loom.
Use the [architecture reference](../reference/architecture.md) for load order
and layer boundaries, and the [development guide](../project/development.md)
for tests, coverage, and local checks.
