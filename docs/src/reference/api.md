# API reference

Every symbol exported from the `loom` package (`src/package.lisp`). Line and
column numbers throughout are zero-based; a `(line . column)` pair denotes a
position *between* characters, exactly like Emacs point, so end positions in
a region are exclusive.

## Buffer

### `make-buffer`

```lisp
(loom:make-buffer &key name path initial-content)
```

Create and return a new, empty-undo-history buffer. `name` defaults to
`"*scratch*"`; `path` associates the buffer with a file for `buffer-save`
without performing any I/O; `initial-content` seeds the buffer's text.

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

### `loom-renderer-cl-tty-renderer`

```lisp
(loom:loom-renderer-cl-tty-renderer renderer)
```

Return the underlying `cl-tty-kit` renderer object `renderer` wraps.

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

### `window-tree-resize`

```lisp
(loom:window-tree-resize tree width height)
```

Resize `tree` to `width`/`height`, re-laying-out every window
proportionally. Returns `tree`.

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
conses, via `cl-host-kit`. The default `file-tree` child-lister used to
back real, disk-backed sidebar listings.

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

## Entry point

### `main`

```lisp
(loom:main)
```

Entry point for the `loom` binary (the `:toplevel` `save-lisp-and-die`
dumps). Initializes `*editor-state*`, then runs the terminal session and
event loop until the user quits (`C-x C-c`) or stdin reaches EOF.
