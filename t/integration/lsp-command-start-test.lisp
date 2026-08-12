(in-package #:loom/test)

(describe
  "LSP commands"
  (it "starts LSP sessions through the command prompt"
    (%with-minibuffer-state (minibuffer "")
      (lsp-start)
      (funcall (loom::%minibuffer-on-confirm minibuffer) " ")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal
              "LSP command cannot be empty"))
    (%with-minibuffer-state (minibuffer "")
      (let* ((transport (make-instance '%fake-lsp-transport))
             (session (make-lsp-session :transport transport)))
        (lsp-session-stop session)
        (with-replaced-function
            (loom/feature/lsp::make-lsp-session
             (lambda (&rest arguments)
               (declare (ignore arguments))
               session))
          (lsp-start)
          (funcall (loom::%minibuffer-on-confirm minibuffer) "closed-server"))
        (expect (loom:minibuffer-message-string minibuffer)
                :to-contain
                "LSP start failed:")
        (expect (%fake-closed-p transport) :to-be-truthy)))
    (%with-minibuffer-state (minibuffer "")
      (let* ((buffer (make-buffer :name "main.lisp"
                                  :path "/tmp/main.lisp"
                                  :initial-content "(+ 1 2)"))
             (window (window-tree-selected-window
                      (editor-state-window-tree *editor-state*)))
             (old-transport (make-instance '%fake-lsp-transport))
             (old-session (make-lsp-session :transport old-transport))
             (new-transport (make-instance '%fake-lsp-transport))
             (original-make-session
               (symbol-function 'loom/feature/lsp::make-lsp-session))
             (new-session nil)
             (captured-arguments nil))
        (unwind-protect
             (progn
               (window-set-buffer window buffer)
               (%register-buffer buffer)
               (setf (editor-state-lsp-session *editor-state*) old-session)
               (with-replaced-function
                   (loom/feature/lsp::make-lsp-session
                    (lambda (&rest arguments)
                      (setf captured-arguments arguments
                            new-session
                            (apply original-make-session
                                   :transport new-transport
                                   arguments))
                      new-session))
                 (lsp-start)
                 (funcall (loom::%minibuffer-on-confirm minibuffer)
                          "fake-server"))
               (expect (editor-state-lsp-session *editor-state*)
                       :to-be
                       new-session)
               (expect (%fake-closed-p old-transport) :to-be-truthy)
               (expect (%fake-closed-p new-transport) :to-be nil)
               (let* ((request
                        (%parse-lsp-json
                         (first (%fake-sent-in-order new-transport))))
                      (params (gethash "params" request)))
                 (expect (gethash "method" request)
                         :to-equal
                         "initialize")
                 (expect (gethash "rootUri" params)
                         :to-equal
                         "file:///tmp/"))
               (expect (getf captured-arguments :root-uri)
                       :to-equal
                       "file:///tmp/")
               (expect (loom:minibuffer-message-string minibuffer)
                       :to-equal
                       "LSP started."))
          (lsp-session-stop old-session)
          (when new-session
            (lsp-session-stop new-session)))))))
