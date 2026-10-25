(in-package #:loom/feature/mode)

(defun buffer-truncate-lines-p (buffer)
  "Return true when BUFFER's long lines should be truncated rather than wrapped.

The buffer stores T, NIL, or :DEFAULT; only :DEFAULT consults the major mode."
  (let ((value (buffer-truncate-lines buffer)))
    (if (eq value :default)
        (major-mode-truncate-lines-p (buffer-major-mode buffer))
        value)))

(defun toggle-truncate-lines ()
  "Flip the selected buffer between truncating and wrapping long lines."
  (let ((buffer (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*)))))
    (when buffer
      (let ((truncate (not (buffer-truncate-lines-p buffer))))
        (buffer-set-truncate-lines buffer truncate)
        (minibuffer-message
         (editor-state-minibuffer *editor-state*)
         (if truncate "Truncate long lines" "Wrap long lines")))))
  nil)
(defun %major-mode-previous-line-indentation (buffer line-number)
  (if (zerop line-number)
      0
      (%major-mode-line-indentation (buffer-line buffer (1- line-number)))))
(defun %shell-line-code (line)
  (loop for index from 0 below (length line)
        for character = (char line index)
        when (and (char= character #\#)
                  (or (zerop index)
                      (char= (char line (1- index)) #\Space)
                      (char= (char line (1- index)) #\Tab)
                      (char= (char line (1- index)) #\;)))
          do (return (subseq line 0 index))
        finally (return line)))
(defun %shell-line-first-word (line)
  (let* ((line (%shell-line-code line))
         (start (%major-mode-line-indentation line))
         (end
          (position-if
           (lambda (character)
             (member character (quote (#\Space #\Tab #\;))
                     :test (function char=)))
           line
           :start
           start)))
    (string-downcase (subseq line start (or end (length line))))))
(defun %shell-line-last-word (line)
  (let* ((trimmed
          (string-right-trim (quote (#\Space #\Tab)) (%shell-line-code line)))
         (separator
          (position-if
           (lambda (character)
             (member character (quote (#\Space #\Tab #\;))
                     :test (function char=)))
           trimmed
           :from-end
           t)))
    (string-downcase
     (subseq trimmed
             (if separator
                 (1+ separator)
                 0)))))
(defun %shell-line-ends-with-open-brace-p (line)
  (let* ((line (%shell-line-code line))
         (end
          (position-if-not
           (lambda (character)
             (member character (quote (#\Space #\Tab)) :test (function char=)))
           line
           :from-end
           t)))
    (and end (char= (char line end) #\{))))
(defun %shell-line-opens-block-p (line)
  (let ((first-word (%shell-line-first-word line))
        (last-word (%shell-line-last-word line)))
    (or
     (and (string= last-word "then")
          (member first-word (quote ("if" "elif" "then")) :test (function string=)))
     (and (string= last-word "do")
          (member first-word
                  (quote ("for" "while" "until" "select" "do"))
                  :test (function string=)))
     (string= first-word "else")
     (and (string= first-word "case")
          (string= last-word "in"))
     (%shell-line-ends-with-open-brace-p line))))
(defun %shell-line-closes-block-p (line)
  (member (%shell-line-first-word line)
          '("fi" "done" "}" "esac" "else" "elif")
          :test
          #'string-equal))
(defun %shell-indentation-rule (buffer line-number)
  (let* ((current-line (buffer-line buffer line-number))
         (previous-indentation
          (%major-mode-previous-line-indentation buffer line-number)))
    (cond
      ((%shell-line-closes-block-p current-line)
       (max 0 (- previous-indentation (major-mode-indentation-width :shell))))
      ((and (plusp line-number)
            (%shell-line-opens-block-p (buffer-line buffer (1- line-number))))
       (+ previous-indentation (major-mode-indentation-width :shell)))
      (t previous-indentation))))
(defun major-mode-indentation-column (buffer line-number)
  "Return BUFFER's desired indentation in columns for zero-based LINE-NUMBER.

Registered indentation rules receive BUFFER and LINE-NUMBER. They return a
non-negative column, or NIL to use the preceding line's indentation."
  (unless
      (and (integerp line-number)
           (<= 0 line-number)
           (< line-number (buffer-line-count buffer)))
    (error "Invalid major-mode line number: ~S" line-number))
  (let* ((mode (buffer-major-mode buffer))
         (rule (gethash mode *major-mode-indentation-rules*))
         (indentation (and rule (funcall rule buffer line-number))))
    (cond
      ((null indentation)
       (%major-mode-previous-line-indentation buffer line-number))
      ((and (integerp indentation) (<= 0 indentation)) indentation)
      (t
       (error "Major-mode indentation rule returned an invalid column: ~S"
              indentation)))))
(defun %indent-column-after-change (column old-indentation new-indentation)
  (if (< column old-indentation)
      (min column new-indentation)
      (+ new-indentation (- column old-indentation))))
(defun %indent-major-mode-line (buffer line-number)
  (let* ((line (buffer-line buffer line-number))
         (old-indentation (%major-mode-line-indentation line))
         (new-indentation (major-mode-indentation-column buffer line-number))
         (point-line (buffer-point-line buffer))
         (point-column (buffer-point-column buffer)))
    (unless (= old-indentation new-indentation)
      (buffer-set-point buffer line-number 0)
      (when (plusp old-indentation)
        (buffer-delete-region buffer line-number 0 line-number old-indentation))
      (when (plusp new-indentation)
        (buffer-insert-string buffer
                              (make-string new-indentation
                                           :initial-element
                                           #\Space)))
      (when (= point-line line-number)
        (setf point-column (%indent-column-after-change point-column
                                                        old-indentation
                                                        new-indentation)))
      (buffer-set-point buffer point-line point-column))
    (values old-indentation new-indentation)))
(defun indent-region ()
  "Reindent the active region, or the current line when no region is active."
  (let ((buffer
         (window-buffer
          (window-tree-selected-window
           (editor-state-window-tree *editor-state*)))))
    (when buffer
      (let* ((span (buffer-active-region-span buffer))
             (point-line (buffer-point-line buffer))
             (point-column (buffer-point-column buffer))
             (mark-active (buffer-mark-active-p buffer))
             (mark-position (multiple-value-list (buffer-mark buffer)))
             (start-line point-line)
             (end-line point-line))
        (when span
          (let* ((span-start-position
                   (buffer-offset-position
                    buffer
                    (buffer-span-start span)))
                 (span-end-position
                   (buffer-offset-position
                    buffer
                    (buffer-span-end span)))
                 (span-start-line
                   (buffer-position-line span-start-position))
                 (span-end-line
                   (buffer-position-line span-end-position))
                 (span-end-column
                   (buffer-position-column span-end-position)))
            (setf start-line span-start-line
                  end-line
                  (max span-start-line
                       (if (and (> span-end-line span-start-line)
                                (zerop span-end-column))
                           (1- span-end-line)
                           span-end-line)))))
        (loop for line-number from start-line to end-line
              do (multiple-value-bind (old-indentation new-indentation)
                     (%indent-major-mode-line buffer line-number)
                   (when (= point-line line-number)
                     (setf point-column (%indent-column-after-change
                                         point-column
                                         old-indentation
                                         new-indentation)))
                   (when
                       (and (first mark-position)
                            (= (first mark-position) line-number))
                     (setf (second mark-position) (%indent-column-after-change
                                                   (second mark-position)
                                                   old-indentation
                                                   new-indentation)))))
        (when (first mark-position)
          (buffer-set-mark buffer (first mark-position) (second mark-position))
          (unless mark-active
            (buffer-deactivate-mark buffer)))
        (buffer-set-point buffer point-line point-column))))
  nil)

(defun indent-for-tab-command ()
  "Indent the current line or the active region using its major mode."
  (let ((buffer
         (window-buffer
          (window-tree-selected-window
           (editor-state-window-tree *editor-state*)))))
    (when buffer
      (if (buffer-mark-active-p buffer)
          (indent-region)
          (%indent-major-mode-line buffer (buffer-point-line buffer)))))
  nil)
(defun newline-and-indent ()
  "Insert a newline and indent the new line using the major-mode protocol."
  (let ((buffer
         (window-buffer
          (window-tree-selected-window
           (editor-state-window-tree *editor-state*)))))
    (when buffer
      (buffer-insert-string buffer (string #\Newline))
      (%indent-major-mode-line buffer (buffer-point-line buffer))))
  nil)

(defun %comment-line-removal-end (line indentation prefix-end)
  (if (and (< prefix-end (length line))
           (char= (char line prefix-end) #\Space))
      (1+ prefix-end) prefix-end))

(defun %comment-line-point-after-removal (point-column indentation remove-end)
  (let ((removed-width (- remove-end indentation)))
    (cond ((<= point-column indentation) point-column)
          ((<= point-column remove-end) indentation)
          (t (- point-column removed-width)))))

(defun %comment-line-remove (buffer line-number line indentation prefix)
  (let* ((prefix-end (+ indentation (length prefix)))
         (remove-end (%comment-line-removal-end line indentation prefix-end))
         (new-column (%comment-line-point-after-removal
                      (buffer-point-column buffer) indentation remove-end)))
    (buffer-delete-region buffer line-number indentation line-number remove-end)
    (buffer-set-point buffer line-number new-column)))

(defun %comment-line-add (buffer line-number indentation prefix)
  (let* ((insertion (format nil "~A " prefix))
         (point (buffer-point-column buffer))
         (new-column (if (>= point indentation) (+ point (length insertion)) point)))
    (buffer-set-point buffer line-number indentation)
    (buffer-insert-string buffer insertion)
    (buffer-set-point buffer line-number new-column)))

(defun %comment-line-context (buffer prefix)
  (let* ((line-number (buffer-point-line buffer))
         (line (buffer-line buffer line-number))
         (indentation (%major-mode-line-indentation line)))
    (values line-number line indentation
            (%major-mode-comment-prefix-at line indentation prefix))))

(defun %comment-line-toggle-buffer (buffer prefix)
  (multiple-value-bind (line-number line indentation commented)
      (%comment-line-context buffer prefix)
    (if commented
        (%comment-line-remove buffer line-number line indentation prefix)
        (%comment-line-add buffer line-number indentation prefix))))

(defun %comment-line-no-prefix-message (mode)
  (minibuffer-message
   (editor-state-minibuffer *editor-state*)
   (format nil "Mode ~A has no line comment syntax" (major-mode-name mode))))

(defun comment-line ()
  "Toggle the current line's comment marker according to its major mode."
  (let* ((buffer (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*))))
         (mode (and buffer (buffer-major-mode buffer)))
         (prefix (and mode (major-mode-comment-prefix mode))))
    (cond
      ((null buffer) nil)
      ((null prefix) (%comment-line-no-prefix-message mode))
      (t (%comment-line-toggle-buffer buffer prefix))))
  nil)

(defun %registered-buffer-truncate-policy (session buffer)
  (declare (ignore session))
  (buffer-truncate-lines-p buffer))
(defun %major-mode-enter-key-input-hook (session event kind)
  (declare (ignore session))
  (let* ((window-tree (editor-state-window-tree *editor-state*))
         (buffer
          (and window-tree
               (window-buffer (window-tree-selected-window window-tree))))
         (minibuffer (editor-state-minibuffer *editor-state*))
         (completion (editor-state-completion *editor-state*)))
    (if (and (eq kind :key)
             (eq (cl-tty-kit:key-event-type event) :special)
             (eq (cl-tty-kit:key-event-code event) :enter)
             buffer
             (not completion)
             (not (buffer-read-only-p buffer))
             (not (and minibuffer (minibuffer-active-p minibuffer))))
        (progn
          (newline-and-indent)
          :handled)
        :pass)))

(eval-when (:load-toplevel :execute)
  (register-buffer-truncate-policy
   :feature/mode
   (function %registered-buffer-truncate-policy))
  (register-major-mode-indentation-rule
   :shell
   (function %shell-indentation-rule))
  (register-session-hook
   :key-input
   :feature/mode
   (function %major-mode-enter-key-input-hook)))

(progn
  (defun %comment-dwim-line-prefix-column (line comment-start)
    (let* ((indentation (%major-mode-line-indentation line))
           (end (+ indentation (length comment-start))))
      (and (<= end (length line))
           (string= comment-start line :start2 indentation :end2 end)
           indentation)))

  (defun %comment-dwim-marker-removal-end (line start-column comment-start)
    (let ((end (+ start-column (length comment-start))))
      (if (and (< end (length line))
               (char= (char line end) #\Space))
          (1+ end)
          end)))

  (defun %comment-dwim-region-line-bounds (buffer span)
    (let* ((start (buffer-offset-position buffer (buffer-span-start span)))
           (end (buffer-offset-position buffer (buffer-span-end span)))
           (start-line (buffer-position-line start))
           (end-line (buffer-position-line end)))
      (values start-line
              (max start-line
                   (if (and (> end-line start-line)
                            (zerop (buffer-position-column end)))
                       (1- end-line)
                       end-line)))))

  (defun %comment-dwim-region-lines-commented-p
      (buffer start-line end-line comment-start)
    (loop for line-number from start-line to end-line
          always
          (%comment-dwim-line-prefix-column
           (buffer-line buffer line-number)
           comment-start)))

  (defun %comment-dwim-offset-after-insert
      (offset insertion-offset length &optional include-boundary)
    (when offset
      (if (if include-boundary
              (>= offset insertion-offset)
              (> offset insertion-offset))
          (+ offset length)
          offset)))

  (defun %comment-dwim-offset-after-delete (offset start-offset end-offset)
    (when offset
      (cond
        ((< offset start-offset) offset)
        ((<= offset end-offset) start-offset)
        (t (- offset (- end-offset start-offset))))))

  (defun %comment-dwim-save-state (buffer)
    (multiple-value-bind (mark-line mark-column)
        (buffer-mark buffer)
      (values
       (loom/core/buffer:buffer-point-offset buffer)
       (and mark-line
            (loom/core/buffer:buffer-position-offset
             buffer mark-line mark-column))
       (buffer-mark-active-p buffer))))

  (defun %comment-dwim-restore-state
      (buffer point-offset mark-offset mark-active)
    (let ((point (buffer-offset-position buffer point-offset)))
      (buffer-set-point buffer
                        (buffer-position-line point)
                        (buffer-position-column point)))
    (when mark-offset
      (let ((mark (buffer-offset-position buffer mark-offset)))
        (buffer-set-mark buffer
                         (buffer-position-line mark)
                         (buffer-position-column mark))))
    (unless mark-active
      (buffer-deactivate-mark buffer)))

  (defun %comment-dwim-text-between-offsets (buffer start-offset end-offset)
    (let ((start (buffer-offset-position buffer start-offset))
          (end (buffer-offset-position buffer end-offset)))
      (loom/core/buffer:buffer-region-string
       buffer
       (buffer-position-line start)
       (buffer-position-column start)
       (buffer-position-line end)
       (buffer-position-column end))))

  (defun %comment-dwim-wrapped-region-kind-p
      (buffer start-offset end-offset comment-start comment-end)
    (let* ((selection
             (%comment-dwim-text-between-offsets
              buffer start-offset end-offset))
           (start-length (length comment-start))
           (end-length (length comment-end))
           (inside
             (and (>= (length selection) (+ start-length end-length))
                  (string= comment-start selection
                           :start2 0 :end2 start-length)
                  (string= comment-end selection
                           :start2 (- (length selection) end-length)
                           :end2 (length selection))))
           (outside
             (and (>= start-offset start-length)
                  (<= (+ end-offset end-length)
                      (length (loom/core/buffer:buffer-text buffer)))
                  (string= comment-start
                           (%comment-dwim-text-between-offsets
                            buffer (- start-offset start-length)
                            start-offset))
                  (string= comment-end
                           (%comment-dwim-text-between-offsets
                            buffer end-offset (+ end-offset end-length))))))
      (cond (inside :inside)
            (outside :outside)
            (t nil))))

  (defun %comment-dwim-toggle-block-span
      (buffer start-line start-column end-line end-column
       comment-start comment-end)
    (let* ((start-offset
             (loom/core/buffer:buffer-position-offset
              buffer start-line start-column))
           (end-offset
             (loom/core/buffer:buffer-position-offset
              buffer end-line end-column))
           (wrapped-kind
             (%comment-dwim-wrapped-region-kind-p
              buffer start-offset end-offset comment-start comment-end)))
      (multiple-value-bind (point-offset mark-offset mark-active)
          (%comment-dwim-save-state buffer)
        (cond
          ((eq wrapped-kind :inside)
           (let* ((suffix-start (- end-offset (length comment-end)))
                  (suffix-end end-offset)
                  (suffix-start-position (buffer-offset-position buffer suffix-start))
                  (suffix-end-position (buffer-offset-position buffer suffix-end)))
             (buffer-set-point buffer
                               (buffer-position-line suffix-start-position)
                               (buffer-position-column suffix-start-position))
             (buffer-delete-region buffer
                                   (buffer-position-line suffix-start-position)
                                   (buffer-position-column suffix-start-position)
                                   (buffer-position-line suffix-end-position)
                                   (buffer-position-column suffix-end-position))
             (setf point-offset (%comment-dwim-offset-after-delete point-offset
                                                                   suffix-start
                                                                   suffix-end)
                   mark-offset (%comment-dwim-offset-after-delete mark-offset
                                                                  suffix-start
                                                                  suffix-end))
             (let* ((prefix-start start-offset)
                    (prefix-end (+ start-offset (length comment-start)))
                    (prefix-start-position (buffer-offset-position buffer prefix-start))
                    (prefix-end-position (buffer-offset-position buffer prefix-end)))
               (buffer-set-point buffer
                                 (buffer-position-line prefix-start-position)
                                 (buffer-position-column prefix-start-position))
               (buffer-delete-region buffer
                                     (buffer-position-line prefix-start-position)
                                     (buffer-position-column prefix-start-position)
                                     (buffer-position-line prefix-end-position)
                                     (buffer-position-column prefix-end-position))
               (setf point-offset (%comment-dwim-offset-after-delete point-offset
                                                                     prefix-start
                                                                     prefix-end)
                     mark-offset (%comment-dwim-offset-after-delete mark-offset
                                                                    prefix-start
                                                                    prefix-end)))))
          ((eq wrapped-kind :outside)
           (let* ((suffix-start end-offset)
                  (suffix-end (+ end-offset (length comment-end)))
                  (suffix-start-position (buffer-offset-position buffer suffix-start))
                  (suffix-end-position (buffer-offset-position buffer suffix-end)))
             (buffer-set-point buffer
                               (buffer-position-line suffix-start-position)
                               (buffer-position-column suffix-start-position))
             (buffer-delete-region buffer
                                   (buffer-position-line suffix-start-position)
                                   (buffer-position-column suffix-start-position)
                                   (buffer-position-line suffix-end-position)
                                   (buffer-position-column suffix-end-position))
             (setf point-offset (%comment-dwim-offset-after-delete point-offset
                                                                   suffix-start
                                                                   suffix-end)
                   mark-offset (%comment-dwim-offset-after-delete mark-offset
                                                                  suffix-start
                                                                  suffix-end))
             (let* ((prefix-start (- start-offset (length comment-start)))
                    (prefix-end start-offset)
                    (prefix-start-position (buffer-offset-position buffer prefix-start))
                    (prefix-end-position (buffer-offset-position buffer prefix-end)))
               (buffer-set-point buffer
                                 (buffer-position-line prefix-start-position)
                                 (buffer-position-column prefix-start-position))
               (buffer-delete-region buffer
                                     (buffer-position-line prefix-start-position)
                                     (buffer-position-column prefix-start-position)
                                     (buffer-position-line prefix-end-position)
                                     (buffer-position-column prefix-end-position))
               (setf point-offset (%comment-dwim-offset-after-delete point-offset
                                                                     prefix-start
                                                                     prefix-end)
                     mark-offset (%comment-dwim-offset-after-delete mark-offset
                                                                    prefix-start
                                                                    prefix-end)))))
          (t
            (let ((end-position (buffer-offset-position buffer end-offset)))
              (buffer-set-point buffer
                                (buffer-position-line end-position)
                                (buffer-position-column end-position))
              (buffer-insert-string buffer comment-end)
              (setf point-offset (%comment-dwim-offset-after-insert point-offset
                                                                    end-offset
                                                                    (length comment-end))
                    mark-offset (%comment-dwim-offset-after-insert mark-offset
                                                                   end-offset
                                                                   (length comment-end))))
            (let ((start-position (buffer-offset-position buffer start-offset)))
              (buffer-set-point buffer
                                (buffer-position-line start-position)
                                (buffer-position-column start-position))
              (buffer-insert-string buffer comment-start)
              (setf point-offset (%comment-dwim-offset-after-insert point-offset
                                                                    start-offset
                                                                    (length
                                                                     comment-start)
                                                                    t)
                    mark-offset (%comment-dwim-offset-after-insert mark-offset
                                                                   start-offset
                                                                   (length
                                                                    comment-start)
                                                                   t)))))
        (%comment-dwim-restore-state
         buffer point-offset mark-offset mark-active)
        (null wrapped-kind))))

  (defun %comment-dwim-toggle-lines
      (buffer start-line end-line comment-start remove-p)
    (multiple-value-bind (point-offset mark-offset mark-active)
        (%comment-dwim-save-state buffer)
      (loop for line-number from start-line to end-line
            for line = (buffer-line buffer line-number)
            for indentation = (%major-mode-line-indentation line)
            do
               (if remove-p
                   (let* ((end
                            (%comment-dwim-marker-removal-end
                             line indentation comment-start))
                          (start-offset
                            (loom/core/buffer:buffer-position-offset
                             buffer line-number indentation))
                          (end-offset
                            (loom/core/buffer:buffer-position-offset
                             buffer line-number end))
                          (start-position
                            (buffer-offset-position buffer start-offset))
                          (end-position
                            (buffer-offset-position buffer end-offset)))
                     (buffer-set-point
                      buffer
                      (buffer-position-line start-position)
                      (buffer-position-column start-position))
                     (buffer-delete-region
                      buffer
                      (buffer-position-line start-position)
                      (buffer-position-column start-position)
                      (buffer-position-line end-position)
                      (buffer-position-column end-position))
                     (setf point-offset
                           (%comment-dwim-offset-after-delete
                            point-offset start-offset end-offset)
                           mark-offset
                           (%comment-dwim-offset-after-delete
                            mark-offset start-offset end-offset)))
                   (let* ((insertion (format nil "~A " comment-start))
                          (insertion-offset
                            (loom/core/buffer:buffer-position-offset
                             buffer line-number indentation))
                          (position
                            (buffer-offset-position buffer insertion-offset)))
                     (buffer-set-point
                      buffer
                      (buffer-position-line position)
                      (buffer-position-column position))
                     (buffer-insert-string buffer insertion)
                     (setf point-offset
                           (%comment-dwim-offset-after-insert
                            point-offset insertion-offset
                            (length insertion) t)
                           mark-offset
                           (%comment-dwim-offset-after-insert
                            mark-offset insertion-offset
                            (length insertion) t)))))
      (%comment-dwim-restore-state
       buffer point-offset mark-offset mark-active)))

  (defun %comment-dwim-comment-region
      (buffer span comment-start comment-end)
    (if (null comment-end)
        (multiple-value-bind (start-line end-line)
            (%comment-dwim-region-line-bounds buffer span)
          (%comment-dwim-toggle-lines
           buffer start-line end-line comment-start
           (%comment-dwim-region-lines-commented-p
            buffer start-line end-line comment-start)))
        (let* ((start-offset (buffer-span-start span))
               (end-offset (buffer-span-end span))
               (start (buffer-offset-position buffer start-offset))
               (end (buffer-offset-position buffer end-offset)))
          (multiple-value-bind (start-line end-line)
              (%comment-dwim-region-line-bounds buffer span)
            (if (or
                 (%comment-dwim-wrapped-region-kind-p
                  buffer start-offset end-offset comment-start comment-end)
                 (not
                  (%comment-dwim-region-lines-commented-p
                   buffer start-line end-line comment-start)))
                (%comment-dwim-toggle-block-span
                 buffer
                 (buffer-position-line start)
                 (buffer-position-column start)
                 (buffer-position-line end)
                 (buffer-position-column end)
                 comment-start comment-end)
                (%comment-dwim-toggle-lines
                 buffer start-line end-line comment-start t))))))

  (defun %comment-dwim-current-line
      (buffer comment-start comment-end)
    (let* ((line-number (buffer-point-line buffer))
           (line (buffer-line buffer line-number))
           (indentation (%major-mode-line-indentation line)))
      (if comment-end
          (let* ((comment-column (search comment-start line))
                 (end-column
                  (and comment-column
                       (search comment-end line
                               :start2 (+ comment-column
                                          (length comment-start))))))
            (if end-column
                (buffer-set-point
                 buffer line-number (+ comment-column (length comment-start)))
              (when
                  (%comment-dwim-toggle-block-span
                   buffer line-number indentation
                   line-number (length line)
                   comment-start comment-end)
                (buffer-set-point
                 buffer line-number (+ indentation (length comment-start))))))
        (let* ((prefix-column
                (%comment-dwim-line-prefix-column line comment-start))
               (inline-column
                (and (null prefix-column)
                     (let ((column
                            (search comment-start line
                                    :start2 indentation)))
                       (and column
                            (> column indentation)
                            (member (char line (1- column))
                                    (list #\Space #\Tab)
                                    :test (function char=))
                            (+ column (length comment-start)))))))
          (multiple-value-bind (point-offset mark-offset mark-active)
              (%comment-dwim-save-state buffer)
            (cond
             (prefix-column
              (setf point-offset
                    (loom/core/buffer:buffer-position-offset
                     buffer line-number
                     (+ prefix-column (length comment-start)))))
             (inline-column
              (setf point-offset
                    (loom/core/buffer:buffer-position-offset
                     buffer line-number inline-column)))
             (t
              (let* ((last-nonblank
                      (position-if-not
                       (lambda (character)
                         (member character (list #\Space #\Tab)
                                 :test (function char=)))
                       line :from-end t))
                     (insertion-column
                      (if last-nonblank
                          (1+ last-nonblank)
                        indentation))
                     (insertion
                      (if last-nonblank
                          (format nil " ~A" comment-start)
                        comment-start))
                     (insertion-offset
                      (loom/core/buffer:buffer-position-offset
                       buffer line-number insertion-column))
                     (position
                      (buffer-offset-position buffer insertion-offset)))
                (buffer-set-point
                 buffer
                 (buffer-position-line position)
                 (buffer-position-column position))
                (buffer-insert-string buffer insertion)
                (setf point-offset
                      (%comment-dwim-offset-after-insert
                       point-offset insertion-offset
                       (length insertion) t)
                      mark-offset
                      (%comment-dwim-offset-after-insert
                       mark-offset insertion-offset
                       (length insertion) t))
                (setf point-offset
                      (+ insertion-offset (length insertion))))))
            (%comment-dwim-restore-state
             buffer point-offset mark-offset mark-active))))))

  (defun comment-dwim ()
    "Comment the active region, or insert or locate a marker on the current line."
    (let* ((buffer
            (window-buffer
             (window-tree-selected-window
              (editor-state-window-tree *editor-state*))))
           (mode (and buffer (buffer-major-mode buffer)))
           (comment-start (and mode (major-mode-comment-start mode)))
           (comment-end (and mode (major-mode-comment-end mode))))
      (cond
       ((null buffer) nil)
       ((null comment-start)
        (%comment-line-no-prefix-message mode))
       ((let ((span (buffer-active-region-span buffer)))
          (and span
               (> (buffer-span-end span) (buffer-span-start span))))
        (%comment-dwim-comment-region
         buffer (buffer-active-region-span buffer)
         comment-start comment-end))
       (t
        (%comment-dwim-current-line buffer comment-start comment-end))))
    nil))
