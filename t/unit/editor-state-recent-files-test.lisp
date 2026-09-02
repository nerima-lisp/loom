;;;; t/unit/editor-state-recent-files-test.lisp
;;;;
;;;; Recent-file tracking and transient yank-reset coverage for editor state.
(in-package #:loom/test)

(describe "editor bookmarks"
  (it "stores bookmark metadata without adapting its representation"
    (let ((bookmark (loom::make-editor-bookmark
                     :name "top"
                     :buffer :buffer
                     :path #P"/tmp/notes.txt"
                     :buffer-name "notes.txt"
                     :line 4
                     :column 2)))
      (expect (loom::editor-bookmark-name bookmark) :to-equal "top")
      (expect (loom::editor-bookmark-buffer bookmark) :to-be :buffer)
      (expect (loom::editor-bookmark-path bookmark) :to-equal #P"/tmp/notes.txt")
      (expect (loom::editor-bookmark-buffer-name bookmark) :to-equal "notes.txt")
      (expect (loom::editor-bookmark-line bookmark) :to-equal 4)
      (expect (loom::editor-bookmark-column bookmark) :to-equal 2))))

(describe "editor-state recent files"
  (it "returns a copy of recent files for completion"
    (let* ((buffer (make-buffer :name "*scratch*" :initial-content "draft"))
           (state (make-editor-state :window-tree (make-window-tree buffer 80 24)))
           (files (list "one.lisp" "two.lisp")))
      (setf (editor-state-recent-files state) files)
      (let ((*editor-state* state))
        (let ((candidates (loom/feature/file-tree::%recent-file-candidates "")))
          (expect candidates :to-equal files)
          (expect candidates :not :to-be files)))))

  (it "bounds normalized files without mutating the input list"
    (let ((files (list "older" "current" "oldest")))
      (expect (loom::%bounded-recent-files "current" files 2)
              :to-equal
              (list "current" "older"))
      (expect files :to-equal (list "older" "current" "oldest"))))

  (it "falls back to the supplied pathname when it is not on disk"
    (let ((path #P"/tmp/loom-path-that-does-not-exist.txt"))
      (expect (editor-path-string path) :to-equal (namestring path))))

  (it "returns no recent files when the configured limit is zero"
    (expect (loom::%bounded-recent-files "current" '("older") 0)
            :to-be nil))

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
