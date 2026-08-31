;;;; t/unit/editor-state-recent-files-test.lisp
;;;;
;;;; Recent-file tracking and transient yank-reset coverage for editor state.
(in-package #:loom/test)

(describe "editor-state recent files"
  (it "bounds normalized files without mutating the input list"
    (let ((files (list "older" "current" "oldest")))
      (expect (loom::%bounded-recent-files "current" files 2)
              :to-equal
              (list "current" "older"))
      (expect files :to-equal (list "older" "current" "oldest"))))

  (it "returns nil for a missing path without mutating recent files"
    (let* ((buffer (make-buffer :name "*scratch*" :initial-content "draft"))
           (state (make-editor-state :window-tree (make-window-tree buffer 80 24))))
      (let ((*editor-state* state))
        (expect (remember-recent-file nil) :to-be nil)
        (expect (editor-state-recent-files state) :to-equal nil))))

  (it "prepends normalized paths and deduplicates existing entries"
    (let* ((buffer (make-buffer :name "*scratch*" :initial-content "draft"))
           (state (make-editor-state :window-tree (make-window-tree buffer 80 24)))
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
           (state (make-editor-state :window-tree (make-window-tree buffer 80 24))))
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

(describe "editor-state yank reset"
  (it "clears the transient yank tracking slots"
    (let* ((buffer (make-buffer :name "*scratch*" :initial-content "draft"))
           (state (make-editor-state :window-tree (make-window-tree buffer 80 24))))
      (setf (loom::editor-state-last-yank-buffer state) buffer
            (loom::editor-state-last-yank-start-offset state) 1
            (loom::editor-state-last-yank-end-offset state) 3
            (editor-state-last-yank-ranges state) '((1 . 3))
            (loom::editor-state-last-yank-ring-index state) 2
            (loom::editor-state-last-yank-repeat-count state) 4)
      (let ((*editor-state* state))
        (loom::%clear-last-yank))
      (expect (loom::editor-state-last-yank-buffer state) :to-be nil)
      (expect (loom::editor-state-last-yank-start-offset state) :to-be nil)
      (expect (loom::editor-state-last-yank-end-offset state) :to-be nil)
      (expect (editor-state-last-yank-ranges state) :to-be nil)
      (expect (loom::editor-state-last-yank-ring-index state) :to-be nil)
      (expect (loom::editor-state-last-yank-repeat-count state) :to-be nil))))
