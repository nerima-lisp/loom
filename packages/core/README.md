# Core packages

Shared editor behavior lives in the core packages under `packages/core/`.

| Package | Responsibility |
| --- | --- |
| `buffer` | Buffer text, storage, edits, undo, and region operations |
| `command` | Command registry, keymaps, dispatch, and core editing commands |
| `editor-session` | Editor state and session hooks shared across features |
| `minibuffer` | Prompt input, completion candidates, and input history |
| `window-tree` | Window layout, selection, and tree operations |
