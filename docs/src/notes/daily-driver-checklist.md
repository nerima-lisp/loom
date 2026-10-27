# Daily-driver manual checklist

Use this checklist to record the author's observations in a real terminal
emulator. PTY E2E scenarios exercise protocol handling, but they do not
establish interaction with a specific terminal emulator, IME conversion, or
day-to-day comfort.

## Preparation

Use a disposable directory and non-sensitive test text. Start Loom in the
terminal emulator used for daily work, following [Getting Started](../getting-started.md).
Record the source revision, OS, terminal emulator and version, terminal size,
and input method. Do not put private paths, file contents, or clipboard data in
the result.

For each row, record `Pass` or `Fail` with a brief observation in `Author
result`. Include any terminal permission prompt or setting that affected the
result. Leave the cell blank until the check has been performed.

## Manual checks

| Procedure | Expected result | Author result |
| --- | --- | --- |
| **IME conversion.** In a text buffer, enter mixed ASCII and Japanese text with the real IME. Compose and accept a candidate, cancel a second composition, move through the accepted text, delete and undo, then save and reopen the file. | The accepted candidate appears once. Cancelling composition adds no unintended text. Movement and deletion follow the inserted text, undo restores it, and the saved text is unchanged after reopening. |  |
| **OSC 52 clipboard.** Put point at the start of a short, non-sensitive string. Run `M-x set-mark-command`, move point past the string, then run `M-w`. Paste into a separate plain-text application. If the terminal emulator asks for clipboard access, record the prompt and response. | The other application receives exactly the selected text through the terminal emulator's clipboard integration. |  |
| **Mouse.** Open a text file and the file-tree sidebar. Click a known position in the text, drag across a region, scroll over the text window, then click a file-tree entry. | The click moves point and selects its window. Dragging extends the region, the wheel scrolls the target window, and the file-tree click opens the selected file. |  |
| **Bracketed paste.** Copy text containing a tab and newline from another application. Paste it into a buffer, save the file, then undo once. | Loom inserts the pasted text literally without auto-indenting it. The saved file retains the pasted characters, and one undo removes the complete paste from the buffer. |  |
| **Daily editing comfort.** Complete a representative editing task in Loom using the terminal emulator and input method you normally use. Note interruptions from input, navigation, redraw, prompts, or selection. | You can complete the task without lost or duplicated input, lost edits, or persistent display problems. Record subjective friction even when no functional failure occurs. |  |

## Acceptance

The FR-V07 manual scope is exactly the five checks above: real-IME text entry,
terminal clipboard access, mouse input, bracketed paste, and daily editing
comfort. The criterion is complete only after the author records an outcome
for every row. A blank result means the check has not been performed; see the
[FR-V07 requirement](requirements-modern-editor.md) for its release context.
