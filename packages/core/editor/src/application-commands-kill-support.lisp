;;;; packages/core/editor/src/application-commands-kill-support.lisp
;;;;
;;;; Application layer: kill-ring support shared by kill commands.
(in-package #:loom)

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

(defun %kill-ring-push (text &key prepend coalesce)
  "Push TEXT onto the kill ring, optionally coalescing with its newest entry.

When COALESCE is true, append TEXT to the newest entry by default, or prepend
it when PREPEND is true.  The caller supplies COALESCE explicitly so a copied
region (M-w) always starts a fresh entry while adjacent kill commands join."
  (let* ((kill-ring (editor-state-kill-ring *editor-state*))
         (existing (and coalesce (first kill-ring)))
         (entry (if existing
                    (if prepend
                        (concatenate 'string text existing)
                        (concatenate 'string existing text))
                    text))
         (kill-ring (cons entry (if existing (rest kill-ring) kill-ring))))
    (when (> (length kill-ring) +kill-ring-max+)
      (setf kill-ring (subseq kill-ring 0 +kill-ring-max+)))
    (setf (editor-state-kill-ring *editor-state*) kill-ring)))

(defun %kill-line-end-position (buffer line column)
  (let ((line-len (length (buffer-line buffer line))))
    (cond
      ((< column line-len) (values line line-len))
      ((< line (1- (buffer-line-count buffer))) (values (1+ line) 0))
      (t (values line column)))))

(defun %kill-line-once (&key coalesce)
  (let* ((buffer (%selected-buffer))
         (line (buffer-point-line buffer))
         (column (buffer-point-column buffer)))
    (multiple-value-bind (end-line end-column)
        (%kill-line-end-position buffer line column)
      (unless (and (= end-line line) (= end-column column))
        (%kill-ring-push
         (buffer-delete-region buffer line column end-line end-column)
         :coalesce coalesce)))))

(defun %kill-between-offsets (buffer start-offset end-offset &key prepend coalesce)
  (unless (= start-offset end-offset)
    (let* ((start (buffer-offset-position buffer start-offset))
           (end (buffer-offset-position buffer end-offset))
           (text (buffer-delete-region
                  buffer
                  (buffer-position-line start)
                  (buffer-position-column start)
                  (buffer-position-line end)
                  (buffer-position-column end))))
      (%kill-ring-push text :prepend prepend :coalesce coalesce))))

(defun %kill-line-command ()
  (%clear-last-yank)
  (with-nonnegative-command-prefix (count)
    (let ((previous-kill (editor-state-last-command-kill-p *editor-state*)))
      (loop for index below count
            do (%kill-line-once
                :coalesce (or previous-kill (plusp index))))
      (setf (editor-state-last-command-kill-p *editor-state*) t))))
