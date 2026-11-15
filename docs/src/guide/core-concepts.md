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

`M-z` (`zap-to-char`) prompts for a character and kills through its next
occurrence; with a negative prefix argument it searches backward. The killed
text joins the kill ring under the same rules as `C-k`. The match is
case-sensitive, unlike Emacs, which follows `case-fold-search`.

## Editing commands

| Key | Command | Action |
| --- | --- | --- |
| `M-m` | `back-to-indentation` | Move to the first non-blank character of the line |
| `M-\` | `delete-horizontal-space` | Delete spaces and tabs around point; with a prefix argument, only before point |
| `M-SPC` | `just-one-space` | Leave one space around point, or N with a prefix argument; a negative N also deletes newlines |
| `M-t` | `transpose-words` | Swap the words around point and move past them |
| `M-=` | `count-words-region` | Report the lines, words, and characters in the region, or in the buffer without a region |

Commands that change text are undone with one undo and are rejected in
read-only buffers. On macOS, set the terminal emulator to use Option as Meta to
type `M-SPC`.

## Buffer list and saving several buffers

`C-x C-b` (`list-buffers`) shows the read-only `*Buffer List*` in another
window. In the list, `n` and `p` move between lines, `RET` and `o` show the
buffer in this or another window, `d` and `s` mark the buffer for deletion or
saving, `u` removes the mark, `x` applies the marks, `g` refreshes the list,
and `q` closes it.

`C-x s` (`save-some-buffers`) asks about each modified file-backed buffer:
`y` saves, `n` skips, `!` saves the rest, `q` stops, and `C-g` quits. A prefix
argument does not skip the questions.

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

- The mode line shows counts by diagnostic severity. Run `M-x lsp-diagnostics`
  to refresh and display diagnostics for the selected file-backed buffer in
  `*Loom-Diagnostics*`. Each entry shows a 1-based line and column, message, and
  severity and source when the server provides them.
- Use `C-M-i` to request completion at point.
- Use `M-.` to jump to a definition and `M-,` to return to the saved location.
- Run `M-x lsp-hover-at-point` to show hover information in the minibuffer when
  the server advertises hover support.
- Run `M-x lsp-find-references` at a symbol to list references returned for
  local files in the read-only `*Loom-References*` result buffer. Declarations
  are included when returned by the server; non-local locations are not listed.
- Run `M-x lsp-rename` at a symbol and enter its new name at the prompt. loom
  validates the server's edits before applying them and reports edits it cannot
  safely apply.
- Run `M-x lsp-format-buffer` to format the selected file when the server
  advertises formatting support.

loom also answers requests that the server sends, such as
`workspace/configuration`. For `window/showMessageRequest`, loom prompts you to
choose one of the server's actions; `C-g` declines. Requests that loom does not
handle receive a "Method not found" error and are recorded in `*Messages*`.

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

## Recovering unsaved work

When loom receives SIGTERM or SIGHUP, it writes the text of modified buffers to
recovery files under `~/.loom/recovery/`. When you open a file whose recovery
file, or auto-save sidecar if auto-save is enabled, is newer than the file and
differs from the buffer, loom reports it in the minibuffer. Run `M-x recover-file` to choose: `r`
replaces the buffer text as one undoable edit without saving, `d` shows a
unified diff in `*Loom-Recover-Diff*`, `i` ignores the work, and `C-g` quits.
`M-x list-recoverable-files` lists every recoverable file in `*Loom-Recover*`;
`RET` on a line opens the file and continues with `recover-file`. Saving the
file deletes its sidecar and recovery files.

loom also locks each open file under `~/.loom/locks/`. If another loom process
has the file open, loom reports that process instead of offering recovery.

## Interrupting evaluation

`M-:`, `C-x C-e`, and `M-x eval-buffer` evaluate on the main thread. Press
`C-g` to interrupt an evaluation; loom reports `Evaluation interrupted`. A
second `C-g` forces the interruption through cleanup code that blocks. Other
keys typed during evaluation run after it ends, in the order typed. The screen
does not redraw while an evaluation runs.

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
