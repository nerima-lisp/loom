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

### `define-command-spec-catalog`

Compose command specifications from predeclared grouped catalog variables.

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

### `buffer-truncate-lines`

```lisp
(loom:buffer-truncate-lines buffer)
```

Return `buffer`'s line-display preference: `t` to truncate long lines, `nil` to
wrap them, or `:default` to follow the major mode. Resolving `:default` to a
boolean needs mode metadata, so use
`loom/feature/mode:buffer-truncate-lines-p` for the answer a renderer wants.

### `buffer-set-truncate-lines`

```lisp
(loom:buffer-set-truncate-lines buffer value)
```

Set `buffer`'s line-display preference to `t`, `nil`, or `:default`, and return
`buffer`. The setting belongs to the buffer rather than a window, so the same
file shown in two windows cannot disagree with itself. It is not persisted in a
session.

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
`buffer` modified, records undo information, and clears any explicit redo
history. Returns `buffer`.

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

### `buffer-read-only-p`

```lisp
(loom:buffer-read-only-p buffer)
```

Return true when `buffer` rejects text mutations, including undo and redo.

### `buffer-set-read-only`

```lisp
(loom:buffer-set-read-only buffer read-only-p)
```

Set whether `buffer` rejects text mutations and return `buffer`. The interactive
`C-x C-q` command toggles this state for the selected buffer.

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

### `buffer-redo`

```lisp
(loom:buffer-redo buffer)
```

Redo the most recently explicitly undone change group in `buffer`. A normal
edit clears the explicit redo history. Returns `buffer`.

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
from the filename. A file that is not writable is loaded as a read-only buffer.

### `buffer-save`

```lisp
(loom:buffer-save buffer)
```

Write `buffer`'s contents to `buffer-path`. Signals an error if `buffer` has
no associated path or is read-only. Clears `buffer-modified-p` on success.
Returns `buffer`.

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

### `loom-renderer-clip-index`

```lisp
(loom:loom-renderer-clip-index renderer string start-column)
```

Return `(values index leading-blank)` for the first character of `string` fully
visible past `start-column` terminal columns. `leading-blank` is `1` when a
full-width character straddles `start-column`, since half a character cannot be
drawn and that cell is left empty.

### `loom-renderer-wrap-segments`

```lisp
(loom:loom-renderer-wrap-segments renderer string width)
```

Return the `(start . end)` character ranges that fill successive `width`-column
rows, always at least one, never ending inside a full-width character.

### `loom-renderer-segment-cells`

```lisp
(loom:loom-renderer-segment-cells renderer string segment column)
```

Return how many terminal columns into `segment` the character `column` sits.
This is the goal column a vertical move carries between wrapped rows.

### `loom-renderer-segment-column`

```lisp
(loom:loom-renderer-segment-column renderer string segment cells)
```

Return the character column `cells` columns into `segment`, clamped to the
segment's end.

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
(loom:make-keymap &key parent)
```

Create and return a new, empty keymap. When `parent` is supplied, lookups
fall through to that keymap. A locally defined first chord shadows the
corresponding parent subtree, so a mode can replace a complete prefix while
the rest of the global bindings remain available.

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

The input dispatcher layers the selected buffer's major-mode keymap over the
editor's top-level keymap before dispatching each event. This keeps global
bindings available while allowing a mode-local binding to take precedence.

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
(loom:minibuffer-activate minibuffer prompt
                          &key on-confirm on-cancel on-change on-key
                               completion-function)
```

Begin an interactive input session, displaying `prompt`. `on-confirm` is
called with the final input string on confirm (e.g. RET); `on-cancel` on
cancel (e.g. C-g). `on-change` is called with the current input after every
edit to it, which is what lets a prompt act while it is still being typed
rather than only at RET. `on-key` is called with each key event before it is
classified, and consumes the event by returning true — that is how a caller
keeps a chord like `C-s` from being typed into the input. Returns
`minibuffer`.

### `minibuffer-set-prompt`

```lisp
(loom:minibuffer-set-prompt minibuffer prompt)
```

Replace an active minibuffer's prompt without disturbing its input. A prompt
that reports state cannot use `minibuffer-message` for it, because the message
line is the same screen row the active prompt occupies. Inactive minibuffers
ignore this.

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

### `minibuffer-message-string`

```lisp
(loom:minibuffer-message-string minibuffer)
```

Return the current transient status message, or `NIL` when none is active.

### `minibuffer-history-entries`

```lisp
(loom:minibuffer-history-entries minibuffer)
```

Return the minibuffer's recalled input strings in newest-first order as a
serializable list.

### `minibuffer-set-history-entries`

```lisp
(loom:minibuffer-set-history-entries minibuffer entries)
```

Replace the minibuffer's recalled input strings with the newest-first list of
strings in `entries`. Signals an error when `entries` is not a proper list of
strings.

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
(loom:make-window-tree-from-layout layout width height &key selected-index)
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
(loom:window-scroll-line window)
(setf (loom:window-scroll-line window) line)
```

Return or set `window`'s zero-based first visible buffer line.

### `window-scroll-column`

```lisp
(loom:window-scroll-column window)
(setf (loom:window-scroll-column window) column)
```

Return or set `window`'s leftmost visible screen column. This counts terminal
cells rather than buffer characters, so it stays comparable with the two cells
a full-width character occupies. Unlike `window-scroll-line` it is not part of
`window-tree-layout`, so a session restore starts every window unscrolled.

### `window-scroll-sub-row`

```lisp
(loom:window-scroll-sub-row window)
(setf (loom:window-scroll-sub-row window) row)
```

Return or set which wrapped segment of `window-scroll-line` occupies the
window's first row. Only a wrapping buffer leaves it at anything but `0`, and
like `window-scroll-column` it is transient rather than part of
`window-tree-layout`.

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

### `file-tree-child-lister`

```lisp
(loom/feature/file-tree:file-tree-child-lister tree)
```

Return the function used to provide `tree`'s direct children. The function
accepts one path and returns `(child-path . kind)` conses.

### `file-tree-install-child-lister`

```lisp
(loom/feature/file-tree:file-tree-install-child-lister tree lister)
```

Install `lister` as `tree`'s child provider and return `tree`. This is the
composition boundary between the pure file-tree state and filesystem or
cached directory data.

### `file-tree-prefetch-paths`

```lisp
(loom/feature/file-tree:file-tree-prefetch-paths tree)
```

Return the root path followed by the currently expanded directory paths. The
concurrent file-tree runtime uses this list to decide which directories to
prefetch.

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

## Auto-save feature

Public symbols from `loom/feature/auto-save`.

### `auto-save-path`

Return the `#file-name#` sidecar pathname for a file path.

### `auto-save-eligible-p`

Return true when a buffer has a file path, is modified, and is writable.

### `write-auto-save-file`

Write text to an auto-save sidecar pathname without changing buffer state.

### `auto-save-buffer-to-file`

Write an eligible buffer to its sidecar and leave its normal modified state
unchanged.

### `auto-save-mode`, `toggle-auto-save`

Enable or disable automatic saving globally or for the selected buffer.

### `delete-auto-save-file`

Delete the sidecar for a file after a normal save. Missing sidecars are
ignored.

### `auto-save-current-buffer`, `maybe-auto-save`

Run an explicit auto-save pass or run the interval-gated pass used by the event
loop.

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
keymap, file-tree sidebar, active renderer, shared kill ring, named workspace
manager, auto-save state, after-save hooks, and terminal sessions for one
running loom session.

### `make-editor-state`

```lisp
(loom:make-editor-state &key window-tree minibuffer keymap file-tree renderer kill-ring workspaces auto-save-mode-p auto-save-buffers auto-save-last-run-at after-save-hooks terminal-sessions)
```

Construct an `editor-state`. If `workspaces` is omitted, the supplied
`window-tree` becomes the named `main` workspace. Supplying `workspaces` is
useful when restoring a session or constructing multiple named views.

### `editor-state-window-tree`

```lisp
(loom:editor-state-window-tree state)
```

Return `state`'s `window-tree-*` protocol object laying out every visible
buffer.

### `editor-state-workspaces`

```lisp
(loom:editor-state-workspaces state)
```

Return `state`'s named workspace manager. Each workspace owns an independent
window tree over the shared buffer registry.

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

### `editor-state-after-save-hooks`

Return the hooks run after a normal buffer save.

### `add-after-save-hook`, `remove-after-save-hook`, `run-after-save-hooks`

Register, unregister, or dispatch after-save hooks for an editor state. Hooks
receive the saved buffer.

### `editor-state-terminal-sessions`

Return the PTY-backed terminal sessions owned by `state`.

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

### `editor-state-recent-files`

```lisp
(loom:editor-state-recent-files state)
```

Return canonical file paths in most-recent-first order. The list is bounded by
`loom:*editor-recent-file-limit*`.

### `editor-state-bookmarks`

```lisp
(loom:editor-state-bookmarks state)
```

Return the hash table of named `editor-bookmark` values attached to `state`.

### `editor-bookmark`

`editor-bookmark` stores a bookmark name, its buffer or file identity, and a
line/column position. Use `make-editor-bookmark` to construct one and the
`editor-bookmark-*` accessors to inspect it.

### `editor-path-string`

```lisp
(loom:editor-path-string path)
```

Return the stable string representation used for recent-file and bookmark
paths, or `nil` when `path` is absent.

### `remember-recent-file`

```lisp
(loom:remember-recent-file path)
```

Record `path` at the front of the current state's bounded recent-file list.

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

### `editor-state-isearch`

```lisp
(loom:editor-state-isearch state)
```

Return the incremental-search session that is live while its prompt is up, or
`nil`. The renderer reads it to highlight matches, which is why it lives here
rather than inside the search command. Transient, and not persisted into a
session.

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
