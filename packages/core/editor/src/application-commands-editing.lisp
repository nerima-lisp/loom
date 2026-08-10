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
  (%clear-last-yank)
  (setf (editor-state-last-command-kill-p *editor-state*) nil)
  (let ((count (%command-prefix-count)))
    (when (plusp count)
      (let* ((buffer (%selected-buffer))
             (text (make-string count :initial-element char)))
        (unless (loom/feature/multiple-cursors:multiple-cursors-apply-insert
                 buffer text)
          (buffer-insert-string buffer text))))))

(defun %delete-char-forward-once ()
  (let ((buffer (%selected-buffer)))
    (unless (loom/feature/multiple-cursors:multiple-cursors-apply-delete
             buffer)
      (buffer-delete-char buffer))))

(defun %delete-char-backward-once ()
  (let ((buffer (%selected-buffer)))
    (unless (loom/feature/multiple-cursors:multiple-cursors-apply-delete
             buffer
             :backward t)
      (buffer-delete-char buffer :backward t))))

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
    (loop repeat count
          do (buffer-insert-string (%selected-buffer) (string #\Newline)))))

(defun open-line ()
  "Insert newlines while leaving point before them (C-o)."
  (let ((count (max 0 (%command-prefix-count))))
    (loop repeat count
          do (let ((buffer (%selected-buffer)))
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

(defun %kill-line-once (&key coalesce)
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
        (%kill-ring-push
         (buffer-delete-region buffer line column end-line end-column)
         :coalesce coalesce)))))

(defun kill-line ()
  "Kill through successive line ends according to the active prefix."
  (%clear-last-yank)
  (let ((count (max 0 (%command-prefix-count)))
        (previous-kill
          (editor-state-last-command-kill-p *editor-state*)))
    (loop for index below count
          do (%kill-line-once
              :coalesce (or previous-kill (plusp index))))
    (setf (editor-state-last-command-kill-p *editor-state*) t)))

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

(defun kill-word ()
  "Kill words around point according to the active prefix (M-d)."
  (%clear-last-yank)
  (let* ((buffer (%selected-buffer))
         (count (%command-prefix-count))
         (start-offset (buffer-narrow-start-offset buffer))
         (point (- (buffer-point-offset buffer) start-offset))
         (text (buffer-visible-text buffer)))
    (cond
      ((plusp count)
       (let ((end point))
         (loop repeat count
               do (setf end (%forward-word-offset text end)))
         (%kill-between-offsets
          buffer (+ start-offset point) (+ start-offset end)
          :coalesce (editor-state-last-command-kill-p *editor-state*))))
      ((minusp count)
       (let ((start point))
         (loop repeat (- count)
               do (setf start (%backward-word-offset text start)))
         (%kill-between-offsets
          buffer (+ start-offset start) (+ start-offset point)
          :prepend t
          :coalesce (editor-state-last-command-kill-p *editor-state*)))))
  (setf (editor-state-last-command-kill-p *editor-state*) t)))

(defun backward-kill-word ()
  "Kill backward or forward according to the active prefix (M-Backspace)."
  (%clear-last-yank)
  (let* ((buffer (%selected-buffer))
         (count (%command-prefix-count))
         (start-offset (buffer-narrow-start-offset buffer))
         (point (- (buffer-point-offset buffer) start-offset))
         (text (buffer-visible-text buffer)))
    (cond
      ((plusp count)
       (let ((start point))
         (loop repeat count
               do (setf start (%backward-word-offset text start)))
         (%kill-between-offsets
          buffer (+ start-offset start) (+ start-offset point)
          :prepend t
          :coalesce (editor-state-last-command-kill-p *editor-state*))))
      ((minusp count)
       (let ((end point))
         (loop repeat (- count)
               do (setf end (%forward-word-offset text end)))
         (%kill-between-offsets
          buffer (+ start-offset point) (+ start-offset end)
          :coalesce (editor-state-last-command-kill-p *editor-state*)))))
  (setf (editor-state-last-command-kill-p *editor-state*) t)))

(defun kill-region ()
  "Kill the region between point and mark, or report no region set."
  (%clear-last-yank)
  (let ((buffer (%selected-buffer)))
    (let ((point-line (buffer-point-line buffer))
          (point-column (buffer-point-column buffer)))
      (multiple-value-bind (mark-line mark-column) (buffer-mark buffer)
        (if (null mark-line)
            (minibuffer-message (editor-state-minibuffer *editor-state*)
                                 "The mark is not set now, so no region is active")
            (multiple-value-bind (start-line start-column end-line end-column)
                (%order-region point-line point-column mark-line mark-column)
              (%kill-ring-push
               (buffer-delete-region buffer start-line start-column end-line end-column)
               :prepend
               (or (> point-line mark-line)
                   (and (= point-line mark-line)
                        (> point-column mark-column)))
               :coalesce (editor-state-last-command-kill-p *editor-state*))
              (setf (editor-state-last-command-kill-p *editor-state*) t)))))))

(defun kill-ring-save ()
  "Copy the active region to the kill ring without changing the buffer."
  (%clear-last-yank)
  (setf (editor-state-last-command-kill-p *editor-state*) nil)
  (let ((buffer (%selected-buffer)))
    (multiple-value-bind (mark-line mark-column) (buffer-mark buffer)
      (if (null mark-line)
          (minibuffer-message
           (editor-state-minibuffer *editor-state*)
           "The mark is not set now, so no region is active")
          (multiple-value-bind (start-line start-column end-line end-column)
              (%order-region (buffer-point-line buffer) (buffer-point-column buffer)
                             mark-line mark-column)
            (%kill-ring-push
             (buffer-region-string
              buffer start-line start-column end-line end-column)))))))

(defun copy-region-as-kill ()
  "Compatibility alias for KILL-RING-SAVE, without a default key binding."
  (kill-ring-save))

(defun %repeat-kill-text (text count)
  (with-output-to-string (stream)
    (loop repeat count
          do (write-string text stream))))

(defun %replace-yank-ranges (buffer ranges replacement)
  "Replace each half-open RANGE in BUFFER with REPLACEMENT.

The ranges use the buffer offsets from before any replacement.  Editing from
right to left preserves those offsets; the returned ranges use the resulting
buffer coordinates and retain the original range order."
  (let ((replacement-length (length replacement)))
    (dolist (range (sort (copy-list ranges) #'> :key #'car))
      (let* ((start (buffer-offset-position buffer (car range)))
             (end (buffer-offset-position buffer (cdr range))))
        (buffer-delete-region buffer
                               (buffer-position-line start)
                               (buffer-position-column start)
                               (buffer-position-line end)
                               (buffer-position-column end))
        (buffer-insert-string buffer replacement)))
    (mapcar
     (lambda (range)
       (let* ((old-start (car range))
              (left-shift
                (loop for other in ranges
                      when (<= (cdr other) old-start)
                        sum (- replacement-length
                               (- (cdr other) (car other))))))
         (cons (+ old-start left-shift)
               (+ old-start left-shift replacement-length))))
     ranges)))

(defun yank ()
  "Insert the most recently killed text, repeating for the active prefix."
  (%clear-last-yank)
  (setf (editor-state-last-command-kill-p *editor-state*) nil)
  (let ((text (first (editor-state-kill-ring *editor-state*)))
        (count (max 0 (%command-prefix-count))))
    (when (and text (plusp count))
      (let* ((buffer (%selected-buffer))
             (start (buffer-point-offset buffer))
             (inserted (%repeat-kill-text text count)))
        (multiple-value-bind (handled ranges primary-start primary-end)
            (loom/feature/multiple-cursors:multiple-cursors-apply-insert
             buffer inserted)
          (if handled
              (setf (editor-state-last-yank-start-offset *editor-state*)
                    primary-start
                    (editor-state-last-yank-end-offset *editor-state*)
                    primary-end
                    (editor-state-last-yank-ranges *editor-state*) ranges)
              (progn
                (buffer-insert-string buffer inserted)
                (setf (editor-state-last-yank-start-offset *editor-state*)
                      start
                      (editor-state-last-yank-end-offset *editor-state*)
                      (+ start (length inserted))
                      (editor-state-last-yank-ranges *editor-state*)
                      (list (cons start (+ start (length inserted)))))))
          (setf (editor-state-last-yank-buffer *editor-state*) buffer
                (editor-state-last-yank-ring-index *editor-state*) 0
                (editor-state-last-yank-repeat-count *editor-state*) count
                (editor-state-last-command-kill-p *editor-state*) nil))))))

(defun yank-pop ()
  "Replace the previous yank with the next entry in the kill ring."
  (setf (editor-state-last-command-kill-p *editor-state*) nil)
  (let* ((buffer (%selected-buffer))
         (ring (editor-state-kill-ring *editor-state*))
         (start (editor-state-last-yank-start-offset *editor-state*))
         (end (editor-state-last-yank-end-offset *editor-state*))
         (ranges (or (editor-state-last-yank-ranges *editor-state*)
                     (and (integerp start)
                          (integerp end)
                          (list (cons start end)))))
         (last-buffer (editor-state-last-yank-buffer *editor-state*))
         (index (editor-state-last-yank-ring-index *editor-state*)))
    (if (not (and ring
                  last-buffer
                  (eq buffer last-buffer)
                  (integerp start)
                  (integerp end)
                  (consp ranges)
                  (integerp index)
                  (= (buffer-point-offset buffer) end)))
        (minibuffer-message
         (editor-state-minibuffer *editor-state*)
         "Previous command was not a yank")
        (let* ((next-index (mod (+ index (%command-prefix-count))
                                (length ring)))
               (text (nth next-index ring))
               (repeat-count
                 (max 1 (or (editor-state-last-yank-repeat-count *editor-state*)
                            1)))
               (replacement (%repeat-kill-text text repeat-count)))
          (let* ((new-ranges
                   (%replace-yank-ranges buffer ranges replacement))
                 (primary-index (or (position start ranges :key #'car :test #'=)
                                    0))
                 (primary-range (nth primary-index new-ranges))
                 (primary-position
                   (buffer-offset-position buffer (cdr primary-range))))
            (loom/feature/multiple-cursors:multiple-cursors-update-after-yank-pop
             buffer ranges new-ranges)
            (buffer-set-point buffer
                              (buffer-position-line primary-position)
                              (buffer-position-column primary-position))
            (setf (editor-state-last-yank-start-offset *editor-state*)
                  (car primary-range)
                  (editor-state-last-yank-end-offset *editor-state*)
                  (cdr primary-range)
                  (editor-state-last-yank-ranges *editor-state*) new-ranges
                  (editor-state-last-yank-ring-index *editor-state*) next-index
                  (editor-state-last-command-kill-p *editor-state*) nil))))))

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
         (start (buffer-offset-position buffer (buffer-narrow-start-offset buffer)))
         (end (buffer-offset-position buffer (buffer-narrow-end-offset buffer))))
    (buffer-set-mark buffer
                     (buffer-position-line end)
                     (buffer-position-column end))
    (buffer-set-point buffer
                      (buffer-position-line start)
                      (buffer-position-column start))))

(defun narrow-to-region ()
  "Limit the selected buffer to the region between point and mark."
  (let ((buffer (%selected-buffer)))
    (multiple-value-bind (mark-line mark-column) (buffer-mark buffer)
      (if (null mark-line)
          (minibuffer-message
           (editor-state-minibuffer *editor-state*)
          "The mark is not set now, so no region is active")
          (let* ((point-offset (buffer-point-offset buffer))
                 (mark-offset (%position-to-offset buffer mark-line mark-column))
                 (start-offset (min point-offset mark-offset))
                 (end-offset (max point-offset mark-offset))
                 (start (buffer-offset-position buffer start-offset))
                 (end (buffer-offset-position buffer end-offset)))
            (buffer-narrow-to-region
             buffer
             (buffer-position-line start)
             (buffer-position-column start)
             (buffer-position-line end)
             (buffer-position-column end))
            (minibuffer-message
             (editor-state-minibuffer *editor-state*)
             "Narrowed to the active region"))))))

(defun widen ()
  "Make the selected buffer's complete text visible and editable."
  (let ((buffer (%selected-buffer)))
    (buffer-widen buffer)
    (minibuffer-message (editor-state-minibuffer *editor-state*)
                        "Widened buffer")))

(defun toggle-read-only ()
  "Toggle whether the selected buffer accepts text changes."
  (let* ((buffer (%selected-buffer))
         (read-only-p (not (buffer-read-only-p buffer))))
    (buffer-set-read-only buffer read-only-p)
    (minibuffer-message
     (editor-state-minibuffer *editor-state*)
     (if read-only-p "Buffer is read-only" "Buffer is writable"))
    buffer))

(defun undo-command ()
  "Undo the most recent change group in the selected buffer."
  (buffer-undo (%selected-buffer)))

(defun redo-command ()
  "Redo the most recently undone change group in the selected buffer."
  (buffer-redo (%selected-buffer)))
