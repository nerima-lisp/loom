(in-package #:loom/test)

(defun %make-editor-session-api-fixture (&key (width 4) (height 3))
  (let* ((buffer (make-buffer :name "*editor-session-api-test*"))
         (window-tree (loom/core/window-tree:make-window-tree buffer width height))
         (session
           (loom/core/editor-session:make-editor-session
            '(:core/window-tree)
            :initial-slices (list (cons :core/window-tree window-tree))))
         (window
           (loom/core/window-tree:window-tree-selected-window window-tree))
         (position
           (loom/core/buffer:buffer-visible-offset-position buffer 0)))
    (values session window buffer position window-tree)))

(progn
  (describe "editor-session hit-test API"
            (it
             "exports bound hit-test and clipboard functions and the opaque result type"
             (let ((package (find-package :loom/core/editor-session)))
               (dolist (name
                        '("HIT-TEST-COORDINATE"
                          "REGISTER-HIT-TEST-PROVIDER"
                          "MAKE-HIT-TEST-RESULT"
                          "HIT-TEST-RESULT-P"
                          "HIT-TEST-RESULT-OWNER"
                          "HIT-TEST-RESULT-KIND"
                          "HIT-TEST-RESULT-WINDOW"
                          "HIT-TEST-RESULT-BUFFER"
                          "HIT-TEST-RESULT-POSITION"
                          "HIT-TEST-RESULT-TARGET"
                          "HIT-TEST-BUFFER-POSITION"
                          "REQUEST-TERMINAL-CLIPBOARD-WRITE"
                          "DRAIN-TERMINAL-CLIPBOARD-REQUESTS"))
                 (multiple-value-bind (symbol status)
                     (find-symbol name package)
                   (expect symbol :to-be-truthy)
                   (expect status :to-be :external)
                   (expect (fboundp symbol) :to-be-truthy)))
               (multiple-value-bind (symbol status)
                   (find-symbol "HIT-TEST-RESULT" package)
                 (expect status :to-be :external)
                 (expect (find-class symbol nil) :to-be-truthy))))
            (it
             "constructs results for each hit kind and exposes their payload"
             (multiple-value-bind (session window buffer position)
                 (%make-editor-session-api-fixture)
               (declare (ignore session))
               (let ((buffer-result
                       (loom/core/editor-session:make-hit-test-result
                        :core/presentation :buffer-text
                        :window window :buffer buffer :position position))
                     (blank-result
                       (loom/core/editor-session:make-hit-test-result
                        :core/presentation :window-blank :window window))
                     (mode-line-result
                       (loom/core/editor-session:make-hit-test-result
                        :core/presentation :mode-line :window window))
                     (feature-target (gensym "FILE-TREE-ENTRY-")))
                 (expect
                  (list
                   (loom/core/editor-session:hit-test-result-owner buffer-result)
                   (loom/core/editor-session:hit-test-result-kind buffer-result)
                   (loom/core/editor-session:hit-test-result-window buffer-result)
                   (loom/core/editor-session:hit-test-result-buffer buffer-result)
                   (loom/core/editor-session:hit-test-result-position buffer-result)
                   (loom/core/editor-session:hit-test-result-target buffer-result))
                  :to-equal
                  (list :core/presentation :buffer-text window buffer position nil))
                 (expect
                  (list
                   (loom/core/editor-session:hit-test-result-kind blank-result)
                   (loom/core/editor-session:hit-test-result-window blank-result)
                   (loom/core/editor-session:hit-test-result-buffer blank-result)
                   (loom/core/editor-session:hit-test-result-position blank-result)
                   (loom/core/editor-session:hit-test-result-target blank-result))
                  :to-equal
                  (list :window-blank window nil nil nil))
                 (expect
                  (loom/core/editor-session:hit-test-result-kind mode-line-result)
                  :to-be
                  :mode-line)
                 (let ((feature-result
                         (loom/core/editor-session:make-hit-test-result
                          :feature/file-tree :feature-item :target feature-target)))
                   (expect
                    (list
                     (loom/core/editor-session:hit-test-result-owner feature-result)
                     (loom/core/editor-session:hit-test-result-target feature-result))
                    :to-equal
                    (list :feature/file-tree feature-target)))))
            (it "rejects hit kinds with missing or unrelated payload"
                (multiple-value-bind (session window buffer position)
                    (%make-editor-session-api-fixture)
                  (declare (ignore session))
                  (signals error
                           (loom/core/editor-session:make-hit-test-result
                            :core/presentation :unknown))
                  (signals error
                           (loom/core/editor-session:make-hit-test-result
                            :core/presentation :buffer-text
                            :window window :buffer buffer))
                  (signals error
                           (loom/core/editor-session:make-hit-test-result
                            :core/presentation :window-blank))
                  (signals error
                           (loom/core/editor-session:make-hit-test-result
                            :core/presentation :mode-line
                            :window window :position position))
                  (signals error
                           (loom/core/editor-session:make-hit-test-result
                            :feature/file-tree :feature-item))
                  (signals error
                           (loom/core/editor-session:make-hit-test-result
                            "core/presentation" :window-blank :window window))))))
  (describe "hit-test provider dispatch"
            (it
             "uses descending priority and preserves registration order for ties"
             (let* ((loom/core/editor-session::*hit-test-providers* nil)
                    (loom/core/editor-session::*next-hit-test-provider-order* 0)
                    (events nil))
               (multiple-value-bind (session window buffer position)
                   (%make-editor-session-api-fixture)
                 (declare (ignore window buffer position))
                 (let ((result
                         (loom/core/editor-session:make-hit-test-result
                          :feature/test :feature-item :target :selected)))
                   (loom/core/editor-session:register-hit-test-provider
                    :feature/test 10
                    (lambda (received-session x y)
                      (declare (ignore received-session x y))
                      (push :tie-first events)
                      nil))
                   (loom/core/editor-session:register-hit-test-provider
                    :feature/test 0
                    (lambda (received-session x y)
                      (declare (ignore received-session x y))
                      (push :low events)
                      result))
                   (loom/core/editor-session:register-hit-test-provider
                    :feature/test 20
                    (lambda (received-session x y)
                      (declare (ignore received-session x y))
                      (push :high events)
                      nil))
                   (loom/core/editor-session:register-hit-test-provider
                    :feature/test 10
                    (lambda (received-session x y)
                      (declare (ignore received-session x y))
                      (push :tie-winner events)
                      result))
                   (expect
                    (loom/core/editor-session:hit-test-coordinate session 1 1)
                    :to-be
                    result)
                   (expect (nreverse events)
                           :to-equal
                           '(:high :tie-first :tie-winner)))))
            (it "rejects provider results owned by another provider"
                (let* ((loom/core/editor-session::*hit-test-providers* nil)
                       (loom/core/editor-session::*next-hit-test-provider-order* 0))
                  (multiple-value-bind (session window buffer position)
                      (%make-editor-session-api-fixture)
                    (declare (ignore window buffer position))
                    (loom/core/editor-session:register-hit-test-provider
                     :feature/test 0
                     (lambda (received-session x y)
                       (declare (ignore received-session x y))
                       (loom/core/editor-session:make-hit-test-result
                        :feature/other :feature-item :target :wrong-owner)))
                    (signals error
                             (loom/core/editor-session:hit-test-coordinate
                              session 0 0)))))
            (it "rejects invalid coordinates and skips providers outside the frame"
                (let* ((loom/core/editor-session::*hit-test-providers* nil)
                       (loom/core/editor-session::*next-hit-test-provider-order* 0)
                       (calls 0))
                  (multiple-value-bind (session window buffer position tree)
                      (%make-editor-session-api-fixture :width 4 :height 3)
                    (declare (ignore window buffer position))
                    (loom/core/editor-session:register-hit-test-provider
                     :feature/test 0
                     (lambda (received-session x y)
                       (declare (ignore received-session x y))
                       (incf calls)
                       nil))
                    (expect
                     (loom/core/editor-session:hit-test-coordinate
                      session (loom/core/window-tree:window-tree-width tree) 0)
                     :to-be
                     nil)
                    (expect
                     (loom/core/editor-session:hit-test-coordinate
                      session 0 (loom/core/window-tree:window-tree-height tree))
                     :to-be
                     nil)
                    (expect
                     (loom/core/editor-session:hit-test-coordinate session -1 0)
                     :to-be
                     nil)
                    (expect calls :to-equal 0)
                    (signals error
                             (loom/core/editor-session:hit-test-coordinate
                              session 0 1.5)))))
            (it
             "returns buffer coordinates only through the compatibility wrapper"
             (let* ((loom/core/editor-session::*hit-test-providers* nil)
                    (loom/core/editor-session::*next-hit-test-provider-order* 0))
               (multiple-value-bind (session window buffer position)
                   (%make-editor-session-api-fixture)
                 (let ((result
                         (loom/core/editor-session:make-hit-test-result
                          :core/presentation :buffer-text
                          :window window :buffer buffer :position position)))
                   (loom/core/editor-session:register-hit-test-provider
                    :core/presentation 0
                    (lambda (received-session x y)
                      (declare (ignore received-session x y))
                      result))
                   (expect
                    (multiple-value-list
                     (loom/core/editor-session:hit-test-buffer-position
                      session 0 0))
                    :to-equal
                    (list window buffer position))
                   (setf loom/core/editor-session::*hit-test-providers* nil)
                   (loom/core/editor-session:register-hit-test-provider
                    :feature/file-tree 1
                    (lambda (received-session x y)
                      (declare (ignore received-session x y))
                      (loom/core/editor-session:make-hit-test-result
                       :feature/file-tree :feature-item :target :entry-id)))
                   (expect
                    (multiple-value-list
                     (loom/core/editor-session:hit-test-buffer-position
                      session 0 0))
                    :to-equal
                    nil))))))
  )
  (describe "terminal clipboard requests"
            (it "drains copied text in FIFO order, once, and per session"
                (let* ((loom/core/editor-session::*terminal-clipboard-requests*
                        (make-hash-table :test #'eq))
                       (session (nth-value 0 (%make-editor-session-api-fixture)))
                       (other-session
                         (nth-value 0 (%make-editor-session-api-fixture)))
                       (source-text (copy-seq "first")))
                  (expect
                   (loom/core/editor-session:request-terminal-clipboard-write
                    session source-text)
                   :to-be
                   :queued)
                  (setf (char source-text 0) #\X)
                  (loom/core/editor-session:request-terminal-clipboard-write
                   session "second")
                  (loom/core/editor-session:request-terminal-clipboard-write
                   other-session "other")
                  (expect
                   (loom/core/editor-session:drain-terminal-clipboard-requests
                    session)
                   :to-equal
                   '("first" "second"))
                  (expect
                   (loom/core/editor-session:drain-terminal-clipboard-requests
                    session)
                   :to-be
                   nil)
                  (expect
                   (loom/core/editor-session:drain-terminal-clipboard-requests
                    other-session)
                   :to-equal
                   '("other"))
                  (loom/core/editor-session:request-terminal-clipboard-write
                   session "after-drain")
                  (expect
                   (loom/core/editor-session:drain-terminal-clipboard-requests
                    session)
                   :to-equal
                   '("after-drain"))
                  (signals error
                           (loom/core/editor-session:request-terminal-clipboard-write
                            session 42))
                  (signals error
                           (loom/core/editor-session:drain-terminal-clipboard-requests
                            :not-a-session)))))
  )
