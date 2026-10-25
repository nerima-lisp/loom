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
