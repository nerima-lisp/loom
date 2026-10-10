# Daily-driver manual verification

Use this checklist to record the author's experience in a real terminal. PTY
tests establish reproducible input and screen behavior, but do not establish
Japanese IME usability or comfort during daily editing. No author-run results
have been supplied for this checklist.

## Preparation

Use a disposable directory, copies of files, and a disposable Git repository.
Do not run staging commands in a shared checkout or open files containing
credentials. Keep session snapshots private: they can contain buffer text.

Build and start the executable using [Getting Started](../getting-started.md).
Record the source revision, whether it has local edits, OS, terminal application,
terminal dimensions, and IME used. Redact private paths, hostnames, and file
contents from evidence. Record the LSP server and version for LSP checks.

For each row, replace `Not run` with `Pass` or `Fail` and a brief observation.
A failure needs reproduction steps and the observed behavior. A missing external
tool leaves the affected row `Not run`; it is not a pass. These are manual
results, separate from automated tests.

## Editing checks

| Check | Actions and expected observation | Author result |
| --- | --- | --- |
| Common Lisp | Open a `.lisp` file with `C-x C-f`. Edit a nested form, move by sexp, and try `M-x forward-slurp-sexp`, `forward-barf-sexp`, `wrap-round`, `splice-sexp`, and `raise-sexp` on suitable forms. Check balanced structure and undo each edit. Save with `C-x C-s` and reopen to check the saved text. SWANK evaluation is deferred, not a passing criterion. | Not run |
| Nix | Open a `.nix` file. Check the selected mode, indentation, movement, undo, saving, and reopening. Keep long lines visible by moving point beyond the right edge; the view should follow point without changing file text. | Not run |
| TypeScript | Open a `.ts` file and check mode selection, indentation, movement, undo, saving, and reopening. This does not establish TypeScript LSP support without a separately configured server. | Not run |
| Markdown | Open a `.md` file containing a paragraph wider than the window. Check wrapping, next/previous visual-row movement, and saving without inserted wrap newlines. Run `M-x toggle-truncate-lines` and check the same text in truncated mode. | Not run |
| Japanese input | Use the real IME to enter and convert Japanese beside ASCII. Move across full-width characters, delete, undo, save, and reopen. Resize the window and check that text and cursor remain aligned. Record any key interception or composition problem. | Not run |
| Search | Use `C-s` on text with multiple occurrences. Accept with `RET`, then search again and cancel with `C-g`. Check the accepted and restored point positions. | Not run |

## Tooling and restoration checks

| Check | Actions and expected observation | Author result |
| --- | --- | --- |
| LSP | In a disposable Nix project, provide the intended server command at the `lsp-start` prompt or in a project-local `.loom-lsp` file. For a discovered command, press `RET`, review the configuration path, directory, and command, then type exactly `yes` to start it. With a command that wraps beyond the visible review area, use PageDown/C-v and PageUp/M-v to scroll to its end and back to the start without changing the trust answer. Check that `C-g` or any other answer cancels without stopping an existing session and restores the original buffer and viewport. With nixd, enter `let completionValue = 1; in comp`, place point after `comp`, and check that `lsp-completion-at-point` offers `completionValue`. Use a local binding and reference to check `lsp-find-definition` and `lsp-pop-definition`, including the return location. Check `lsp-diagnostics` with invalid syntax, then `lsp-stop`. Record the actual candidates, locations, and diagnostics. | Not run |
| Terminal | Run `M-x terminal`, enter `printf 'terminal-check\n'`, and check the child output. Resize the editor, then run `M-x terminal-stop` and confirm editor input still works. Repeat opening and stopping to check cleanup. | Not run |
| Git | In the disposable repository, change one file. Run `C-x g`, `M-x git-diff`, `git-stage-file`, `git-diff-staged`, and `git-unstage-file`. Check the reported exit status and compare the index and file contents with an external Git inspection. Do not commit or push as part of this check. | Not run |
| Session | Open two disposable files, split a window, move point, and create a bookmark. Run `M-x save-session` with a private snapshot path. Change the buffers and layout, then `M-x load-session` using that path. Check restored text, point, layout, and bookmark. Display-mode persistence is deferred; do not expect a changed truncate/wrap setting to survive restoration. | Not run |
| Exit and restart | Save intended changes, exit with `C-x C-c`, and restart. Check that the terminal's echo, cursor, and normal screen are restored and that saved file bytes match the edits. | Not run |

## Acceptance boundary

All rows need author observations before the manual criterion FR-V08 in the
[verification plan](verification-plan.md) can be considered complete. Failures
and unrun rows remain release-verification gaps. See the
[daily-driver requirements](requirements-daily-driver.md) for deferred features;
this checklist does not convert them into implemented functionality.
