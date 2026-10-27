(in-package #:loom/feature/clipboard)

(progn
  (defgeneric clipboard-read-text ())
  (defgeneric %clipboard-copy-to-local (text))
  (defun %clipboard-message (text)
    (let ((minibuffer
           (and *editor-state* (editor-state-minibuffer *editor-state*))))
      (when minibuffer
        (minibuffer-message minibuffer text)))))

(defun %record-paste-undo-boundary ()
  (loom/core/buffer:buffer-record-undo-boundary
   (loom/core/window-tree:window-buffer
    (loom/core/window-tree:window-tree-selected-window
     (loom/core/editor-session:editor-state-window-tree *editor-state*)))))

(defun clipboard-yank ()
  (multiple-value-bind (text provider failure) (clipboard-read-text)
    (if provider
        (progn
          (%record-paste-undo-boundary)
          (invoke-command "core/insert-pasted-text"
                          :paste
                          (with-output-to-string (stream)
                            (dotimes
                                (index
                                 (max 0
                                      (or
                                       loom/core/command:*current-prefix-argument*
                                       1)))
                              (declare (ignore index))
                              (write-string text stream)))))
        (progn
          (yank)
          (%clipboard-message
           (if (and failure (or (not (stringp failure)) (string/= failure "")))
               (format nil
                       "Clipboard read failed (~A); using kill ring"
                       failure)
               "Clipboard unavailable; using kill ring"))))))

(defun clipboard-copy-text (text)
  (check-type text string)
  (multiple-value-bind (copied failure) (%clipboard-copy-to-local text)
    (when failure
      (%clipboard-message
       (format nil
               "Local clipboard write failed (~A); kill ring remains available"
               failure)))
    copied))
