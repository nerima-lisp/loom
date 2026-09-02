# Feature APIs

This page documents the public APIs for optional editor features.

## Major mode feature

Public symbols from `loom/feature/mode`.

### `major-mode-known-p`

Return true when a mode name is registered.

### `major-mode-from-name`

Return the major-mode object identified by a name.

### `major-mode-name`

Return a major mode's display name.

### `major-mode-comment-prefix`

Return the comment prefix used by a major mode.

### `major-mode-indentation-width`

Return a major mode's indentation width.

### `major-mode-language-id`

Return the language identifier associated with a major mode.

### `major-mode-keywords`

Return the syntax keyword table for a major mode.

### `major-mode-truncate-lines-p`

Return true when a mode displays long lines truncated rather than wrapped. Code
modes truncate; `markdown`, `org`, and `text` wrap. A mode that declares nothing
truncates, which is what loom did before the setting existed.

### `buffer-truncate-lines-p`

Return true when a buffer's long lines should be truncated. Only a buffer whose
`loom:buffer-truncate-lines` is `:default` consults its major mode.

### `major-mode-parent`

Return a mode's parent mode, or `nil` for an unknown mode. Built-in and
extension-defined modes without an explicit parent use `:fundamental`.

### `major-mode-keybindings`

Return a copy of a mode's local keybinding specifications. Each specification
is a `(key-form . command)` pair; the command is a function designator or a
fbound, non-macro symbol.

### `major-mode-definition`

Return a copy of a mode's complete metadata definition, including its parent,
file associations, syntax metadata, and local keybindings.

### `major-mode-names`

Return the registered major-mode names.

### `major-mode-for-path`

Infer and return a major mode for a pathname.

### `register-major-mode`

```lisp
(loom/feature/mode:register-major-mode
 mode &key name aliases parent extensions filenames comment-prefix
 indentation-width language-id keywords keybindings)
```

Register an extension-defined major mode and return its canonical keyword.
`aliases`, `extensions`, and `filenames` participate in name and pathname
inference; extensions may be written with or without a leading dot. The
optional `parent` supplies inherited mode-local bindings and defaults to
`:fundamental`.

### `unregister-major-mode`

Remove a dynamically registered mode and return its canonical keyword. Built-in
modes cannot be removed, and an unknown mode returns `nil`.

### `major-mode-keymap`

```lisp
(loom/feature/mode:major-mode-keymap mode fallback)
```

Return the mode-local keymap layered over `fallback`, recursively including
registered parent modes. The result is cached until the mode registry or
fallback changes.

### `current-major-mode`

Return the major mode currently active in the selected buffer.

### `set-major-mode`

Set the selected buffer's major mode and return the mode.

### `toggle-truncate-lines`

Flip the selected buffer between truncating and wrapping long lines
(`M-x toggle-truncate-lines`). The flip resolves the mode default first and
stores the opposite as an explicit choice, so the first toggle always changes
something and a later mode change no longer overrides it.

### `indent-for-tab-command`

Indent the current line according to the selected buffer's major mode.

### `comment-line`

Comment or uncomment the current line according to its major mode.

## Syntax-highlighting feature

Public symbols from `loom/feature/syntax-highlighting`.

### `syntax-token`

The syntax-token value type used by syntax highlighting.

### `syntax-token-p`

Return true when an object is a syntax token.

### `syntax-token-kind`

Return a syntax token's kind.

### `syntax-token-text`

Return the source text represented by a syntax token.

### `syntax-highlight-line`

Tokenize and return highlighted spans for one source line.

### `syntax-highlight-line-for-mode`

Tokenize one source line using an explicitly supplied major mode.

### `syntax-draw-highlighted-line`

```lisp
(loom/feature/syntax-highlighting:syntax-draw-highlighted-line
 renderer line x y width &optional mode)
```

Draw one highlighted source line through the renderer.

### `syntax-draw-buffer`

```lisp
(loom/feature/syntax-highlighting:syntax-draw-buffer
 renderer buffer x y width height &key start-line)
```

Draw the visible portion of `buffer` with line-local syntax styles.

## Project feature

Public symbols from `loom/feature/project`.

### `project-marker-names`

Return the filenames that identify a project root.

### `project-ignored-directory-names`

Return directory names excluded from project file searches.

### `project-marker-name-p`

Return true when a filename is a recognized project marker.

### `project-directory-path`

Return the directory form of a project path.

### `project-parent-directory`

Return the parent directory of a project path.

### `project-root-for-path`

Find and return the project root containing a path.

### `project-relative-path`

Return a path relative to a project root.

### `project-search-lines`

Search project files line by line and return matching locations.

### `project-find-root`

Find a project root from a starting directory.

### `project-list-files`

Return the project files eligible for project operations.

### `project-search-files`

Search the eligible files in a project for a pattern.

### `project-find-file`

Find a project file by its project-relative name.

### `project-search`

Run the interactive project search command.

### `project-root`

Return the project root associated with the current editor context.

## Search feature

Public symbols from `loom/feature/search`.

### `buffer-search-forward`

Search forward from the current buffer position.

### `buffer-search-backward`

Search backward from the current buffer position.

### `buffer-search-spans`

Return all matching spans for a buffer search.

### `make-isearch-session`

```lisp
(loom/feature/search:make-isearch-session buffer origin-offset
                                          &key direction)
```

Start an incremental-search session over `buffer`, remembering `origin-offset`
as the point `C-g` returns to.

### `isearch-apply-pattern`

Search for a new pattern from the session's current search offset and return
the session. A longer pattern searches from the same offset, so the match grows
in place. The empty pattern the prompt opens with is not a failure.

### `isearch-repeat`

Advance the session to the next match in `:forward` or `:backward`, wrapping
once. A repeat on a failed pattern leaves the session where it is, so point
stops moving.

### `isearch-session-match` / `isearch-session-matches`

Return the span point currently sits on, and every span the pattern matches in
buffer order. The renderer draws the two differently.

### `isearch-session-buffer` / `isearch-session-origin-offset` / `isearch-session-direction` / `isearch-session-pattern` / `isearch-session-failed-p`

The rest of the session's readable state.

### `replace-string`

Replace matching text in the selected buffer.

### `isearch-forward`

Search forward as the pattern is typed (`C-s`). Each keystroke moves point to
the next match, a further `C-s` advances and `C-r` turns around, RET keeps
point and files the pattern in the minibuffer history, and `C-g` returns point
to where the search started. A failing pattern says so in the prompt and stops
moving point.

### `isearch-backward`

Search backward as the pattern is typed (`C-r`). See `isearch-forward`.

### `search-forward`

Run the non-incremental forward-search command, which reads a whole pattern
before moving. Available as `M-x search-forward`; `C-s` runs `isearch-forward`.

### `search-backward`

Run the non-incremental backward-search command. Available as
`M-x search-backward`; `C-r` runs `isearch-backward`.

## Evaluation feature

Public symbols from `loom/feature/evaluation`.

### `evaluation-result`

The evaluation-result value type returned by Lisp evaluation.

### `make-evaluation-result`

Construct an evaluation result value.

### `evaluation-result-p`

Return true when an object is an evaluation result.

### `evaluation-result-form-count`

Return the number of forms evaluated in a result.

### `evaluation-result-value-lines`

Return printed value lines from an evaluation result.

### `evaluation-result-output`

Return standard output captured by an evaluation result.

### `evaluation-result-error-output`

Return error output captured by an evaluation result.

### `evaluation-result-error-message`

Return the formatted error message from an unsuccessful result.

### `evaluation-result-success-p`

Return true when evaluation completed successfully.

### `evaluation-result-text`

Return the display-oriented text for an evaluation result.

### `evaluate-lisp-source`

Evaluate a string containing one or more Common Lisp forms.

### `eval-expression`

Evaluate one interactive Lisp expression.

### `eval-buffer`

Evaluate the contents of the selected buffer.

## Shell feature

Public symbols from `loom/feature/shell`.

### `shell-command-result`

The captured result value for one shell command invocation.

### `make-shell-command-result`

Construct a shell command result with its command, directory, output streams,
and exit code.

### `shell-command-result-command`, `shell-command-result-directory`

Return the command string and canonical working directory.

### `shell-command-result-output`, `shell-command-result-error-output`

Return captured standard output and standard error separately.

### `shell-command-result-exit-code`

Return the process exit code.

### `shell-command-result-success-p`

Return true when the process exit code is zero.

### `shell-command-result-text`

Render the result for a command-result buffer.

### `run-shell-command`

Run a shell command in an optional directory and return a captured result.
When supplied, `:input` is sent to standard input. Non-zero exit status is
represented in the result instead of signaled.

### `pipe-command`

Interactively prompt for a shell command, run it in the selected file's
directory, and append the result to `*Loom-Pipe-Command*`.

## Format feature

Public symbols from `loom/feature/format`.

### `format-buffer-with-command`

Send the complete selected buffer text to a formatter command and replace the
buffer only when the command exits successfully. The formatter runs in the
buffer's file directory when available; point and mark are restored by their
text offsets and the replacement is undoable as one edit.

Read-only and narrowed buffers are rejected before the command is started.

### `format-current-buffer`

Prompt for a formatter command and format the selected buffer.

## Git feature

Public symbols from `loom/feature/git`.

### `git-status-command`

Return the concise branch-aware status command used by the Git feature.

### `run-git-status`

Run Git status in a directory and return its captured shell command result.

### `git-status`

Run status from the current project root and display the captured result in the
read-only `*Loom-Git-Status*` buffer.

### `git-diff-command`

Return `git diff` for the working tree or `git diff --cached` for the index.

### `run-git-diff`

Run the working-tree or staged Git diff in a directory and return its captured
shell command result.

### `git-diff`, `git-diff-staged`

Display the working-tree or staged diff from the current project root in the
read-only `*Loom-Git-Diff*` buffer. Captured output includes standard output,
standard error, and the process exit status.

### `git-stage-command`, `git-unstage-command`

Build shell-quoted `git add -- PATH` and `git restore --staged -- PATH`
commands for a repository path.

### `run-git-stage`, `run-git-unstage`

Run the corresponding index operation in a directory and return its captured
shell command result.

### `git-stage-file`, `git-unstage-file`

Prompt for a repository path, run the corresponding index operation from the
current project root, and report the result in the minibuffer.

## Terminal feature

Public symbols from `loom/feature/terminal`.

### `terminal-session`

The PTY-backed child-process session object. It records the program, arguments,
directory, terminal buffer, raw output, a bounded ANSI screen model, liveness,
and exit code.

### `start-terminal-session`, `terminal-session-poll`, `terminal-session-send`,
`terminal-session-resize`, `stop-terminal-session`

Start, poll, write to, resize, or stop a terminal session. Polling updates the
session's ANSI-stripped transcript buffer and bounded screen model, and closes
the PTY after process exit.

### `terminal-screen`, `make-terminal-screen`, `terminal-screen-feed`,
`terminal-screen-text`, `terminal-screen-resize`

Create and inspect the bounded ANSI screen model. It supports common
cursor-addressed movement, line and character erasure, cursor save/restore, and
minimal alternate-screen switching; it is not a complete VT compatibility
layer.

### `poll-terminal-sessions`, `resize-terminal-sessions`

Poll or resize all sessions in an editor state.

### `terminal-input-event-p`, `terminal-handle-key-event`

Recognize and translate terminal input events, including characters, paste,
control keys, and supported special keys.

### `terminal`, `terminal-stop`

Interactive commands for starting a PTY session in the selected context and
stopping the session shown by the selected terminal buffer. The selected
terminal presents the transcript and the bounded ANSI screen model.

## Keyboard-macro feature

Public symbols from `loom/feature/keyboard-macro`.

### `keyboard-macro-event`

The keyboard-macro event value type.

### `keyboard-macro-event-p`

Return true when an object is a keyboard-macro event.

### `make-keyboard-macro-event`

Construct a keyboard-macro event.

### `keyboard-macro-event-kind`

Return the kind of a keyboard-macro event.

### `keyboard-macro-event-value`

Return the payload of a keyboard-macro event.

### `keyboard-macro`

The keyboard-macro value type.

### `keyboard-macro-p`

Return true when an object is a keyboard macro.

### `make-keyboard-macro`

Construct an empty keyboard macro.

### `keyboard-macro-events`

Return the recorded events in a keyboard macro.

### `keyboard-macro-recording-p`

Return true while a keyboard macro is recording.

### `keyboard-macro-replaying-p`

Return true while a keyboard macro is replaying.

### `keyboard-macro-start-recording`

Start recording keyboard events.

### `keyboard-macro-stop-recording`

Stop recording and return the recorded keyboard macro.

### `keyboard-macro-drop`

Discard the current keyboard macro recording.

### `keyboard-macro-record-event`

Append an event to the current keyboard macro.

### `keyboard-macro-remove-last-event`

Remove the most recently recorded keyboard-macro event.

### `keyboard-macro-begin-replay`

Begin replaying a keyboard macro.

### `keyboard-macro-end-replay`

End the current keyboard-macro replay.

### `start-kbd-macro`

Interactive command to start keyboard-macro recording.

### `end-kbd-macro`

Interactive command to stop keyboard-macro recording.

### `call-last-kbd-macro`

Interactive command to replay the last keyboard macro.

## Register feature

Public symbols from `loom/feature/register`.

### `register-value`

The register-value type stored in a register bank.

### `register-value-p`

Return true when an object is a register value.

### `register-value-kind`

Return the kind of a register value.

### `register-value-value`

Return the payload of a register value.

### `register-bank`

The register-bank value type.

### `register-bank-p`

Return true when an object is a register bank.

### `make-register-bank`

Construct an empty register bank.

### `register-bank-put-text`

Store text under a register name.

### `register-bank-text`

Return text stored under a register name.

### `register-bank-put-position`

Store a buffer position under a register name.

### `register-bank-position`

Return a position stored under a register name.

### `copy-to-register`

Copy the selected buffer region to a named register.

### `insert-register`

Insert the contents of a named register at point.

### `point-to-register`

Store the selected buffer's point in a named register.

### `jump-to-register`

Move point to the position stored in a named register.

## Workspace feature

Public symbols from `loom/feature/workspace`.

### `workspace`

The value type for one named workspace and its independent window tree.

### `make-workspace`

Construct a workspace from a non-empty name and a window tree.

### `workspace-name`

Return a workspace's name.

### `workspace-window-tree`

Return the window tree owned by a workspace.

### `workspace-manager`

The ordered collection of named workspaces and its active index.

### `make-workspace-manager`

Construct a manager with one initial workspace around a window tree.

### `make-workspace-manager-from-workspaces`

Construct a manager from an ordered list of workspaces and an active index.

### `workspace-manager-workspaces`

Return the manager's ordered workspace list.

### `workspace-manager-current-index`

Return the active workspace index.

### `workspace-manager-current`

Return the active workspace.

### `workspace-manager-current-name`

Return the active workspace name.

### `workspace-manager-create`

Create and append a uniquely named workspace without changing the active
workspace.

### `workspace-manager-switch-index`

Make the workspace at an index active.

### `workspace-manager-switch-name`

Make the uniquely named workspace active.

### `workspace-manager-next` / `workspace-manager-previous`

Cycle through workspaces, wrapping at either end.

### `workspace-manager-delete`

Delete a named workspace; the final remaining workspace cannot be deleted.

### `new-workspace`, `switch-workspace`, `next-workspace`,
`previous-workspace`, `kill-workspace`

Interactive commands for creating, selecting, cycling, and deleting
workspaces. They operate on `*editor-state*` and preserve each workspace's
window tree. `new-workspace` captures the selected buffer into a new workspace
and activates it, `switch-workspace` prompts by workspace name, and
`kill-workspace` deletes the active workspace while activating the surviving
selection.

## Session feature

Public symbols from `loom/feature/session`.

### `session-buffer-snapshot`

The session-buffer-snapshot value type.

### `make-session-buffer-snapshot`

Construct a buffer snapshot for session persistence.

### `session-buffer-snapshot-name`

Return a snapshot's buffer name.

### `session-buffer-snapshot-path`

Return a snapshot's buffer path.

### `session-buffer-snapshot-text`

Return a snapshot's buffer text.

### `session-buffer-snapshot-point-line`

Return a snapshot's point line.

### `session-buffer-snapshot-point-column`

Return a snapshot's point column.

### `session-buffer-snapshot-mark-line`

Return a snapshot's mark line.

### `session-buffer-snapshot-mark-column`

Return a snapshot's mark column.

### `session-buffer-snapshot-modified-p`

Return whether a snapshot's buffer was modified.

### `session-bookmark-snapshot`

The serializable value type for one named bookmark. It stores the name, path,
buffer name, line, and column.

### `make-session-bookmark-snapshot`

Construct a bookmark snapshot for session persistence.

### `session-workspace-snapshot`

The serializable value type for one named workspace, including its layout and
selected-window index.

### `make-session-workspace-snapshot`

Construct a workspace snapshot for session persistence.

### `session-workspace-snapshot-name`

Return a workspace snapshot's name.

### `session-workspace-snapshot-layout`

Return a workspace snapshot's serialized window layout.

### `session-workspace-snapshot-selected-window-index`

Return a workspace snapshot's selected-window index.

### `session-snapshot-recent-files`

Return the recent-file paths in a session snapshot.

### `session-snapshot-bookmarks`

Return the bookmark snapshots in a session snapshot.

### `session-snapshot-command-history`

Return the M-x/minibuffer command history in newest-first order.

### `session-snapshot`

The session-snapshot value type.

### `make-session-snapshot`

Construct a complete session snapshot.

### `session-snapshot-buffers`

Return the buffer snapshots in a session snapshot.

### `session-snapshot-layout`

Return the window layout in a session snapshot.

### `session-snapshot-selected-window-index`

Return the selected-window index in a session snapshot.

### `session-snapshot-workspaces`

Return the named workspace snapshots in a session snapshot.

### `session-snapshot-current-workspace-index`

Return the active workspace index in a session snapshot.

### `validate-session-snapshot`

Validate a session snapshot and return it or signal an invalid snapshot.

### `session-store-read`

Read a serialized session snapshot from the session store. The current format
is version 5; the reader accepts only the v5 envelope and signals an error for
any other version, including pre-v5 session files.

### `session-store-write`

Write a session snapshot to the session store.

### `save-session`

Save the current editor session.

### `load-session`

Load a saved editor session.

## User-init feature

Public symbols from `loom/feature/user-init`.

### `define-command`

Define a user command for the initialization file.

### `bind-key`

Add a user key binding to the initialization configuration.

### `load-user-init`

Load the user's initialization file and apply its configuration.

## LSP feature

Public symbols from `loom/feature/lsp`.

### `lsp-position`

The LSP position value type.

### `make-lsp-position`

Construct an LSP position.

### `lsp-position-p`

Return true when an object is an LSP position.

### `lsp-position-line`

Return an LSP position's zero-based line.

### `lsp-position-character`

Return an LSP position's zero-based character.

### `lsp-range`

The LSP range value type.

### `make-lsp-range`

Construct an LSP range.

### `lsp-range-p`

Return true when an object is an LSP range.

### `lsp-range-start`

Return an LSP range's start position.

### `lsp-range-end`

Return an LSP range's end position.

### `lsp-diagnostic`

The LSP diagnostic value type.

### `make-lsp-diagnostic`

Construct an LSP diagnostic.

### `lsp-diagnostic-p`

Return true when an object is an LSP diagnostic.

### `lsp-diagnostic-range`

Return a diagnostic's source range.

### `lsp-diagnostic-message`

Return a diagnostic's message.

### `lsp-diagnostic-severity`

Return a diagnostic's numeric severity.

### `lsp-diagnostic-source`

Return a diagnostic's source name.

### `lsp-diagnostic-code`

Return a diagnostic's code.

### `lsp-diagnostic-severity-name`

Return the display name for a diagnostic severity.

### `lsp-document`

The LSP document value type.

### `make-lsp-document`

Construct an LSP document state.

### `lsp-document-p`

Return true when an object is an LSP document.

### `lsp-document-uri`

Return an LSP document's URI.

### `lsp-document-language-id`

Return an LSP document's language identifier.

### `lsp-document-version`

Return an LSP document's version.

### `lsp-document-text`

Return an LSP document's current text.

### `make-lsp-session`

Construct an LSP session for a project or document root.

### `lsp-session-p`

Return true when an object is an LSP session.

### `lsp-session-start`

Start the language-server process for an LSP session.

### `lsp-session-drain`

Drain available language-server messages and apply them to the session.

### `lsp-session-refresh`

Refresh an LSP session's pending diagnostics and server state.

### `lsp-session-sync-buffer`

Synchronize a buffer's current text with the language server.

### `lsp-session-diagnostics`

Return diagnostics currently associated with a session.

### `lsp-session-stop`

Stop the language-server process for a session. An initialized session sends
`shutdown` and then `exit`; if the response does not arrive before the
shutdown timeout, it sends the `exit` fallback.

### `lsp-session-initialized-p`

Return true when the language server completed initialization.

### `lsp-session-last-error`

Return the last error recorded by an LSP session, or `nil`.

### `lsp-session-server-capabilities`

Return the server capability object received during initialization, or an
empty object when the server did not provide one.

### `lsp-session-capability`

Return the advertised capability named `name`, or `nil` when the server did
not advertise it or explicitly disabled it.

### `lsp-session-server-info`

Return the optional server information object received during initialization,
or `nil`.

### `lsp-path-uri`

Convert a pathname to an LSP file URI, percent-encoding non-URI-safe path
characters as UTF-8.

### `lsp-uri-path`

Convert a `file://` URI back to its UTF-8 pathname. Return `nil` for a URI
with another scheme or an unusable path.

### `lsp-discover-command`

Find the nearest ancestor `.loom-lsp` for a pathname and return its first
non-empty, non-comment command line, the project root, and the configuration
pathname as three values. Return three `nil` values when no usable
configuration exists.

### `lsp-start`

Start LSP support for the current editor context.

### `lsp-stop`

Stop LSP support for the current editor context.

### `lsp-diagnostics`

Return diagnostics for the selected buffer.

### `lsp-request-completion`

Request completion at a document position. The request is not sent when the
server does not advertise `completionProvider`; the callback receives the
decoded completion items or an error message.

### `lsp-request-definition`

Request the definition at a document position. The request is not sent when
the server does not advertise `definitionProvider`; the callback receives
decoded locations or an error message.

### `lsp-completion-item`

Represent one completion candidate. `lsp-completion-item-label` is displayed,
while `lsp-completion-item-text` prefers `insertText` when present and falls
back to the label. `detail` and `kind` preserve optional server metadata.

### `lsp-location`

Represent a definition target as a URI and an LSP range.

### `lsp-completion-at-point`

Request and display completion candidates at point. `C-M-i` opens the popup;
`C-n` / `C-p` or the arrow keys move selection, and RET or TAB inserts it.

### `lsp-find-definition`

Request the definition at point and visit the returned local file. Bound to
`M-.`.

### `lsp-pop-definition`

Return point to the origin of the most recent definition jump. Bound to
`M-,`.

The complete export contract remains
[`src/package-exports.lisp`](https://github.com/nerima-lisp/loom/blob/main/src/package-exports.lisp).
