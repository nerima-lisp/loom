;;;; packages/core/editor/src/application-commands-movement.lisp
;;;;
;;;; Application layer: point-movement commands. Shared word-boundary helpers
;;;; live in application-word-motion.lisp so kill commands can reuse the same
;;;; text/offset logic without depending on this command file.
(in-package #:loom)

(define-repeating-command forward-char
    %forward-char-once %backward-char-once
  "Move point forward, repeating for the active numeric prefix.")

(define-repeating-command backward-char
    %backward-char-once %forward-char-once
  "Move point backward, repeating for the active numeric prefix.")

(define-repeating-command next-line
    %next-visual-line-once %previous-visual-line-once
  "Move point down one screen row, repeating for the active numeric prefix.

In a wrapping buffer a screen row is one wrapped segment, so the move follows
what the user can see, matching Emacs's LINE-MOVE-VISUAL default. A truncating
buffer draws one row per logical line, which makes the two the same thing.")

(define-repeating-command previous-line
    %previous-visual-line-once %next-visual-line-once
  "Move point up one screen row, repeating for the active numeric prefix.")

(define-current-line-boundary-command move-beginning-of-line
  "Move point to the beginning of the current line."
  0)

(define-current-line-boundary-command move-end-of-line
  "Move point to the end of the current line."
  (length (buffer-line buffer (buffer-point-line buffer))))

(define-repeating-command forward-word
    %forward-word-once %backward-word-once
  "Move point forward by words, repeating for the active numeric prefix.")

(define-repeating-command backward-word
    %backward-word-once %forward-word-once
  "Move point backward by words, repeating for the active numeric prefix.")

(define-buffer-boundary-command beginning-of-buffer
  "Move point to the beginning of the buffer (M-<)."
  (buffer-narrow-start-offset buffer))

(define-buffer-boundary-command end-of-buffer
  "Move point to the end of the buffer (M->)."
  (buffer-narrow-end-offset buffer))

(define-scroll-command scroll-up-command
  "Scroll down by roughly one page, repeating for the active prefix (C-v)."
  1)

(define-scroll-command scroll-down-command
  "Scroll up by roughly one page, repeating for the active prefix (M-v)."
  -1)

(defun goto-line ()
  "Prompt for a one-based line number and move point there."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((input "Go to line: "))
    (%goto-visible-line-input minibuffer input)))
