# API reference

This page documents selected APIs exported by the root `loom` facade and the
core packages. Feature-package APIs are documented in
[`api/features.md`](api/features.md). The root `loom` and `loom/application`
packages provide convenience exports; the `loom/core/*` and
`loom/feature/*` packages are the canonical owners of their APIs. Root exports
are declared in
[`src/package-exports.lisp`](https://github.com/nerima-lisp/loom/blob/main/src/package-exports.lisp),
and package exports are declared in each package's `src/package.lisp`.
Line and column numbers throughout are zero-based; a
`(line . column)` pair denotes a position *between* characters, exactly like
Emacs point, so end positions in a region are exclusive.

## Application package

`loom/application` re-exports selected command, prompt, and keybinding helpers.
It does not own buffer lookup or selected-window helpers. Use
`loom/feature/buffers` for the buffer registry and
`loom/core/window-tree` with the current editor state for window selection.

### `with-prompts`

Run a command body with the prompt helpers provided by
`loom/core/minibuffer:with-prompts`.

### `command-spec`

```lisp
(loom/application:command-spec
 name command &key keys help help-order mutates prompts needs-region external modes)
```

This macro produces declarative command-specification data. The five metadata
keys `mutates`, `prompts`, `needs-region`, `external`, and `modes` are required.
The resulting data form is distinct from a registered command spec.

### `define-command-specs`, `define-command-spec-catalog`

Build declarative command data from `command-spec` forms or grouped data. These
forms remain available to callers that compose a catalogue; feature commands
currently populate the runtime registry with `register-command-spec` while
their ASDF components load.

### `command-completion-candidates`

```lisp
(loom/application:command-completion-candidates input)
```

Return registered command-spec objects whose names match `input`, sorted by
name. Matching normalizes surrounding spaces and tabs and supports the
registry's command-name completion styles.

### `find-extended-command-spec`

```lisp
(loom/application:find-extended-command-spec input)
```

Return the matching registered command spec, or `nil`. Lookup trims spaces and
tabs and ignores case.

### `defkeys-chord`, `defkeys-key-sequence`

```lisp
(loom/application:defkeys-chord spec)
(loom/application:defkeys-key-sequence key-form)
```

Convert command key forms to normalized key-event descriptors. These
converters do not install keymap bindings.

### `install-default-keybindings`

```lisp
(loom/application:install-default-keybindings keymap &key (keymap-name :global))
```

Install registered command IDs for the selected keymap name into `keymap` and
return it.

## Command registration and dispatch

The canonical registry and keymap APIs are exported by `loom/core/command`.
Keymaps store stable command IDs. Dispatch resolves an ID through the registry
and calls the command gateway, which records the invocation route before
applying any supplied arguments.

### `register-command-spec`

```lisp
(loom/core/command:register-command-spec
 owner id name command &key keys (keymap :global) group help help-order
      mutates prompts needs-region external modes
      (catalog-visible-p t) (trace-visible-p t))
```

Register a command and return its spec. All five classification metadata keys
are required. Registering the same ID, name, or key sequence with a conflicting
definition signals an error.

### `invoke-command`

```lisp
(loom:invoke-command id route &rest arguments)
```

Resolve `id`, record `route`, call the registered command with `arguments`, and
return the command's values. Supported routes are `:key`, `:mx`, `:macro`,
`:paste`, and `:mouse`.

### `command-specs`, `find-command-spec`

`command-specs` returns a copy of the registered spec list. `find-command-spec`
looks up a spec by its stable ID. `find-extended-command-spec` looks up a spec
by its interactive name.

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

Return the pathname/namestring `buffer` is associated with, or `nil` when no
path is associated. `make-buffer` can associate a path without loading or
saving a file.

### `buffer-major-mode`

```lisp
(loom:buffer-major-mode buffer)
```

Return the major-mode identity associated with `buffer`, initially
`:fundamental`. The core stores this identity without interpreting it;
feature packages provide its semantics.

### `buffer-set-major-mode`

```lisp
(loom:buffer-set-major-mode buffer mode)
```

Store `mode` as `buffer`'s major-mode identity and return `buffer`.

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

Delete the text between the two positions (end exclusive), clamped to the
visible region. The end must not precede the start. A nonempty deletion moves
point to the clamped start; an empty range leaves point and undo history
unchanged. Returns the deleted text as a string. Read-only buffers signal an
error even for an empty range.

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

Bind `key-sequence` (a list of key-event descriptors) to a registered command
ID or function designator. Function designators are resolved to their
registered IDs. Keymaps store IDs, not callable values. A sequence that is a
strict prefix of another binding becomes a prefix key. Returns `keymap`.

### `keymap-lookup`

```lisp
(loom:keymap-lookup keymap key-sequence)
```

Look up `key-sequence` in `keymap`. Returns the command ID and the map that
owns the binding as two values, `:prefix` and the owning map for a prefix, or
`nil` when there is no match.

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
(loom/core/command:keymap-state-dispatch state key-event command-invoker)
```

Feed one `key-event` into `state`. A complete binding is passed to
`command-invoker` with its command ID, normalized key sequence, and keymap
name. Prefixes remain pending; an unbound sequence resets the state.

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
classified, and consumes the event by returning true. That is how a caller
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
(loom/core/window-tree:make-window-tree initial-buffer width height)
```

Create and return a new window tree with a single, initially selected
window displaying `initial-buffer` over the full `width` by `height` area.

### `window-tree-windows`

```lisp
(loom/core/window-tree:window-tree-windows tree)
```

Return a list of every leaf window in `tree`, in stable order.

### `window-tree-selected-window`

```lisp
(loom/core/window-tree:window-tree-selected-window tree)
```

Return `tree`'s currently selected (focused) window.

### `window-tree-layout`

```lisp
(loom/core/window-tree:window-tree-layout tree)
```

Return the serializable layout description of `tree`.

### `make-window-tree-from-layout`

```lisp
(loom/core/window-tree:make-window-tree-from-layout layout width height &key selected-index)
```

Reconstruct a window tree from `layout`, whose leaf nodes contain the buffers
to display.

### `window-tree-selected-index`

```lisp
(loom/core/window-tree:window-tree-selected-index tree)
```

Return the index of the selected leaf window in `tree`.

### `window-tree-select-index`

```lisp
(loom/core/window-tree:window-tree-select-index tree index)
```

Select the leaf window at `index` and return it.

### `window-tree-width`

```lisp
(loom/core/window-tree:window-tree-width tree)
```

Return `tree`'s width in terminal columns.

### `window-tree-height`

```lisp
(loom/core/window-tree:window-tree-height tree)
```

Return `tree`'s height in terminal rows.

### `window-split`

```lisp
(loom/core/window-tree:window-split tree window direction)
```

Split `window` into two along `direction` (`:horizontal`, i.e. `C-x 2`, or
`:vertical`, i.e. `C-x 3`); both initially show the same buffer. Selection
moves to the new window, which is returned.

### `window-select-next`

```lisp
(loom/core/window-tree:window-select-next tree)
```

Select the next window in `tree`, cycling back to the first after the last
(`C-x o`). Returns the newly selected window.

### `window-delete`

```lisp
(loom/core/window-tree:window-delete tree window)
```

Delete `window` from `tree` when another leaf can remain selected, then
return the selected window. If `window` is the only leaf, leave the tree unchanged
and return that window.

### `window-delete-other-windows`

```lisp
(loom/core/window-tree:window-delete-other-windows tree window)
```

Remove every leaf except `window`, select it, and return that window.

### `window-buffer`

```lisp
(loom/core/window-tree:window-buffer window)
```

Return the buffer currently displayed in `window`.

### `window-set-buffer`

```lisp
(loom/core/window-tree:window-set-buffer window buffer)
```

Display `buffer` in `window` (`C-x b`), replacing what it previously showed.
Returns `window`.

### `window-x`

```lisp
(loom/core/window-tree:window-x window)
```

Return `window`'s left edge, in terminal columns, relative to its tree's
origin.

### `window-y`

```lisp
(loom/core/window-tree:window-y window)
```

Return `window`'s top edge, in terminal rows, relative to its tree's origin.

### `window-width`

```lisp
(loom/core/window-tree:window-width window)
```

Return `window`'s width in terminal columns.

### `window-height`

```lisp
(loom/core/window-tree:window-height window)
```

Return `window`'s height in terminal rows.

### `window-scroll-line`

```lisp
(loom/core/window-tree:window-scroll-line window)
(setf (loom/core/window-tree:window-scroll-line window) line)
```

Return or set `window`'s zero-based first visible buffer line.

### `window-scroll-column`

```lisp
(loom/core/window-tree:window-scroll-column window)
(setf (loom/core/window-tree:window-scroll-column window) column)
```

Return or set `window`'s leftmost visible screen column. This counts terminal
cells rather than buffer characters, so it stays comparable with the two cells
a full-width character occupies. Unlike `window-scroll-line` it is not part of
`window-tree-layout`, so restoring a session resets the horizontal offset to
`0` while preserving the saved vertical scroll line.

### `window-scroll-sub-row`

```lisp
(loom/core/window-tree:window-scroll-sub-row window)
(setf (loom/core/window-tree:window-scroll-sub-row window) row)
```

Return or set which wrapped segment of `window-scroll-line` occupies the
window's first row. Only a wrapping buffer leaves it at anything but `0`, and
like `window-scroll-column` it is transient rather than part of
`window-tree-layout`.

### `window-tree-resize`

```lisp
(loom/core/window-tree:window-tree-resize tree width height)
```

Resize `tree` to `width`/`height`, re-laying-out every window
proportionally. Returns `tree`.

The following interactive window commands use `loom:*editor-state*` and take
no arguments.

### `split-window-below`

```lisp
(loom/feature/window:split-window-below)
```

Split the selected window horizontally and return the new selected window.

### `split-window-right`

```lisp
(loom/feature/window:split-window-right)
```

Split the selected window vertically and return the new selected window.

### `other-window`

```lisp
(loom/feature/window:other-window)
```

Select the next window in the current window tree and return it.

### `delete-window`

```lisp
(loom/feature/window:delete-window)
```

Delete the selected window and return the remaining selected window. If it
is the only window, leave it unchanged.

### `delete-other-windows`

```lisp
(loom/feature/window:delete-other-windows)
```

Keep only the selected window and return it.

## File tree

### `make-file-tree`

```lisp
(loom/feature/file-tree:make-file-tree root-path)
```

Create and return a new file tree rooted at `root-path`; initially not
visible, every directory starts collapsed. Its default child lister performs
no filesystem access and returns no children; install a lister to populate it.
The editor composition wires in the cached runtime from
`packages/feature/file-tree/src/application-file-tree-runtime.lisp`; callers
using the lower-level APIs must connect the runtime cache to the lister and
schedule prefetch and result draining themselves.

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
(loom/feature/file-tree:file-tree-visible-p tree)
```

Return true if `tree`'s sidebar is currently shown.

### `file-tree-toggle`

```lisp
(loom/feature/file-tree:file-tree-toggle tree)
```

Toggle whether `tree`'s sidebar is shown. Returns the new visibility state.

### `file-tree-entries`

```lisp
(loom/feature/file-tree:file-tree-entries tree)
```

Return the flattened list of currently visible entries in `tree`, respecting
expand/collapse state, as `(path . depth)` conses in display order.

### `file-tree-entry-kind`

```lisp
(loom/feature/file-tree:file-tree-entry-kind tree path)
```

Return `:file` or `:directory` for a currently reachable entry in `tree`, or
`nil` if the path is not reachable. Collapsed directories are not searched.

### `file-tree-selected-path`

```lisp
(loom/feature/file-tree:file-tree-selected-path tree)
```

Return the path of `tree`'s currently selected entry, or `nil`.

### `file-tree-move-selection`

```lisp
(loom/feature/file-tree:file-tree-move-selection tree direction)
```

Move `tree`'s selection cursor by one visible entry in `direction` (`:up` or
`:down`); a no-op at either end. Returns the newly selected path.

### `file-tree-toggle-expand`

```lisp
(loom/feature/file-tree:file-tree-toggle-expand tree path)
```

Toggle the expand/collapse state of the directory at `path`. Signals an
error if `path` is not a directory in `tree`. Returns the new expanded-p
state.

### `file-tree-create-file`

```lisp
(loom/feature/file-tree:file-tree-create-file tree path)
```

Create a new, empty regular file through `*loom-filesystem*`. Signals an error
if `path` already exists and returns `path`.

### `file-tree-create-directory`

```lisp
(loom/feature/file-tree:file-tree-create-directory tree path)
```

Create a new, empty directory through `*loom-filesystem*`. Signals an error if
`path` already exists and returns `path`.

### `file-tree-rename`

```lisp
(loom/feature/file-tree:file-tree-rename tree old-path new-path)
```

Move or rename the entry at `old-path` to `new-path` through
`*loom-filesystem*`. Signals an error if `old-path` is missing or
`new-path` already exists, and returns `new-path`.

### `file-tree-delete`

```lisp
(loom/feature/file-tree:file-tree-delete tree path)
```

Delete the file or directory at `path` recursively through the filesystem
dispatch. Signals an error if `path` does not exist and returns `tree`.

These mutations use the direct native path only with the real filesystem and a
wild pathname; other paths use the CL-BOUNDARY-KIT or CL-HOST-KIT boundary.

### `loom-fs-list-directory`

```lisp
(loom/feature/file-tree:loom-fs-list-directory path)
```

List `path`'s direct children as `(child-path . :file-or-:directory)`
conses, via `cl-host-kit`. This is the infrastructure lister used for real,
disk-backed sidebar listings. Directories precede files, and each group is
sorted by namestring. Symbolic links and other special entries are omitted.

The following interactive file commands use `loom:*editor-state*` and take
no arguments. Paths are read from the minibuffer when needed.

### `toggle-file-tree`

```lisp
(loom/feature/file-tree:toggle-file-tree)
```

Toggle the current editor's file-tree sidebar and return the new visibility
state.

### `file-tree-select-next`

```lisp
(loom/feature/file-tree:file-tree-select-next)
```

Select the next visible file-tree entry and return its path.

### `file-tree-select-previous`

```lisp
(loom/feature/file-tree:file-tree-select-previous)
```

Select the previous visible file-tree entry and return its path.

### `file-tree-open-selected`

```lisp
(loom/feature/file-tree:file-tree-open-selected)
```

Open the selected file or toggle the selected directory's expansion.

### `file-tree-create-file-command`

```lisp
(loom/feature/file-tree:file-tree-create-file-command)
```

Prompt for a path and create a file.

### `file-tree-create-directory-command`

```lisp
(loom/feature/file-tree:file-tree-create-directory-command)
```

Prompt for a path and create a directory.

### `file-tree-rename-command`

```lisp
(loom/feature/file-tree:file-tree-rename-command)
```

Prompt for a new path and rename the selected file-tree entry.

### `file-tree-delete-command`

```lisp
(loom/feature/file-tree:file-tree-delete-command)
```

Delete the selected file-tree entry.

File commands such as `find-file`, `visit-file`, `recent-file`, `save-buffer`,
`write-file`, and `revert-buffer` are owned by `loom/feature/files`. The
`loom/feature/file-tree` package re-exports several of these names for
compatibility. See the [feature API reference](api/features.md#files-feature)
for their current API.

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

## Editor session and slice state

### `make-editor-session`, `register-slice-state`

```lisp
(loom/core/editor-session:make-editor-session slice-names &key initial-slices)
(loom/core/editor-session:register-slice-state name constructor)
```

Register a slice-state constructor when its package loads, then create a
session for the requested slice names. Initial state entries are installed
before constructors run. Constructors run in the caller's `slice-names` order;
a constructor can read only an initial state or a state constructed earlier.
Registering the same constructor again is idempotent, while a different
constructor for the same name signals an error.

### `editor-session-slice`, `editor-session-slice-names`

```lisp
(loom/core/editor-session:editor-session-slice session name)
(loom/core/editor-session:editor-session-slice-names session)
```

Return a slice's state or a copy of the requested slice names. Looking up a
slice that is not part of the session signals an error. An explicit initial
state may be `nil`; lookup still distinguishes it from a missing slice.

## Editor state

### `*editor-state*`

```lisp
loom:*editor-state*
```

The dynamically bound `editor-state` used by interactive commands. The
application binds it while dispatching editor input; it is `nil` outside that
binding.

### `editor-state`

The root state struct for one running Loom session. It holds application
services and state slots, and references the `editor-session` envelope returned
by `editor-state-session` for registered slice state.

### `make-editor-state`

```lisp
(loom:make-editor-state &rest initargs)
```

Construct an `editor-state` from keyword arguments. `:session` is required.
`:window-tree` must be
the same object as the session's `:core/window-tree` slice. If `:workspaces` is
`nil`, it defaults to the session's `:feature/workspace` slice; if
`:keyboard-macro` is omitted, that value defaults to the session's
`:feature/keyboard-macro` slice.

### `editor-state-session`

```lisp
(loom:editor-state-session state)
```

Return the `editor-session` envelope referenced by `state`. Session hooks
receive this value so slices can access their own state.

### `editor-state-window-tree`

```lisp
(loom:editor-state-window-tree state)
```

Return `state`'s current `window-tree-*` protocol object.

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

### `register-session-hook`, `run-session-hooks`

```lisp
(loom/core/editor-session:register-session-hook kind owner function)
(loom/core/editor-session:run-session-hooks kind session &rest arguments)
```

Register and dispatch hooks. The supported kinds are `:tick`, `:resize`,
`:key-input`, `:input-event`, `:render`, `:terminal-modes`, `:before-save`,
`:after-save`, `:buffer-close`, `:startup`, `:signal`, `:suspend`, `:resume`,
`:shutdown`, and `:exit-status`. Hooks run in the registered owner order and
preserve registration order within an owner. The lifecycle kinds
`:startup`, `:signal`, `:suspend`, `:resume`, `:shutdown`, and `:exit-status`
require owner `:feature/lifecycle`. `:key-input` and `:input-event` hooks
return `:pass` or `:handled`; `:render` hooks return render operations;
`:signal` hooks return `:continue` or `:terminate`; `:exit-status` hooks return
an integer from 0 through 255.

### `editor-state-terminal-sessions`

Return the PTY-backed terminal sessions owned by `state`.

### `editor-state-kill-ring`

```lisp
(loom:editor-state-kill-ring state)
```

Return `state`'s Emacs-style kill ring: a list of killed strings, most
recent first, that `C-y`/`M-y` consume.

### `editor-state-recent-files`

```lisp
(loom:editor-state-recent-files state)
```

Return remembered file paths in most-recent-first order. When remembering a
path, Loom uses its truename if available, otherwise its pathname namestring.
The list is bounded by `loom:*editor-recent-file-limit*`.

### `editor-state-bookmarks`

```lisp
(loom:editor-state-bookmarks state)
```

Return the hash table of named bookmark values attached to `state`.

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

Return the value stored in the editor state's `lsp-session` slot. Current LSP
routing is managed by the `:feature/lsp` slice and selects sessions by project
root and language ID.

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
(loom:self-insert-command character)
```

Insert `character` into the selected buffer of `*editor-state*`, repeated
according to `*current-prefix-argument*` (one insertion when it is `nil`).
A zero or negative prefix inserts nothing.

### `*current-prefix-argument*`

```lisp
loom:*current-prefix-argument*
```

The dynamically-bound prefix argument available while a command executes.

### `prefix-argument-for-editor`

```lisp
(loom:prefix-argument-for-editor)
```

Return the prefix argument attached to `*editor-state*`, creating one when
none is attached.

### `prefix-argument-action`

```lisp
(loom:prefix-argument-action descriptor argument)
```

Decode a key descriptor against `argument`. Return `(kind . value)` for a
universal, digit, or negative-prefix action, or `nil` for an ordinary key.
This function does not mutate `argument`.

### `apply-prefix-argument-action`

```lisp
(loom:apply-prefix-argument-action kind value)
```

Apply the decoded `kind` (`:universal`, `:digit`, or `:negative`) and `value`
to the prefix argument attached to `*editor-state*`. `:digit` uses `value`;
the other kinds ignore it. An unknown kind signals an error.

### `prefix-argument-value-for-editor`

```lisp
(loom:prefix-argument-value-for-editor)
```

Return the numeric value of `*editor-state*`'s pending prefix argument.

### `consume-prefix-argument-for-editor`

```lisp
(loom:consume-prefix-argument-for-editor)
```

Return the pending numeric prefix of `*editor-state*`, or 1 when inactive,
and reset its prefix-argument object to the inactive state.

### `record-undo-boundary-for-command`

```lisp
(loom:record-undo-boundary-for-command self-insert-p)
```

Record an undo boundary for the selected buffer when `self-insert-p` differs
from the previous command's self-insert flag. Consecutive self inserts share
one undo group. Update the flag in `*editor-state*`.

## Numeric prefix arguments

The following values and operations represent universal, digit, and negative
prefix arguments independently of the editor-state integration above.

### `prefix-argument`

The prefix-argument value type.

### `make-prefix-argument`

```lisp
(loom:make-prefix-argument)
```

Construct an inactive prefix-argument object with numeric value 1.

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

### `prefix-argument-value`

```lisp
(loom:prefix-argument-value argument)
```

Return the signed numeric value of `argument`.

### `prefix-argument-universal`

```lisp
(loom:prefix-argument-universal argument)
```

Activate an inactive `argument` with magnitude 4, or multiply an active
argument's magnitude by 4. Return the mutated argument object.

### `prefix-argument-digit`

```lisp
(loom:prefix-argument-digit argument digit)
```

Use `digit` as the first explicit digit, or append it to an already explicit
magnitude. `digit` must be an integer from 0 through 9. Return the mutated
argument object.

### `prefix-argument-negative`

```lisp
(loom:prefix-argument-negative argument)
```

Activate `argument` if needed, toggle its sign, and return the mutated
argument object.

### `prefix-argument-consume`

```lisp
(loom:prefix-argument-consume argument)
```

Return the numeric value of an active `argument`, or 1 when inactive, then
reset the argument object.

### `prefix-argument-reset`

```lisp
(loom:prefix-argument-reset argument)
```

Reset `argument` to inactive with magnitude 1 and clear its explicit and
negative flags. Return the mutated argument object.

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
(loom/feature/file-tree:make-loom-concurrent-runtime
  &key directory-lister (parallelism 4) (queue-capacity 64))
```

Create a runtime. `directory-lister` defaults to
`loom-fs-list-directory`; the worker pool has `parallelism` workers and a
bounded submission queue of `queue-capacity`. The total in-flight bound is
`parallelism + queue-capacity`. Returns the runtime.

### `loom-concurrent-runtime-directory-entries`

```lisp
(loom/feature/file-tree:loom-concurrent-runtime-directory-entries runtime path)
  => (values entries present-p)
```

Read the cached direct entries for `path`. The second value is true when a
cache entry exists, including an empty directory.

### `loom-concurrent-runtime-directory-error`

```lisp
(loom/feature/file-tree:loom-concurrent-runtime-directory-error runtime path)
  => (values condition present-p)
```

Read a cached directory-listing error for `path`. The second value indicates
whether an error was recorded.

### `loom-concurrent-runtime-prime-directory`

```lisp
(loom/feature/file-tree:loom-concurrent-runtime-prime-directory runtime path entries)
```

Seed `path`'s cache from a synchronous listing, advance its generation, and
clear its cached error. Returns `entries`.

### `loom-concurrent-runtime-invalidate-directory`

```lisp
(loom/feature/file-tree:loom-concurrent-runtime-invalidate-directory runtime path)
```

Advance `path`'s generation and remove its cached entries, error, and pending
promise. Returns the runtime.

### `loom-concurrent-runtime-invalidate-path`

```lisp
(loom/feature/file-tree:loom-concurrent-runtime-invalidate-path runtime path)
```

Invalidate `path` and its parent directory, then return the runtime. File-tree
mutations use this to make both a changed entry and its containing listing
stale.

### `loom-concurrent-runtime-prefetch`

```lisp
(loom/feature/file-tree:loom-concurrent-runtime-prefetch runtime paths)
  => (values promises accepted-count)
```

Try to submit uncached, non-pending paths to the bounded worker pool. Returns
the promises for accepted submissions and the number accepted. A full queue,
an already cached/pending path, or a shut-down runtime causes a path to be
skipped rather than blocking the render lane.

### `loom-concurrent-runtime-drain`

```lisp
(loom/feature/file-tree:loom-concurrent-runtime-drain runtime)
  => drained-count
```

Drain all currently available worker results on the calling thread and
return the number drained. Apply results from the current generation and
discard older results; both count toward the return value.

### `loom-concurrent-runtime-shutdown`

```lisp
(loom/feature/file-tree:loom-concurrent-runtime-shutdown runtime)
```

Stop the worker pool, close the result channel, and return `runtime`.
Shutdown is idempotent.


## CLI and commands

`loom:main` uses application name `loom` and the package version declared in
`loom.asd`. `--help`/`-h` and `--version`/`-V` are handled by `cl-cli`; registered
lifecycle options and file requests are parsed into an opaque startup context.
The built-in feature set currently registers no lifecycle options. The CLI
accepts `loom [+LINE[:COL]] FILE...`; the position applies to the first file
and later files open at line 1, column 1. With no file, the editor opens `.`.
There are no subcommands.

`install-default-keybindings` installs registered command IDs into the
top-level keymap. Core and feature command components register their command
specs as ASDF loads them. `M-x` resolves a registered command spec and dispatches
its stable ID through `invoke-command`. Feature command APIs are listed in the
[feature API reference](api/features.md).

## Entry point

### `main`

```lisp
(loom:main)
```

Runtime entry point for the `loom` binary. It dispatches raw command-line
arguments through `cl-cli` and exits with the returned status. The ASDF
`program-op` build uses `loom:main` as the dumped image's `:toplevel` for
`sb-ext:save-lisp-and-die`; the build operation is separate from this runtime
function.
