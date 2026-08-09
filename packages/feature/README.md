# Feature packages

Each directory below is one user-facing capability. A feature may contain
domain state, application commands, external-system integrations, and
presentation
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
| `mode` | Major modes and mode-specific editing commands |
| `project` | Project roots, file listing, and project search |
| `register` | Named text and point registers |
| `keyboard-macro` | Record and replay keyboard input |

The root composition source remains responsible for cross-feature layout and
the terminal main loop, while
`src/application/command-definitions.lisp` provides the declarative command
catalogue and `src/application/command-registry.lisp` owns M-x lookup and
registration.
