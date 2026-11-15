# loom v0.2.0

This release adds recovery of unsaved work, interruption of Lisp evaluation,
a buffer list, confirmed saving of several buffers, more Emacs editing
commands, file-tree scrolling, multi-line Common Lisp highlighting, and
answers to language server requests.

## Features

### Recovering unsaved work

- When you open a file that has newer unsaved work than the file on disk, loom
  reports `Unsaved work found (<kind>, <age> newer); M-x recover-file to
  restore`. `<kind>` is `auto-save` for the `#name#` sidecar that auto-save
  writes when it is enabled, or `recovery` for a recovery file that loom wrote
  when it received SIGTERM or SIGHUP. loom does
  not report work whose content matches the buffer.
- `M-x recover-file` asks `Recover from <kind> (<age> newer)? (r, d, i, C-g)`.
  `r` replaces the buffer text as one undoable edit and leaves the buffer
  modified; it does not save. `d` shows a unified diff in
  `*Loom-Recover-Diff*` and asks again. `i` leaves the buffer unchanged, and
  `C-g` quits. In a narrowed buffer, the command asks you to widen first.
- `M-x list-recoverable-files` lists recoverable files with their path and local
  time in the read-only `*Loom-Recover*` buffer. `RET` on a line opens the file
  and continues with `recover-file`. A recovery file written by loom v0.1.0 has
  no recorded path; `RET` on it shows its text read-only.
- At startup, if recovery files exist, loom reports how many and suggests
  `M-x list-recoverable-files`.
- Saving a file deletes its auto-save sidecar and its recovery files. Restoring
  with `r` does not delete them.
- loom locks each open file under `~/.loom/locks/`. If another loom process
  holds the lock, opening the file reports `<path> is open in another loom (pid
  N)` instead of offering recovery. If the lock directory is not writable, loom
  works without locks.
- Recovery files are created with mode 0600 in directories created with mode
  0700. When loom backs up a file to `~/.loom/backups/` before saving, it no
  longer overwrites an existing backup with the same name.

### Interrupting evaluation

`C-g` interrupts a running `M-:`, `C-x C-e`, or `M-x eval-buffer` evaluation
and reports `Evaluation interrupted`. A second `C-g` forces the interruption
through cleanup code that blocks or keeps re-entering. Keys typed during
evaluation run afterwards in the order typed. A `C-g` inside a bracketed paste
does not interrupt. If loom receives SIGTERM or SIGHUP during an
evaluation, it interrupts the evaluation, writes recovery files, and exits with
status 143 for SIGTERM or 129 for SIGHUP.

### Buffer list

`C-x C-b` (`list-buffers`) shows the read-only `*Buffer List*` in another
window and leaves point in the original window. Each row shows a mark, flags
(`.` for the buffer that was current, `%` for read-only, `*` for modified),
the name, size, mode, and file path with the home directory shortened to `~`.
These keys work in the list:

| Key | Action |
| --- | --- |
| `n`, `p` | Move to the next or previous line |
| `RET` | Show the buffer in this window |
| `o` | Show the buffer in another window |
| `d` | Mark the buffer for deletion |
| `s` | Mark the buffer for saving |
| `u` | Remove the mark |
| `x` | Save the buffers marked `s`, kill those marked `d`, then refresh the list |
| `g` | Refresh the list |
| `q` | Close the list |

### Saving several buffers

`C-x s` (`save-some-buffers`) asks about each modified file-backed buffer with
`Save file <path>? (y, n, !, q, C-g)`. `y` saves, `n` skips, `!` saves the rest
without asking, `q` stops and reports the count, and `C-g` quits. loom still
asks before overwriting a file that changed on disk. When nothing needs saving,
it reports `(No files need saving)`; otherwise it reports `Saved N file(s)`.

### Editing commands

| Key | Command | Action |
| --- | --- | --- |
| `M-m` | `back-to-indentation` | Move to the first non-blank character of the line |
| `M-\` | `delete-horizontal-space` | Delete spaces and tabs around point; with a prefix argument, only before point |
| `M-SPC` | `just-one-space` | Leave one space around point, or N with a prefix argument; a negative N also deletes newlines |
| `M-t` | `transpose-words` | Swap the words around point and move past them |
| `M-=` | `count-words-region` | Report the lines, words, and characters in the region, or in the buffer without a region |
| `M-z` | `zap-to-char` | Kill through the next occurrence of a character typed at the prompt; a negative prefix argument searches backward |

`M-z` adds the killed text to the kill ring. If the character is not found, it
reports `Search failed: "<c>"` and leaves the buffer unchanged. Each editing
command is undone with one undo and is rejected in a read-only buffer. `M-m`
and `M-=` also work in read-only buffers.

On macOS, set the terminal emulator to use Option as Meta to type `M-SPC`.

### File-tree scrolling

The file-tree sidebar scrolls to keep the selection visible when you move with
`C-c n` and `C-c p`, open or close a directory, or resize the terminal. The
mouse wheel over the sidebar scrolls it three lines at a time without changing
the selection, and clicks select the entry under the pointer after scrolling.

### Common Lisp highlighting across lines

In Common Lisp buffers, strings and `#| |#` block comments that span several
lines are highlighted on every line. Nested block comments are supported.
Symbols written as `|...|` across lines are not.

### Language server requests

loom now answers requests that a language server sends. It accepts capability
registration and unregistration, answers `workspace/configuration` and
`workspace/workspaceFolders`, and accepts progress creation. For
`window/showMessageRequest`, loom prompts you to choose one of the server's
actions; `C-g` declines. loom answers other requests with a "Method not found"
error and records them in `*Messages*`. loom replaces control characters in
text from the server before displaying or recording it.

## Differences from Emacs

- `undo` in a narrowed buffer applies changes outside the visible region and
  adjusts the region and point. Emacs refuses with "Changes to be undone are
  outside visible portion of buffer".
- `C-x s` with a prefix argument such as `C-u` still asks about each buffer.
  Emacs saves all of them without asking. loom keeps the question so that no
  command saves files without confirmation.
- `C-x s` stops when you cancel the `File changed on disk. Overwrite?`
  confirmation (with `c` or `C-g`) or when a save fails. It then shows the
  cancellation or error message instead of a count.
- `M-z` matches the character case-sensitively. Emacs follows
  `case-fold-search`, which ignores case by default.

## Known limitations

### Evaluation

- SBCL delays the interruption while it runs code with interrupts disabled or
  collects garbage.
- loom cannot redraw the screen while it evaluates, because evaluation runs on
  the main thread.
- Text that the evaluated code writes to its error stream just after `C-g` is
  discarded. loom does not display what evaluated code writes to standard
  output or error output; the minibuffer shows only the value or the error.
- A `C-g` typed just as the evaluation starts may arrive before loom watches
  input. It then does not interrupt, and loom runs it as `keyboard-quit` after
  the evaluation.
- Code that reads `*standard-input*` competes with loom for the terminal input.
- If several evaluation commands arrive in one burst of input, for example when
  you type ahead, a SIGTERM that arrives between two of them
  does not interrupt the next one. loom exits after that evaluation.
- If an evaluation does not stop after SIGTERM or SIGHUP, loom writes recovery
  files from another thread while the evaluation still runs. Those files may
  miss the last changes.

### Signals during other long commands

During a long command other than evaluation, such as an external command run by
`M-!` or `M-x format-current-buffer`, loom handles SIGTERM and SIGHUP after the
command finishes.

### Recovery and locks

- loom does not guarantee advisory locks on a home directory mounted over NFS.
- Reading recovery metadata creates Lisp keywords before loom validates the
  metadata. The metadata is a 0600 file in a 0700 directory that only you can
  write, so this was judged harmless.
- If you move a directory after loom writes recovery files and leave a symlink
  at the old location, opening the file shows no recovery notice and saving does
  not delete the recovery files. `M-x list-recoverable-files` still lists them.
- If you cancel the question about a file changed on disk when loom first
  displays the file, loom takes the file's lock and shows the recovery notice
  after the next command that displays the buffer. In that case, if a keyboard
  macro or one burst of input displays the buffer, edits it, and switches away, loom takes
  the lock only when the buffer is displayed again. loom still writes recovery
  files for the buffer when it exits.
- cl-host-kit, the library loom uses for files, locks, and processes, treats
  each `PATH` entry as a Lisp pathname when it looks up a program. An entry
  containing characters that are special in Lisp pathnames may not be searched
  correctly. The library's tests also do not yet check that the OS lock stays
  held. Both are planned for a later cl-host-kit release.

### Projects and windows

- `C-x p f` (`project-find-file`) does not check whether a buffer already visits
  the file, so it can open a second buffer for the same file.
- Two windows that show the same buffer share point and move together.

### Language server requests

- loom ignores, without recording them, responses from the server that match no
  request loom sent.
- If loom fails to send an internal error (-32603) response, the original error
  is lost.
- loom answers a request whose method is not a string with an invalid
  parameters error (-32602).

## Manual checks

Not yet recorded; the author has not filled in the results. See the `Author
result` column in [the daily-driver checklist](daily-driver-checklist.md).
