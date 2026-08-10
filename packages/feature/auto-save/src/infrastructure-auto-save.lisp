(in-package #:loom/feature/auto-save)

(defun write-auto-save-file (path text)
  "Write TEXT to the auto-save sidecar PATH and return its pathname."
  (check-type text string)
  (let ((pathname (pathname path)))
    (ensure-directories-exist pathname)
    (with-open-file (stream pathname
                            :direction :output
                            :if-exists :supersede
                            :if-does-not-exist :create
                            :external-format :utf-8)
      (write-string text stream))
    pathname))

(defun delete-auto-save-file (buffer)
  "Delete BUFFER's auto-save sidecar when it exists and return its pathname.

This is intended for the ordinary after-save hook.  A missing sidecar is
harmless, so saving a buffer that has not previously been auto-saved still
completes normally."
  (when (and (buffer-p buffer)
             (buffer-path buffer))
    (let ((pathname (auto-save-path (buffer-path buffer))))
      (when (probe-file pathname)
        (delete-file pathname))
      pathname)))

(defun auto-save-buffer-to-file (buffer)
  "Write BUFFER's current text to its auto-save sidecar.

Return NIL when BUFFER is not eligible; otherwise return the sidecar
pathname.  The buffer remains modified because an auto-save is not a normal
save."
  (when (auto-save-eligible-p buffer)
    (write-auto-save-file (auto-save-path (buffer-path buffer))
                          (buffer-text buffer))))
