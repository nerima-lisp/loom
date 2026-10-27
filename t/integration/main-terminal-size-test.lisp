(in-package #:loom/test)

(describe "%initial-terminal-size"
          (it "returns cl-tty-kit's reported terminal size when available"
              (%with-stubbed-terminal-size (100 40)
                                           (expect
                                            (multiple-value-list
                                             (loom::%initial-terminal-size))
                                            :to-equal
                                            (list 100 40))))
          (it "falls back to 80x24 when the terminal size is unavailable"
              (with-replaced-function
               (cl-tty-kit:terminal-size
                (lambda ()
                  (values nil nil)))
               (expect (multiple-value-list (loom::%initial-terminal-size))
                       :to-equal
                       (list 80 24)))))

(describe "%poll-terminal-resize"
          (it
           "resizes the renderer and returns the new size when the terminal size changed"
           (let ((renderer (make-loom-renderer 80 24)))
             (%with-stubbed-terminal-size (100 40)
                                          (expect
                                           (multiple-value-list
                                            (loom::%poll-terminal-resize
                                             renderer
                                             80
                                             24))
                                           :to-equal
                                           (list 100 40))
                                          (expect
                                           (cl-tty-kit:renderer-width
                                            (loom::%loom-renderer-cl-tty-renderer
                                             renderer))
                                           :to-equal
                                           100))))
          (it
           "returns the last-seen size unchanged when the terminal size is unavailable"
           (let ((renderer (make-loom-renderer 80 24)))
             (with-replaced-function
              (cl-tty-kit:terminal-size
               (lambda ()
                 (values nil nil)))
              (expect
               (multiple-value-list
                (loom::%poll-terminal-resize renderer 80 24))
               :to-equal
               (list 80 24)))))
          (it
           "returns the last-seen size unchanged when the terminal size is unchanged"
           (let ((renderer (make-loom-renderer 80 24)))
             (%with-stubbed-terminal-size (80 24)
                                          (expect
                                           (multiple-value-list
                                            (loom::%poll-terminal-resize
                                             renderer
                                             80
                                             24))
                                           :to-equal
                                           (list 80 24))))))

(describe "%event-loop-background-work-p"
          (it "reports no background work for an idle editor state"
              (let ((loom::*editor-state*
                     (make-editor-state :session (%make-test-editor-session))))
                (expect (loom::%event-loop-background-work-p) :to-be nil)))
          (it "reports background work when auto-save mode is enabled"
              (let ((loom::*editor-state*
                     (make-editor-state :session (%make-test-editor-session))))
                (setf (editor-state-auto-save-mode-p loom::*editor-state*) t)
                (expect (loom::%event-loop-background-work-p) :to-be t)))
          (it "reports background work when auto-save buffers are present"
              (let ((loom::*editor-state*
                     (make-editor-state :session (%make-test-editor-session))))
                (setf (editor-state-auto-save-buffers loom::*editor-state*) (list
                                                                             :buffer))
                (expect (loom::%event-loop-background-work-p) :to-be t)))
          (it "reports background work when an LSP session is present"
              (let ((loom::*editor-state*
                     (make-editor-state :session (%make-test-editor-session nil
                      :additional-slices (list :feature/lsp)))))
                (progn
                  (loom/feature/lsp::%lsp-register-session
                   (editor-state-session loom::*editor-state*)
                   (loom/feature/lsp:make-lsp-session
                    :transport (make-instance (quote %fake-lsp-transport))
                    :root-path #P"/tmp/"
                    :language-id "common-lisp"))
                  (expect
                   (loom/feature/lsp:lsp-editor-session-background-work-p
                    (editor-state-session loom::*editor-state*))
                   :to-be t))
                (expect (loom::%event-loop-background-work-p) :to-be t)))
          (it "polls while a file-tree listing is pending"
              (let* ((runtime
                       (make-loom-concurrent-runtime
                        :directory-lister
                        (lambda (path)
                          (declare (ignore path))
                          nil)))
                     (state (make-editor-state :session (%make-test-editor-session))))
                (unwind-protect
                     (progn
                       (multiple-value-bind (promises accepted)
                           (loom-concurrent-runtime-prefetch runtime (list #P"/"))
                         (declare (ignore promises))
                         (expect accepted :to-be 1))
                       (setf (editor-state-concurrent-runtime state) runtime)
                       (let ((loom::*editor-state* state))
                         (expect (loom::%event-loop-background-work-p) :to-be t)))
                  (loom-concurrent-runtime-shutdown runtime)))))

(describe "%wait-for-editor-input"
          (it "returns immediately when no background work is pending"
              (let ((loom::*editor-state*
                     (make-editor-state :session (%make-test-editor-session))))
                (expect (loom::%wait-for-editor-input nil) :to-be t)))
          (it "waits for input while background work is pending"
              (let ((loom::*editor-state*
                     (make-editor-state :session (%make-test-editor-session)))
                    (wait-calls 0))
                (setf (editor-state-auto-save-mode-p loom::*editor-state*) t)
                (with-replaced-function
                 (cl-tty-kit:fd-wait
                  (lambda (&rest arguments)
                    (declare (ignore arguments))
                    (incf wait-calls)
                    :ready))
                 (expect (loom::%wait-for-editor-input :input) :to-be t))
                (expect wait-calls :to-be 1)))
          (it "continues when stream-fd rejects an unsupported stream"
              (let ((loom::*editor-state*
                     (make-editor-state :session (%make-test-editor-session))))
                (setf (editor-state-auto-save-mode-p loom::*editor-state*) t)
                (with-replaced-function
                 (cl-tty-kit:stream-fd
                  (lambda (&rest arguments)
                    (declare (ignore arguments))
                    (error 'type-error
                           :datum
                           :unsupported-stream
                           :expected-type
                           'stream)))
                 (expect (loom::%wait-for-editor-input :input) :to-be t))))
          (it "propagates errors from fd-wait after resolving the stream fd"
              (let ((loom::*editor-state*
                     (make-editor-state :session (%make-test-editor-session))))
                (setf (editor-state-auto-save-mode-p loom::*editor-state*) t)
                (with-replaced-function
                 (cl-tty-kit:stream-fd (lambda (stream)
                                         (declare (ignore stream))
                                         10))
                 (with-replaced-function
                  (cl-tty-kit:fd-wait
                   (lambda (&rest arguments)
                     (declare (ignore arguments))
                     (error 'type-error
                            :datum
                            :unsupported-fd
                            :expected-type
                            'fixnum)))
                  (signals type-error
                    (loom::%wait-for-editor-input :input)))))
          (it "propagates errors from the terminal wake poll"
              (let ((loom::*editor-state*
                     (make-editor-state :session (%make-test-editor-session))))
                (setf (editor-state-auto-save-mode-p loom::*editor-state*) t)
                (with-replaced-function
                 (cl-tty-kit:stream-fd (lambda (stream)
                                         (declare (ignore stream))
                                         10))
                 (with-replaced-function
                  (loom::%poll-loom-terminal-session
                   (lambda (&rest arguments)
                     (declare (ignore arguments))
                     (error 'type-error
                            :datum
                            :invalid-poll
                            :expected-type
                            'fixnum)))
                  (signals type-error
                    (loom::%wait-for-editor-input
                     :input
                     :terminal-session))))))))
