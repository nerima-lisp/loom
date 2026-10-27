(in-package #:loom/test)

(describe
  "LSP session paths"
  (it "maps file paths and diagnostic severities"
    (expect (lsp-path-uri "/tmp/example.LISP")
            :to-equal
            "file:///tmp/example.LISP")
    (expect (lsp-path-uri "/tmp/space name#x?y%z/日本語.lisp")
            :to-equal
            "file:///tmp/space%20name%23x%3Fy%25z/%E6%97%A5%E6%9C%AC%E8%AA%9E.lisp")
    (expect (mapcar #'lsp-diagnostic-severity-name '(1 2 3 4 99))
            :to-equal
            '("error" "warning" "info" "hint" "info")))

  (it "uses the buffer major mode language identifier"
    (%with-initialized-fake-lsp-session ((transport session))
      (let ((python-buffer (make-buffer :name "notes.txt"
                                        :path "/tmp/notes.txt"
                                        :initial-content "notes"))
            (plain-buffer (make-buffer :name "README"
                                       :path "/tmp/README"
                                       :initial-content "read me")))
        (buffer-set-major-mode python-buffer :python)
        (lsp-session-sync-buffer session python-buffer)
        (lsp-session-sync-buffer session plain-buffer)
        (let* ((python-open (%fake-sent-message transport 2))
               (plain-open (%fake-sent-message transport 3)))
          (expect (gethash "languageId"
                           (gethash "textDocument"
                                    (gethash "params" python-open)))
                  :to-equal
                  "python")
          (expect (gethash "languageId"
                           (gethash "textDocument"
                                    (gethash "params" plain-open)))
                  :to-equal
                  "plaintext")))))
  (it "closes and reopens a document when its language changes"
    (%with-initialized-fake-lsp-session
        ((python-transport python-session)
         :root-path #P"/tmp/"
         :language-id "python")
      (%with-initialized-fake-lsp-session
          ((plain-transport plain-session)
           :root-path #P"/tmp/"
           :language-id "plaintext")
        (let* ((buffer (make-buffer :name "main.txt"
                                    :path "/tmp/main.txt"
                                    :initial-content "same"))
               (tree
                 (loom/core/window-tree:make-window-tree buffer 80 24))
               (editor-session
                 (%make-test-editor-session
                  nil
                  :window-tree tree
                  :additional-slices (list :feature/lsp)))
               (state
                 (loom/core/editor-session:make-editor-state
                  :window-tree tree
                  :session editor-session))
               (*editor-state* state)
               (loom/core/editor-session:*editor-session* editor-session))
          (loom/feature/lsp::%lsp-register-session
           editor-session python-session)
          (loom/feature/lsp::%lsp-register-session
           editor-session plain-session)
          (loom/feature/buffers:register-buffer editor-session buffer)
          (buffer-set-major-mode buffer :python)
          (lsp-session-sync-buffer python-session buffer)
          (buffer-set-major-mode buffer :fundamental)
          (lsp-refresh-editor-state state)
          (expect (gethash "method"
                           (%fake-sent-message python-transport 3))
                  :to-equal
                  "textDocument/didClose")
          (expect (gethash (lsp-path-uri "/tmp/main.txt")
                           (loom/feature/lsp::lsp-session-documents
                            python-session))
                  :to-be
                  nil)
          (let ((open (%fake-sent-message plain-transport 2)))
            (expect (gethash "method" open)
                    :to-equal
                    "textDocument/didOpen")
            (expect (gethash "languageId"
                             (gethash "textDocument"
                                      (gethash "params" open)))
                    :to-equal
                    "plaintext"))
          (buffer-set-major-mode buffer :python)
          (lsp-session-sync-buffer python-session buffer)
          (expect (gethash "method"
                           (%fake-sent-message plain-transport 3))
                  :to-equal
                  "textDocument/didClose")
          (let ((open (%fake-sent-message python-transport 4)))
            (expect (gethash "method" open)
                    :to-equal
                    "textDocument/didOpen")
            (progn
              (expect (gethash "languageId"
                               (gethash "textDocument"
                                        (gethash "params" open)))
                      :to-equal
                      "python")
              (buffer-set-major-mode buffer :fundamental)
              (loom/core/editor-session:run-session-hooks
               :after-save editor-session buffer)
              (expect (gethash "method"
                               (%fake-sent-message python-transport 5))
                      :to-equal
                      "textDocument/didClose")
              (expect (gethash (lsp-path-uri "/tmp/main.txt")
                               (loom/feature/lsp::lsp-session-documents
                                python-session))
                      :to-be
                      nil)
              (let ((plain-open (%fake-sent-message plain-transport 4)))
                (expect (gethash "method" plain-open)
                        :to-equal
                        "textDocument/didOpen")
                (expect (gethash "languageId"
                                 (gethash "textDocument"
                                          (gethash "params" plain-open)))
                        :to-equal
                        "plaintext"))
              (expect (gethash "method"
                               (%fake-sent-message plain-transport 5))
                      :to-equal
                      "textDocument/didSave")))
          (loom/feature/buffers:unregister-buffer
           editor-session buffer :reason :test)
          (expect (gethash "method"
                           (%fake-sent-message plain-transport 6))
                  :to-equal
                  "textDocument/didClose")
          (expect (gethash (lsp-path-uri "/tmp/main.txt")
                           (loom/feature/lsp::lsp-session-documents
                            plain-session))
                  :to-be
                  nil)))))

  (it "refreshes through the render-loop boundary"
    (%with-started-fake-lsp-session ((transport session))
      (%fake-push-initialize-response transport)
      (lsp-session-refresh session :not-a-buffer)
      (expect (lsp-session-last-error session) :to-be-truthy)
      (setf (lsp-session-last-error session) nil)
      (lsp-session-stop session)
      (lsp-session-refresh session :not-a-buffer)
      (expect (lsp-session-last-error session) :to-be nil))))
(describe
  "LSP session lookup"
  (it "returns no session when the editor has no LSP slice"
    (let ((editor-session
            (loom/core/editor-session:make-editor-session
             '(:feature/buffers)))
          (buffer (make-buffer :name "main.lisp"
                               :path "/tmp/main.lisp")))
      (expect
       (loom/feature/lsp::lsp-session-for-buffer editor-session buffer)
       :to-be nil)
      (expect (loom/feature/lsp::lsp-session-for-buffer nil buffer)
              :to-be nil))))
(describe
  "LSP session routing"
  (it "selects a project-language session and routes save and close hooks"
    (host-kit:with-temporary-directory (directory)
      (let* ((directory (truename directory))
             (source-directory (merge-pathnames "src/" directory))
             (buffer-path (merge-pathnames "main.txt" source-directory))
             (python-path (merge-pathnames "main.py" source-directory))
             (other-root (merge-pathnames "other/" directory))
             (other-path (merge-pathnames "main.txt" other-root))
             (configuration (merge-pathnames ".loom-lsp" directory))
             (other-configuration (merge-pathnames ".loom-lsp" other-root)))
        (ensure-directories-exist buffer-path)
        (ensure-directories-exist other-path)
        (host-kit:write-file-string "fake-server --stdio" configuration)
        (host-kit:write-file-string "fake-server --stdio" other-configuration)
        (let* ((buffer (make-buffer :name "main.txt"
                                    :path buffer-path
                                    :initial-content "notes"))
               (python-buffer (make-buffer :name "main.py"
                                           :path python-path
                                           :initial-content "value"))
               (other-buffer (make-buffer :name "main.txt"
                                          :path other-path
                                          :initial-content "other"))
               (editor-session
                 (loom/core/editor-session:make-editor-session
                  '(:feature/buffers :feature/lsp))))
          (buffer-set-major-mode python-buffer :python)
          (loom/feature/buffers:register-buffer editor-session buffer)
          (loom/feature/buffers:register-buffer editor-session python-buffer)
          (loom/feature/buffers:register-buffer editor-session other-buffer)
          (%with-initialized-fake-lsp-session
              ((transport session-a)
               :root-path directory
               :language-id "plaintext")
            (let* ((session-python
                     (make-lsp-session
                      :transport (make-instance '%fake-lsp-transport)
                      :root-path directory
                      :language-id "python"))
                   (session-other
                     (make-lsp-session
                      :transport (make-instance '%fake-lsp-transport)
                      :root-path other-root
                      :language-id "plaintext"))
                   (loom/core/editor-session:*editor-session* editor-session))
              (loom/feature/lsp::%lsp-register-session editor-session session-a)
              (loom/feature/lsp::%lsp-register-session editor-session session-python)
              (loom/feature/lsp::%lsp-register-session editor-session session-other)
              (expect (loom/feature/lsp::lsp-session-for-buffer editor-session buffer)
                      :to-be session-a)
              (expect (loom/feature/lsp::lsp-session-for-buffer editor-session python-buffer)
                      :to-be session-python)
              (expect (loom/feature/lsp::lsp-session-for-buffer editor-session other-buffer)
                      :to-be session-other)
              (lsp-session-sync-buffer session-a buffer)
              (progn
               (host-kit:write-file-string "notes" buffer-path)
               (loom/core/buffer:buffer-save buffer))
              (expect (gethash "method" (%fake-sent-message transport 3))
                      :to-equal "textDocument/didSave")
              (loom/feature/buffers:unregister-buffer
               editor-session buffer :reason :test)
              (expect (gethash "method" (%fake-sent-message transport 4))
                      :to-equal "textDocument/didClose")))))))
)
(describe
  "LSP configuration trust"
  (it "starts only a trusted unchanged command identity"
    (host-kit:with-temporary-directory (directory)
      (let* ((directory (truename directory))
             (source (merge-pathnames "main.nix" directory))
             (configuration (merge-pathnames ".loom-lsp" directory))
             (editor-session
               (loom/core/editor-session:make-editor-session
                '(:feature/buffers :feature/lsp)))
             (buffer (make-buffer :name "main.nix" :path source))
             (identity nil)
             (changed-identity nil)
             (session
               (make-lsp-session
                :transport (make-instance '%fake-lsp-transport)
                :root-path directory
                :language-id "plaintext"))
             (start-count 0))
        (host-kit:write-file-string "source" source)
        (host-kit:write-file-string "exec fake-server --stdio" configuration)
        (setf identity (nth-value 3 (lsp-discover-command source))
              (lsp-session-initialized-p session) t)
        (let ((loom/core/editor-session:*editor-session* editor-session))
          (with-replaced-function
              (loom/feature/lsp::%lsp-start-session
               (lambda (&rest arguments)
                 (declare (ignore arguments))
                 (incf start-count)
                 (loom/feature/lsp::%lsp-register-session editor-session session)
                 (values session nil)))
            (loom/feature/lsp::%lsp-auto-start-buffer editor-session buffer)
            (expect start-count :to-equal 0)
            (loom/feature/lsp::%lsp-trust-configuration editor-session identity)
            (loom/feature/lsp::%lsp-auto-start-buffer editor-session buffer)
            (expect start-count :to-equal 1)
            (loom/feature/lsp::%lsp-unregister-session editor-session session)
            (host-kit:write-file-string "changed-server --stdio" configuration)
            (setf changed-identity
                  (nth-value 3 (lsp-discover-command source)))
            (loom/feature/lsp::%lsp-auto-start-buffer editor-session buffer)
            (expect start-count :to-equal 1)
            (expect (loom/feature/lsp::%lsp-configuration-trusted-p
                     editor-session changed-identity)
                    :to-be nil)))))))
