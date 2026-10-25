(in-package #:loom/test)

(describe "editor-state recent files"
  (it "bounds normalized files without mutating the input list"
    (let ((files (list "older" "current" "oldest")))
      (expect (loom/feature/files::%bounded-recent-files "current" files 2)
              :to-equal
              (list "current" "older"))
      (expect files :to-equal (list "older" "current" "oldest"))))

  (it "falls back to the supplied pathname when it is not on disk"
    (let ((path #P"/tmp/loom-path-that-does-not-exist.txt"))
      (expect (editor-path-string path) :to-equal (namestring path))))

  (it "returns no recent files when the configured limit is zero"
    (expect (loom/feature/files::%bounded-recent-files "current" '("older") 0)
            :to-be nil))

  (it "returns nil for a missing path without mutating recent files"
    (let* ((buffer (make-buffer :name "*scratch*" :initial-content "draft"))
           (state (let ((tree (make-window-tree buffer 80 24))) (make-editor-state :window-tree tree :session (%make-test-editor-session (list buffer) :window-tree tree)))))
      (let ((*editor-state* state))
        (expect (remember-recent-file nil) :to-be nil)
        (expect (editor-state-recent-files state) :to-equal nil))))

  (it "prepends normalized paths and deduplicates existing entries"
    (let* ((buffer (make-buffer :name "*scratch*" :initial-content "draft"))
           (state (let ((tree (make-window-tree buffer 80 24))) (make-editor-state :window-tree tree :session (%make-test-editor-session (list buffer) :window-tree tree))))
           (path #P"/tmp/loom-recent.txt")
           (path-string (editor-path-string path)))
      (setf (editor-state-recent-files state) (list "older" path-string "oldest"))
      (let ((*editor-state* state))
        (expect (remember-recent-file path) :to-equal path-string)
        (expect (editor-state-recent-files state)
                :to-equal
                (list path-string "older" "oldest")))))

  (it "enforces the configured recent-file limit"
    (let* ((buffer (make-buffer :name "*scratch*" :initial-content "draft"))
           (state (let ((tree (make-window-tree buffer 80 24))) (make-editor-state :window-tree tree :session (%make-test-editor-session (list buffer) :window-tree tree)))))
      (setf (editor-state-recent-files state) '("third" "fourth"))
      (let ((*editor-state* state)
            (*editor-recent-file-limit* 3))
        (remember-recent-file #P"/tmp/first.txt")
        (remember-recent-file #P"/tmp/second.txt")
        (expect (editor-state-recent-files state)
                :to-equal
                (list (editor-path-string #P"/tmp/second.txt")
                      (editor-path-string #P"/tmp/first.txt")
                      "third"))))))
