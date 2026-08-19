;;;; packages/feature/file-tree/src/infrastructure-buffer-filesystem.lisp
;;;;
;;;; Infrastructure layer: the disk-backed BUFFER-LOAD / BUFFER-SAVE methods
;;;; for the buffer protocol declared in packages/core/editor/src/domain-buffer.lisp.
;;;; The pure buffer domain owns text state and editing logic; actual file I/O
;;;; lives here so tests can swap *LOOM-FILESYSTEM* for an in-memory fake.
;;;;
(in-package #:loom/feature/file-tree)

;;; ---------------------------------------------------------------------
;;; BUFFER-LOAD / BUFFER-SAVE: the real, disk-backed :METHOD bodies for the
;;; generics declared (name, docstring, argument list only) in
;;; domain/buffer.lisp. domain/buffer.lisp is deliberately pure text-storage
;;; state with no dependency on CL-HOST-KIT -- see that file's header
;;; comment -- so the actual file I/O lives here instead, same split as
;;; FILE-TREE-CREATE-FILE and friends in
;;; infrastructure-file-tree-filesystem.lisp.
;;; ---------------------------------------------------------------------

(defmethod buffer-load (path)
  (let ((content (if (%native-path-operation-p path)
                     (%native-read-file path)
                     (cl-boundary-kit:filesystem-read-file
                      *loom-filesystem* path))))
    (let ((buffer (make-buffer :name (file-namestring path)
                               :path path
                               :initial-content content)))
      (buffer-set-major-mode buffer
                             (loom/feature/mode:major-mode-for-path path))
      (when (and (eq *loom-filesystem* *loom-real-filesystem*)
                 (not (if (%native-path-operation-p path)
                          (%native-file-writable-p path)
                          (host-kit:file-writable-p path))))
        (buffer-set-read-only buffer t))
      buffer)))

(defmethod buffer-save (buffer)
  (let ((path (buffer-path buffer)))
    (unless path
      (error "buffer-save: buffer ~A has no associated path" (buffer-name buffer)))
    (when (buffer-read-only-p buffer)
      (error 'loom:buffer-read-only-error :buffer buffer))
    (run-before-save-hooks buffer)
    (if (%native-path-operation-p path)
        (%native-write-file path (buffer-text buffer))
        (cl-boundary-kit:filesystem-store-file
         *loom-filesystem* path (buffer-text buffer)))
    (buffer-mark-saved buffer)
    (run-after-save-hooks buffer))
  buffer)
