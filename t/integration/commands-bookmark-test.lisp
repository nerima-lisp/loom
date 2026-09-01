(in-package #:loom/test)

(defun %run-bookmark-command (command minibuffer input)
  "Invoke COMMAND and confirm its minibuffer prompt with INPUT."
  (funcall command)
  (funcall (loom::%minibuffer-on-confirm minibuffer) input))

(describe
  "recent files and bookmarks"
  (it
    "tracks existing files and visits a recent file"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "recent.txt" dir)))
        (host-kit:write-file-string "recent" path)
        (%with-minibuffer-state (minibuffer "")
          (loom/feature/file-tree:find-file)
          (funcall (loom::%minibuffer-on-confirm minibuffer) path)
          (expect (editor-state-recent-files *editor-state*)
                  :to-equal (list (editor-path-string path)))
          (expect (buffer-text (%selected-test-buffer)) :to-equal "recent")
          (loom/feature/file-tree:recent-file)
          (funcall (loom::%minibuffer-on-confirm minibuffer)
                   (editor-path-string path))
          (expect (buffer-text (%selected-test-buffer)) :to-equal "recent")))))

  (it
    "rejects a directory in find-file without replacing the current buffer"
    (host-kit:with-temporary-directory (dir)
      (%with-minibuffer-state (minibuffer "existing")
        (let ((buffer (%selected-test-buffer)))
          (loom/feature/file-tree:find-file)
          (funcall (loom::%minibuffer-on-confirm minibuffer) dir)
          (expect (minibuffer-message-string minibuffer)
                  :to-equal (format nil "Cannot open directory: ~A" dir))
          (expect (%selected-test-buffer) :to-be buffer)))))

  (it
    "reports a recent file that disappeared before it was visited"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "gone.txt" dir)))
        (%with-minibuffer-state (minibuffer "existing")
          (setf (editor-state-recent-files *editor-state*)
                (list (editor-path-string path)))
          (loom/feature/file-tree:recent-file)
          (funcall (loom::%minibuffer-on-confirm minibuffer)
                   (editor-path-string path))
          (expect (minibuffer-message-string minibuffer)
                  :to-equal (format nil "Recent file is unavailable: ~A" path)))))))

  (it
    "visits an existing file directly and records it as recent"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "direct.txt" dir)))
        (host-kit:write-file-string "direct" path)
        (%with-minibuffer-state (minibuffer "existing")
          (let ((buffer (loom/feature/file-tree:visit-file path)))
            (expect (buffer-text buffer) :to-equal "direct")
            (expect (%selected-test-buffer) :to-be buffer)
            (expect (editor-state-recent-files *editor-state*)
                    :to-equal (list (editor-path-string path)))))))

  (it
    "leaves the selected buffer unchanged when visiting a missing file directly"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "missing.txt" dir)))
        (%with-minibuffer-state (minibuffer "existing")
          (let ((buffer (%selected-test-buffer)))
            (expect (loom/feature/file-tree:visit-file path) :to-be nil)
            (expect (%selected-test-buffer) :to-be buffer)
            (expect (editor-state-recent-files *editor-state*)
                    :to-equal nil)))))))

  (it
    "sets, jumps to, lists, and deletes a named bookmark"
    (%with-minibuffer-state (minibuffer (format nil "one~%two~%three")
                             (name "spot"))
      (buffer-set-point (%selected-test-buffer) 1 2)
      (%run-bookmark-command #'loom::set-bookmark minibuffer name)
      (let ((bookmark (gethash "spot"
                               (editor-state-bookmarks *editor-state*))))
        (expect (editor-bookmark-p bookmark) :to-be-truthy)
        (expect (editor-bookmark-line bookmark) :to-equal 1)
        (expect (editor-bookmark-column bookmark) :to-equal 2))
      (buffer-set-point (%selected-test-buffer) 0 0)
      (%run-bookmark-command #'loom::jump-to-bookmark minibuffer name)
      (expect (buffer-point-line (%selected-test-buffer)) :to-equal 1)
      (expect (buffer-point-column (%selected-test-buffer)) :to-equal 2)
      (loom::list-bookmarks)
      (expect (minibuffer-message-string minibuffer)
              :to-equal "Bookmarks: spot")
      (%run-bookmark-command #'loom::delete-bookmark minibuffer name)
      (expect (gethash "spot" (editor-state-bookmarks *editor-state*))
              :to-be nil)))

  (it
    "rejects an empty bookmark name after trimming minibuffer whitespace"
    (%with-minibuffer-state (minibuffer "bookmark body")
      (%run-bookmark-command
       #'loom::set-bookmark minibuffer (format nil " ~C " #\Tab))
      (expect (minibuffer-message-string minibuffer)
              :to-equal "Bookmark name cannot be empty")
      (expect (hash-table-count (loom::%bookmark-table)) :to-equal 0)))

  (it-each
      (("jump" loom::jump-to-bookmark)
       ("delete" loom::delete-bookmark))
      "reports a missing bookmark for ~A" (label command)
    (declare (ignore label))
    (%with-minibuffer-state (minibuffer "bookmark body")
      (%run-bookmark-command command minibuffer "missing")
      (expect (minibuffer-message-string minibuffer)
              :to-equal "Unknown bookmark: missing")))

  (it
    "reports an unavailable bookmark target when its file no longer exists"
    (let* ((path #P"/tmp/loom-nonexistent-bookmark-target.txt")
           (bookmark (make-editor-bookmark
                      :name "gone"
                      :path (editor-path-string path)
                      :buffer-name "vanished.txt"
                      :line 0
                      :column 0)))
      (%with-minibuffer-state (minibuffer "")
        (setf (gethash "gone" (loom::%bookmark-table)) bookmark)
        (%run-bookmark-command #'loom::jump-to-bookmark minibuffer "gone")
        (expect (minibuffer-message-string minibuffer)
                :to-equal "Bookmark target is unavailable: gone"))))

  (it
    "reports an unavailable bookmark target when its path is a directory"
    (host-kit:with-temporary-directory (dir)
      (let ((bookmark (make-editor-bookmark
                       :name "directory"
                       :path (editor-path-string dir)
                       :buffer-name "directory"
                       :line 0
                       :column 0)))
        (%with-minibuffer-state (minibuffer "")
          (setf (gethash "directory" (loom::%bookmark-table)) bookmark)
          (%run-bookmark-command #'loom::jump-to-bookmark minibuffer "directory")
          (expect (minibuffer-message-string minibuffer)
                  :to-equal "Bookmark target is unavailable: directory")))))

  (it
    "reloads a bookmark target from its existing file and completes prefixes"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "bookmark-target.txt" dir)))
        (host-kit:write-file-string "loaded" path)
        (%with-minibuffer-state (minibuffer "bookmark body")
          (setf (gethash "alpha" (loom::%bookmark-table))
                (make-editor-bookmark
                 :name "alpha"
                 :path (editor-path-string path)
                 :line 0
                 :column 3))
          (setf (gethash "beta" (loom::%bookmark-table))
                (make-editor-bookmark :name "beta" :line 0 :column 0))
          (expect (loom::%bookmark-candidates "al") :to-equal (list "alpha"))
          (%run-bookmark-command #'loom::jump-to-bookmark minibuffer "alpha")
          (expect (buffer-text (%selected-test-buffer)) :to-equal "loaded")
          (expect (buffer-point-column (%selected-test-buffer)) :to-equal 3)))))

  (it
    "reports when no bookmarks are available to list"
    (%with-minibuffer-state (minibuffer "")
      (loom::list-bookmarks)
      (expect (minibuffer-message-string minibuffer)
              :to-equal "No bookmarks")))
