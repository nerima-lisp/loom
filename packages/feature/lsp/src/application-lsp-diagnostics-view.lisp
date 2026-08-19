;;;; packages/feature/lsp/src/application-lsp-diagnostics-view.lisp
;;;;
;;;; Diagnostics presentation helpers for the LSP feature.  Session protocol
;;;; code produces structured diagnostics; this file owns the Loom buffer and
;;;; text rendering used to display them.
(in-package #:loom/feature/lsp)

(defparameter *lsp-diagnostics-buffer-name* "*Loom-Diagnostics*")

(defun %lsp-diagnostics-buffer ()
  "Return the registered buffer used to display LSP diagnostics."
  (or (find *lsp-diagnostics-buffer-name*
            (loom/application:%editor-buffers)
            :key #'buffer-name
            :test #'string=)
      (loom/application:%register-buffer
       (make-buffer :name *lsp-diagnostics-buffer-name*))))

(defun %replace-buffer-text (buffer text)
  "Replace BUFFER's complete contents with TEXT and mark it saved."
  (let ((end (buffer-offset-position buffer (length (buffer-text buffer)))))
    (unless (and (zerop (buffer-position-line end))
                 (zerop (buffer-position-column end)))
      (buffer-delete-region buffer
                            0
                            0
                            (buffer-position-line end)
                            (buffer-position-column end)))
    (buffer-insert-string buffer text)
    (buffer-mark-saved buffer)))

(defun %lsp-diagnostic-text-line (diagnostic)
  "Render DIAGNOSTIC to a single text line."
  (let* ((range (lsp-diagnostic-range diagnostic))
         (start (lsp-range-start range))
         (severity (lsp-diagnostic-severity diagnostic))
         (source (lsp-diagnostic-source diagnostic)))
    (format nil
            "~D:~D ~A~@[ [~A]~]~@[ (~A)~]"
            (1+ (lsp-position-line start))
            (1+ (lsp-position-character start))
            (lsp-diagnostic-message diagnostic)
            (and severity
                 (lsp-diagnostic-severity-name severity))
            source)))

(defun %lsp-diagnostics-text (buffer diagnostics)
  "Render DIAGNOSTICS for BUFFER as plain text suitable for a Loom buffer."
  (with-output-to-string (output)
    (format output "Diagnostics for ~A~%" (buffer-name buffer))
    (if diagnostics
        (dolist (diagnostic diagnostics)
          (write-line (%lsp-diagnostic-text-line diagnostic) output))
        (write-line "No diagnostics." output))))
