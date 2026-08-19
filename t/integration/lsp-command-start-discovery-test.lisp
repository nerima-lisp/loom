(in-package #:loom/test)

(describe
  "LSP commands"
  (it "uses the discovered command and project root when RET confirms it"
    (host-kit:with-temporary-directory (directory)
      (let* ((directory (truename directory))
             (path (merge-pathnames "src/main.lisp" directory))
             (configuration (merge-pathnames ".loom-lsp" directory)))
        (ensure-directories-exist path)
        (host-kit:write-file-string "(+ 1 2)" path)
        (host-kit:write-file-string
         (format nil "# project LSP~%~% fake-server --stdio ~%")
         configuration)
        (%with-minibuffer-state (minibuffer "")
          (let* ((buffer (make-buffer :name "main.lisp"
                                      :path path
                                      :initial-content "(+ 1 2)"))
                 (window (window-tree-selected-window
                          (editor-state-window-tree *editor-state*)))
                 (transport (make-instance '%fake-lsp-transport))
                 (original-make-session
                   (symbol-function 'loom/feature/lsp::make-lsp-session))
                 (new-session nil)
                 (captured-arguments nil))
            (unwind-protect
                 (progn
                   (window-set-buffer window buffer)
                   (%register-buffer buffer)
                   (with-replaced-function
                       (loom/feature/lsp::make-lsp-session
                        (lambda (&rest arguments)
                          (setf captured-arguments arguments
                                new-session
                                (apply original-make-session
                                       :transport transport
                                       arguments))
                          new-session))
                     (lsp-start)
                     (%expect-minibuffer-prompt
                      minibuffer
                      (%lsp-command-prompt-string "fake-server --stdio"))
                     (funcall (loom::%minibuffer-on-confirm minibuffer) ""))
                   (expect (getf captured-arguments :command)
                           :to-equal
                           "fake-server --stdio")
                   (expect (getf captured-arguments :directory)
                           :to-equal
                           directory)
                   (expect (getf captured-arguments :root-uri)
                           :to-equal
                           (lsp-path-uri directory))
                   (let* ((request
                            (%parse-lsp-json
                             (first (%fake-sent-in-order transport))))
                          (params (gethash "params" request)))
                     (expect (gethash "rootUri" params)
                             :to-equal
                             (lsp-path-uri directory)))
                   (expect (loom:minibuffer-message-string minibuffer)
                           :to-equal
                           "LSP started."))
              (when new-session
                (lsp-session-stop new-session)))))))))
