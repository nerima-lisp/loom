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
    %next-line-once %previous-line-once
  "Move point down, repeating for the active numeric prefix.")

(define-repeating-command previous-line
    %previous-line-once %next-line-once
  "Move point up, repeating for the active numeric prefix.")

(define-current-line-boundary-command move-beginning-of-line
    0
  "Move point to the beginning of the current line.")

(define-current-line-boundary-command move-end-of-line
    (length (buffer-line buffer (buffer-point-line buffer)))
  "Move point to the end of the current line.")

(define-repeating-command forward-word
    %forward-word-once %backward-word-once
  "Move point forward by words, repeating for the active numeric prefix.")

(define-repeating-command backward-word
    %backward-word-once %forward-word-once
  "Move point backward by words, repeating for the active numeric prefix.")

(define-buffer-boundary-command beginning-of-buffer
    (buffer-narrow-start-offset buffer)
  "Move point to the beginning of the buffer (M-<).")

(define-buffer-boundary-command end-of-buffer
    (buffer-narrow-end-offset buffer)
  "Move point to the end of the buffer (M->).")

(define-scroll-command scroll-up-command
    1
  "Scroll down by roughly one page, repeating for the active prefix (C-v).")

(define-scroll-command scroll-down-command
    -1
  "Scroll up by roughly one page, repeating for the active prefix (M-v).")

(defun goto-line ()
  "Prompt for a one-based line number and move point there."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((input "Go to line: "))
    (%goto-visible-line-input minibuffer input)))
