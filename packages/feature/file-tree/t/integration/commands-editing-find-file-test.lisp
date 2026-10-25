(in-package #:loom/test)

(describe "find-file"
  (it
    "loads an existing file's contents into the selected window"
    (host-kit:with-temporary-directory (dir)
      (%with-minibuffer-state (minibuffer ""
                               (path (merge-pathnames "existing.txt" dir)))
        (host-kit:write-file-string "already here" path)
        (loom/feature/file-tree:find-file)
        (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) path)
        (let ((buffer (%selected-test-buffer)))
          (expect (buffer-name buffer) :to-equal "existing.txt")
          (expect (buffer-text buffer) :to-equal "already here")))))
)