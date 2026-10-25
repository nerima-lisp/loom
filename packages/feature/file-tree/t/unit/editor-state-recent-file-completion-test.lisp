(in-package #:loom/test)

(describe "editor-state recent files"
  (it "returns a copy of recent files for completion"
    (let* ((buffer (make-buffer :name "*scratch*" :initial-content "draft"))
           (state (let ((tree (make-window-tree buffer 80 24)))
                    (make-editor-state :window-tree tree
                                       :session (%make-test-editor-session
                                                 (list buffer)
                                                 :window-tree tree))))
           (files (list "one.lisp" "two.lisp")))
      (setf (editor-state-recent-files state) files)
      (let ((*editor-state* state))
        (let ((candidates
                (loom/feature/files::%recent-file-candidates "")))
          (expect candidates :to-equal files)
          (expect candidates :not :to-be files))))))
