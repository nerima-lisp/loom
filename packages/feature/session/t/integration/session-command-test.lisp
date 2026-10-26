(in-package #:loom/test)

(describe
  "session commands"
  (it
    "recognizes session path values by content"
    (dolist (case (list (list nil nil)
                        (list (concatenate 'string "  " (string #\Tab)) nil)
                        (list "session.sexp" t)))
      (destructuring-bind (path expected) case
        (if expected
            (expect (loom/feature/session::%session-path-present-p path)
                    :to-be t)
            (expect (loom/feature/session::%session-path-present-p path)
                    :to-be-falsy)))))
  (it
    "keeps load-session available through M-x"
    (let ((spec (loom/core/command:find-command-spec "load-session")))
      (expect (loom/core/command:command-spec-name spec)
              :to-equal "load-session")
      (expect (member "load-session"
                      (loom/core/command:command-completion-names "")
                      :test (function string-equal))
              :to-be-truthy)))

  (it
    "reject empty save and load paths through the minibuffer"
    (%with-minibuffer-state (minibuffer "")
      (save-session)
      (%expect-minibuffer-prompt minibuffer (%save-session-prompt-string))
      (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "  ")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Session path cannot be empty")
      (load-session)
      (%expect-minibuffer-prompt minibuffer (%load-session-prompt-string))
      (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) " ")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Session path cannot be empty")))

  (it
    "saves and loads a session through the public commands"
    (host-kit:with-temporary-directory (directory)
      (let ((path (namestring (merge-pathnames "session.sexp" directory))))
        (%with-minibuffer-state (minibuffer "")
          (save-session)
          (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) path)
          (expect (loom:minibuffer-message-string minibuffer)
                  :to-equal (format nil "Session saved: ~A" path))
          (expect (host-kit:path-exists-p path) :to-be-truthy)
          (load-session)
          (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) path)
          (expect (loom:minibuffer-message-string minibuffer)
                  :to-equal (format nil "Session loaded: ~A" path))))))

  (it
    "reports save and load failures without replacing editor state"
    (host-kit:with-temporary-directory (directory)
      (let ((path (namestring
                   (merge-pathnames "missing/session.sexp" directory))))
        (%with-minibuffer-state (minibuffer "")
          (let ((original (buffer-text (%selected-test-buffer))))
            (save-session)
            (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) path)
            (expect (loom:minibuffer-message-string minibuffer)
                    :to-contain "Could not save session:")
            (load-session)
            (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) path)
            (expect (loom:minibuffer-message-string minibuffer)
                    :to-contain "Could not load session:")
              (expect (buffer-text (%selected-test-buffer)) :to-equal original))))))

  (describe
    "session command cancellation"
    (it
      "cancels save and load prompts through a real C-g event"
      (%with-minibuffer-state (minibuffer "")
        (save-session)
        (minibuffer-handle-key minibuffer (%special-key :control-g))
        (expect (loom:minibuffer-message-string minibuffer) :to-equal "Quit")
        (load-session)
        (minibuffer-handle-key minibuffer (%special-key :control-g))
        (expect (loom:minibuffer-message-string minibuffer) :to-equal "Quit"))))
  (it
    "reports when a loaded session has a missing file-tree root"
    (host-kit:with-temporary-directory (directory)
      (let* ((path (namestring (merge-pathnames "session.sexp" directory)))
             (stale-root (merge-pathnames "missing/" directory))
             (snapshot (%session-test-snapshot)))
        (setf (session-snapshot-file-tree snapshot)
              (make-session-file-tree-snapshot
               :root-path (namestring stale-root)
               :visible-p t
               :expanded-paths
               (list (namestring (merge-pathnames "src/" stale-root)))
               :selected-path
               (namestring (merge-pathnames "src/main.lisp" stale-root))))
        (with-replaced-function
            (loom/feature/session:session-store-read
             (lambda (stored-path)
               (declare (ignore stored-path))
               snapshot))
          (%with-minibuffer-state (minibuffer "")
            (load-session)
            (funcall
             (loom/core/minibuffer::%minibuffer-on-confirm minibuffer)
             path)
            (expect (loom:minibuffer-message-string minibuffer)
                    :to-equal
                    (format nil
                            "Session loaded with warning: File-tree root not found: ~A"
                            (namestring stale-root)))
            (expect (length (%test-registered-buffers *editor-state*))
                    :to-equal 1)))))))
