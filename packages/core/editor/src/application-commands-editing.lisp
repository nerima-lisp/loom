;;;; packages/core/editor/src/application-commands-editing.lisp
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
  "Insert CHAR repeatedly according to the active numeric prefix."
  (let ((count (%command-prefix-count)))
    (when (plusp count)
      (buffer-insert-string (%selected-buffer)
                            (make-string count :initial-element char)))))

(defun %delete-char-forward-once ()
  (buffer-delete-char (%selected-buffer)))

(defun %delete-char-backward-once ()
  (buffer-delete-char (%selected-buffer) :backward t))

(defun delete-char ()
  "Delete characters at point, repeating for the active numeric prefix."
  (%repeat-command (%command-prefix-count)
                   #'%delete-char-forward-once
                   #'%delete-char-backward-once))

(defun delete-backward-char ()
  "Delete characters before point, repeating for the active numeric prefix."
  (%repeat-command (%command-prefix-count)
                   #'%delete-char-backward-once
                   #'%delete-char-forward-once))

(defun newline-command ()
  "Insert newlines repeatedly according to the active numeric prefix."
  (let ((count (max 0 (%command-prefix-count))))
    (dotimes (index count)
      (declare (ignore index))
      (buffer-insert-string (%selected-buffer) (string #\Newline)))))

(defun open-line ()
  "Insert newlines while leaving point before them (C-o)."
  (let ((count (max 0 (%command-prefix-count))))
    (dotimes (index count)
      (declare (ignore index))
      (let ((buffer (%selected-buffer)))
        (let ((line (buffer-point-line buffer))
              (column (buffer-point-column buffer)))
          (buffer-insert-string buffer (string #\Newline))
          (buffer-set-point buffer line column))))))

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

(defun %kill-line-once ()
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

(defun kill-line ()
  "Kill through successive line ends according to the active prefix."
  (let ((count (max 0 (%command-prefix-count))))
    (dotimes (index count)
      (declare (ignore index))
      (%kill-line-once))))

(defun %kill-between-offsets (buffer start-offset end-offset)
  (unless (= start-offset end-offset)
    (let* ((start (buffer-offset-position buffer start-offset))
           (end (buffer-offset-position buffer end-offset))
           (text (buffer-delete-region
                  buffer
                  (buffer-position-line start)
                  (buffer-position-column start)
                  (buffer-position-line end)
                  (buffer-position-column end))))
      (%kill-ring-push text))))

(defun kill-word ()
  "Kill words around point according to the active prefix (M-d)."
  (let* ((buffer (%selected-buffer))
         (count (%command-prefix-count))
         (point (buffer-point-offset buffer)))
    (cond
      ((plusp count)
       (let ((end point))
         (dotimes (index count)
           (declare (ignore index))
           (setf end (%forward-word-offset (buffer-text buffer) end)))
         (%kill-between-offsets buffer point end)))
      ((minusp count)
       (let ((start point))
         (dotimes (index (- count))
           (declare (ignore index))
           (setf start (%backward-word-offset (buffer-text buffer) start)))
         (%kill-between-offsets buffer start point))))))

(defun backward-kill-word ()
  "Kill backward or forward according to the active prefix (M-Backspace)."
  (let* ((buffer (%selected-buffer))
         (count (%command-prefix-count))
         (point (buffer-point-offset buffer)))
    (cond
      ((plusp count)
       (let ((start point))
         (dotimes (index count)
           (declare (ignore index))
           (setf start (%backward-word-offset (buffer-text buffer) start)))
         (%kill-between-offsets buffer start point)))
      ((minusp count)
       (let ((end point))
         (dotimes (index (- count))
           (declare (ignore index))
           (setf end (%forward-word-offset (buffer-text buffer) end)))
         (%kill-between-offsets buffer point end))))))

(defun %order-region (point-line point-column mark-line mark-column)
  "Return (VALUES START-LINE START-COLUMN END-LINE END-COLUMN) for the region
delimited by point and mark, with whichever of the two positions comes first
in the buffer as the start: positions are compared by line, then by column."
  (if (or (< point-line mark-line)
          (and (= point-line mark-line) (<= point-column mark-column)))
      (values point-line point-column mark-line mark-column)
      (values mark-line mark-column point-line point-column)))

(defun kill-region ()
  "Kill the region between point and mark, or report no region set."
  (let ((buffer (%selected-buffer)))
    (multiple-value-bind (mark-line mark-column) (buffer-mark buffer)
      (if (null mark-line)
          (minibuffer-message (editor-state-minibuffer *editor-state*)
                               "The mark is not set now, so no region is active")
          (multiple-value-bind (start-line start-column end-line end-column)
              (%order-region (buffer-point-line buffer) (buffer-point-column buffer)
                             mark-line mark-column)
            (%kill-ring-push (buffer-delete-region buffer start-line start-column end-line end-column)))))))

(defun yank ()
  "Insert the most recently killed text, repeating for the active prefix."
  (let ((text (first (editor-state-kill-ring *editor-state*))))
    (when (and text (plusp (%command-prefix-count)))
      (dotimes (index (%command-prefix-count))
        (declare (ignore index))
        (buffer-insert-string (%selected-buffer) text)))))

(defun set-mark-command ()
  "Set mark to point's current position."
  (let ((buffer (%selected-buffer)))
    (buffer-set-mark buffer (buffer-point-line buffer) (buffer-point-column buffer))))

(defun exchange-point-and-mark ()
  "Exchange point and mark, or report that no mark is set (C-x C-x)."
  (let ((buffer (%selected-buffer)))
    (multiple-value-bind (mark-line mark-column) (buffer-mark buffer)
      (if (null mark-line)
          (minibuffer-message (editor-state-minibuffer *editor-state*)
                              "The mark is not set")
          (let ((point-line (buffer-point-line buffer))
                (point-column (buffer-point-column buffer)))
            (buffer-set-point buffer mark-line mark-column)
            (buffer-set-mark buffer point-line point-column))))))

(defun mark-whole-buffer ()
  "Set the mark at the end and point at the beginning of the buffer (C-x h)."
  (let* ((buffer (%selected-buffer))
         (end (buffer-offset-position buffer (length (buffer-text buffer)))))
    (buffer-set-mark buffer
                     (buffer-position-line end)
                     (buffer-position-column end))
    (buffer-set-point buffer 0 0)))

(defun undo-command ()
  "Undo the most recent change group in the selected buffer."
  (buffer-undo (%selected-buffer)))
