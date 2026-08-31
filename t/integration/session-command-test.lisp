;;;; t/integration/session-command-test.lisp
;;;;
;;;; Session persistence tests cover the public save/load commands.
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
    "reject empty save and load paths through the minibuffer"
    (%with-minibuffer-state (minibuffer "")
      (save-session)
      (%expect-minibuffer-prompt minibuffer (%save-session-prompt-string))
      (funcall (loom::%minibuffer-on-confirm minibuffer) "  ")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Session path cannot be empty")
      (load-session)
      (%expect-minibuffer-prompt minibuffer (%load-session-prompt-string))
      (funcall (loom::%minibuffer-on-confirm minibuffer) " ")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Session path cannot be empty")))

  (it
    "saves and loads a session through the public commands"
    (host-kit:with-temporary-directory (directory)
      (let ((path (namestring (merge-pathnames "session.sexp" directory))))
        (%with-minibuffer-state (minibuffer "")
          (save-session)
          (funcall (loom::%minibuffer-on-confirm minibuffer) path)
          (expect (loom:minibuffer-message-string minibuffer)
                  :to-equal (format nil "Session saved: ~A" path))
          (expect (host-kit:path-exists-p path) :to-be-truthy)
          (load-session)
          (funcall (loom::%minibuffer-on-confirm minibuffer) path)
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
            (funcall (loom::%minibuffer-on-confirm minibuffer) path)
            (expect (loom:minibuffer-message-string minibuffer)
                    :to-contain "Could not save session:")
            (load-session)
            (funcall (loom::%minibuffer-on-confirm minibuffer) path)
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
        (expect (loom:minibuffer-message-string minibuffer) :to-equal "Quit")))))
