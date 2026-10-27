# Feature packages

Each directory below is one user-facing capability. A feature may contain
domain state, application commands, external-system integrations, and
presentation helpers in one slice:

| Package | Capability |
| --- | --- |
| `auto-save` | Recovery files for modified buffers |
| `bookmark` | Named bookmarks and navigation |
| `buffers` | Buffer registry, switching, killing, and result buffers |
| `clipboard` | System clipboard reads and writes, plus literal paste handling |
| `completion` | Candidate popup display and input handling |
| `evaluation` | Common Lisp form and buffer evaluation |
| `file-tree` | Directory browsing, file operations, and asynchronous refresh |
| `files` | File opening, saving, and recent-file tracking |
| `format` | External formatter commands and buffer formatting |
| `git` | Git status, diff, staging, and unstaging |
| `help` | Command and keybinding help |
| `keyboard-macro` | Record and replay keyboard input |
| `kill-ring` | Kill, copy, yank, and yank-pop commands |
| `lang-lisp` | Lisp language editing support |
| `lang-markup` | Markdown and Org editing support |
| `lang-nix` | Nix editing support |
| `lang-web` | Web language editing support |
| `lifecycle` | Quit prompts and shutdown handling |
| `lisp-structure` | S-expression motion and structural editing |
| `lsp` | Stdio client with diagnostics, completion, definition navigation, and document synchronization |
| `minibuffer-ui` | Minibuffer cursor and completion-candidate rendering |
| `mode` | Major-mode registry and mode-specific commands |
| `mouse` | SGR mouse clicks, selection, scrolling, and file-tree interaction |
| `project` | Project roots, file listing, and project search |
| `register` | Named text and point registers |
| `search` | Incremental search, result lists, and replacement |
| `session` | Session snapshots and persistence |
| `shell` | Shell commands and captured results |
| `syntax-highlighting` | Line-local Common Lisp and mode-aware generic highlighting |
| `terminal` | PTY sessions and a bounded ANSI screen model |
| `user-init` | User configuration and init-file loading |
| `window` | Window selection, splitting, deletion, and scrolling |
| `workspace` | Named workspaces and window trees |

The root `loom.asd` composes the feature systems with the core systems and
application startup code. Each feature system declares its dependencies and
source order in `packages/feature/<name>/loom-feature-<name>.asd`. Command
specifications register through the shared command API as their defining
components load; there is no central command catalogue file.
