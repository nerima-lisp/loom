(in-package #:loom/test)

(it
  "writes the selected buffer to a new path and registers the new buffer"
  (host-kit:with-temporary-directory (dir)
    (%with-minibuffer-state (minibuffer "hello world"
                             (original (%selected-test-buffer))
                             (path (merge-pathnames "alias.txt" dir)))
      (buffer-set-point original 0 5)
      (buffer-set-mark original 0 2)
      (loom/feature/files:write-file)
      (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) path)
      (let ((new-buffer (%selected-test-buffer)))
        (expect (buffer-name new-buffer) :to-equal "alias.txt")
        (expect (buffer-path new-buffer) :to-equal path)
        (expect (buffer-text new-buffer) :to-equal "hello world")
        (expect new-buffer :to-have-point (cons 0 5))
        (multiple-value-bind (mark-line mark-column) (buffer-mark new-buffer)
          (expect mark-line :to-equal 0)
          (expect mark-column :to-equal 2))
        (expect (host-kit:read-file-string path) :to-equal "hello world")
        (expect (member original (%test-registered-buffers *editor-state*))
                :to-be-truthy)
        (expect (member new-buffer (%test-registered-buffers *editor-state*))
                :to-be-truthy)))))

(describe
  "save-buffer path-less first save"
  (it
    "carries the old buffer's point onto the newly-swapped-in buffer"
    (host-kit:with-temporary-directory (dir)
      (%with-minibuffer-state (minibuffer "hello world"
                               (tree (editor-state-window-tree *editor-state*))
                               (buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 5)
        (buffer-set-mark buffer 0 2)
        (loom/feature/files:save-buffer)
        (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer)
                 (merge-pathnames "new-save.txt" dir))
        (let ((new-buffer (window-buffer (window-tree-selected-window tree))))
          (expect new-buffer :to-have-point (cons 0 5))
          (multiple-value-bind (mark-line mark-column) (buffer-mark new-buffer)
            (expect mark-line :to-equal 0)
            (expect mark-column :to-equal 2))))))

  (it
    "warns instead of overwriting when the typed path already names an existing file"
    (host-kit:with-temporary-directory (dir)
      (let ((existing-path (merge-pathnames "already-here.txt" dir)))
        (host-kit:write-file-string "old content" existing-path)
        (%with-minibuffer-state (minibuffer "hello")
          (loom/feature/files:save-buffer)
          (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) existing-path)
          (expect (loom:minibuffer-message-string minibuffer)
                  :to-equal
                  (format nil "File exists: ~A (press C-x C-s again to overwrite)" existing-path))
          (expect (host-kit:read-file-string existing-path) :to-equal "old content"))))))

(describe
  "find-file buffer identity"
  (it
    "reuses the same buffer when a visited file is reopened"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "reopened.txt" dir)))
        (host-kit:write-file-string "disk" path)
        (%with-minibuffer-state (minibuffer "")
          (let ((before-count (length (%test-registered-buffers *editor-state*))))
            (loom/feature/files:find-file)
            (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) path)
            (let ((buffer (%selected-test-buffer)))
              (buffer-set-point buffer 0 4)
              (buffer-insert-string buffer " edit")
              (loom/feature/files:find-file)
              (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) path)
              (expect (%selected-test-buffer) :to-be buffer)
              (expect (buffer-text buffer) :to-equal "disk edit")
              (expect (length (%test-registered-buffers *editor-state*))
                      :to-equal (1+ before-count)))))))))

(it
  "disambiguates file buffers that share a basename"
  (host-kit:with-temporary-directory (dir)
    (let* ((left-path (merge-pathnames "left/same.txt" dir))
           (right-path (merge-pathnames "right/same.txt" dir)))
      (ensure-directories-exist left-path)
      (ensure-directories-exist right-path)
      (host-kit:write-file-string "left" left-path)
      (host-kit:write-file-string "right" right-path)
      (%with-minibuffer-state (minibuffer "")
        (let* ((left (loom/feature/files:visit-file left-path))
               (right (loom/feature/files:visit-file right-path)))
          (expect (buffer-name left) :to-equal "same.txt")
          (expect (buffer-name right) :to-equal "same.txt<right>")
          (expect (buffer-path left) :to-equal left-path)
          (expect (buffer-path right) :to-equal right-path)
          (expect (buffer-text left) :to-equal "left")
          (expect (buffer-text right) :to-equal "right"))))))
