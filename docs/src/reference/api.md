# API reference

This page documents every symbol exported by the packages declared in
`src/package.lisp`. The headings follow those export groups; symbols that are
useful mainly as accessors or predicates still appear so the public contract is
searchable in one place. Line and column numbers throughout are zero-based; a
`(line . column)` pair denotes a position *between* characters, exactly like
Emacs point, so end positions in a region are exclusive.

## Application

These symbols expose the command-specification and keybinding layer used by
the editor's interactive commands.

### `%selected-window`

Return the currently selected window for application-level command code.

### `%selected-buffer`

Return the buffer displayed by the selected window.

### `%editor-buffers`

Return the buffers registered with the current editor state.

### `%register-buffer`

Register a buffer with the current editor state.

### `%unregister-buffer`

Remove a buffer from the current editor state's registry.

### `%order-region`

Normalize two buffer positions into start and end order for a region.

### `with-prompts`

Execute a command body with the editor's prompt helpers bound for interactive
input.

### `command-spec`

The command specification type used by the command registry.

### `define-command-specs`

Define or replace command specifications in the declarative command catalogue.

### `*command-specs*`

The variable holding the currently registered command specifications.

### `command-completion-candidates`

Return command names available for extended-command completion.

### `find-extended-command`

Look up a command specification by its interactive name.

### `defkeys-single-chord-p`

Return true when a key definition describes one chord rather than a sequence.

### `defkeys-chord`

Define a key binding for one chord in a keymap.

### `defkeys-key-sequence`

Define a key binding for a sequence of chords in a keymap.

### `install-default-keybindings`

Install loom's default command bindings into the supplied editor keymap.

## Buffer

### `make-buffer`

```lisp
(loom:make-buffer &key name path initial-content)
```

Create and return a new, empty-undo-history buffer. `name` defaults to
`"*scratch*"`; `path` associates the buffer with a file for `buffer-save`
without performing any I/O; `initial-content` seeds the buffer's text.

### `buffer-p`

```lisp
(loom:buffer-p object)
```

Return true when `object` is a loom buffer.

### `buffer-name`

```lisp
(loom:buffer-name buffer)
```

Return `buffer`'s display name, as a string.

### `buffer-path`

```lisp
(loom:buffer-path buffer)
```

Return the pathname/namestring `buffer` is associated with, or `nil` if it
has never been loaded from or saved to a file.

### `buffer-major-mode`

```lisp
(loom:buffer-major-mode buffer)
```

Return the major-mode object currently associated with `buffer`, or `nil`.

### `buffer-set-major-mode`

```lisp
(loom:buffer-set-major-mode buffer mode)
```

Associate `mode` with `buffer` and return `buffer`.

### `buffer-text`

```lisp
(loom:buffer-text buffer)
```

Return `buffer`'s entire contents as a single string, including internal
newlines between lines.

### `buffer-line-count`

```lisp
(loom:buffer-line-count buffer)
```

Return the number of lines in `buffer`, always at least 1 (an empty buffer
has one empty line).

### `buffer-line`

```lisp
(loom:buffer-line buffer line-number)
```

Return the text of `line-number` in `buffer`, with no trailing newline.
Signals an error if `line-number` is out of range.

### `buffer-point-line`

```lisp
(loom:buffer-point-line buffer)
```

Return the zero-based line number of `buffer`'s point.

### `buffer-point-column`

```lisp
(loom:buffer-point-column buffer)
```

Return the zero-based column (in characters) of `buffer`'s point on its
current line.

### `buffer-set-point`

```lisp
(loom:buffer-set-point buffer line column)
```

Move `buffer`'s point to `(line, column)`, clamping an out-of-range position.
Returns `buffer`.

### `buffer-mark`

```lisp
(loom:buffer-mark buffer)
  => (values line column)
```

Return the position of `buffer`'s mark, or `(values nil nil)` if no mark is
set.

### `buffer-set-mark`

```lisp
(loom:buffer-set-mark buffer line column)
```

Set `buffer`'s mark to `(line, column)`, clamped. Returns `buffer`.

### `buffer-insert-string`

```lisp
(loom:buffer-insert-string buffer string)
```

Insert `string` into `buffer` at point, moving point to just after it. Marks
`buffer` modified and records undo information. Returns `buffer`.

### `buffer-delete-char`

```lisp
(loom:buffer-delete-char buffer &key backward)
```

Delete a single character adjacent to point: the character before point
(Backspace) when `backward` is true, otherwise the character at/after point
(Delete). A no-op at a buffer boundary. Returns `buffer`.

### `buffer-delete-region`

```lisp
(loom:buffer-delete-region buffer start-line start-column end-line end-column)
```

Delete the text between the two positions (end exclusive), moving point to
the start position. Returns the deleted text as a string.

### `buffer-region-string`

```lisp
(loom:buffer-region-string buffer start-line start-column end-line end-column)
```

Return, without modifying `buffer`, the text between the two positions (end
exclusive).

### `buffer-modified-p`

```lisp
(loom:buffer-modified-p buffer)
```

Return true if `buffer` has unsaved changes since it was created, loaded, or
last saved.

### `buffer-mark-saved`

```lisp
(loom:buffer-mark-saved buffer)
```

Mark `buffer` as saved and return `buffer`.

### `buffer-mark-modified`

```lisp
(loom:buffer-mark-modified buffer)
```

Mark `buffer` as modified and return `buffer`.

### `buffer-offset`

```lisp
(loom:buffer-offset buffer line column)
```

Convert a zero-based line and column in `buffer` to its zero-based character
offset.

### `buffer-position`

```lisp
(loom:buffer-position buffer offset)
```

Convert a zero-based character `offset` to a `(line . column)` position.

### `buffer-position-line`

```lisp
(loom:buffer-position-line position)
```

Return the line component of a buffer position.

### `buffer-position-column`

```lisp
(loom:buffer-position-column position)
```

Return the column component of a buffer position.

### `buffer-span`

```lisp
(loom:buffer-span buffer)
```

Return the current span object associated with `buffer`'s point and mark.

### `make-buffer-span`

```lisp
(loom:make-buffer-span start end)
```

Create a span from the zero-based character offsets `start` and `end`.

### `buffer-span-start`

```lisp
(loom:buffer-span-start span)
```

Return the start offset of `span`.

### `buffer-span-end`

```lisp
(loom:buffer-span-end span)
```

Return the exclusive end offset of `span`.

### `buffer-point-offset`

```lisp
(loom:buffer-point-offset buffer)
```

Return `buffer`'s point as a zero-based character offset.

### `buffer-offset-position`

```lisp
(loom:buffer-offset-position buffer offset)
```

Convert `offset` to the corresponding zero-based line and column position in
`buffer`.

### `buffer-undo`

```lisp
(loom:buffer-undo buffer)
```

Undo the most recent change group in `buffer`, Emacs ring-style: repeated
calls keep walking back through history, and once exhausted further calls
are a no-op. Returns `buffer`.

### `buffer-record-undo-boundary`

```lisp
(loom:buffer-record-undo-boundary buffer)
```

Record an undo boundary, so edits before and after this call belong to
distinct groups that `buffer-undo` steps between independently. Returns
`buffer`.

### `buffer-load`

```lisp
(loom:buffer-load path)
```

Read the file at `path` and return a new buffer whose `buffer-path` is
`path`, initial text is the file's contents, and `buffer-name` is derived
from the filename.

### `buffer-save`

```lisp
(loom:buffer-save buffer)
```

Write `buffer`'s contents to `buffer-path`. Signals an error if `buffer` has
no associated path. Clears `buffer-modified-p` on success. Returns `buffer`.

## Renderer

### `make-loom-renderer`

```lisp
(loom:make-loom-renderer width height)
```

Create and return a new loom renderer backed by a `cl-tty-kit` screen and
double-buffered diff renderer of the given `width`/`height` (terminal
columns/rows).

### `loom-renderer-width`

```lisp
(loom:loom-renderer-width renderer)
```

Return the renderer's current width in terminal columns.

### `loom-renderer-height`

```lisp
(loom:loom-renderer-height renderer)
```

Return the renderer's current height in terminal rows.

### `loom-renderer-string-width`

```lisp
(loom:loom-renderer-string-width renderer string)
```

Return the terminal display width of `string`.

### `loom-renderer-truncate-string`

```lisp
(loom:loom-renderer-truncate-string renderer string width)
```

Return `string` truncated to at most `width` terminal columns.

### `loom-renderer-write-string`

```lisp
(loom:loom-renderer-write-string renderer x y string)
```

Write `string` into the renderer's back buffer at terminal position `(x, y)`.

### `loom-renderer-draw-horizontal-line`

```lisp
(loom:loom-renderer-draw-horizontal-line renderer x y width)
```

Draw a horizontal separator of `width` cells at `(x, y)`.

### `loom-renderer-draw-vertical-line`

```lisp
(loom:loom-renderer-draw-vertical-line renderer x y height)
```

Draw a vertical separator of `height` cells at `(x, y)`.

### `loom-renderer-clear`

```lisp
(loom:loom-renderer-clear renderer)
```

Clear the renderer's back buffer and return `renderer`.

### `loom-renderer-make-cursor`

```lisp
(loom:loom-renderer-make-cursor renderer x y)
```

Create a cursor descriptor at terminal position `(x, y)` for presentation.

### `loom-renderer-draw-buffer`

```lisp
(loom:loom-renderer-draw-buffer renderer buffer x y width height)
```

Draw `buffer`'s currently visible region into `renderer`'s screen, occupying
the rectangle at `(x, y)` sized `width` by `height`. Does not flush to a
terminal. Returns `renderer`.

### `loom-renderer-present`

```lisp
(loom:loom-renderer-present renderer &key stream cursor)
```

Flush `renderer`'s pending screen diff to `stream` (defaults to
`*standard-output*`), positioning the cursor at `cursor` when supplied.
Returns `renderer`.

### `loom-renderer-resize`

```lisp
(loom:loom-renderer-resize renderer width height)
```

Resize `renderer`'s underlying screen and renderer to `width`/`height`.
Returns `renderer`.

## Keymap

### `make-keymap`

```lisp
(loom:make-keymap)
```

Create and return a new, empty keymap.

### `keymap-define-key`

```lisp
(loom:keymap-define-key keymap key-sequence command)
```

Bind `key-sequence` (a list of key-event descriptors) to `command`, a
zero-argument function designator invoked against `*editor-state*`. A
sequence that is a strict prefix of another bound sequence implicitly
becomes a prefix key. Returns `keymap`.

### `keymap-lookup`

```lisp
(loom:keymap-lookup keymap key-sequence)
```

Look up `key-sequence` in `keymap`. Returns the bound command, the keyword
`:prefix` if `key-sequence` is a strict prefix of one or more bindings, or
`nil`.

### `make-keymap-state`

```lisp
(loom:make-keymap-state keymap)
```

Create and return a new dispatch state for `keymap` that tracks in-progress
prefix-key accumulation across successive `keymap-state-dispatch` calls.

### `keymap-state-sequence`

```lisp
(loom:keymap-state-sequence state)
```

Return the key-event sequence currently accumulated by `state`.

### `keymap-state-dispatch`

```lisp
(loom:keymap-state-dispatch state key-event)
```

Feed one `key-event` into `state`: returns `:pending` while accumulating a
prefix key, invokes and returns the bound command's value once a complete
sequence resolves, or returns `nil` and resets on an unbound sequence.

## Minibuffer

### `make-minibuffer`

```lisp
(loom:make-minibuffer &key history)
```

Create and return a new, inactive minibuffer. `history`, when supplied, is a
`cl-history-kit` history object driving Up/Down recall while active.

### `minibuffer-active-p`

```lisp
(loom:minibuffer-active-p minibuffer)
```

Return true if `minibuffer` is currently prompting for input.

### `minibuffer-prompt-string`

```lisp
(loom:minibuffer-prompt-string minibuffer)
```

Return `minibuffer`'s current prompt text, or `nil` when inactive.

### `minibuffer-input-string`

```lisp
(loom:minibuffer-input-string minibuffer)
```

Return the text typed into `minibuffer` so far, or `""` when inactive.

### `minibuffer-activate`

```lisp
(loom:minibuffer-activate minibuffer prompt &key on-confirm on-cancel)
```

Begin an interactive input session, displaying `prompt`. `on-confirm` is
called with the final input string on confirm (e.g. RET); `on-cancel` on
cancel (e.g. C-g). Returns `minibuffer`.

### `minibuffer-complete`

```lisp
(loom:minibuffer-complete minibuffer candidates)
```

Complete the active minibuffer input against `candidates` and return
`minibuffer`.

### `minibuffer-handle-key`

```lisp
(loom:minibuffer-handle-key minibuffer key-event)
```

Feed one `key-event` to an active `minibuffer`: characters append to the
input, Backspace/Delete edit it, Up/Down recall history, RET confirms, C-g
cancels. A no-op when inactive. Returns `minibuffer`.

### `minibuffer-message`

```lisp
(loom:minibuffer-message minibuffer text)
```

Display `text` as a transient status message; unlike `minibuffer-activate`,
does not solicit input or affect `minibuffer-active-p`. Returns `minibuffer`.

## Window

### `make-window-tree`

```lisp
(loom:make-window-tree initial-buffer width height)
```

Create and return a new window tree with a single, initially selected
window displaying `initial-buffer` over the full `width` by `height` area.

### `window-tree-windows`

```lisp
(loom:window-tree-windows tree)
```

Return a list of every leaf window in `tree`, in stable order.

### `window-tree-selected-window`

```lisp
(loom:window-tree-selected-window tree)
```

Return `tree`'s currently selected (focused) window.

### `window-tree-layout`

```lisp
(loom:window-tree-layout tree)
```

Return the serializable layout description of `tree`.

### `make-window-tree-from-layout`

```lisp
(loom:make-window-tree-from-layout layout buffers width height)
```

Reconstruct a window tree from `layout`, resolving its leaf buffers from
`buffers`.

### `window-tree-selected-index`

```lisp
(loom:window-tree-selected-index tree)
```

Return the index of the selected leaf window in `tree`.

### `window-tree-select-index`

```lisp
(loom:window-tree-select-index tree index)
```

Select the leaf window at `index` and return it.

### `window-tree-width`

```lisp
(loom:window-tree-width tree)
```

Return `tree`'s width in terminal columns.

### `window-tree-height`

```lisp
(loom:window-tree-height tree)
```

Return `tree`'s height in terminal rows.

### `window-split`

```lisp
(loom:window-split tree window direction)
```

Split `window` into two along `direction` (`:horizontal`, i.e. `C-x 2`, or
`:vertical`, i.e. `C-x 3`); both initially show the same buffer. Selection
moves to the new window, which is returned.

### `window-select-next`

```lisp
(loom:window-select-next tree)
```

Select the next window in `tree`, cycling back to the first after the last
(`C-x o`). Returns the newly selected window.

### `window-delete`

```lisp
(loom:window-delete tree window)
```

Delete `window` from `tree` when another leaf can remain selected, then
return `tree`.

### `window-delete-other-windows`

```lisp
(loom:window-delete-other-windows tree window)
```

Remove every leaf except `window` and return the resulting tree.

### `window-buffer`

```lisp
(loom:window-buffer window)
```

Return the buffer currently displayed in `window`.

### `window-set-buffer`

```lisp
(loom:window-set-buffer window buffer)
```

Display `buffer` in `window` (`C-x b`), replacing what it previously showed.
Returns `window`.

### `window-x`

```lisp
(loom:window-x window)
```

Return `window`'s left edge, in terminal columns, relative to its tree's
origin.

### `window-y`

```lisp
(loom:window-y window)
```

Return `window`'s top edge, in terminal rows, relative to its tree's origin.

### `window-width`

```lisp
(loom:window-width window)
```

Return `window`'s width in terminal columns.

### `window-height`

```lisp
(loom:window-height window)
```

Return `window`'s height in terminal rows.

### `window-scroll-line`

```lisp
(loom:window-scroll-line window amount)
```

Scroll `window`'s displayed buffer by `amount` lines and return `window`.

### `window-tree-resize`

```lisp
(loom:window-tree-resize tree width height)
```

Resize `tree` to `width`/`height`, re-laying-out every window
proportionally. Returns `tree`.

### `split-window-below`

```lisp
(loom:split-window-below tree)
```

Split the selected window horizontally and return the new selected window.

### `split-window-right`

```lisp
(loom:split-window-right tree)
```

Split the selected window vertically and return the new selected window.

### `other-window`

```lisp
(loom:other-window tree)
```

Select the next window in `tree` and return it.

### `delete-window`

```lisp
(loom:delete-window tree)
```

Delete the selected window and return the resulting tree.

### `delete-other-windows`

```lisp
(loom:delete-other-windows tree)
```

Keep only the selected window and return the resulting tree.

### `switch-to-buffer`

```lisp
(loom:switch-to-buffer tree buffer)
```

Display `buffer` in the selected window and return that window.

### `kill-buffer`

```lisp
(loom:kill-buffer tree buffer)
```

Remove `buffer` from the window tree's buffer set and return the updated tree.

## File tree

### `make-file-tree`

```lisp
(loom:make-file-tree root-path)
```

Create and return a new file tree rooted at `root-path`; initially not
visible, every directory starts collapsed.

### `file-tree-visible-p`

```lisp
(loom:file-tree-visible-p tree)
```

Return true if `tree`'s sidebar is currently shown.

### `file-tree-toggle`

```lisp
(loom:file-tree-toggle tree)
```

Toggle whether `tree`'s sidebar is shown. Returns the new visibility state.

### `file-tree-entries`

```lisp
(loom:file-tree-entries tree)
```

Return the flattened list of currently visible entries in `tree`, respecting
expand/collapse state, as `(path . depth)` conses in display order.

### `file-tree-entry-kind`

```lisp
(loom:file-tree-entry-kind tree path)
```

Return whether `path` is a file or directory entry in `tree`.

### `file-tree-selected-path`

```lisp
(loom:file-tree-selected-path tree)
```

Return the path of `tree`'s currently selected entry, or `nil`.

### `file-tree-move-selection`

```lisp
(loom:file-tree-move-selection tree direction)
```

Move `tree`'s selection cursor by one visible entry in `direction` (`:up` or
`:down`); a no-op at either end. Returns the newly selected path.

### `file-tree-toggle-expand`

```lisp
(loom:file-tree-toggle-expand tree path)
```

Toggle the expand/collapse state of the directory at `path`. Signals an
error if `path` is not a directory in `tree`. Returns the new expanded-p
state.

### `file-tree-create-file`

```lisp
(loom:file-tree-create-file tree path)
```

Create a new, empty file at `path` on disk (`cl-host-kit`-backed).

### `file-tree-create-directory`

```lisp
(loom:file-tree-create-directory tree path)
```

Create a new, empty directory at `path` on disk.

### `file-tree-rename`

```lisp
(loom:file-tree-rename tree old-path new-path)
```

Rename the entry at `old-path` to `new-path` on disk.

### `file-tree-delete`

```lisp
(loom:file-tree-delete tree path)
```

Delete the entry at `path` from disk.

### `loom-fs-list-directory`

```lisp
(loom:loom-fs-list-directory path)
```

List `path`'s direct children as `(child-path . :file-or-:directory)`
conses, via `cl-host-kit`. This is the infrastructure lister used for real,
disk-backed sidebar listings.

### `toggle-file-tree`

```lisp
(loom:toggle-file-tree state)
```

Toggle the file-tree sidebar in `state` and return the new visibility state.

### `file-tree-select-next`

```lisp
(loom:file-tree-select-next tree)
```

Select the next visible file-tree entry and return its path.

### `file-tree-select-previous`

```lisp
(loom:file-tree-select-previous tree)
```

Select the previous visible file-tree entry and return its path.

### `file-tree-open-selected`

```lisp
(loom:file-tree-open-selected state)
```

Open the selected file-tree entry in the current editor state.

### `file-tree-create-file-command`

```lisp
(loom:file-tree-create-file-command state)
```

Create a file through the file-tree command interface.

### `file-tree-create-directory-command`

```lisp
(loom:file-tree-create-directory-command state)
```

Create a directory through the file-tree command interface.

### `file-tree-rename-command`

```lisp
(loom:file-tree-rename-command state)
```

Rename the selected file-tree entry through the command interface.

### `file-tree-delete-command`

```lisp
(loom:file-tree-delete-command state)
```

Delete the selected file-tree entry through the command interface.

### `find-file`

```lisp
(loom:find-file state path)
```

Open `path` in the editor state, reusing an existing buffer when possible.

### `save-buffer`

```lisp
(loom:save-buffer state)
```

Save the selected buffer and return the resulting buffer.

### `write-file`

```lisp
(loom:write-file state path)
```

Write the selected buffer to `path` and return the buffer.

## Editor state

### `*editor-state*`

```lisp
loom:*editor-state*
```

The single, dynamically-bound `editor-state` struct that every command
reads and mutates. Bound by loom's entry point before any command runs, and
`nil` otherwise.

### `editor-state`

The struct type of `*editor-state*`: the window layout, minibuffer, top-level
keymap, file-tree sidebar, active renderer, and shared kill ring for one
running loom session.

### `make-editor-state`

```lisp
(loom:make-editor-state &key window-tree minibuffer keymap file-tree renderer kill-ring)
```

Construct an `editor-state`.

### `editor-state-window-tree`

```lisp
(loom:editor-state-window-tree state)
```

Return `state`'s `window-tree-*` protocol object laying out every visible
buffer.

### `editor-state-minibuffer`

```lisp
(loom:editor-state-minibuffer state)
```

Return `state`'s `minibuffer-*` protocol object.

### `editor-state-keymap`

```lisp
(loom:editor-state-keymap state)
```

Return `state`'s top-level `keymap-*` protocol object.

### `editor-state-file-tree`

```lisp
(loom:editor-state-file-tree state)
```

Return `state`'s `file-tree-*` protocol object for the sidebar.

### `editor-state-concurrent-runtime`

```lisp
(loom:editor-state-concurrent-runtime state)
```

Return the file-tree concurrent runtime attached to `state`, or `nil`.

### `editor-state-renderer`

```lisp
(loom:editor-state-renderer state)
```

Return `state`'s `loom-renderer-*` protocol object used to draw each frame.

### `editor-state-kill-ring`

```lisp
(loom:editor-state-kill-ring state)
```

Return `state`'s Emacs-style kill ring: a list of killed strings, most
recent first, that `C-y`/`M-y` consume.

### `editor-state-buffers`

```lisp
(loom:editor-state-buffers state)
```

Return the buffers currently owned by `state`.

### `editor-state-lsp-session`

```lisp
(loom:editor-state-lsp-session state)
```

Return the active LSP session attached to `state`, or `nil`.

### `editor-state-registers`

```lisp
(loom:editor-state-registers state)
```

Return the register bank attached to `state`.

### `editor-state-keyboard-macro`

```lisp
(loom:editor-state-keyboard-macro state)
```

Return the keyboard-macro state attached to `state`.

### `editor-state-prefix-argument`

```lisp
(loom:editor-state-prefix-argument state)
```

Return the pending prefix argument attached to `state`, or `nil`.

### `self-insert-command`

```lisp
(loom:self-insert-command state key-event)
```

Insert the character represented by `key-event` into the selected buffer.

### `*current-prefix-argument*`

```lisp
loom:*current-prefix-argument*
```

The dynamically-bound prefix argument available while a command executes.

### `prefix-argument-for-editor`

```lisp
(loom:prefix-argument-for-editor state)
```

Return the prefix argument currently accumulated for `state`.

### `prefix-argument-action`

```lisp
(loom:prefix-argument-action state action)
```

Apply a prefix-argument `action` to `state`.

### `apply-prefix-argument-action`

```lisp
(loom:apply-prefix-argument-action state action)
```

Apply a decoded prefix-argument action to the editor state.

### `prefix-argument-value-for-editor`

```lisp
(loom:prefix-argument-value-for-editor state)
```

Return the numeric value represented by `state`'s pending prefix argument.

### `consume-prefix-argument-for-editor`

```lisp
(loom:consume-prefix-argument-for-editor state)
```

Return and clear the pending prefix argument for `state`.

### `record-undo-boundary-for-command`

```lisp
(loom:record-undo-boundary-for-command state)
```

Record an undo boundary for the selected buffer before or after a command.

## Numeric prefix arguments

The following values and operations represent universal, digit, and negative
prefix arguments independently of the editor-state integration above.

### `prefix-argument`

The prefix-argument value type.

### `prefix-argument-p`

```lisp
(loom:prefix-argument-p object)
```

Return true when `object` is a prefix-argument value.

### `make-prefix-argument`

```lisp
(loom:make-prefix-argument &key value explicit-p negative-p)
```

Construct a prefix-argument value.

### `prefix-argument-magnitude`

```lisp
(loom:prefix-argument-magnitude argument)
```

Return the non-negative magnitude of `argument`.

### `prefix-argument-active-p`

```lisp
(loom:prefix-argument-active-p argument)
```

Return true when `argument` represents an active prefix.

### `prefix-argument-explicit-p`

```lisp
(loom:prefix-argument-explicit-p argument)
```

Return true when the prefix was explicitly entered.

### `prefix-argument-negative-p`

```lisp
(loom:prefix-argument-negative-p argument)
```

Return true when `argument` is negative.

### `prefix-argument-value`

```lisp
(loom:prefix-argument-value argument)
```

Return the signed numeric value of `argument`.

### `prefix-argument-universal`

```lisp
(loom:prefix-argument-universal argument)
```

Apply a universal-prefix action to `argument` and return the updated value.

### `prefix-argument-digit`

```lisp
(loom:prefix-argument-digit argument digit)
```

Append `digit` to `argument` and return the updated value.

### `prefix-argument-negative`

```lisp
(loom:prefix-argument-negative argument)
```

Apply a negative-prefix action to `argument` and return the updated value.

### `prefix-argument-consume`

```lisp
(loom:prefix-argument-consume argument)
```

Return the value consumed by a command from `argument`.

### `prefix-argument-reset`

```lisp
(loom:prefix-argument-reset argument)
```

Return the inactive/reset form of `argument`.

## Concurrent file-tree runtime

The concurrent runtime is a bounded directory-listing cache built on
`cl-concurrent-kit`. `main` performs the initial root listing synchronously,
submits uncached root and expanded directories to worker threads, and applies
available results on the render lane. Generation numbers prevent a result for
an invalidated directory from replacing newer cache state. This runtime is
specific to file-tree listings; it is not a general background editor or LSP
runtime.

### `make-loom-concurrent-runtime`

```lisp
(loom:make-loom-concurrent-runtime
  &key directory-lister (parallelism 4) (queue-capacity 64))
```

Create a runtime. `directory-lister` defaults to
`loom-fs-list-directory`; the worker pool has `parallelism` workers and a
bounded submission queue of `queue-capacity`. The total in-flight bound is
`parallelism + queue-capacity`. Returns the runtime.

### `loom-concurrent-runtime-directory-entries`

```lisp
(loom:loom-concurrent-runtime-directory-entries runtime path)
  => (values entries present-p)
```

Read the cached direct entries for `path`. The second value is true when a
cache entry exists, including an empty directory.

### `loom-concurrent-runtime-directory-error`

```lisp
(loom:loom-concurrent-runtime-directory-error runtime path)
  => (values condition present-p)
```

Read a cached directory-listing error for `path`. The second value indicates
whether an error was recorded.

### `loom-concurrent-runtime-prime-directory`

```lisp
(loom:loom-concurrent-runtime-prime-directory runtime path entries)
```

Seed `path`'s cache from a synchronous listing, advance its generation, and
clear its cached error. Returns `entries`.

### `loom-concurrent-runtime-invalidate-directory`

```lisp
(loom:loom-concurrent-runtime-invalidate-directory runtime path)
```

Advance `path`'s generation and remove its cached entries, error, and pending
promise. Returns the runtime.

### `loom-concurrent-runtime-invalidate-path`

```lisp
(loom:loom-concurrent-runtime-invalidate-path runtime path)
```

Invalidate `path` and its parent directory, then return the runtime. File-tree
mutations use this to make both a changed entry and its containing listing
stale.

### `loom-concurrent-runtime-prefetch`

```lisp
(loom:loom-concurrent-runtime-prefetch runtime paths)
  => (values promises accepted-count)
```

Try to submit uncached, non-pending paths to the bounded worker pool. Returns
the promises for accepted submissions and the number accepted. A full queue,
an already cached/pending path, or a shut-down runtime causes a path to be
skipped rather than blocking the render lane.

### `loom-concurrent-runtime-drain`

```lisp
(loom:loom-concurrent-runtime-drain runtime)
  => applied-count
```

Apply all currently available worker results on the calling thread and
return the number applied. Results from older generations are discarded.

### `loom-concurrent-runtime-shutdown`

```lisp
(loom:loom-concurrent-runtime-shutdown runtime)
```

Stop the worker pool, close the result channel, and return `runtime`.
Shutdown is idempotent.

## Feature APIs

Feature slices export their own package-level APIs in addition to the shared
`#:loom` kernel. The following sections list every export from each feature
package. Accessors and predicates are included because they are part of the
supported package contract.

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

### `major-mode-names`

Return the registered major-mode names.

### `major-mode-for-path`

Infer and return a major mode for a pathname.

### `current-major-mode`

Return the major mode currently active in the selected buffer.

### `set-major-mode`

Set the selected buffer's major mode and return the mode.

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

### `replace-string`

Replace matching text in the selected buffer.

### `search-forward`

Run the interactive forward-search command.

### `search-backward`

Run the interactive backward-search command.

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

### `validate-session-snapshot`

Validate a session snapshot and return it or signal an invalid snapshot.

### `session-store-read`

Read a serialized session snapshot from the session store.

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

Stop the language-server process for a session.

### `lsp-session-initialized-p`

Return true when the language server completed initialization.

### `lsp-session-last-error`

Return the last error recorded by an LSP session, or `nil`.

### `lsp-path-uri`

Convert a pathname to an LSP file URI.

### `lsp-start`

Start LSP support for the current editor context.

### `lsp-stop`

Stop LSP support for the current editor context.

### `lsp-diagnostics`

Return diagnostics for the selected buffer.

The complete export contract remains
[`src/package.lisp`](https://github.com/nerima-lisp/loom/blob/main/src/package.lisp).

## CLI and commands

`loom:main` delegates argument parsing to `cl-cli` using application name
`loom` and version `0.1.0`. The CLI accepts `--help`/`-h`,
`--version`/`-V`, and one optional positional `path`; a file opens in the
first window, a directory becomes the file-tree root, and no path defaults to
`.`. There are no subcommands.

`install-default-keybindings` installs the command registry's bindings into
the top-level keymap. The declarative catalogue is maintained in
`src/application/command-definitions.lisp`, while
`src/application/command-registry.lisp` stores specifications, completion
candidates, and M-x lookup. The registry includes movement, editing,
search/replace, file, window, file-tree, help, keyboard-quit, and quit
commands. `M-x` invokes `execute-extended-command`, which prompts for a
command name and dispatches a registered command. Command functions are
intentionally not exported; use the keymap or `M-x` entry points for
interactive invocation.

## Entry point

### `main`

```lisp
(loom:main)
```

Entry point for the `loom` binary (the `:toplevel` `save-lisp-and-die`
dumps). Initializes `*editor-state*`, then runs the terminal session and
event loop until the user quits (`C-x C-c`) or stdin reaches EOF.
