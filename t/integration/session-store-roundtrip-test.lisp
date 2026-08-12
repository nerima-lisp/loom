;;;; t/integration/session-store-roundtrip-test.lisp
;;;;
;;;; Session store round-trip and atomic write tests.
(in-package #:loom/test)

(describe
  "session-store round-trip"
  (it
    "round-trips a validated snapshot through a versioned file"
    (host-kit:with-temporary-directory (directory)
      (let ((path (merge-pathnames "session.sexp" directory))
            (snapshot (%session-test-snapshot)))
        (expect (session-store-write path snapshot) :to-be snapshot)
        (expect (host-kit:path-exists-p path) :to-be-truthy)
        (let ((restored (session-store-read path)))
          (let ((workspace (first (session-snapshot-workspaces restored))))
            (expect (session-workspace-snapshot-layout workspace)
                    :to-equal '(:leaf 0 4))
            (expect (session-workspace-snapshot-selected-window-index workspace)
                    :to-equal 0)
            (expect (session-workspace-snapshot-name workspace)
                    :to-equal "main"))
          (expect (session-snapshot-current-workspace-index restored) :to-equal 0)
          (expect (session-snapshot-recent-files restored)
                  :to-equal '("one.lisp" "two.lisp"))
          (expect (session-snapshot-command-history restored)
                  :to-equal '("M-x find-file" "M-x"))
          (let ((bookmark (first (session-snapshot-bookmarks restored))))
            (expect (session-bookmark-snapshot-name bookmark)
                    :to-equal "spot")
            (expect (session-bookmark-snapshot-path bookmark)
                    :to-equal "one.lisp")
            (expect (session-bookmark-snapshot-line bookmark) :to-equal 1)
            (expect (session-bookmark-snapshot-column bookmark) :to-equal 2))
          (let ((buffer (first (session-snapshot-buffers restored))))
            (expect (session-buffer-snapshot-name buffer)
                    :to-equal "*scratch*")
            (expect (session-buffer-snapshot-text buffer)
                    :to-equal (format nil "one~%two"))
            (expect (session-buffer-snapshot-point-line buffer) :to-equal 1)
            (expect (session-buffer-snapshot-point-column buffer) :to-equal 2)
            (expect (session-buffer-snapshot-mark-line buffer) :to-equal 0)
            (expect (session-buffer-snapshot-mark-column buffer) :to-equal 1)
            (expect (session-buffer-snapshot-modified-p buffer)
                    :to-be-truthy)))))))

  (it
    "round-trips multiple named workspaces and their active view"
    (host-kit:with-temporary-directory (directory)
      (let* ((path (merge-pathnames "workspace-v5.sexp" directory))
             (buffer
               (make-session-buffer-snapshot
                :name "*workspace*"
                :path nil
                :text "text"
                :point-line 0
                :point-column 0
                :mark-line nil
                :mark-column nil
                :modified-p nil))
             (main
               (make-session-workspace-snapshot
                :name "main"
                :layout '(:leaf 0 2)
                :selected-window-index 0))
             (notes
               (make-session-workspace-snapshot
                :name "Notes"
                :layout '(:split :vertical (:leaf 0 1) (:leaf 0 3))
                :selected-window-index 1))
             (snapshot
               (make-session-snapshot
                :buffers (list buffer)
                :recent-files nil
                :bookmarks nil
                :command-history nil
                :workspaces (list main notes)
                :current-workspace-index 1)))
        (session-store-write path snapshot)
        (expect (search ":LOOM-SESSION 5"
                        (string-upcase (host-kit:read-file-string path)))
                :to-be-truthy)
        (let ((restored (session-store-read path)))
          (expect (mapcar #'session-workspace-snapshot-name
                          (session-snapshot-workspaces restored))
                  :to-equal '("main" "Notes"))
          (expect (session-snapshot-current-workspace-index restored) :to-equal 1)
          (let ((restored-notes (second (session-snapshot-workspaces restored))))
            (expect (session-workspace-snapshot-layout restored-notes)
                    :to-equal '(:split :vertical (:leaf 0 1) (:leaf 0 3)))
            (expect (session-workspace-snapshot-selected-window-index restored-notes)
                    :to-equal 1))))))

  (it
    "rejects reader evaluation and malformed session input"
    (host-kit:with-temporary-directory (directory)
      (let ((path (merge-pathnames "unsafe.sexp" directory)))
        (host-kit:write-file-string
         "(:loom-session 5 :buffers () :recent-files () :bookmarks () :command-history () :workspaces ((:name \"main\" :layout (:leaf 0 0) :selected-window-index 0)) :current-workspace-index 0 #.(list))"
         path)
        (signals error (session-store-read path)))))

  (it
    "removes the temporary file when atomic replacement fails"
    (host-kit:with-temporary-directory (directory)
      (let* ((path (merge-pathnames "session.sexp" directory))
             (temporary (merge-pathnames "session.sexp.tmp" directory))
             (snapshot (%session-test-snapshot)))
        (host-kit:write-file-string "previous session" path)
        (with-replaced-function
            (loom/feature/session::%session-temporary-path
             (lambda (target)
               (declare (ignore target))
               temporary))
          (with-replaced-function
              (loom/feature/session::%session-rename
               (lambda (old-path new-path)
                 (declare (ignore old-path new-path))
                 (error "replacement failed")))
            (signals error (session-store-write path snapshot))))
        (expect (probe-file temporary) :to-be nil)
        (expect (host-kit:read-file-string path) :to-equal "previous session"))))
