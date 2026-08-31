;;;; packages/core/editor/src/application-commands-editing.lisp
;;;;
;;;; Application layer: text insertion/deletion commands (see
;;;; application/commands-internal.lisp for the shared command-authoring
;;;; convention every commands-*.lisp file follows).
(in-package #:loom)

;; SELF-INSERT-COMMAND is the one deliberate exception to the zero-argument
;; command convention: ordinary commands are bound once, ahead of time, via
;; KEYMAP-DEFINE-KEY, so a command function never needs to know which key
;; invoked it. Printable-character input does not go through that lookup at
;; all -- the main input loop's :CHARACTER key-events are handed directly to
;; whatever inserts text, since binding all of Unicode into the keymap trie
;; one codepoint at a time would be pointless -- so SELF-INSERT-COMMAND takes
;; the typed character as an explicit argument instead of reading it back out
;; of some special variable.
(defun self-insert-command (char)
  "Insert CHAR repeatedly according to the active numeric prefix."
  (%self-insert-character char))

(define-repeating-command delete-char
    %delete-char-forward-once %delete-char-backward-once
  "Delete characters at point, repeating for the active numeric prefix.")

(define-repeating-command delete-backward-char
    %delete-char-backward-once %delete-char-forward-once
  "Delete characters before point, repeating for the active numeric prefix.")

(defun newline-command ()
  "Insert newlines repeatedly according to the active numeric prefix."
  (with-nonnegative-command-prefix (count)
    (%insert-newlines count)))

(defun open-line ()
  "Insert newlines while leaving point before them (C-o)."
  (with-nonnegative-command-prefix (count)
    (%open-line-with-newlines count)))
