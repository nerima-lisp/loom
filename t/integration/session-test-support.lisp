;;;; t/integration/session-test-support.lisp
;;;;
;;;; Shared helpers for session persistence integration tests.
(in-package #:loom/test)

(defun %session-test-workspace (&key (name "main")
                                      (layout '(:leaf 0 0))
                                      (selected-window-index 0))
  (make-session-workspace-snapshot
   :name name
   :layout layout
   :selected-window-index selected-window-index))

(defun %session-test-snapshot ()
  "Return a small snapshot with every persisted buffer field populated."
  (make-session-snapshot
   :buffers (list
             (make-session-buffer-snapshot
              :name "*scratch*"
              :path nil
              :text (format nil "one~%two")
              :point-line 1
              :point-column 2
              :mark-line 0
              :mark-column 1
              :modified-p t))
   :recent-files (list "one.lisp" "two.lisp")
   :bookmarks (list
               (make-session-bookmark-snapshot
                :name "spot"
                :path "one.lisp"
                :buffer-name "*scratch*"
                :line 1
                :column 2))
   :command-history (list "M-x find-file" "M-x")
   :workspaces (list (%session-test-workspace :layout '(:leaf 0 4)))
   :current-workspace-index 0))
