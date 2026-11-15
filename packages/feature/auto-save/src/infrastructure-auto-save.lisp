(in-package #:loom/feature/auto-save)

(defun %file-access-mode (path)
  "Return PATH's permission bits, or NIL when PATH names no regular file."
  (let ((metadata
          (and path
               (handler-case (host-kit:file-metadata path)
                 (host-kit:host-operation-failed () nil)))))
    (when (and metadata
               (eq (host-kit:file-metadata-kind metadata) :regular-file))
      (logand #o777 (host-kit:file-metadata-mode metadata)))))

(defun write-auto-save-file (path text &key (mode #o600))
  "Atomically replace the auto-save sidecar PATH with TEXT and return its pathname.
The sidecar gets permission bits MODE. The staging file beside it starts with
the sidecar's own name and a dot, #<name>#."
  (check-type text string)
  (let* ((pathname (pathname path))
         (existing-mode (%file-access-mode pathname)))
    (ensure-directories-exist pathname)
    ;; An existing target keeps its own mode through the atomic replacement.
    (when (and existing-mode (/= existing-mode mode))
      (host-kit:set-file-mode pathname mode))
    (host-kit:write-file-string text
                                pathname
                                :mode mode
                                :prefix (format nil "~A."
                                                (native-path-basename pathname)))
    pathname))

(progn
  (defun delete-auto-save-file (buffer)
    "Delete the auto-save sidecar for BUFFER when it exists and return its pathname.

A missing sidecar is harmless, so saving a buffer that has not previously been
auto-saved still completes normally."
    (when (and (buffer-p buffer) (buffer-path buffer))
      (let ((pathname (auto-save-path (buffer-path buffer))))
        (when (probe-file pathname)
          (delete-file pathname))
        pathname)))
  (defun %delete-auto-save-file-after-save (session buffer)
    (declare (ignore session))
    (delete-auto-save-file buffer))
  (eval-when (:load-toplevel :execute)
    (register-session-hook :after-save
                           :feature/auto-save
                           (function %delete-auto-save-file-after-save))))

(defun auto-save-buffer-to-file (buffer)
  "Write BUFFER's current text to its auto-save sidecar.

Return NIL when BUFFER is not eligible; otherwise return the sidecar
pathname.  The buffer remains modified because an auto-save is not a normal
save."
  (when (auto-save-eligible-p buffer)
    (write-auto-save-file (auto-save-path (buffer-path buffer))
                          (buffer-text buffer)
                          :mode (or (%file-access-mode (buffer-path buffer))
                                    #o600))))
