# Feature packages

Each directory below is one user-facing capability. A feature may contain
domain state, application commands, infrastructure adapters, and presentation
helpers in one slice:

| Package | Capability |
| --- | --- |
| `file-tree` | Directory browsing, file I/O, and asynchronous refresh |
| `search` | Buffer search and replacement commands |
| `window` | Window tree and split/delete commands |
| `session` | Session snapshots and persistence |
| `evaluation` | Common Lisp expression and buffer evaluation |
| `lsp` | Minimal stdio LSP client and diagnostics |
| `user-init` | User configuration and init-file loading |
| `syntax-highlighting` | Line-local Common Lisp highlighting |
| `register` | Named text and point registers |
| `keyboard-macro` | Record and replay keyboard input |

The root composition source remains responsible for cross-feature layout,
command registration, and the terminal main loop.
