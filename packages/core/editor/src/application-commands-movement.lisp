(in-package #:loom)

(define-repeating-command forward-char
  "Move point forward, repeating for the active numeric prefix."
  %forward-char-once %backward-char-once)

(define-repeating-command backward-char
  "Move point backward, repeating for the active numeric prefix."
  %backward-char-once %forward-char-once)

(define-repeating-command next-line
  "Move point down one screen row, repeating for the active numeric prefix.

In a wrapping buffer a screen row is one wrapped segment, so the move follows
what the user can see, matching Emacs's LINE-MOVE-VISUAL default. A truncating
buffer draws one row per logical line, which makes the two the same thing."
  next-visual-line-once previous-visual-line-once)

(define-repeating-command previous-line
  "Move point up one screen row, repeating for the active numeric prefix."
  previous-visual-line-once next-visual-line-once)

(define-current-line-boundary-command move-beginning-of-line
  "Move point to the beginning of the current line."
  0)

(define-current-line-boundary-command move-end-of-line
  "Move point to the end of the current line."
  (length (buffer-line buffer (buffer-point-line buffer))))

(define-repeating-command forward-word
  "Move point forward by words, repeating for the active numeric prefix."
  %forward-word-once %backward-word-once)

(define-repeating-command backward-word
  "Move point backward by words, repeating for the active numeric prefix."
  %backward-word-once %forward-word-once)

(define-buffer-boundary-command beginning-of-buffer
  "Move point to the beginning of the buffer's visible region (M-<)."
  (buffer-narrow-start-offset buffer))

(define-buffer-boundary-command end-of-buffer
  "Move point to the end of the buffer's visible region (M->)."
  (buffer-narrow-end-offset buffer))

(defun goto-line ()
  "Prompt for a one-based line number within the visible region and move point there."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((input "Go to line: "))
    (%goto-visible-line-input minibuffer input)))
