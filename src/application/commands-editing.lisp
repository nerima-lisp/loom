;;;; src/application/commands-editing.lisp
;;;;
;;;; Application layer: text-editing, kill-ring, and undo commands (see
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
  "Insert CHAR at point in the selected window's buffer."
  (buffer-insert-string (%selected-buffer) (string char)))

(defun delete-char ()
  "Delete the character at/after point (forward delete, C-d)."
  (buffer-delete-char (%selected-buffer)))

(defun delete-backward-char ()
  "Delete the character before point (backspace)."
  (buffer-delete-char (%selected-buffer) :backward t))

(defun newline-command ()
  "Insert a newline at point and continue on the new line."
  (buffer-insert-string (%selected-buffer) (string #\Newline)))

(defun open-line ()
  "Insert a newline at point while leaving point before it (C-o)."
  (let ((buffer (%selected-buffer)))
    (let ((line (buffer-point-line buffer))
          (column (buffer-point-column buffer)))
      (buffer-insert-string buffer (string #\Newline))
      (buffer-set-point buffer line column))))

;; Unlike Emacs's KILL-RING-MAX (~120 by default), nothing previously capped
;; how many entries EDITOR-STATE-KILL-RING could accumulate: repeated
;; kill-line/kill-region calls in a long session would grow it without bound,
;; holding onto arbitrarily large amounts of killed text indefinitely (a
;; low-severity memory/security concern as well as wasted work walking a
;; needlessly long list). +KILL-RING-MAX+ mirrors Emacs's default; %KILL-
;; RING-PUSH is the single place both KILL-LINE and KILL-REGION funnel
;; through so the cap is enforced consistently.
(defconstant +kill-ring-max+ 120
  "Maximum number of entries kept in EDITOR-STATE-KILL-RING. Oldest entries
(the tail of the list, since new kills are pushed onto the front) are
dropped once a push would exceed this.")

(defun %kill-ring-push (text)
  "Push TEXT onto *EDITOR-STATE*'s kill ring, then trim the ring down to
+KILL-RING-MAX+ entries by dropping the oldest (tail) entries."
  (let ((kill-ring (cons text (editor-state-kill-ring *editor-state*))))
    (when (> (length kill-ring) +kill-ring-max+)
      (setf kill-ring (subseq kill-ring 0 +kill-ring-max+)))
    (setf (editor-state-kill-ring *editor-state*) kill-ring)))

(defun kill-line ()
  "Kill from point to the end of the line, pushing the text onto the kill ring."
  (let* ((buffer (%selected-buffer))
         (line (buffer-point-line buffer))
         (column (buffer-point-column buffer))
         (line-len (length (buffer-line buffer line))))
    (multiple-value-bind (end-line end-column)
        (cond
          ((< column line-len) (values line line-len))
          ((< line (1- (buffer-line-count buffer))) (values (1+ line) 0))
          (t (values line column)))
      (unless (and (= end-line line) (= end-column column))
        (%kill-ring-push (buffer-delete-region buffer line column end-line end-column))))))

(defun kill-region ()
  "Kill the region between point and mark, or report no region set."
  (let ((buffer (%selected-buffer)))
    (multiple-value-bind (mark-line mark-column) (buffer-mark buffer)
      (if (null mark-line)
          (minibuffer-message (editor-state-minibuffer *editor-state*)
                               "The mark is not set now, so no region is active")
          (let ((point-line (buffer-point-line buffer))
                (point-column (buffer-point-column buffer)))
            (multiple-value-bind (start-line start-column end-line end-column)
                (if (or (< point-line mark-line)
                        (and (= point-line mark-line) (<= point-column mark-column)))
                    (values point-line point-column mark-line mark-column)
                    (values mark-line mark-column point-line point-column))
              (%kill-ring-push (buffer-delete-region buffer start-line start-column end-line end-column))))))))

(defun yank ()
  "Insert the most recently killed text at point."
  (let ((text (first (editor-state-kill-ring *editor-state*))))
    (when text
      (buffer-insert-string (%selected-buffer) text))))

(defun set-mark-command ()
  "Set mark to point's current position."
  (let ((buffer (%selected-buffer)))
    (buffer-set-mark buffer (buffer-point-line buffer) (buffer-point-column buffer))))

(defun undo-command ()
  "Undo the most recent change group in the selected buffer."
  (buffer-undo (%selected-buffer)))
