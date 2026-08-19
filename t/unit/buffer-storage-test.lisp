;;;; t/unit/buffer-storage-test.lisp
(in-package #:loom/test)

(describe
  "buffer-load / buffer-save"
  (it
    "loads a file's contents into a new buffer named after the file"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "notes.txt" dir)))
        (host-kit:write-file-string (format nil "line one~%line two") path)
        (let ((buffer (buffer-load path)))
          (expect (buffer-name buffer) :to-equal "notes.txt")
          (expect (buffer-path buffer) :to-equal path)
          (expect (buffer-line-count buffer) :to-equal 2)
          (expect (buffer-line buffer 0) :to-equal "line one")
          (expect (buffer-read-only-p buffer) :to-be-falsy)
          (expect (buffer-modified-p buffer) :to-be-falsy)))))

  (it
    "marks a non-writable real file read-only"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "readonly.txt" dir)))
        (host-kit:write-file-string "locked" path)
        (sb-posix:chmod (namestring path) #o444)
        (unwind-protect
             (let ((buffer (buffer-load path)))
               (expect (buffer-read-only-p buffer) :to-be-truthy)
               (signals buffer-read-only-error
                 (buffer-insert-string buffer "!")))
          (sb-posix:chmod (namestring path) #o644)))))

  (it
    "saves buffer-text to buffer-path and clears modified-p"
    (host-kit:with-temporary-directory (dir)
      (let* ((path (merge-pathnames "out.txt" dir))
             (buffer (make-buffer :path path :initial-content "hi")))
        (buffer-set-point buffer 0 2)
        (buffer-insert-string buffer " there")
        (expect (buffer-modified-p buffer) :to-be-truthy)
        (buffer-save buffer)
        (expect (buffer-modified-p buffer) :to-be-falsy)
        (expect (host-kit:read-file-string path) :to-equal "hi there"))))

  (it
    "refuses to save a read-only buffer without changing the file"
    (host-kit:with-temporary-directory (dir)
      (let* ((path (merge-pathnames "locked.txt" dir))
             (buffer (make-buffer :path path :initial-content "new")))
        (host-kit:write-file-string "old" path)
        (buffer-set-read-only buffer t)
        (signals buffer-read-only-error
          (buffer-save buffer))
        (expect (host-kit:read-file-string path) :to-equal "old"))))

  (it
    "signals an error saving a buffer with no path"
    (let ((buffer (make-buffer :initial-content "hi")))
      (signals error (buffer-save buffer)))))

(describe
  "piece table storage"
  (it
    "preserves initial text while later edits use the add buffer"
    (let ((buffer (make-buffer :initial-content (format nil "alpha~%omega"))))
      (buffer-set-point buffer 0 5)
      (buffer-insert-string buffer "-beta")
      (buffer-delete-region buffer 1 1 1 3)
      (expect (buffer-text buffer) :to-equal (format nil "alpha-beta~%oga"))
      (expect (loom::%buffer-original buffer) :to-equal (format nil "alpha~%omega"))
      (expect (length (loom::%buffer-add-buffer buffer)) :to-equal 5)
      (expect (length (loom::%buffer-pieces buffer)) :to-equal 4))))

(describe
  "%raw-insert-at and %raw-delete-region"
  (it
    "%raw-insert-at is a no-op for an empty string"
    (let ((buffer (make-buffer :initial-content "hello")))
      (loom::%raw-insert-at buffer 0 2 "")
      (expect (buffer-line buffer 0) :to-equal "hello")
      (expect (length (loom::%buffer-pieces buffer)) :to-equal 1)))

  (it
    "%raw-delete-region is a no-op for an empty (start = end) region"
    (let ((buffer (make-buffer :initial-content "hello")))
      (loom::%raw-delete-region buffer 0 2 0 2)
      (expect (buffer-line buffer 0) :to-equal "hello")
      (expect (length (loom::%buffer-pieces buffer)) :to-equal 1))))
