(in-package #:loom/test)

(describe
  "LSP commands"
  (it "starts LSP sessions through the command prompt"
    (%with-lsp-minibuffer-state (minibuffer "")
      (lsp-start)
      (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) " ")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal
              "LSP command cannot be empty"))
    (%with-lsp-minibuffer-state (minibuffer "")
      (let* ((transport (make-instance '%fake-lsp-transport))
             (session (make-lsp-session :transport transport)))
        (lsp-session-stop session)
        (with-replaced-function
            (loom/feature/lsp::make-lsp-session
             (lambda (&rest arguments)
               (declare (ignore arguments))
               session))
          (lsp-start)
          (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "closed-server"))
        (expect (loom:minibuffer-message-string minibuffer)
                :to-contain
                "LSP start failed:")
        (expect (%fake-closed-p transport) :to-be-truthy)))
    (%with-lsp-minibuffer-state (minibuffer "")
      (let* ((buffer (make-buffer :name "main.lisp"
                                  :path "/tmp/main.lisp"
                                  :initial-content "(+ 1 2)"))
             (window (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*)))
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
               (%register-test-buffer *editor-state* buffer)
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
                 (progn (%fake-push-initialize-response new-transport) (lsp-start))
                 (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer)
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

(describe
  "LSP command replacement failures"
  (it "keeps the existing session when construction fails"
    (%with-lsp-minibuffer-state (minibuffer "")
      (%with-initialized-fake-lsp-session ((old-transport old-session))
        (setf (editor-state-lsp-session *editor-state*) old-session)
        (with-replaced-function
            (loom/feature/lsp::make-lsp-session
             (lambda (&rest arguments)
               (declare (ignore arguments))
               (error "constructor failed")))
          (lsp-start)
          (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "fake-server"))
        (expect (editor-state-lsp-session *editor-state*) :to-be old-session)
        (expect (loom/feature/lsp::lsp-session-closed-p old-session) :to-be nil)
        (expect (%fake-closed-p old-transport) :to-be nil)
        (expect (%fake-sent-in-order old-transport) :to-have-length 2)
        (expect (loom:minibuffer-message-string minibuffer)
                :to-equal "LSP start failed: constructor failed"))))

  (it "keeps the existing session and closes the new one when initialize send fails"
    (%with-lsp-minibuffer-state (minibuffer "")
      (%with-initialized-fake-lsp-session ((old-transport old-session))
        (%with-fake-lsp-session ((new-transport new-session))
          (setf (editor-state-lsp-session *editor-state*) old-session
                (%fake-send-error new-transport) "initialize send failed")
          (with-replaced-function
              (loom/feature/lsp::make-lsp-session
               (lambda (&rest arguments)
                 (declare (ignore arguments))
                 new-session))
            (lsp-start)
            (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "fake-server"))
          (expect (editor-state-lsp-session *editor-state*) :to-be old-session)
          (expect (loom/feature/lsp::lsp-session-closed-p old-session) :to-be nil)
          (expect (%fake-closed-p old-transport) :to-be nil)
          (expect (%fake-sent-in-order old-transport) :to-have-length 2)
          (expect (loom/feature/lsp::lsp-session-closed-p new-session) :to-be-truthy)
          (expect (%fake-closed-p new-transport) :to-be-truthy)
          (expect (loom:minibuffer-message-string minibuffer)
                  :to-equal "LSP start failed: initialize send failed")))))

  (it-each ((:receive) (:close))
    "does not propagate an old transport ~S error through real shutdown"
    (failure)
      (%with-lsp-minibuffer-state (minibuffer "")
        (%with-initialized-fake-lsp-session ((old-transport old-session))
          (%with-fake-lsp-session ((new-transport new-session))
            (let* ((boundary (ecase failure
                               (:receive 'loom/feature/lsp::lsp-transport-receive)
                               (:close 'loom/feature/lsp::lsp-transport-close)))
                   (original-boundary (symbol-function boundary))
                   (failure-count 0))
              (setf (editor-state-lsp-session *editor-state*) old-session)
              (flet ((fail-old-transport (transport)
                       (if (eq transport old-transport)
                           (progn
                             (incf failure-count)
                             (error "old transport failed"))
                           (funcall original-boundary transport)))
                     (start-command ()
                       (progn (%fake-push-initialize-response new-transport) (lsp-start))
                       (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "fake-server")))
                (with-replaced-function
                    (loom/feature/lsp::make-lsp-session
                     (lambda (&rest arguments)
                       (declare (ignore arguments))
                       new-session))
                  (ecase failure
                    (:receive
                     (with-replaced-function
                         (loom/feature/lsp::lsp-transport-receive #'fail-old-transport)
                       (start-command)))
                    (:close
                     (with-replaced-function
                         (loom/feature/lsp::lsp-transport-close #'fail-old-transport)
                       (start-command))))))
              (expect failure-count :to-be-greater-than 0)
              (expect (editor-state-lsp-session *editor-state*) :to-be new-session)
              (expect (loom/feature/lsp::lsp-session-closed-p old-session) :to-be-truthy)
              (expect (loom/feature/lsp::lsp-session-closed-p new-session) :to-be nil)
              (expect (%fake-closed-p new-transport) :to-be nil)
              (expect (gethash "method" (%fake-sent-message old-transport 2))
                      :to-equal "shutdown")
              (expect (gethash "method" (%fake-sent-message old-transport 3))
                      :to-equal "exit")
              (expect (lsp-session-last-error old-session)
                      :to-equal (when (eq failure :receive) "old transport failed"))
              (expect (loom:minibuffer-message-string minibuffer)
                      :to-equal "LSP started.")))))))
