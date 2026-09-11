(in-package #:loom)

(defun self-insert-command (character)
  "Insert CHARACTER repeatedly according to the active numeric prefix."
  (%self-insert-character character))

(define-repeating-command delete-char
  "Delete characters at point, repeating for the active numeric prefix."
  %delete-char-forward-once %delete-char-backward-once)

(define-repeating-command delete-backward-char
  "Delete characters before point, repeating for the active numeric prefix."
  %delete-char-backward-once %delete-char-forward-once)

(defun newline-command ()
  "Insert newlines repeatedly according to the active numeric prefix."
  (with-nonnegative-command-prefix (count)
    (%insert-newlines count)))

(defun open-line ()
  "Insert newlines while leaving point before them (C-o)."
  (with-nonnegative-command-prefix (count)
    (%open-line-with-newlines count)))
