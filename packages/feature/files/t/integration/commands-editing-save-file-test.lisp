(in-package #:loom/test)
(defun %write-test-file-octets (path octets)
  (with-open-file (stream path :direction :output
                          :element-type (quote (unsigned-byte 8))
                          :if-exists :supersede
                          :if-does-not-exist :create)
    (write-sequence octets stream))
  path)
(defun %read-test-file-octets (path)
  (with-open-file (stream path :direction :input
                          :element-type (quote (unsigned-byte 8)))
    (let ((octets (make-array (file-length stream)
                              :element-type (quote (unsigned-byte 8)))))
      (read-sequence octets stream)
      octets)))

(it
  "refreshes file path completion after a directory entry is created"
  (host-kit:with-temporary-directory (directory)
    (let* ((directory-text
             (namestring (host-kit:ensure-directory-pathname directory)))
           (first-name (concatenate 'string directory-text "first.txt"))
           (second-name (concatenate 'string directory-text "second.txt")))
      (host-kit:write-file-string "first" first-name)
      (expect (member first-name
                      (loom/feature/files::%find-file-candidates directory-text)
                      :test #'string=)
              :to-be-truthy)
      (host-kit:write-file-string "second" second-name)
      (expect (member second-name
                      (loom/feature/files::%find-file-candidates directory-text)
                      :test #'string=)
              :to-be-truthy))))

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
(progn
  (it
    "refuses to overwrite an existing file from an unregistered raw buffer"
    (host-kit:with-temporary-directory (dir)
      (let* ((path (merge-pathnames "raw.txt" dir))
             (backup-dir (merge-pathnames "backups/" dir)))
        (%write-test-file-octets path #(111 108 100))
        (%with-minibuffer-state (minibuffer "")
          (let ((buffer (make-buffer :name "raw.txt"
                                     :path path
                                     :initial-content "new")))
            (expect (member buffer (%test-registered-buffers *editor-state*))
                    :to-be nil)
            (let ((loom/feature/files::*loom-backup-directory* backup-dir))
              (signals error (buffer-save buffer))
              (expect (%read-test-file-octets path)
                      :to-equalp
                      #(111 108 100))))))))
  (it
    "rejects an empty path from write-file without changing its buffer or files"
    (host-kit:with-temporary-directory (dir)
      (let ((*default-pathname-defaults* dir))
        (%with-minibuffer-state (minibuffer "draft")
          (let* ((original (%selected-test-buffer))
                 (buffers-before (%test-registered-buffers *editor-state*)))
            (loom/feature/files:write-file)
            (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "")
            (expect (%selected-test-buffer) :to-be original)
            (expect (buffer-path original) :to-be nil)
            (expect (buffer-text original) :to-equal "draft")
            (expect (%test-registered-buffers *editor-state*)
                    :to-equal buffers-before)
            (expect (loom:minibuffer-message-string minibuffer)
                    :to-equal "File name cannot be empty")
            (expect (uiop:directory-files dir) :to-equal nil)
            (expect (uiop:subdirectories dir) :to-equal nil)))))))

(progn
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

  (it
    "rejects an empty path from save-buffer without changing its buffer or files"
    (host-kit:with-temporary-directory (dir)
      (let ((*default-pathname-defaults* dir))
        (%with-minibuffer-state (minibuffer "draft")
          (let* ((original (%selected-test-buffer))
                 (buffers-before (%test-registered-buffers *editor-state*)))
            (loom/feature/files:save-buffer)
            (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "")
            (expect (%selected-test-buffer) :to-be original)
            (expect (buffer-path original) :to-be nil)
            (expect (buffer-text original) :to-equal "draft")
            (expect (%test-registered-buffers *editor-state*)
                    :to-equal buffers-before)
            (expect (loom:minibuffer-message-string minibuffer)
                    :to-equal "File name cannot be empty")
            (expect (uiop:directory-files dir) :to-equal nil)
            (expect (uiop:subdirectories dir) :to-equal nil)))))))

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
(describe
  "file overwrite backups and notifications"
  (it
    "preserves the exact bytes before every save and reports the written path"
    (host-kit:with-temporary-directory (dir)
      (let* ((path (merge-pathnames "note.txt" dir))
             (backup-dir (merge-pathnames "backups/" dir)))
        (%write-test-file-octets path #(111 108 100))
        (%with-minibuffer-state (minibuffer "")
          (let ((buffer (loom/feature/files:visit-file path)))
            (let ((loom/feature/files::*loom-backup-directory* backup-dir))
              (buffer-set-point buffer 0 (length (buffer-text buffer)))
              (buffer-insert-string buffer " first")
              (buffer-save buffer)
              (expect (loom:minibuffer-message-string minibuffer)
                      :to-equal
                      (format nil "Wrote ~A" path))
              (buffer-set-point buffer 0 (length (buffer-text buffer)))
              (buffer-insert-string buffer " second")
              (buffer-save buffer)
              (expect (loom:minibuffer-message-string minibuffer)
                      :to-equal
                      (format nil "Wrote ~A" path))
              (expect (%read-test-file-octets path)
                      :to-equalp
                      #(111 108 100 32 102 105 114 115 116 32 115 101 99 111 110 100))
              (expect (%read-test-file-octets
                       (merge-pathnames "note.txt.1~" backup-dir))
                      :to-equalp
                      #(111 108 100))
              (expect (%read-test-file-octets
                       (merge-pathnames "note.txt.2~" backup-dir))
                      :to-equalp
                      #(111 108 100 32 102 105 114 115 116))))))))
  (progn
  (it
    "leaves the original file untouched when its backup cannot be created"
    (host-kit:with-temporary-directory (dir)
      (let* ((path (merge-pathnames "note.txt" dir))
             (blocked (merge-pathnames "blocked" dir))
             (backup-dir (merge-pathnames "blocked/backups/" dir)))
        (%write-test-file-octets path #(111 108 100))
        (%write-test-file-octets blocked #(110 111 116 32 97 32 100 105 114 101 99 116 111 114 121))
        (%with-minibuffer-state (minibuffer "")
          (let ((buffer (loom/feature/files:visit-file path)))
            (let ((loom/feature/files::*loom-backup-directory* backup-dir))
              (buffer-set-point buffer 0 (length (buffer-text buffer)))
              (buffer-insert-string buffer " changed")
              (let ((failed
                      (handler-case
                          (progn (buffer-save buffer) nil)
                        (file-error () t))))
                (expect failed :to-be-truthy)
                (expect (loom/core/buffer:buffer-modified-p buffer)
                        :to-be-truthy)
                (expect (%read-test-file-octets path)
                        :to-equalp
                        #(111 108 100))
                (expect (loom:minibuffer-message-string minibuffer)
                        :to-be nil))))))))

  (it
    "rechecks disk contents after the overwrite confirmation"
    (host-kit:with-temporary-directory (dir)
      (let* ((path (merge-pathnames "note.txt" dir))
             (backup-dir (merge-pathnames "backups/" dir)))
        (%write-test-file-octets path #(111 108 100))
        (%with-minibuffer-state (minibuffer "")
          (let ((buffer (loom/feature/files:visit-file path)))
            (let ((loom/feature/files::*loom-backup-directory* backup-dir))
              (buffer-set-point buffer 0 3)
              (buffer-insert-string buffer " local")
              (%write-test-file-octets path #(101 120 116 101 114 110 97 108))
              (loom/feature/files:save-buffer)
              (expect (minibuffer-prompt-string minibuffer)
                      :to-equal
                      (format nil "File changed on disk. Overwrite? (y/n): ~A" path))
              (expect (%read-test-file-octets path)
                      :to-equalp
                      #(101 120 116 101 114 110 97 108))
              (%confirm-minibuffer minibuffer "n")
              (expect (%read-test-file-octets path)
                      :to-equalp
                      #(101 120 116 101 114 110 97 108))
              (expect (loom/core/buffer:buffer-modified-p buffer)
                      :to-be-truthy)
              (loom/feature/files:save-buffer)
              (%write-test-file-octets path #(114 97 99 101 100))
              (%confirm-minibuffer minibuffer "y")
              (expect (minibuffer-prompt-string minibuffer)
                      :to-equal
                      (format nil "File changed on disk. Overwrite? (y/n): ~A" path))
              (expect (%read-test-file-octets path)
                      :to-equalp
                      #(114 97 99 101 100))
              (%confirm-minibuffer minibuffer "y")
              (expect (%read-test-file-octets path)
                      :to-equalp
                      #(111 108 100 32 108 111 99 97 108))
              (expect (loom/core/buffer:buffer-modified-p buffer)
                      :to-be nil)))))))
  (it
    "checks restored file buffers before saving"
    (host-kit:with-temporary-directory (dir)
      (let* ((path (merge-pathnames "restored.txt" dir))
             (backup-dir (merge-pathnames "backups/" dir)))
        (host-kit:write-file-string "disk" path)
        (%with-minibuffer-state (minibuffer "")
          (let* ((tree (editor-state-window-tree *editor-state*))
                 (buffer (make-buffer :name "restored.txt"
                                      :path path
                                      :initial-content "stale"))
                 (window (window-tree-selected-window tree)))
            (let ((loom/feature/files::*loom-backup-directory* backup-dir))
              (progn
                (%register-test-buffer *editor-state* buffer)
                (window-set-buffer window buffer))
              (loom/feature/files:save-buffer)
              (expect (minibuffer-prompt-string minibuffer)
                      :to-equal
                      (format nil "File changed on disk. Overwrite? (y/n): ~A" path))
              (expect (host-kit:read-file-string path) :to-equal "disk")
              (%confirm-minibuffer minibuffer "n")
              (expect (host-kit:read-file-string path) :to-equal "disk")
              (loom/feature/files:save-buffer)
              (expect (minibuffer-prompt-string minibuffer)
                      :to-equal
                      (format nil "File changed on disk. Overwrite? (y/n): ~A" path))
              (expect (host-kit:read-file-string path) :to-equal "disk")
              (%confirm-minibuffer minibuffer "y")
              (expect (host-kit:read-file-string path) :to-equal "stale")
              (expect (loom:minibuffer-message-string minibuffer)
                      :to-equal
                      (format nil "Wrote ~A" path))))))))
  (it
    "checks restored file buffers before recreating a missing file"
    (host-kit:with-temporary-directory (dir)
      (let* ((path (merge-pathnames "missing.txt" dir))
             (backup-dir (merge-pathnames "backups/" dir)))
        (%with-minibuffer-state (minibuffer "")
          (let* ((tree (editor-state-window-tree *editor-state*))
                 (buffer (make-buffer :name "missing.txt"
                                      :path path
                                      :initial-content "recoverable"))
                 (window (window-tree-selected-window tree)))
            (let ((loom/feature/files::*loom-backup-directory* backup-dir))
              (progn
                (%register-test-buffer *editor-state* buffer)
                (window-set-buffer window buffer))
              (loom/feature/files:save-buffer)
              (expect (minibuffer-prompt-string minibuffer)
                      :to-equal
                      (format nil "File changed on disk. Overwrite? (y/n): ~A" path))
              (expect (probe-file path) :to-be nil)
              (%confirm-minibuffer minibuffer "n")
              (expect (probe-file path) :to-be nil)
              (loom/feature/files:save-buffer)
              (expect (minibuffer-prompt-string minibuffer)
                      :to-equal
                      (format nil "File changed on disk. Overwrite? (y/n): ~A" path))
              (%confirm-minibuffer minibuffer "y")
              (expect (host-kit:read-file-string path)
                      :to-equal
                      "recoverable")
              (expect (loom:minibuffer-message-string minibuffer)
                      :to-equal
                      (format nil "Wrote ~A" path)))))))))

  (it
    "checks a file buffer before switching and can reload the external version"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "target.txt" dir)))
        (host-kit:write-file-string "disk" path)
        (%with-minibuffer-state (minibuffer "source"
                                 (source (%selected-test-buffer))
                                 (tree (editor-state-window-tree *editor-state*)))
          (let* ((snapshot-read-count 0)
                 (snapshot-reader loom/feature/files::*file-snapshot-reader*)
                 (loom/feature/files::*file-snapshot-reader*
                  (lambda (path)
                    (incf snapshot-read-count)
                    (funcall snapshot-reader path)))
                 (target
                  (prog1 (loom/feature/files:visit-file path)
                    (expect snapshot-read-count
                            :to-equal
                            (if (funcall
                                 loom/feature/files::*file-metadata-stamp-reader*
                                 path)
                                0
                                1)))))
            (window-set-buffer (window-tree-selected-window tree) source)
            (host-kit:write-file-string "external" path)
            (loom/feature/buffers:switch-to-buffer)
            (%confirm-minibuffer minibuffer (buffer-name target))
            (expect (minibuffer-prompt-string minibuffer)
                    :to-equal
                    (format nil
                            "File changed on disk. [r]eload (discard local edits), [k]eep, [c]ancel: ~A"
                            path))
            (expect (window-buffer (window-tree-selected-window tree))
                    :to-be source)
            (%confirm-minibuffer minibuffer "k")
            (expect (window-buffer (window-tree-selected-window tree))
                    :to-be target)
            (expect (buffer-text target) :to-equal "disk")
            (host-kit:write-file-string "later" path)
            (window-set-buffer (window-tree-selected-window tree) source)
            (loom/feature/buffers:switch-to-buffer)
            (%confirm-minibuffer minibuffer (buffer-name target))
            (%confirm-minibuffer minibuffer "r")
            (expect (buffer-text target) :to-equal "later")
            (expect (window-buffer (window-tree-selected-window tree))
                    :to-be target))))))
  (it
    "rechecks an external write between loading and the first display"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "target.txt" dir))
            (snapshot-read-count 0)
            (snapshot-reader loom/feature/files::*file-snapshot-reader*))
        (host-kit:write-file-string "disk" path)
        (%with-minibuffer-state (minibuffer "source")
          (let* ((loom/feature/files::*file-snapshot-reader*
                  (lambda (snapshot-path)
                    (incf snapshot-read-count)
                    (funcall snapshot-reader snapshot-path)))
                 (target (loom/feature/files::%load-file-buffer path))
                 (continued nil))
            (%register-test-buffer *editor-state* target)
            (host-kit:write-file-string "external" path)
            (loom/feature/files::%guard-file-buffer-switch
             target
             (lambda () (setf continued t)))
            (expect snapshot-read-count :to-equal 1)
            (expect continued :to-be nil)
            (expect (buffer-text target) :to-equal "disk")
            (expect (minibuffer-prompt-string minibuffer)
                    :to-equal
                    (format nil
                            "File changed on disk. [r]eload (discard local edits), [k]eep, [c]ancel: ~A"
                            path)))))))
  #+(and sbcl darwin 64-bit)
(it
  "detects a same-size rewrite with a changed subsecond stamp on first display"
  (host-kit:with-temporary-directory (dir)
    (let ((path (merge-pathnames "target.txt" dir))
          (snapshot-read-count 0)
          (snapshot-reader loom/feature/files::*file-snapshot-reader*))
      (host-kit:write-file-string "disk" path)
      (expect (sb-posix:utimes (namestring path)
                               1700000000.125d0
                               1700000000.125d0)
              :to-equal 0)
      (%with-minibuffer-state (minibuffer "source")
        (let* ((loom/feature/files::*file-snapshot-reader*
                 (lambda (snapshot-path)
                   (incf snapshot-read-count)
                   (funcall snapshot-reader snapshot-path)))
               (target (loom/feature/files::%load-file-buffer path))
               (loaded-stamp
                 (gethash target
                          loom/feature/files::*freshly-loaded-file-buffers*))
               (continued nil))
          (%register-test-buffer *editor-state* target)
          (expect loaded-stamp :to-be-truthy)
          (with-open-file (stream path
                                  :direction :output
                                  :if-exists :overwrite)
            (write-string "else" stream))
          (expect (sb-posix:utimes (namestring path)
                                   1700000000.875d0
                                   1700000000.875d0)
                  :to-equal 0)
          (let ((current-stamp
                  (loom/feature/files::%file-metadata-stamp path)))
            (expect (equal (subseq loaded-stamp 0 4)
                           (subseq current-stamp 0 4))
                    :to-be-truthy)
            (expect (/= (nth 4 loaded-stamp) (nth 4 current-stamp))
                    :to-be-truthy)
            (setf (gethash target
                           loom/feature/files::*freshly-loaded-file-buffers*)
                  (append (subseq current-stamp 0 4)
                          (list (nth 4 loaded-stamp))
                          (subseq current-stamp 5))))
          (loom/feature/files::%guard-file-buffer-switch
           target
           (lambda () (setf continued t)))
          (expect snapshot-read-count :to-equal 1)
          (expect continued :to-be nil)
          (expect (buffer-text target) :to-equal "disk")
          (expect (minibuffer-prompt-string minibuffer)
                  :to-equal
                  (format nil
                          "File changed on disk. [r]eload (discard local edits), [k]eep, [c]ancel: ~A"
                          path)))))))
  (it
    "distinguishes restored file buffers from external changes"
    (host-kit:with-temporary-directory (dir)
      (let ((matching-path (merge-pathnames "matching.txt" dir))
            (stale-path (merge-pathnames "stale.txt" dir))
            (missing-path (merge-pathnames "missing.txt" dir)))
        (host-kit:write-file-string "same" matching-path)
        (host-kit:write-file-string "disk" stale-path)
        (%with-minibuffer-state (minibuffer "source"
                                 (source (%selected-test-buffer))
                                 (matching (make-buffer :name "matching.txt"
                                                        :path matching-path
                                                        :initial-content "same"))
                                 (stale (make-buffer :name "stale.txt"
                                                     :path stale-path
                                                     :initial-content "stale"))
                                 (missing (make-buffer :name "missing.txt"
                                                       :path missing-path
                                                       :initial-content "recoverable"))
                                 (tree (editor-state-window-tree *editor-state*)))
          (%register-test-buffer *editor-state* matching)
          (%register-test-buffer *editor-state* stale)
          (%register-test-buffer *editor-state* missing)
          (loom/feature/buffers:switch-to-buffer)
          (%confirm-minibuffer minibuffer "matching.txt")
          (expect (window-buffer (window-tree-selected-window tree))
                  :to-be matching)
          (host-kit:write-file-string "external" matching-path)
          (window-set-buffer (window-tree-selected-window tree) source)
          (loom/feature/buffers:switch-to-buffer)
          (%confirm-minibuffer minibuffer "matching.txt")
          (expect (minibuffer-prompt-string minibuffer)
                  :to-equal
                  (format nil
                          "File changed on disk. [r]eload (discard local edits), [k]eep, [c]ancel: ~A"
                          matching-path))
          (expect (window-buffer (window-tree-selected-window tree))
                  :to-be source)
          (%confirm-minibuffer minibuffer "k")
          (expect (window-buffer (window-tree-selected-window tree))
                  :to-be matching)
          (expect (buffer-text matching) :to-equal "same")
          (host-kit:write-file-string "later" matching-path)
          (window-set-buffer (window-tree-selected-window tree) source)
          (loom/feature/buffers:switch-to-buffer)
          (%confirm-minibuffer minibuffer "matching.txt")
          (expect (minibuffer-prompt-string minibuffer)
                  :to-equal
                  (format nil
                          "File changed on disk. [r]eload (discard local edits), [k]eep, [c]ancel: ~A"
                          matching-path))
          (%confirm-minibuffer minibuffer "r")
          (expect (buffer-text matching) :to-equal "later")
          (expect (window-buffer (window-tree-selected-window tree))
                  :to-be matching)
          (window-set-buffer (window-tree-selected-window tree) source)
          (loom/feature/buffers:switch-to-buffer)
          (%confirm-minibuffer minibuffer "stale.txt")
          (expect (minibuffer-prompt-string minibuffer)
                  :to-equal
                  (format nil
                          "File changed on disk. [r]eload (discard local edits), [k]eep, [c]ancel: ~A"
                          stale-path))
          (%confirm-minibuffer minibuffer "r")
          (expect (buffer-text stale) :to-equal "disk")
          (expect (window-buffer (window-tree-selected-window tree))
                  :to-be stale)
          (window-set-buffer (window-tree-selected-window tree) source)
          (loom/feature/buffers:switch-to-buffer)
          (%confirm-minibuffer minibuffer "missing.txt")
          (expect (minibuffer-prompt-string minibuffer)
                  :to-equal
                  (format nil
                          "File changed on disk. [r]eload (discard local edits), [k]eep, [c]ancel: ~A"
                          missing-path))
          (expect (window-buffer (window-tree-selected-window tree))
                  :to-be source)
          (%confirm-minibuffer minibuffer "k")
          (progn
            (expect (window-buffer (window-tree-selected-window tree))
                    :to-be missing)
            (expect (probe-file missing-path) :to-be nil)
            (loom/feature/files:save-buffer)
            (expect (minibuffer-prompt-string minibuffer) :to-be nil)
            (expect (host-kit:read-file-string missing-path)
                    :to-equal
                    "recoverable")
            (expect (loom:minibuffer-message-string minibuffer)
                    :to-equal
                    (format nil "Wrote ~A" missing-path)))))))

  (it
    "reverts only after reading the file and confirming modified contents"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "note.txt" dir)))
        (host-kit:write-file-string "disk" path)
        (%with-minibuffer-state (minibuffer "")
          (let ((buffer (loom/feature/files:visit-file path)))
            (buffer-set-point buffer 0 4)
            (buffer-insert-string buffer " local")
            (host-kit:write-file-string "external" path)
            (loom/feature/files:revert-buffer)
            (expect (buffer-text buffer) :to-equal "disk local")
            (expect (minibuffer-prompt-string minibuffer)
                    :to-equal
                    (format nil "Discard local changes and revert ~A? (y/n): " path))
            (%confirm-minibuffer minibuffer "n")
            (expect (buffer-text buffer) :to-equal "disk local")
            (loom/feature/files:revert-buffer)
            (%confirm-minibuffer minibuffer "y")
            (expect (buffer-text buffer) :to-equal "external")
            (expect (loom/core/buffer:buffer-modified-p buffer)
                    :to-be nil)
            (buffer-set-point buffer 0 8)
            (buffer-insert-string buffer " local")
            (delete-file path)
            (let ((before (buffer-text buffer)))
              (loom/feature/files:revert-buffer)
              (expect (buffer-text buffer) :to-equal before)
              (expect (loom:minibuffer-message-string minibuffer)
                      :to-equal
                      (format nil "File is unavailable: ~A" path))))))))
  (it
    "undoes a revert without undoing the prior local edit, then saves from the reverted snapshot"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "note.txt" dir)))
        (host-kit:write-file-string "disk" path)
        (%with-minibuffer-state (minibuffer "")
          (let ((buffer (loom/feature/files:visit-file path)))
            (buffer-set-point buffer 0 4)
            (buffer-insert-string buffer " local")
            (host-kit:write-file-string "external" path)
            (loom/feature/files:revert-buffer)
            (expect (minibuffer-prompt-string minibuffer)
                    :to-equal
                    (format nil "Discard local changes and revert ~A? (y/n): " path))
            (%confirm-minibuffer minibuffer "y")
            (expect (buffer-text buffer) :to-equal "external")
            (loom/core/buffer:buffer-undo buffer)
            (expect (buffer-text buffer) :to-equal "disk local")
            (expect (host-kit:read-file-string path) :to-equal "external")
            (loom/feature/files:save-buffer)
            (expect (minibuffer-prompt-string minibuffer) :to-be nil)
            (expect (host-kit:read-file-string path) :to-equal "disk local")
            (expect (loom:minibuffer-message-string minibuffer)
                    :to-equal
                    (format nil "Wrote ~A" path))))))))
(describe
  "saving to a missing parent directory"
  (it
    "creates the parent directories and saves after confirmation"
    (host-kit:with-temporary-directory (dir)
      (let* ((path (merge-pathnames "nested/deep/new.txt" dir))
             (nested (merge-pathnames "nested/" dir))
             (parent (host-kit:pathname-directory-pathname path)))
        (%with-minibuffer-state (minibuffer "")
          (let* ((buffer (loom/feature/files::%make-file-buffer
                          path
                          :initial-content "pending"))
                 (window (window-tree-selected-window
                          (editor-state-window-tree *editor-state*))))
            (%register-test-buffer *editor-state* buffer)
            (window-set-buffer window buffer)
            (loom/feature/files:save-buffer)
            (expect (minibuffer-prompt-string minibuffer)
                    :to-equal
                    (format nil
                            "Parent directory does not exist. Create it? (y/n): ~A"
                            parent))
            (expect (host-kit:directory-exists-p nested) :to-be nil)
            (expect (host-kit:directory-exists-p parent) :to-be nil)
            (expect (probe-file path) :to-be nil)
            (%confirm-minibuffer minibuffer "y")
            (expect (host-kit:directory-exists-p nested) :to-be-truthy)
            (expect (host-kit:directory-exists-p parent) :to-be-truthy)
            (expect (host-kit:read-file-string path) :to-equal "pending")
            (expect (minibuffer-prompt-string minibuffer) :to-be nil)
            (expect (loom:minibuffer-message-string minibuffer)
                    :to-equal
                    (format nil "Wrote ~A" path))
            (expect (loom/core/buffer:buffer-modified-p buffer) :to-be nil))))))
  (it
    "does not create parent directories or a file after a negative answer"
    (host-kit:with-temporary-directory (dir)
      (let* ((path (merge-pathnames "nested/deep/new.txt" dir))
             (nested (merge-pathnames "nested/" dir))
             (parent (host-kit:pathname-directory-pathname path)))
        (%with-minibuffer-state (minibuffer "")
          (let* ((buffer (loom/feature/files::%make-file-buffer
                          path
                          :initial-content "pending"))
                 (window (window-tree-selected-window
                          (editor-state-window-tree *editor-state*))))
            (%register-test-buffer *editor-state* buffer)
            (window-set-buffer window buffer)
            (loom/feature/files:save-buffer)
            (expect (minibuffer-prompt-string minibuffer)
                    :to-equal
                    (format nil
                            "Parent directory does not exist. Create it? (y/n): ~A"
                            parent))
            (%confirm-minibuffer minibuffer "n")
            (expect (host-kit:directory-exists-p nested) :to-be nil)
            (expect (host-kit:directory-exists-p parent) :to-be nil)
            (expect (probe-file path) :to-be nil)
            (expect (loom:minibuffer-message-string minibuffer)
                    :to-equal "Save cancelled"))))))
  (it
    "does not create parent directories or a file when the prompt is cancelled"
    (host-kit:with-temporary-directory (dir)
      (let* ((path (merge-pathnames "nested/deep/new.txt" dir))
             (nested (merge-pathnames "nested/" dir))
             (parent (host-kit:pathname-directory-pathname path)))
        (%with-minibuffer-state (minibuffer "")
          (let* ((buffer (loom/feature/files::%make-file-buffer
                          path
                          :initial-content "pending"))
                 (window (window-tree-selected-window
                          (editor-state-window-tree *editor-state*))))
            (%register-test-buffer *editor-state* buffer)
            (window-set-buffer window buffer)
            (loom/feature/files:save-buffer)
            (expect (minibuffer-prompt-string minibuffer)
                    :to-equal
                    (format nil
                            "Parent directory does not exist. Create it? (y/n): ~A"
                            parent))
            (let ((on-cancel
                    (loom/core/minibuffer::%minibuffer-on-cancel minibuffer)))
              (loom/core/minibuffer:minibuffer-deactivate minibuffer)
              (funcall on-cancel))
            (expect (host-kit:directory-exists-p nested) :to-be nil)
            (expect (host-kit:directory-exists-p parent) :to-be nil)
            (expect (probe-file path) :to-be nil)
            (expect (loom:minibuffer-message-string minibuffer)
                    :to-equal "Quit")))))))
