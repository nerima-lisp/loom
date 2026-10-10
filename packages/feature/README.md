# Feature packages

Each directory below is one user-facing capability. A feature may contain
domain state, application commands, external-system integrations, and
presentation helpers in one slice:

| Package | Capability |
| --- | --- |
| `file-tree` | Directory browsing, file I/O, and asynchronous refresh |
| `search` | Buffer search and replacement commands |
| `window` | Window tree and split/delete commands |
| `session` | Session snapshots and persistence |
| `evaluation` | Common Lisp expression and buffer evaluation |
| `lsp` | Minimal stdio LSP client and diagnostics |
| `user-init` | User configuration and init-file loading |
| `syntax-highlighting` | Line-local Common Lisp and mode-aware generic highlighting |
| `mode` | Major modes and mode-specific editing commands |
| `project` | Project roots, file listing, and project search |
| `register` | Named text and point registers |
| `keyboard-macro` | Record and replay keyboard input |
| `auto-save` | Recovery files for modified buffers |
| `format` | External formatter commands and save hooks |
| `git` | Git status, diff, staging, and unstaging |
| `shell` | Shell commands and captured results |
| `terminal` | PTY sessions and ANSI screen state |
| `workspace` | Named workspaces and window trees |

The root composition source remains responsible for cross-feature layout and
the terminal main loop. `src/application/command-definitions.lisp` combines
the declarative groups in `command-definitions-*.lisp` into a command catalogue.
`src/application/command-registry-build.lisp` validates and builds the registry;
`src/application/command-registry.lisp` provides M-x lookup and completion.
