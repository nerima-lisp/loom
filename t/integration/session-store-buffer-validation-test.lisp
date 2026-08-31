;;;; t/integration/session-store-buffer-validation-test.lisp
;;;;
;;;; Session snapshot buffer validation tests.
(in-package #:loom/test)

(describe
  "session-store snapshot buffer validation"
  (it
    "accepts unmodified buffers without a mark"
    (let* ((buffer (make-session-buffer-snapshot
                    :name "*unmodified*"
                    :path "unmodified.txt"
                    :text ""
                    :point-line 0
                    :point-column 0
                    :mark-line nil
                    :mark-column nil
                    :modified-p nil))
           (snapshot (make-session-snapshot
                      :buffers (list buffer)
                      :recent-files nil
                      :bookmarks nil
                      :command-history nil
                      :workspaces (list (%session-test-workspace))
                      :current-workspace-index 0)))
      (expect (validate-session-snapshot snapshot) :to-be snapshot)))

  (it
    "rejects malformed snapshot envelopes and buffer values"
    (flet ((buffer (&key (name "*buffer*")
                         (path nil)
                         (text "text")
                         (point-line 0)
                         (point-column 0)
                         (mark-line nil)
                         (mark-column nil)
                         (modified-p nil))
             (make-session-buffer-snapshot
              :name name
              :path path
              :text text
              :point-line point-line
              :point-column point-column
              :mark-line mark-line
              :mark-column mark-column
              :modified-p modified-p)))
      (flet ((snapshot (value &key (recent-files nil)
                                      (bookmarks nil)
                                      (command-history nil)
                                      (layout '(:leaf 0 0))
                                      (selected-index 0))
               (make-session-snapshot
                :buffers (list value)
                :recent-files recent-files
                :bookmarks bookmarks
                :command-history command-history
                :workspaces (list (%session-test-workspace
                                   :layout layout
                                   :selected-window-index selected-index))
                :current-workspace-index 0)))
        (signals error (validate-session-snapshot nil))
        (signals error
                 (validate-session-snapshot
                  (make-session-snapshot
                   :buffers nil
                   :recent-files nil
                   :bookmarks nil
                   :command-history nil
                   :workspaces (list (%session-test-workspace))
                   :current-workspace-index 0)))
        (signals error
                 (validate-session-snapshot
                  (snapshot "not a buffer")))
        (signals error (validate-session-snapshot
                        (snapshot (buffer :name nil))))
        (signals error (validate-session-snapshot
                        (snapshot (buffer :path 42))))
        (signals error (validate-session-snapshot
                        (snapshot (buffer :text nil))))
        (signals error (validate-session-snapshot
                        (snapshot (buffer :point-line -1))))
        (signals error (validate-session-snapshot
                        (snapshot (buffer :point-column -1))))
        (signals error (validate-session-snapshot
                        (snapshot (buffer :mark-line 0))))
        (signals error (validate-session-snapshot
                        (snapshot (buffer :mark-line 0 :mark-column nil))))
        (signals error (validate-session-snapshot
                        (snapshot (buffer :mark-line -1 :mark-column 0))))
        (signals error (validate-session-snapshot
                        (snapshot (buffer :mark-line nil :mark-column 0))))
        (signals error (validate-session-snapshot
                        (snapshot (buffer :modified-p :maybe))))
        (signals error
                 (validate-session-snapshot
                  (snapshot (buffer) :recent-files (list 42))))
        (signals error
                 (validate-session-snapshot
                  (snapshot
                   (buffer)
                   :bookmarks
                   (list (make-session-bookmark-snapshot
                          :name ""
                          :path nil
                          :buffer-name nil
                          :line 0
                          :column 0)))))
        (signals error
                 (validate-session-snapshot
                  (snapshot (buffer) :command-history (list "ok" 42))))))))

  (it
    "rejects malformed optional bookmark and workspace fields"
    (let ((snapshot (%session-test-snapshot)))
      (dolist (bookmark-case
                (list
                 (make-session-bookmark-snapshot
                  :name nil :path nil :buffer-name nil :line 0 :column 0)
                 (make-session-bookmark-snapshot
                  :name "spot" :path 42 :buffer-name nil :line 0 :column 0)
                 (make-session-bookmark-snapshot
                  :name "spot" :path nil :buffer-name 42 :line 0 :column 0)
                 (make-session-bookmark-snapshot
                  :name "spot" :path nil :buffer-name nil :line -1 :column 0)
                 (make-session-bookmark-snapshot
                  :name "spot" :path nil :buffer-name nil :line 0 :column -1)))
        (setf (session-snapshot-bookmarks snapshot) (list bookmark-case))
        (signals error (validate-session-snapshot snapshot)))
      (dolist (workspace-case
                (list
                 (%session-test-workspace :name nil)
                 (%session-test-workspace :name "")
                 (%session-test-workspace :layout nil)
                 (%session-test-workspace :selected-window-index -1)))
        (setf (session-snapshot-workspaces snapshot) (list workspace-case))
        (signals error (validate-session-snapshot snapshot)))
      (setf (session-snapshot-workspaces snapshot)
            (list (%session-test-workspace :name "Main")
                  (%session-test-workspace :name "main")))
      (signals error (validate-session-snapshot snapshot))
      (setf (session-snapshot-workspaces snapshot)
            (list (%session-test-workspace)))
      (dolist (index '(-1 1))
        (setf (session-snapshot-current-workspace-index snapshot) index)
        (signals error (validate-session-snapshot snapshot)))))
