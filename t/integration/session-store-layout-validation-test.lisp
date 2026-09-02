;;;; t/integration/session-store-layout-validation-test.lisp
;;;;
;;;; Session snapshot layout validation tests.
(in-package #:loom/test)

(describe
  "session-store snapshot layout validation"
  (it
    "keeps every generated codec shape round-trippable"
    (dolist (codec
              (list
               (list #'loom/feature/session::%session-sexp-buffer
                     #'loom/feature/session::%session-buffer-from-sexp
                     (make-session-buffer-snapshot
                      :name "*buffer*" :path "buffer.lisp" :text "text"
                      :point-line 1 :point-column 2 :mark-line 0
                      :mark-column 1 :modified-p t))
               (list #'loom/feature/session::%session-sexp-bookmark
                     #'loom/feature/session::%session-bookmark-from-sexp
                     (make-session-bookmark-snapshot
                      :name "bookmark" :path "buffer.lisp"
                      :buffer-name "*buffer*" :line 1 :column 2))
               (list #'loom/feature/session::%session-sexp-workspace
                     #'loom/feature/session::%session-workspace-from-sexp
                     (make-session-workspace-snapshot
                      :name "main" :layout '(:leaf 0 1)
                      :selected-window-index 0))))
      (destructuring-bind (serializer reader object) codec
        (let ((serialized (funcall serializer object)))
          (expect serialized :to-be-truthy)
          (expect (funcall serializer (funcall reader serialized))
                  :to-equal serialized)))))

  (it
    "rejects malformed generated plist codec declarations"
    (signals error
             (macroexpand-1
              '(loom/feature/session::define-session-plist-codec
                42
                make-session-buffer-snapshot
                (:name session-buffer-snapshot-name))))
    (signals error
             (macroexpand-1
              '(loom/feature/session::define-session-plist-codec
                temporary
                42
                (:name session-buffer-snapshot-name))))
    (signals error
             (macroexpand-1
              '(loom/feature/session::define-session-plist-codec
                temporary
                make-session-buffer-snapshot
                (:name))))
    (signals error
             (macroexpand-1
              '(loom/feature/session::define-session-plist-codec
                temporary
                make-session-buffer-snapshot
                42)))
    (signals error
             (macroexpand-1
              '(loom/feature/session::define-session-plist-codec
                temporary
                make-session-buffer-snapshot
                (:name 42))))
    (signals error
             (macroexpand-1
              '(loom/feature/session::define-session-plist-codec
                temporary
                make-session-buffer-snapshot
                (name session-buffer-snapshot-name)))))
  (it
    "rejects malformed fixed-shape session plists"
    (dolist (value
              (list
               nil
               '(:name)
               '(:name . "buffer")
               '(:name "buffer" 42 "path")
               '(:name "buffer" :unexpected "path")
               '(:name "buffer" :name "duplicate")))
      (signals error
               (loom/feature/session::%validate-session-plist
                value '(:name :path) "test")))
    (expect (handler-case
                (loom/feature/session::%validate-session-plist
                 '(:name . "buffer") '(:name :path) "test")
              (error (condition) (princ-to-string condition)))
            :to-contain "expected a keyword plist"))
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

  (it
    "accepts nested layouts and every persisted metadata collection"
    (let* ((buffer (make-session-buffer-snapshot
                    :name "*layout*"
                    :path "layout.lisp"
                    :text "text"
                    :point-line 0
                    :point-column 0
                    :mark-line 0
                    :mark-column 0
                    :modified-p t))
           (snapshot (make-session-snapshot
                      :buffers (list buffer)
                      :recent-files (list "layout.lisp")
                      :bookmarks (list
                                  (make-session-bookmark-snapshot
                                   :name "spot"
                                   :path "layout.lisp"
                                   :buffer-name "*layout*"
                                   :line 0
                                   :column 0))
                      :command-history (list "M-x find-file")
                      :workspaces (list
                                   (%session-test-workspace
                                    :layout '(:split :vertical
                                              (:leaf 0 0)
                                              (:split :horizontal
                                                       (:leaf 0 0)
                                                       (:leaf 0 0)))
                                    :selected-window-index 2))
                      :current-workspace-index 0)))
      (expect (validate-session-snapshot snapshot) :to-be snapshot)))

  (it
    "rejects duplicate metadata names using their documented comparison rules"
    (let ((snapshot (%session-test-snapshot)))
      (setf (session-snapshot-bookmarks snapshot)
            (list (make-session-bookmark-snapshot
                   :name "spot" :path nil :buffer-name nil :line 0 :column 0)
                  (make-session-bookmark-snapshot
                   :name "spot" :path nil :buffer-name nil :line 0 :column 0)))
      (signals error (validate-session-snapshot snapshot))))
