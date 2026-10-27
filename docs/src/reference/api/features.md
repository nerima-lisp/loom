# Feature APIs

This page documents selected APIs exported by optional editor-feature packages.

## Major mode feature

Public symbols from `loom/feature/mode`.

### `major-mode-known-p`

`(major-mode-known-p mode)` accepts a keyword, symbol, or registered mode name
string. Strings also match registered aliases. Return true when the mode is
known.

### `major-mode-from-name`

`(major-mode-from-name name)` accepts a keyword, symbol, mode name, or alias.
Return the registered mode's canonical keyword, or `nil` for an unknown name.

### `major-mode-name`

`(major-mode-name mode)` returns a major mode's display name, or `nil` when the
mode is unknown.

### `major-mode-comment-prefix`

`(major-mode-comment-prefix mode)` returns the comment prefix used by a major
mode, or `nil` when it has none.

### `major-mode-indentation-width`

`(major-mode-indentation-width mode)` returns a major mode's indentation width.
Unknown modes default to 2.

### `major-mode-language-id`

`(major-mode-language-id mode)` returns the language identifier associated
with a major mode, or `nil` when it has none.

### `major-mode-keywords`

`(major-mode-keywords mode)` returns a copy of the syntax keyword table for a
major mode.

### `major-mode-truncate-lines-p`

Return true when a mode displays long lines truncated rather than wrapped. Code
modes truncate; `markdown`, `org`, and `text` wrap. A mode that declares nothing
truncates.

### `buffer-truncate-lines-p`

Return true when a buffer's long lines should be truncated. Only a buffer whose
`loom:buffer-truncate-lines` is `:default` consults its major mode.

### `major-mode-parent`

`(major-mode-parent mode)` returns a mode's parent mode, or `nil` for an
unknown mode. Built-in and extension-defined modes without an explicit parent
use `:fundamental`.

### `major-mode-keybindings`

`(major-mode-keybindings mode)` returns a copy of a mode's local keybinding
specifications. Each specification is a `(key-form . command)` pair; the
command is a function designator or a fbound, non-macro symbol.

### `major-mode-definition`

`(major-mode-definition mode)` returns a copy of a mode's complete metadata
definition, including its parent, file associations, syntax metadata, and
local keybindings.

### `major-mode-names`

`(major-mode-names)` returns the registered major-mode names.

### `major-mode-for-path`

`(major-mode-for-path path)` infers and returns a major mode for a pathname.

### `register-major-mode`

```lisp
(loom/feature/mode:register-major-mode
 mode &key name description aliases (parent :fundamental) extensions filenames
 comment-prefix (comment-start comment-prefix) comment-end
 skip-closing-delimiter (indentation-width 2) (tab-width 8) language-id
 keywords keybindings (truncate-lines t))
```

Register an extension-defined major mode and return its canonical keyword.
`aliases`, `extensions`, and `filenames` participate in name and pathname
inference; extensions may be written with or without a leading dot. `parent`
supplies inherited mode-local bindings and defaults to `:fundamental`.
`comment-start` and `comment-end` define comment delimiters,
`skip-closing-delimiter` controls paired closer skipping, and `description`
provides a summary for mode help.

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

```lisp
(loom/feature/mode:set-major-mode)
```

Prompt for a mode name and apply it to the selected buffer. Return the
activated minibuffer, not a mode value.

### `toggle-truncate-lines`

Flip the selected buffer between truncating and wrapping long lines
(`M-x toggle-truncate-lines`). The flip resolves the mode default first and
stores the opposite as an explicit choice, so the first toggle always changes
something and a later mode change no longer overrides it.

### `indent-for-tab-command`

Indent the current line according to the selected buffer's major mode.

### `comment-line`

Comment or uncomment the current line according to its major mode.

### Additional mode metadata and commands

`major-mode-tab-width` returns a mode's tab-stop width.
`major-mode-comment-start`, `major-mode-comment-end`, and
`major-mode-skip-closing-delimiter-p` return the corresponding mode metadata.
`mode-description-for-buffer(buffer)` returns a plist with the active mode,
display name, optional description, and local keybindings.
`major-mode-indentation-column(buffer line-number)` returns the desired
indentation column for a zero-based line. `indent-region` reindents the active
region, or the current line when no region is active. `newline-and-indent`
inserts a newline and applies the mode's continuation and indentation rules.
`comment-dwim` comments the active region when available, otherwise the current
line.

### Mode extension callbacks

`register-major-mode-indentation-rule(mode function)` installs a callback that
receives a buffer and zero-based line number and returns a non-negative column,
or `nil` to use the preceding line's indentation.
`register-major-mode-newline-continuation(mode function)` installs a callback
that receives the buffer and line being split and returns continuation text
and an optional half-open range to remove from the original line.
`register-major-mode-pair-completion(mode opener closer)` configures a
character pair for a known mode. `major-mode-display-lines(source mode)` uses a
registered provider or returns plain-text display runs;
`register-major-mode-display-lines-provider(mode function)` installs a
provider that receives the complete source and canonical mode key.

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
 renderer line x y width &optional (mode :common-lisp) (start-column 0))
```

Draw one highlighted source line through the renderer. `start-column` is a
horizontal offset in screen cells.

### `syntax-draw-buffer`

```lisp
(loom/feature/syntax-highlighting:syntax-draw-buffer
 renderer buffer x y width height &key (start-line 0) (start-column 0))
```

Draw the visible portion of `buffer` with line-local syntax styles.

## File tree feature

Public symbols from `loom/feature/file-tree`.

Manage the file sidebar, directory listings, and tree operations. See the
[File tree API](../api.md#file-tree) for signatures and detailed contracts.

### Tree navigation

`make-file-tree`, `file-tree-visible-p`, `file-tree-toggle`,
`file-tree-entries`, `file-tree-selected-path`, `file-tree-entry-kind`,
`file-tree-move-selection`, `file-tree-toggle-expand`

Construct, inspect, and navigate the sidebar tree.

### Directory providers

`file-tree-child-lister`, `file-tree-install-child-lister`,
`file-tree-prefetch-paths`, `loom-fs-list-directory`

Inspect or install a child-listing provider, prefetch paths, and list a directory.

### Filesystem operations

`file-tree-create-file`, `file-tree-create-directory`,
`file-tree-rename`, `file-tree-delete`

Perform filesystem changes through the tree API.

### Concurrent runtime

`make-loom-concurrent-runtime`, `loom-concurrent-runtime-directory-entries`,
`loom-concurrent-runtime-directory-error`, `loom-concurrent-runtime-prime-directory`,
`loom-concurrent-runtime-invalidate-directory`, `loom-concurrent-runtime-invalidate-path`,
`loom-concurrent-runtime-prefetch`, `loom-concurrent-runtime-drain`,
`loom-concurrent-runtime-shutdown`

Manage the concurrent directory-listing cache and its lifecycle.

### Sidebar commands

`toggle-file-tree`, `file-tree-select-next`, `file-tree-select-previous`,
`file-tree-open-selected`, `file-tree-create-file-command`,
`file-tree-create-directory-command`, `file-tree-rename-command`,
`file-tree-delete-command`

Interactive commands for sidebar navigation and filesystem changes.

### File commands

`find-file`, `visit-file`, `recent-file`, `save-buffer`, and `write-file` are
re-exported by this package. Their canonical owner is `loom/feature/files`;
see [Files feature](#files-feature).

## Buffers feature

Public symbols from `loom/feature/buffers`. This feature owns the session's
buffer registry and buffer-switch lifecycle.

### Registry operations

```lisp
(loom/feature/buffers:register-buffer session buffer)
(loom/feature/buffers:unregister-buffer session buffer &key reason)
(loom/feature/buffers:registered-buffers session)
(loom/feature/buffers:find-buffer-by-name session name)
(loom/feature/buffers:find-buffer-by-path session path)
(loom/feature/buffers:ensure-result-buffer session name)
```

Register a buffer once by object identity and return it. `unregister-buffer`
runs the buffer-close hook before removal and returns the buffer. The registry
query returns a copy in registry order. Name and path lookups return the first
match or `nil`; existing paths are compared by truename and paths that do not
exist by namestring. `ensure-result-buffer` returns a same-named buffer or
creates and registers one.

### Buffer commands and switch guards

`register-buffer-switch-guard`, `run-buffer-switch-guard`, `switch-to-buffer`,
`kill-buffer`, and `quit-buffer-list`

The interactive commands switch to a registered buffer, kill a selected buffer
with the required modified-buffer prompt, and operate on the buffer list.
Switch guards let features run logic before a buffer change.

## Files feature

Public symbols from `loom/feature/files`. This package is the canonical owner
of file visits, recent-file tracking, save operations, file snapshots, and file
format indicators. The file-tree package re-exports selected command names.

### File-buffer operations

```lisp
(loom/feature/files:make-file-buffer path &key name initial-content)
(loom/feature/files:visit-file path)
(loom/feature/files:read-file-snapshot path)
(loom/feature/files:file-format-indicator buffer)
```

`make-file-buffer` creates a file-associated buffer and infers its major mode
from `path`. `visit-file` displays an existing file and returns its buffer, or
`nil` when the path does not exist. `read-file-snapshot` returns the stored
snapshot for a file or `nil` when there is none. `file-format-indicator`
returns a display string containing newline style and encoding, with a BOM
marker when present, or `nil` for an unvisited buffer.

### File commands and recent paths

`editor-path-string`, `remember-recent-file`, `find-file`, `recent-file`,
`save-buffer`, `write-file`, `revert-buffer`, and `register-recent-file-recorder`

`find-file` visits an existing path or creates an empty associated buffer for
a new path. `recent-file` prompts from recorded paths. `save-buffer` writes to
the associated path or prompts for one. `write-file` creates a fresh buffer
for the prompted path with the current text, point, and mark; the original buffer
remains registered and its undo history is not copied. `revert-buffer` reloads
the current file and asks before discarding local edits.
`editor-path-string` produces the path key used by recent-file state, and
`remember-recent-file` records a path.

## Bookmark feature

The `loom/feature/bookmark` package exports the bookmark value type and
accessors. The root `loom` facade re-exports these symbols.

```lisp
(loom:make-editor-bookmark &key name buffer path buffer-name line column)
```

`editor-bookmark-p` tests the value type. `editor-bookmark-name`,
`editor-bookmark-buffer`, `editor-bookmark-path`,
`editor-bookmark-buffer-name`, `editor-bookmark-line`, and
`editor-bookmark-column` read its fields.

The registered commands `set-bookmark`, `jump-to-bookmark`,
`delete-bookmark`, and `list-bookmarks` create, visit, delete, and list named
bookmarks in the current editor state.

## Kill-ring feature

Public symbols from `loom/feature/kill-ring`.

### Editing and copy commands

`backward-kill-word`, `kill-line`, `kill-region`, `kill-between-offsets`,
`kill-ring-save`, `kill-word`, `yank`, and `yank-pop`

`kill-between-offsets(buffer start-offset end-offset &key prepend coalesce)`
deletes the selected offset range and adds it to the kill ring. The other
commands provide word/line/region kills, region copy, yank, and cycling the
most recent yank through the ring.

## Clipboard feature

Public symbols from `loom/feature/clipboard`.

`clipboard-copy-text`, `clipboard-read-text`, and `clipboard-yank` provide
clipboard access. `clipboard-read-text` returns three values: text, provider,
and failure information. `clipboard-yank` uses the kill ring when no clipboard
provider supplies text.

## Completion feature

The `loom/feature/completion` package has no exported symbols. The completion
value type and its accessors are exported by the root `loom` facade.

```lisp
(loom:make-editor-completion buffer line column items)
(loom:editor-completion-selected completion)
(loom:editor-completion-move completion delta)
```

`make-editor-completion` creates completion state anchored at a buffer
position. The selected accessor returns the selected item pair or `nil`; moving the
selection wraps and returns the completion state. `editor-completion-buffer`,
`editor-completion-line`, `editor-completion-column`,
`editor-completion-items`, `editor-completion-index`,
`editor-completion-item-label`, and `editor-completion-item-text` expose the
completion anchor and item data.

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

```lisp
(loom/feature/project:project-root)
```

Display the current project root, or a no-root message, in the minibuffer.
Use `project-find-root` to obtain a root pathname programmatically.

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

### `shell-command-result-p`

Return true when an object is a shell command result.

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

```lisp
(loom/feature/shell:run-shell-command
 command &key directory (input nil input-supplied-p)
 (timeout-seconds loom/feature/shell:*shell-command-timeout-seconds*))
```

Run a shell command in an optional directory and return a captured result.
When supplied, `:input` is sent to standard input. Non-zero exit status is
represented in the result instead of signaled. A timeout returns exit code
124 and a timeout message in the error-output field, retaining captured stdout.
`command` and supplied `input` must be strings; `timeout-seconds` must be a
non-negative real. Invalid arguments or directory resolution can signal errors.

### `*shell-command-timeout-seconds*`

The default shell-command timeout in seconds, initially `30`.

### `pipe-command`

Interactively prompt for a shell command, run it in the selected file's
directory, and append the result to `*Loom-Pipe-Command*`.

## Format feature

Public symbols from `loom/feature/format`.

### `format-buffer-with-command`

```lisp
(loom/feature/format:format-buffer-with-command
 command &optional buffer)
```

Send the complete buffer text to a formatter command and replace the
buffer only when the command exits successfully. The formatter runs in the
buffer's file directory when available; point and mark are restored by their
text offsets and the replacement is undoable as one edit.

Return a `shell-command-result`, including unsuccessful process results.
Invalid command or buffer types, read-only buffers, and narrowed buffers signal
errors before the command is started. The default buffer is the selected buffer.

### `format-current-buffer`

Prompt for a formatter command and format the selected buffer.

### `set-format-command`

```lisp
(loom/feature/format:set-format-command command &optional (state loom:*editor-state*))
```

Store and return the command after trimming surrounding whitespace. Signal an
error for a non-string command, an empty trimmed command, or a missing state.

### `format-on-save-mode`

```lisp
(loom/feature/format:format-on-save-mode
 &optional (enabled-p nil enabled-p-supplied-p) (state loom:*editor-state*))
```

Toggle formatting before save when `enabled-p` is omitted, or set it from the
supplied value. Return the resulting boolean. Signal an error for a missing
state or when enabling without a configured formatter command.

### `format-before-save`

```lisp
(loom/feature/format:format-before-save buffer &optional (state loom:*editor-state*))
```

Attempt formatting when the state enables format-on-save and has a command.
Return `buffer`; caught formatter errors and unsuccessful exits are reported
in the state's minibuffer when present, rather than propagated by this hook.

### `set-format-command-command`

```lisp
(loom/feature/format:set-format-command-command)
```

Prompt for the format-on-save command. Report configuration errors in the
minibuffer. Return the activated minibuffer.

## Auto-save feature

Public symbols from `loom/feature/auto-save`.

Write recovery sidecars for eligible modified file buffers. See the
[Auto-save API](../api.md#auto-save-feature) for signatures and detailed contracts.

### Configuration and eligibility

`*auto-save-interval*`, `auto-save-path`, `auto-save-eligible-p`

Configure the interval, derive a sidecar path, and check buffer eligibility.

### Recovery files

`write-auto-save-file`, `delete-auto-save-file`, `auto-save-buffer-to-file`

Write or remove a sidecar, or save a buffer's recovery text.

### Enablement

`auto-save-enabled-p`, `auto-save-mode`, `toggle-auto-save`

Inspect, set, or toggle auto-save enablement.

### Save passes

`auto-save-current-buffer`, `maybe-auto-save`

Run auto-save for the selected buffer or an interval-controlled save pass.

## Git feature

Public symbols from `loom/feature/git`.

### `*git-command-timeout-seconds*`

The Git-command timeout in seconds, initially `30`. It is used for both the
resilience deadline and the `cl-vcs-kit` process timeout.

### `run-git-status`

Run Git status in a directory and return its captured process result from
`cl-vcs-kit`.

### `git-status`

Run status from the current project root and display the captured result in the
read-only `*Loom-Git-Status*` buffer. The buffer shows stdout, falling back to
stderr when stdout is empty. Non-zero exit statuses are reported in the minibuffer.

### `run-git-diff`

Run the working-tree or staged Git diff in a directory and return its captured
process result from `cl-vcs-kit`.

### `git-diff`, `git-diff-staged`

Display the working-tree or staged diff from the current project root in the
read-only `*Loom-Git-Diff*` buffer, using the same output selection and
minibuffer exit-status reporting as `git-status`.

### `run-git-stage`, `run-git-unstage`

Run the corresponding index operation in a directory and return its captured
process result from `cl-vcs-kit`. Paths are passed as arguments after `--`.

### `git-stage-file`, `git-unstage-file`

Prompt for a repository path, run the corresponding index operation from the
current project root, and report the result in the minibuffer.

## Terminal feature

Public symbols from `loom/feature/terminal`.

### `terminal-session`

The PTY-backed child-process session object. It records the program, arguments,
directory, terminal buffer, raw output, a bounded ANSI screen model, liveness,
and exit code.

### `terminal-session-p`

Return true when an object is a terminal session.

### Session metadata

`terminal-session-name`, `terminal-session-program`, `terminal-session-args`,
`terminal-session-directory`, `terminal-session-buffer`, `terminal-session-pty`

Return the session's name, program, arguments, working directory, display buffer,
or PTY handle.

### Session state

`terminal-session-raw-output`, `terminal-session-alive-p`,
`terminal-session-exit-code`, `terminal-session-screen`

Return the cumulative raw PTY output, liveness flag, recorded exit code, or
bounded screen model. The exit code is initially `nil`.

### `terminal-session-output`

```lisp
(loom/feature/terminal:terminal-session-output session)
```

Return the current visible screen as a string, not the cumulative raw output.

### `terminal-session-feed-output`

```lisp
(loom/feature/terminal:terminal-session-feed-output session text)
```

Append `text` to raw output, feed it into the screen model, and return `session`.
Signal a type error when `text` is not a string. This function does not itself
replace the display buffer's text.

### `terminal-session-for-buffer`

```lisp
(loom/feature/terminal:terminal-session-for-buffer buffer &optional (state loom:*editor-state*))
```

Return the state's session whose display buffer is `eq` to `buffer`, or `nil`.

### Session lifecycle

`start-terminal-session`, `terminal-session-poll`, `terminal-session-send`,
`terminal-session-resize`, `stop-terminal-session`

Start, poll, write to, resize, or stop a terminal session. Polling updates the
session's bounded screen model and replaces the read-only buffer with the
current visible screen. It closes the PTY after process exit.

### Screen operations

`terminal-screen`, `make-terminal-screen`, `terminal-screen-feed`,
`terminal-screen-text`, `terminal-screen-resize`

Create and inspect the bounded ANSI screen model. It supports common
cursor-addressed movement, line and character erasure, cursor save/restore, and
minimal alternate-screen switching; it is not a complete VT compatibility
layer.

### `terminal-screen-p`

Return true when an object is a terminal screen.

### Screen geometry

`terminal-screen-width`, `terminal-screen-height`,
`terminal-screen-cursor-row`, `terminal-screen-cursor-column`

Return the screen's column count, row count, or zero-based cursor coordinates.

### `poll-terminal-sessions`, `resize-terminal-sessions`

Poll or resize all sessions in an editor state.

### `terminal-input-event-p`, `terminal-handle-key-event`

Recognize and translate terminal input events, including characters, paste,
control keys, and supported special keys.

### `terminal`, `terminal-stop`

Interactive commands for starting a PTY session in the selected context and
stopping the session shown by the selected terminal buffer. The selected
terminal displays the current bounded ANSI screen, not a cumulative transcript.

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

## Window feature

Public symbols from `loom/feature/window`.

Window-tree and window-view domain operations belong to
`loom/core/window-tree`. See the [Window API](../api.md#window) for those
signatures and contracts.

### Window commands

`split-window-below`, `split-window-right`, `other-window`,
`delete-window`, `delete-other-windows`, `scroll-up-command`,
`scroll-down-command`

Interactive commands for splitting, selecting, deleting, and scrolling windows.
Buffer switching and killing belong to `loom/feature/buffers`.

## Workspace feature

Public symbols from `loom/feature/workspace`.

### `workspace`

The value type for one named workspace and its independent window tree.

### `workspace-p`

Return true when an object is a workspace.

### `make-workspace`

Construct a workspace from a non-empty name and a window tree.

### `workspace-name`

Return a workspace's name.

### `workspace-window-tree`

Return the window tree owned by a workspace.

### `workspace-manager`

The ordered collection of named workspaces and its active index.

### `workspace-manager-p`

Return true when an object is a workspace manager.

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

### Workspace commands

`new-workspace`, `switch-workspace`, `next-workspace`,
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

### Bookmark snapshot fields

`session-bookmark-snapshot-name`, `session-bookmark-snapshot-path`,
`session-bookmark-snapshot-buffer-name`, `session-bookmark-snapshot-line`,
`session-bookmark-snapshot-column`

Return the bookmark snapshot's name, path, buffer name, line, or column.

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

### `session-snapshot-workspaces`

Return the named workspace snapshots in a session snapshot. Each workspace
snapshot owns its layout and selected-window index.

### `session-snapshot-current-workspace-index`

Return the active workspace index in a session snapshot.

### `validate-session-snapshot`

Validate a session snapshot and return it or signal an invalid snapshot.

### `session-store-read`

Read a serialized session snapshot from the session store. The writer emits
version 6. The reader accepts version 6 and the legacy version 5 envelope;
session files older than version 5 are unsupported.

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

## Help feature

Public symbols from `loom/feature/help`.

`help-command`, `describe-key`, `describe-command`, `describe-bindings`, and
`describe-mode` provide interactive help for keys, registered commands,
bindings, and the active major mode.

## Lifecycle feature

Public symbols from `loom/feature/lifecycle`.

`loom-quit`, `loom-quit-abort`, `save-buffers-kill-terminal`,
`kill-loom-abort`, and `suspend-frame` implement quit, save-and-quit, abort,
and suspend commands. This feature owns the `:startup`, `:signal`, `:suspend`,
`:resume`, `:shutdown`, and `:exit-status` session hooks.

## Language slices

The `loom/feature/lang-lisp`, `loom/feature/lang-nix`, and
`loom/feature/lang-web` packages export no symbols. Loading them registers their
major-mode definitions and mode-specific behavior through
`loom/feature/mode`.

### Lisp structural commands

The root `loom` facade exports these commands implemented by
`loom/feature/lisp-structure`: `forward-slurp-sexp`, `forward-barf-sexp`,
`backward-slurp-sexp`, `backward-barf-sexp`, `wrap-round`, `splice-sexp`, and
`raise-sexp`.

### Markup language feature

Public symbols from `loom/feature/lang-markup`.

```lisp
(loom/feature/lang-markup:markup-display-lines source mode)
```

Return display runs for each source line in `:markdown` or `:org` mode.

## LSP feature

Public symbols from `loom/feature/lsp`.

LSP sessions are selected by canonical project root and the buffer's language
ID from `loom/feature/mode:major-mode-language-id`. The commands and session
APIs below cover diagnostics, completion, hover, definition jumps, and returning
from the most recent definition jump.

### `lsp-column-to-character`

`(lsp-column-to-character text column)` converts a zero-based Common Lisp
character column in `text` to an LSP UTF-16 code-unit offset. Columns beyond
the string's end are clamped to its length.

### `lsp-character-to-column`

`(lsp-character-to-column text character)` converts an LSP UTF-16 code-unit
offset to a zero-based Common Lisp character column. An offset inside a
surrogate pair maps to that character's start; offsets beyond the string's
end map to its length.

### `lsp-position`

The LSP position value type.

### `make-lsp-position`

Construct an LSP position.

### `lsp-position-p`

Return true when an object is an LSP position.

### `lsp-position-line`

Return an LSP position's zero-based line.

### `lsp-position-character`

Return an LSP position's zero-based UTF-16 code-unit offset within its line.

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

For an initialized session and a file-backed buffer, send `didOpen` for a new
document or full-text `didChange` when the text differs. Unchanged text sends
neither notification. Return the session.

### `lsp-session-diagnostics`

```lisp
(loom/feature/lsp:lsp-session-diagnostics session buffer-or-path)
```

Return a copy of the diagnostic list for the specified buffer or pathname,
or `nil` when no diagnostics are stored for its URI.

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

### Session integration helpers

`lsp-session-for-buffer(editor-session buffer)` returns the open session
selected by that buffer's project root and language ID, or `nil`.
`lsp-editor-session-background-work-p(editor-session)` reports whether the
registry has an open session. `lsp-refresh-editor-state(state)` refreshes the
selected file buffer and drains other sessions;
`lsp-stop-editor-state-lsp-session(state)` stops and removes all sessions for
the editor state. `register-client-version-provider(owner function)` installs
the version callback used in the LSP client identity.

### `lsp-path-uri`

Convert a pathname to an LSP file URI, percent-encoding non-URI-safe path
characters as UTF-8.

### `lsp-uri-path`

Convert a `file://` URI back to its UTF-8 pathname. Return `nil` for a URI
with another scheme or an unusable path.

### `lsp-discover-command`

Find the nearest ancestor `.loom-lsp` for a pathname. When its first
non-empty, non-comment line is usable, return five values: an argv list, the
project root, the configuration pathname, an identity containing the
configuration's canonical pathname and contents, and the original line for
review. Return exactly three `nil` values when no usable configuration exists.
The line is split into arguments; shell operators and quoting syntax are
rejected, and a leading `exec` is removed.

### `lsp-start`

Start LSP support for the current editor context.
RET selects the discovered `.loom-lsp` command for review. The review displays
the configuration path, execution directory, and source command line. Type
exactly `yes` at the trust prompt to start it; any other answer or C-g cancels
without constructing a process or replacing the existing session. The
configuration identity is checked again before process creation. An explicitly
typed command overrides discovery and is parsed into argv without the extra
discovery trust prompt. Typed commands use the same parser as discovered
commands, so shell operators and quoting syntax are rejected. Confirmation is
required for each discovered-command start.

### `lsp-stop`

Stop LSP support for the current editor context.

### `lsp-diagnostics`

```lisp
(loom/feature/lsp:lsp-diagnostics)
```

Refresh the session and display the selected file buffer's diagnostics in the
read-only diagnostics buffer. Report missing session/file context or a refresh
error in the minibuffer. Use `lsp-session-diagnostics` to obtain a diagnostic list.

### `lsp-request-completion`

Request completion at a zero-based document position, with the character
offset measured in UTF-16 code units. The caller must synchronize the document
before requesting completion. The request is not sent when the
server does not advertise `completionProvider`; the callback receives the
decoded completion items or an error message.

### `lsp-request-definition`

Request the definition at a zero-based document position, with the character
offset measured in UTF-16 code units. The caller must synchronize the document
before requesting a definition. The request is not sent when
the server does not advertise `definitionProvider`; the callback receives
decoded locations or an error message.

### `lsp-request-hover`

```lisp
(loom/feature/lsp:lsp-request-hover session uri line character handler)
```

Request hover information at a zero-based document position, with the character
offset measured in UTF-16 code units. The caller must synchronize the document
before requesting hover. The request is not sent when the server does not
advertise `hoverProvider`; in that case the function returns `nil` and does not
call the handler. When sent, the function returns the request ID. The handler
receives `(content error-message)`: `content` is decoded hover text or `nil`,
and `error-message` is a string or `nil`.

### `lsp-completion-item`

The value type for one completion candidate.

### `make-lsp-completion-item`

```lisp
(loom/feature/lsp:make-lsp-completion-item label &key insert-text detail kind)
```

Construct a completion candidate with optional insertion text and server metadata.

### `lsp-completion-item-p`

Return true when an object is a completion item.

### Completion item fields

`lsp-completion-item-label`, `lsp-completion-item-insert-text`,
`lsp-completion-item-detail`, `lsp-completion-item-kind`

Return the display label, optional insertion text, detail, or kind.

### `lsp-completion-item-text`

Return the insertion text when non-`nil`, otherwise the display label.

### `lsp-location`

Represent a definition target as a URI and an LSP range.

### `make-lsp-location`

```lisp
(loom/feature/lsp:make-lsp-location uri range)
```

Construct a definition target from its URI and range.

### `lsp-location-p`

Return true when an object is an LSP location.

### `lsp-location-uri`, `lsp-location-range`

Return a location's URI or range.

### `lsp-completion-at-point`

Request and display completion candidates at point. `C-M-i` opens the popup;
`C-n` / `C-p` or the arrow keys move selection, and RET or TAB inserts it.

### `lsp-hover-at-point`

Run `M-x lsp-hover-at-point` to request hover information at point. The command
shows the decoded server text in the minibuffer when the server advertises
`hoverProvider`.

### `lsp-find-definition`

Request the definition at point and visit the returned local file. Bound to
`M-.`.

### `lsp-pop-definition`

Return point to the origin of the most recent definition jump. Bound to
`M-,`.

Feature exports are defined in each `packages/feature/<name>/src/package.lisp`;
core exports are defined in
[`src/package-exports.lisp`](https://github.com/nerima-lisp/loom/blob/main/src/package-exports.lisp).
