;;;; packages/feature/mode/src/application-major-mode-editing.lisp
;;;;
;;;; Mode-aware buffer editing commands.
(in-package #:loom/feature/mode)

(defun buffer-truncate-lines-p (buffer)
  "Return true when BUFFER's long lines should be truncated rather than wrapped.

The buffer stores T, NIL, or :DEFAULT; only :DEFAULT consults the major mode."
  (let ((value (loom:buffer-truncate-lines buffer)))
    (if (eq value :default)
        (major-mode-truncate-lines-p (loom:buffer-major-mode buffer))
        value)))

(defun toggle-truncate-lines ()
  "Flip the selected buffer between truncating and wrapping long lines."
  (let ((buffer (loom/application:%selected-buffer)))
    (when buffer
      (let ((truncate (not (buffer-truncate-lines-p buffer))))
        (loom:buffer-set-truncate-lines buffer truncate)
        (loom:minibuffer-message
         (loom:editor-state-minibuffer loom:*editor-state*)
         (if truncate "Truncate long lines" "Wrap long lines")))))
  nil)

(defun indent-for-tab-command ()
  "Insert spaces until point reaches the selected mode's indentation stop."
  (let ((buffer (loom/application:%selected-buffer)))
    (when buffer
      (let* ((width (max 1 (major-mode-indentation-width
                            (loom:buffer-major-mode buffer))))
             (column (loom:buffer-point-column buffer))
             (spaces (- width (mod column width))))
        (loom:buffer-insert-string buffer
                                   (make-string spaces :initial-element #\Space)))))
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
                      (loom:buffer-point-column buffer) indentation remove-end)))
    (loom:buffer-delete-region buffer line-number indentation line-number remove-end)
    (loom:buffer-set-point buffer line-number new-column)))

(defun %comment-line-add (buffer line-number indentation prefix)
  (let* ((insertion (format nil "~A " prefix))
         (point (loom:buffer-point-column buffer))
         (new-column (if (>= point indentation) (+ point (length insertion)) point)))
    (loom:buffer-set-point buffer line-number indentation)
    (loom:buffer-insert-string buffer insertion)
    (loom:buffer-set-point buffer line-number new-column)))

(defun %comment-line-context (buffer prefix)
  (let* ((line-number (loom:buffer-point-line buffer))
         (line (loom:buffer-line buffer line-number))
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
  (loom:minibuffer-message
   (loom:editor-state-minibuffer loom:*editor-state*)
   (format nil "Mode ~A has no line comment syntax" (major-mode-name mode))))

(defun comment-line ()
  "Toggle the current line's comment marker according to its major mode."
  (let* ((buffer (loom/application:%selected-buffer))
         (mode (and buffer (loom:buffer-major-mode buffer)))
         (prefix (and mode (major-mode-comment-prefix mode))))
    (cond
      ((null buffer) nil)
      ((null prefix) (%comment-line-no-prefix-message mode))
      (t (%comment-line-toggle-buffer buffer prefix))))
  nil)
