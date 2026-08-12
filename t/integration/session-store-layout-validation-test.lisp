;;;; t/integration/session-store-layout-validation-test.lisp
;;;;
;;;; Session snapshot layout validation tests.
(in-package #:loom/test)

(describe
  "session-store snapshot layout validation"
  (it
    "rejects malformed layouts and selected window indexes"
    (let ((buffer (make-session-buffer-snapshot
                   :name "*layout*"
                   :path nil
                   :text ""
                   :point-line 0
                   :point-column 0
                   :mark-line nil
                   :mark-column nil
                   :modified-p nil)))
      (flet ((snapshot (layout &optional (selected-index 0))
               (make-session-snapshot
                :buffers (list buffer)
                :recent-files nil
                :bookmarks nil
                :command-history nil
                :workspaces (list (%session-test-workspace
                                   :layout layout
                                   :selected-window-index selected-index))
                :current-workspace-index 0)))
        (signals error (validate-session-snapshot
                        (snapshot "not a list")))
        (signals error (validate-session-snapshot
                        (snapshot nil)))
        (signals error (validate-session-snapshot
                        (snapshot '(:leaf 0))))
        (signals error (validate-session-snapshot
                        (snapshot '(:leaf 1 0))))
        (signals error (validate-session-snapshot
                        (snapshot '(:leaf 0 -1))))
        (signals error (validate-session-snapshot
                        (snapshot '(:split :diagonal
                                    (:leaf 0 0)
                                    (:leaf 0 0)))))
        (signals error (validate-session-snapshot
                        (snapshot '(:split :horizontal (:leaf 0 0)))))
        (signals error (validate-session-snapshot
                        (snapshot '(:split :horizontal
                                    (:leaf 0 0)
                                    (:unknown)))))
        (signals error (validate-session-snapshot
                        (snapshot '(:split :horizontal
                                    42
                                    (:leaf 0 0)))))
        (signals error (validate-session-snapshot
                        (snapshot '(:leaf 0 0) -1)))
        (signals error (validate-session-snapshot
                        (snapshot '(:leaf 0 0) 1)))
        (signals error
                 (validate-session-snapshot
                  (make-session-snapshot
                   :buffers (list buffer)
                   :recent-files nil
                   :bookmarks nil
                   :command-history nil
                   :workspaces (list (%session-test-workspace
                                      :layout '(:split :horizontal
                                                (:leaf 0 0)
                                                (:leaf 0 0))
                                      :selected-window-index 2))
                   :current-workspace-index 0)))))))
