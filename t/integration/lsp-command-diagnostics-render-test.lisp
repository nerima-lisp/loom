(in-package #:loom/test)

(describe
  "LSP diagnostics command rendering"
  (it "renders refreshed diagnostics in a registered buffer"
    (let* ((transport (make-instance '%fake-lsp-transport))
           (session (make-lsp-session :transport transport))
           (buffer (make-buffer :name "main.lisp"
                                :path "/tmp/main.lisp"
                                :initial-content "(+ 1 2)"))
           (state
             (make-editor-state
              :window-tree (make-window-tree buffer 80 24)
              :minibuffer (make-minibuffer)
              :keymap (make-keymap)
              :file-tree nil
              :renderer nil
              :buffers (list buffer)
              :kill-ring nil)))
      (unwind-protect
           (progn
             (lsp-session-start session)
             (%fake-push-initialize-response transport)
             (%fake-push-publish-diagnostics
              transport
              "/tmp/main.lisp"
              "[{\"range\":{\"start\":{\"line\":0,\"character\":1},\"end\":{\"line\":0,\"character\":2}},\"message\":\"bad\",\"severity\":1,\"source\":\"fake\"}]")
             (setf (editor-state-lsp-session state) session)
             (let ((*editor-state* state))
               (loom/feature/lsp:lsp-diagnostics)
               (let ((diagnostics-buffer (%selected-test-buffer)))
                 (expect (buffer-name diagnostics-buffer)
                         :to-equal "*Loom-Diagnostics*")
                 (expect (buffer-text diagnostics-buffer)
                         :to-contain "bad")
                 (expect (loom:minibuffer-message-string
                          (editor-state-minibuffer state))
                         :to-equal "LSP diagnostics refreshed.")))
             (loom/feature/window:window-set-buffer
              (loom/feature/window:window-tree-selected-window
               (editor-state-window-tree state))
              buffer)
             (%fake-push-publish-diagnostics
              transport
              "/tmp/main.lisp"
              "[]")
             (let ((*editor-state* state))
               (loom/feature/lsp:lsp-diagnostics)
               (expect (buffer-text (%selected-test-buffer))
                       :to-contain
                       "No diagnostics.")))
        (lsp-session-stop session)))))
