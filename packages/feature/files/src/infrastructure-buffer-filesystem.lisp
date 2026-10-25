(in-package #:loom/feature/files)

(defmethod buffer-load (path)
  (let ((content
         (if (%native-path-operation-p path)
             (%native-read-file path)
             (cl-boundary-kit:filesystem-read-file *loom-filesystem* path))))
    (let ((buffer
           (make-buffer :name
                        (file-namestring path)
                        :path
                        path
                        :initial-content
                        content)))
      (buffer-set-major-mode buffer
                             (loom/feature/mode:major-mode-for-path path))
      (when
          (and (eq *loom-filesystem* *loom-real-filesystem*)
               (not
                (if (%native-path-operation-p path)
                    (%native-file-writable-p path)
                    (host-kit:file-writable-p path))))
        (buffer-set-read-only buffer t))
      buffer)))

(defmethod buffer-save (buffer)
  (let ((path (buffer-path buffer)))
    (unless path
      (error "buffer-save: buffer ~A has no associated path"
             (buffer-name buffer)))
    (when (buffer-read-only-p buffer)
      (error 'buffer-read-only-error :buffer buffer))
    (run-session-hooks :before-save *editor-session* buffer)
    (if (%native-path-operation-p path)
        (%native-write-file path (buffer-text buffer))
        (cl-boundary-kit:filesystem-store-file *loom-filesystem*
                                               path
                                               (buffer-text buffer)))
    (buffer-mark-saved buffer)
    (run-session-hooks :after-save *editor-session* buffer))
  buffer)
