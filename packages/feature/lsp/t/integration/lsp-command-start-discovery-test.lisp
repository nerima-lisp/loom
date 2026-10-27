(in-package #:loom/test)

(describe
  "LSP commands"
  (it "constructs the discovered session only after exact yes confirms its provenance"
    (host-kit:with-temporary-directory (directory)
      (let* ((directory (truename directory))
             (path (merge-pathnames "src/main.lisp" directory))
             (configuration (merge-pathnames ".loom-lsp" directory)))
        (ensure-directories-exist path)
        (host-kit:write-file-string "(+ 1 2)" path)
        (host-kit:write-file-string
         (format nil "# project LSP~%~% exec fake-server --stdio ~%")
         configuration)
        (%with-lsp-minibuffer-state (minibuffer "")
          (let* ((buffer (make-buffer :name "main.lisp"
                                      :path path
                                      :initial-content "(+ 1 2)"))
                 (window (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*)))
                 (transport (make-instance '%fake-lsp-transport))
                 (old-transport (make-instance '%fake-lsp-transport))
                 (old-session (make-lsp-session :transport old-transport))
                 (original-make-session
                   (symbol-function 'loom/feature/lsp::make-lsp-session))
                 (new-session nil)
                 (constructor-count 0)
                 (captured-arguments nil))
            (unwind-protect
                 (progn
                   (window-set-buffer window buffer)
                   (%register-test-buffer *editor-state* buffer)
                   (progn
      (%lsp-test-register-session-for-buffer buffer old-session)
      (setf (window-scroll-line window) 2
                         (window-scroll-column window) 3
                         (window-scroll-sub-row window) 1))
                   (with-replaced-function
                       (loom/feature/lsp::make-lsp-session
                        (lambda (&rest arguments)
                          (incf constructor-count)
                          (setf captured-arguments arguments
                                new-session
                                (apply original-make-session
                                       :transport transport
                                       arguments))
                          new-session))
                     (progn (%fake-push-initialize-response transport) (lsp-start))
                     (%expect-minibuffer-prompt
                      minibuffer
                      (%lsp-command-prompt-string "fake-server --stdio"))
                     (expect constructor-count :to-equal 0)
                     (minibuffer-handle-key minibuffer (%special-key :enter))
                     (%expect-minibuffer-prompt
                      minibuffer "Run discovered LSP command? Type yes: ")
                     (expect (buffer-text (window-buffer window))
                             :to-equal
                             (format nil "Discovered LSP command~%PageDown/C-v: next; PageUp/M-v: previous~%Config: ~A~%Directory: ~A~%Command: fake-server --stdio~%"
                                     configuration directory))
                     (expect (buffer-read-only-p (window-buffer window)) :to-be t)
                     (expect (buffer-truncate-lines (window-buffer window)) :to-be nil)
                     (expect constructor-count :to-equal 0)
                     (expect (loom/feature/lsp::lsp-session-for-buffer
              (editor-state-session *editor-state*) buffer)
            :to-be old-session)
                     (expect (%fake-closed-p old-transport) :to-be nil)
                     (%type-string minibuffer "yes")
                     (expect constructor-count :to-equal 0)
                     (minibuffer-handle-key minibuffer (%special-key :enter))
                     (expect constructor-count :to-equal 1))
                   (expect (window-buffer window) :to-be buffer)
                   (expect (window-scroll-line window) :to-equal 2)
                   (expect (window-scroll-column window) :to-equal 3)
                   (expect (window-scroll-sub-row window) :to-equal 1)
                   (expect (loom/feature/lsp::lsp-session-for-buffer
              (editor-state-session *editor-state*) buffer)
            :to-be new-session)
                   (expect (%fake-closed-p old-transport) :to-be t)
                   (expect (getf captured-arguments :command) :to-equal (list "fake-server" "--stdio"))
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
              (lsp-session-stop old-session)
              (when new-session
                (lsp-session-stop new-session))))))))

  (it-each (("") (" ") ("no") ("y") ("YES") (" yes") ("yes ") (nil))
    "does not construct or replace a session after trust answer ~S"
    (answer)
    (host-kit:with-temporary-directory (directory)
      (let* ((directory (truename directory))
             (path (merge-pathnames "main.lisp" directory)))
        (host-kit:write-file-string "(+ 1 2)" path)
        (host-kit:write-file-string "fake-server --stdio"
                                    (merge-pathnames ".loom-lsp" directory))
        (%with-lsp-minibuffer-state (minibuffer "")
          (let* ((buffer (make-buffer :name "main.lisp" :path path))
                 (window (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*)))
                 (transport (make-instance '%fake-lsp-transport))
                 (session (make-lsp-session :transport transport))
                 (constructor-count 0))
            (unwind-protect
                 (progn
                   (window-set-buffer window buffer)
                   (progn
      (%lsp-test-register-session-for-buffer buffer session)
      (setf (window-scroll-line window) 2
                         (window-scroll-column window) 3
                         (window-scroll-sub-row window) 1))
                   (with-replaced-function
                       (loom/feature/lsp::make-lsp-session
                        (lambda (&rest arguments)
                          (declare (ignore arguments))
                          (incf constructor-count)
                          (error "Unexpected LSP construction")))
                     (lsp-start)
                     (expect constructor-count :to-equal 0)
                     (minibuffer-handle-key minibuffer (%special-key :enter))
                     (%expect-minibuffer-prompt
                      minibuffer "Run discovered LSP command? Type yes: ")
                     (expect constructor-count :to-equal 0)
                     (if answer
                         (progn
                           (%type-string minibuffer answer)
                           (minibuffer-handle-key minibuffer (%special-key :enter)))
                         (minibuffer-handle-key minibuffer (%special-key :control-g)))
                     (expect constructor-count :to-equal 0))
                   (expect (minibuffer-active-p minibuffer) :to-be nil)
                   (expect (minibuffer-message-string minibuffer)
                           :to-equal (if answer "LSP start cancelled." "Quit"))
                   (expect (loom/feature/lsp::lsp-session-for-buffer
              (editor-state-session *editor-state*) buffer)
            :to-be session)
                   (expect (%fake-closed-p transport) :to-be nil)
                   (expect (%fake-sent transport) :to-be nil)
                   (expect (window-buffer window) :to-be buffer)
                   (expect (window-scroll-line window) :to-equal 2)
                   (expect (window-scroll-column window) :to-equal 3)
                   (expect (window-scroll-sub-row window) :to-equal 1))
              (lsp-session-stop session)))))))

  (it-each ((:page nil) (:page "") (:page "yes")
            (:control nil) (:control "") (:control "yes")
            (:modified nil) (:modified "") (:modified "yes"))
    "pages wrapped disclosure with ~S, preserving input and trust answer ~S"
    (encoding answer)
    (%with-lsp-file-minibuffer-state (minibuffer buffer #P"/project/main.lisp" "original buffer")
     (let* ((tree (editor-state-window-tree *editor-state*))
             (window (window-tree-selected-window tree))
             (buffer (window-buffer window))
             (transport (make-instance '%fake-lsp-transport))
             (old-transport (make-instance '%fake-lsp-transport))
             (old-session (make-lsp-session :transport old-transport))
             (original-make-session
               (symbol-function 'loom/feature/lsp::make-lsp-session))
             (new-session nil)
             (constructor-count 0)
             (input (or answer "yes"))
             (forward (case encoding
                        (:page (%special-key :page-down))
                        (:control (%special-key :control-v))
                        (:modified (cl-tty-kit:make-key-event
                                    :type :character :code #\v :modifiers '(:control)))))
             (backward (if (eq encoding :page)
                           (%special-key :page-up)
                           (cl-tty-kit:make-key-event
                            :type :character :code #\v :modifiers '(:alt)))))
        (unwind-protect
             (progn
               (window-tree-resize tree 80 9)
               (progn
      (%lsp-test-register-session-for-buffer buffer old-session)
      (setf (editor-state-renderer *editor-state*) (make-loom-renderer 80 10)
            (window-scroll-line window) 2
            (window-scroll-column window) 3
            (window-scroll-sub-row window) 1))
               (with-replaced-function
                   (loom/feature/lsp::make-lsp-session
                    (lambda (&rest arguments)
                      (incf constructor-count)
                      (setf new-session
                            (apply original-make-session :transport transport arguments))))
                 (progn
  (%fake-push-initialize-response transport)
  (loom/feature/lsp::%lsp-confirm-discovered-command
     (list "fake-server"
           (concatenate 'string (make-string 1600 :initial-element #\x)
                        "REVIEW_END_UNIQUE"))
     #P"/project/" #P"/project/.loom-lsp" buffer minibuffer))
                 (%type-string minibuffer input)
                 (let ((review (window-buffer window)))
                   ;; Both pages remain inside one wrapped logical Command line.
                   (buffer-set-point review 4 320)
                   (minibuffer-handle-key minibuffer forward)
                   (expect (buffer-point-line review) :to-equal 4)
                   (expect (buffer-point-column review) :to-equal 960)
                   (expect (minibuffer-input-string minibuffer) :to-equal input)
                   (minibuffer-handle-key minibuffer backward)
                   (expect (buffer-point-line review) :to-equal 4)
                   (expect (buffer-point-column review) :to-equal 320)
                   (dotimes (page 10) (minibuffer-handle-key minibuffer forward))
                   (expect (buffer-point-line review) :to-equal 5)
                   (dotimes (page 10) (minibuffer-handle-key minibuffer backward))
                   (expect (buffer-point-line review) :to-equal 0)
                   (expect (buffer-point-column review) :to-equal 0))
                 (expect (minibuffer-input-string minibuffer) :to-equal input)
                 (expect constructor-count :to-equal 0)
                 (expect (loom/feature/lsp::lsp-session-for-buffer
              (editor-state-session *editor-state*) buffer)
            :to-be old-session)
                 (expect (%fake-closed-p old-transport) :to-be nil)
                 (expect (%fake-sent old-transport) :to-be nil)
                 (minibuffer-handle-key minibuffer
                                        (%special-key (if answer :enter :control-g)))
                 (expect constructor-count :to-equal (if (equal answer "yes") 1 0)))
               (expect (minibuffer-active-p minibuffer) :to-be nil)
               (expect (window-buffer window) :to-be buffer)
               (expect (window-scroll-line window) :to-equal 2)
               (expect (window-scroll-column window) :to-equal 3)
               (expect (window-scroll-sub-row window) :to-equal 1)
               (expect (loom/feature/lsp::lsp-session-for-buffer
              (editor-state-session *editor-state*) buffer)
            :to-be (or new-session old-session))
               (expect (%fake-closed-p old-transport)
                       :to-be (not (null new-session)))
               (expect (minibuffer-message-string minibuffer)
                       :to-equal (cond (new-session "LSP started.")
                                       (answer "LSP start cancelled.")
                                       (t "Quit"))))
          (lsp-session-stop old-session)
          (when new-session (lsp-session-stop new-session))))))

  (it "parses an explicit manual command into argv without the discovery trust prompt"
    (host-kit:with-temporary-directory (directory)
      (let* ((directory (truename directory))
             (path (merge-pathnames "main.lisp" directory))
             (command "manual-server --name value"))
        (host-kit:write-file-string "(+ 1 2)" path)
        (host-kit:write-file-string "discovered-server"
                                    (merge-pathnames ".loom-lsp" directory))
        (%with-lsp-minibuffer-state (minibuffer "")
          (let* ((buffer (make-buffer :name "main.lisp" :path path))
                 (window (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*)))
                 (transport (make-instance '%fake-lsp-transport))
                 (original-make-session
                   (symbol-function 'loom/feature/lsp::make-lsp-session))
                 (new-session nil)
                 (captured-arguments nil)
                 (constructor-count 0))
            (unwind-protect
                 (progn
                   (window-set-buffer window buffer)
                   (with-replaced-function
                       (loom/feature/lsp::make-lsp-session
                        (lambda (&rest arguments)
                          (incf constructor-count)
                          (setf captured-arguments arguments
                                new-session (apply original-make-session
                                                   :transport transport arguments))))
                     (progn (%fake-push-initialize-response transport) (lsp-start))
                     (%expect-minibuffer-prompt
                      minibuffer (%lsp-command-prompt-string "discovered-server"))
                     (expect constructor-count :to-equal 0)
                     (%type-string minibuffer command)
                     (minibuffer-handle-key minibuffer (%special-key :enter))
                     (expect constructor-count :to-equal 1))
                   (expect (getf captured-arguments :command) :to-equal (list "manual-server" "--name" "value"))
                   (expect (getf captured-arguments :directory) :to-equal directory)
                   (expect (window-buffer window) :to-be buffer)
                   (expect (minibuffer-active-p minibuffer) :to-be nil)
                   (expect (minibuffer-message-string minibuffer) :to-equal "LSP started."))
              (when new-session
                (lsp-session-stop new-session))))))))
  (it "reports the exit status only for an initialize send failure"
    (host-kit:with-temporary-directory (directory)
      (let* ((directory (truename directory))
             (original-make-session
               (fdefinition (find-symbol "MAKE-LSP-SESSION"
                                          "LOOM/FEATURE/LSP")))
             (original-transport-send
               (fdefinition (find-symbol "LSP-TRANSPORT-SEND"
                                          "LOOM/FEATURE/LSP")))
             (new-session nil)
             (initialize-method nil)
             (initialize-send-attempted nil)
             (process-exited-before-send nil)
             (initialize-send-error nil))
        (%with-lsp-minibuffer-state (minibuffer "")
          (unwind-protect
               (progn
                 (with-replaced-function
                     (loom/feature/lsp::lsp-transport-send
                      (lambda (transport json)
                        (let* ((message (%parse-lsp-json json))
                               (method (gethash "method" message)))
                          (when (equal method "initialize")
                            (setf initialize-method method
                                  initialize-send-attempted t)
                            (let ((process
                                    (loom/feature/lsp::lsp-process-process
                                     transport)))
                              (loop repeat 200
                                    until (not (uiop:process-alive-p process))
                                    do (sleep 0.01))
                              (setf process-exited-before-send
                                    (not (uiop:process-alive-p process)))))
                          (handler-case
                              (funcall original-transport-send transport json)
                            (error (condition)
                              (when (equal method "initialize")
                                (setf initialize-send-error condition))
                              (error condition))))))
                   (with-replaced-function
                       (loom/feature/lsp::make-lsp-session
                        (lambda (&rest arguments)
                          (setf new-session
                                (apply original-make-session arguments))))
                     (multiple-value-bind (session condition)
                         (loom/feature/lsp::%lsp-start-session
                          (list "sh" "-c" "exit 17")
                          directory
                          "plaintext"
                          nil
                          (editor-state-session *editor-state*))
                       (declare (ignore session))
                       (loom/feature/lsp::%lsp-report-start-result
                        minibuffer new-session condition)
                       (expect initialize-method :to-equal "initialize")
                       (expect initialize-send-attempted :to-be t)
                       (expect process-exited-before-send :to-be t)
                       (expect initialize-send-error :to-be-truthy)
                       (expect
                        (typep
                         (loom/feature/lsp::lsp-session-transport-error
                          new-session)
                         (quote loom/feature/lsp::lsp-transport-send-exit-error))
                        :to-be t)
                       (expect
                        (loom/feature/lsp::lsp-transport-send-exit-status
                         (loom/feature/lsp::lsp-session-transport-error
                          new-session))
                        :to-equal 17)
                       (expect
                        (loom:minibuffer-message-string minibuffer)
                        :to-equal
                        "LSP start failed: server exited with status 17")
                       (expect
                        (loom/feature/lsp::lsp-session-closed-p new-session)
                        :to-be t)))
                 (let* ((unrelated-condition
                          (make-condition 'simple-error
                                           :format-control
                                           "unrelated initialization failure"
                                           :format-arguments nil))
                        (unrelated-session nil)
                        (returned-condition nil))
                   (unwind-protect
                        (with-replaced-function
                            (loom/feature/lsp::make-lsp-session
                             (lambda (&rest arguments)
                               (setf unrelated-session
                                     (apply original-make-session
                                            arguments))))
                          (with-replaced-function
                              (loom/feature/lsp::lsp-session-start
                               (lambda (session)
                                 (let* ((transport
                                          (loom/feature/lsp::lsp-session-transport
                                           session))
                                        (process
                                          (loom/feature/lsp::lsp-process-process
                                           transport)))
                                   (loop repeat 200
                                         until
                                         (not (uiop:process-alive-p process))
                                         do (sleep 0.01)))
                                 (error unrelated-condition)))
                            (multiple-value-bind (session condition)
                                (loom/feature/lsp::%lsp-start-session
                          (list "sh" "-c" "exit 17")
                          directory
                          "plaintext"
                          nil
                          (editor-state-session *editor-state*))
                              (declare (ignore session))
                              (setf returned-condition condition)))
                     (when unrelated-session
                       (lsp-session-stop unrelated-session)))
                   (expect (eq returned-condition unrelated-condition)
                           :to-be t)
                   (expect
                    (loom/feature/lsp::lsp-session-closed-p unrelated-session)
                    :to-be t))))
            (when new-session
              (lsp-session-stop new-session)))))))))
