(in-package #:loom/test)

(describe "editor-state yank reset"
          (it "clears the transient yank tracking slots"
              (let* ((buffer
                      (make-buffer :name "*scratch*" :initial-content "draft"))
                     (state
                      (let ((tree (make-window-tree buffer 80 24)))
                        (make-editor-state :window-tree
                                           tree
                                           :session
                                           (%make-test-editor-session
                                            (list buffer)
                                            :window-tree
                                            tree)))))
                (setf (loom/core/editor-session:editor-state-last-yank-buffer
                       state) buffer
                      (loom/core/editor-session:editor-state-last-yank-start-offset
                       state) 1
                      (loom/core/editor-session:editor-state-last-yank-end-offset
                       state) 3
                      (loom/core/editor-session:editor-state-last-yank-ranges
                       state) '((1 . 3))
                      (loom/core/editor-session:editor-state-last-yank-ring-index
                       state) 2
                      (loom/core/editor-session:editor-state-last-yank-repeat-count
                       state) 4)
                (let ((*editor-state* state))
                  (loom/core/editor-session:editor-state-clear-last-yank state))
                (expect
                 (loom/core/editor-session:editor-state-last-yank-buffer state)
                 :to-be
                 nil)
                (expect
                 (loom/core/editor-session:editor-state-last-yank-start-offset
                  state)
                 :to-be
                 nil)
                (expect
                 (loom/core/editor-session:editor-state-last-yank-end-offset
                  state)
                 :to-be
                 nil)
                (expect
                 (loom/core/editor-session:editor-state-last-yank-ranges state)
                 :to-be
                 nil)
                (expect
                 (loom/core/editor-session:editor-state-last-yank-ring-index
                  state)
                 :to-be
                 nil)
                (expect
                 (loom/core/editor-session:editor-state-last-yank-repeat-count
                  state)
                 :to-be
                 nil))))
