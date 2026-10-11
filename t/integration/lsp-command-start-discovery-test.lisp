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
         (format nil "# project LSP~%~% fake-server --stdio ~%")
         configuration)
        (%with-minibuffer-state (minibuffer "")
          (let* ((buffer (make-buffer :name "main.lisp"
                                      :path path
                                      :initial-content "(+ 1 2)"))
                 (window (window-tree-selected-window
                          (editor-state-window-tree *editor-state*)))
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
                   (%register-buffer buffer)
                   (setf (editor-state-lsp-session *editor-state*) old-session
                         (window-scroll-line window) 2
                         (window-scroll-column window) 3
                         (window-scroll-sub-row window) 1)
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
                     (lsp-start)
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
                     (expect (editor-state-lsp-session *editor-state*) :to-be old-session)
                     (expect (%fake-closed-p old-transport) :to-be nil)
                     (%type-string minibuffer "yes")
                     (expect constructor-count :to-equal 0)
                     (minibuffer-handle-key minibuffer (%special-key :enter))
                     (expect constructor-count :to-equal 1))
                   (expect (window-buffer window) :to-be buffer)
                   (expect (window-scroll-line window) :to-equal 2)
                   (expect (window-scroll-column window) :to-equal 3)
                   (expect (window-scroll-sub-row window) :to-equal 1)
                   (expect (editor-state-lsp-session *editor-state*) :to-be new-session)
                   (expect (%fake-closed-p old-transport) :to-be t)
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
        (%with-minibuffer-state (minibuffer "")
          (let* ((buffer (make-buffer :name "main.lisp" :path path))
                 (window (window-tree-selected-window
                          (editor-state-window-tree *editor-state*)))
                 (transport (make-instance '%fake-lsp-transport))
                 (session (make-lsp-session :transport transport))
                 (constructor-count 0))
            (unwind-protect
                 (progn
                   (window-set-buffer window buffer)
                   (setf (editor-state-lsp-session *editor-state*) session
                         (window-scroll-line window) 2
                         (window-scroll-column window) 3
                         (window-scroll-sub-row window) 1)
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
                   (expect (editor-state-lsp-session *editor-state*) :to-be session)
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
    (%with-minibuffer-state (minibuffer "original buffer")
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
               (setf (editor-state-renderer *editor-state*) (make-loom-renderer 80 10)
                     (editor-state-lsp-session *editor-state*) old-session
                     (window-scroll-line window) 2
                     (window-scroll-column window) 3
                     (window-scroll-sub-row window) 1)
               (with-replaced-function
                   (loom/feature/lsp::make-lsp-session
                    (lambda (&rest arguments)
                      (incf constructor-count)
                      (setf new-session
                            (apply original-make-session :transport transport arguments))))
                 (loom/feature/lsp::%lsp-confirm-discovered-command
                  (concatenate 'string (make-string 1600 :initial-element #\x)
                               "REVIEW_END_UNIQUE")
                  #P"/project/" #P"/project/.loom-lsp" buffer minibuffer)
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
                 (expect (editor-state-lsp-session *editor-state*) :to-be old-session)
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
               (expect (editor-state-lsp-session *editor-state*)
                       :to-be (or new-session old-session))
               (expect (%fake-closed-p old-transport)
                       :to-be (not (null new-session)))
               (expect (minibuffer-message-string minibuffer)
                       :to-equal (cond (new-session "LSP started.")
                                       (answer "LSP start cancelled.")
                                       (t "Quit"))))
          (lsp-session-stop old-session)
          (when new-session (lsp-session-stop new-session))))))

  (it "preserves an explicit shell command override without the discovery trust prompt"
    (host-kit:with-temporary-directory (directory)
      (let* ((directory (truename directory))
             (path (merge-pathnames "main.lisp" directory))
             (command "exec manual-server --name 'a b'"))
        (host-kit:write-file-string "(+ 1 2)" path)
        (host-kit:write-file-string "discovered-server"
                                    (merge-pathnames ".loom-lsp" directory))
        (%with-minibuffer-state (minibuffer "")
          (let* ((buffer (make-buffer :name "main.lisp" :path path))
                 (window (window-tree-selected-window
                          (editor-state-window-tree *editor-state*)))
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
                     (lsp-start)
                     (%expect-minibuffer-prompt
                      minibuffer (%lsp-command-prompt-string "discovered-server"))
                     (expect constructor-count :to-equal 0)
                     (%type-string minibuffer command)
                     (minibuffer-handle-key minibuffer (%special-key :enter))
                     (expect constructor-count :to-equal 1))
                   (expect (getf captured-arguments :command) :to-equal command)
                   (expect (getf captured-arguments :directory) :to-equal directory)
                   (expect (window-buffer window) :to-be buffer)
                   (expect (minibuffer-active-p minibuffer) :to-be nil)
                   (expect (minibuffer-message-string minibuffer) :to-equal "LSP started."))
              (when new-session
                (lsp-session-stop new-session)))))))))
