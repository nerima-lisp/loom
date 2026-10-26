(in-package #:loom/test)

(describe "%render-event-loop-frame"
          (it
           "runs optional refresh work before composing and presenting a frame"
           (let* ((buffer
                   (make-buffer :path "/tmp/main.lisp" :initial-content "x"))
                  (*editor-state* (%fresh-full-editor-state ""))
                  (runtime-drained nil)
                  (prefetched-paths nil)
                  (lsp-refreshed nil)
                  (composed nil)
                  (presented nil))
             (window-set-buffer
              (loom/core/window-tree:window-tree-selected-window
               (editor-state-window-tree *editor-state*))
              buffer)
             (setf (editor-state-concurrent-runtime *editor-state*) :runtime
                   (editor-state-lsp-session *editor-state*) :session)
             (with-replaced-function
              (loom/feature/terminal:poll-terminal-sessions
               (lambda (state)
                 (declare (ignore state))))
              (with-replaced-function
               (loom/feature/file-tree:loom-concurrent-runtime-drain
                (lambda (runtime)
                  (expect runtime :to-be :runtime)
                  (setf runtime-drained t)))
               (with-replaced-function
                (loom/feature/file-tree:file-tree-prefetch-paths
                 (lambda (tree)
                   (declare (ignore tree))
                   '(:prefetch-path)))
                (with-replaced-function
                 (loom/feature/file-tree:loom-concurrent-runtime-prefetch
                  (lambda (runtime paths)
                    (expect runtime :to-be :runtime)
                    (setf prefetched-paths paths)))
                 (with-replaced-function
                  (loom/feature/lsp:lsp-session-refresh
                   (lambda (session selected-buffer)
                     (expect session :to-be :session)
                     (expect selected-buffer :to-be buffer)
                     (setf lsp-refreshed t)))
                  (with-replaced-function
                   (loom::compose-frame
                    (lambda (state)
                      (expect state :to-be *editor-state*)
                      (progn
                        (setf composed t)
                        (loom/core/editor-session:make-frame-snapshot
                         80 24
                         (make-array 1920 :initial-element (list " " nil))))))
                   (with-replaced-function
                    (loom:loom-renderer-present
                     (lambda (renderer &key stream cursor)
                       (declare (ignore stream cursor))
                       (expect renderer
                               :to-be
                               (editor-state-renderer *editor-state*))
                       (setf presented t)))
                    (loom::%render-event-loop-frame (make-string-output-stream) #'loom::%render-root-frame)))))))
              (expect runtime-drained :to-be-truthy)
              (expect prefetched-paths :to-equal '(:prefetch-path))
              (expect lsp-refreshed :to-be-truthy)
              (expect composed :to-be-truthy)
              (expect presented :to-be-truthy)))))

(it "composes and presents when optional refresh services are absent"
    (let ((*editor-state* (%fresh-full-editor-state ""))
          (composed nil)
          (presented nil))
      (with-replaced-function
       (loom/feature/terminal:poll-terminal-sessions
        (lambda (state)
          (declare (ignore state))))
       (with-replaced-function
        (loom::compose-frame
         (lambda (state)
           (expect state :to-be *editor-state*)
           (progn
             (setf composed t)
             (loom/core/editor-session:make-frame-snapshot
              80 24
              (make-array 1920 :initial-element (list " " nil))))))
        (with-replaced-function
         (loom:loom-renderer-present
          (lambda (renderer &key stream cursor)
            (declare (ignore renderer stream cursor))
            (setf presented t)))
         (loom::%render-event-loop-frame (make-string-output-stream) #'loom::%render-root-frame))))
      (expect composed :to-be-truthy)
      (expect presented :to-be-truthy)))

(describe
  "%run-event-loop input"
  (it
    "returns no status when an input wait succeeds but reaches EOF"
    (let ((buffer (make-array 16 :element-type (quote (unsigned-byte 8))))
          (decoder :decoder)
          (keymap-state :keymap)
          (terminal-session :terminal-session))
      (with-replaced-function
          (loom::%wait-for-editor-input
           (lambda (stream received-terminal-session)
             (declare (ignore stream))
             (expect received-terminal-session :to-be terminal-session)
             (values t nil nil)))
        (with-replaced-function
            (loom::%read-input-octets
             (lambda (target stream)
               (declare (ignore target stream))
               nil))
          (expect
           (multiple-value-list
            (loom::%read-and-dispatch-event-loop-input
             (make-string-input-stream "")
             buffer
             decoder
             keymap-state
             terminal-session
             nil))
           :to-equal
           (list nil nil nil nil nil))))))

  (it
    "returns timeout and requests rendering for a background poll"
    (let* ((*editor-state* (%fresh-full-editor-state ""))
           (buffer (make-array 16 :element-type '(unsigned-byte 8)))
           (poll-ready-p nil)
           (terminal-session :terminal-session))
      (with-replaced-function
          (loom::%wait-for-editor-input
           (lambda (stream received-terminal-session)
             (declare (ignore stream))
             (expect received-terminal-session :to-be terminal-session)
             (values nil nil poll-ready-p)))
        (with-replaced-function
            (loom::%process-loom-wake-events
             (lambda (received-terminal-session session wake-bytes poll-work-p)
               (declare (ignore received-terminal-session session wake-bytes))
               (expect poll-work-p :to-be t)
               (values nil nil nil nil nil)))
          (with-replaced-function
              (loom::%read-input-octets
               (lambda (&rest arguments)
                 (declare (ignore arguments))
                 (error "input should not be read after a timeout")))
            (flet ((run-turn ()
                     (multiple-value-list
                      (loom::%read-and-dispatch-event-loop-input
                       (make-string-input-stream "")
                       buffer
                       :decoder
                       :keymap-state
                       terminal-session
                       nil))))
              (expect (run-turn) :to-equal (list :timeout nil nil nil nil))
              (setf poll-ready-p t)
              (expect (run-turn) :to-equal (list :timeout nil nil t nil))))))))

  (it
    "self-inserts decoded input and exits cleanly at end-of-file"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "input.bin" dir)))
        (with-open-file (out path :direction :output :element-type '(unsigned-byte 8))
          (write-byte (char-code #\a) out))
        (let* ((*editor-state* (%fresh-full-editor-state ""))
               (loom/core/editor-session:*editor-session*
                 (loom/core/editor-session:editor-state-session *editor-state*)))
          (%with-stubbed-terminal-size (80 24)
            (with-open-file (*standard-input* path :direction :input
                                              :element-type '(unsigned-byte 8))
              (loom::%run-event-loop (make-string-output-stream)
                                     *standard-input*
                                     nil
                                     (function
                                       (lambda (stream)
                                         (declare (ignore stream)))))))
          (expect (buffer-line (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*)))
                               0)
                  :to-equal "a")))))

  (it
    "decodes a full 4096-byte read as-is, without slicing a partial chunk"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "input.bin" dir)))
        (with-open-file (out path :direction :output :element-type '(unsigned-byte 8))
          (dotimes (i 4096) (write-byte (char-code #\a) out)))
        (let* ((*editor-state* (%fresh-full-editor-state ""))
         (loom/core/editor-session:*editor-session*
           (loom/core/editor-session:editor-state-session *editor-state*)))
          (%with-stubbed-terminal-size (80 24)
            (with-open-file (*standard-input* path :direction :input
                                              :element-type '(unsigned-byte 8))
              (loom::%run-event-loop (make-string-output-stream)
                                     *standard-input*
                                     nil
                                     (function
                                       (lambda (stream)
                                         (declare (ignore stream)))))))
          (expect (length (buffer-line (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*)))
                                       0))
                  :to-equal 4096)))))

  (it
    "exits via LOOM-QUIT when a dispatched command signals it"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "input.bin" dir)))
        (with-open-file (out path :direction :output :element-type '(unsigned-byte 8))
          ;; C-x C-c signals LOOM-QUIT; the following x must not be dispatched.
          (write-byte 24 out)
          (write-byte 3 out)
          (write-byte (char-code #\x) out))
        (let* ((*editor-state* (%fresh-full-editor-state ""))
         (loom/core/editor-session:*editor-session*
           (loom/core/editor-session:editor-state-session *editor-state*)))
          (%with-stubbed-terminal-size (80 24)
            (with-open-file (*standard-input* path :direction :input
                                              :element-type '(unsigned-byte 8))
              (loom::%run-event-loop (make-string-output-stream)
                                     *standard-input*
                                     nil
                                     (function
                                       (lambda (stream)
                                         (declare (ignore stream)))))))
          (expect (buffer-line (%selected-test-buffer) 0)
                  :to-equal ""))))))

(it "continues after a timeout status and stops at end-of-input"
    (let ((*editor-state* (%fresh-full-editor-state ""))
          (statuses (list :timeout nil))
          (turns 0))
      (%with-stubbed-terminal-size (80 24)
                                   (with-replaced-function
                                    (loom::%read-and-dispatch-event-loop-input
                                     (lambda (&rest arguments)
                                       (declare (ignore arguments))
                                       (incf turns)
                                       (pop statuses)))
                                    (with-replaced-function
                                     (loom::%render-event-loop-frame
                                      (lambda (&rest arguments)
                                        (declare (ignore arguments))))
                                     (loom::%run-event-loop
                                      (make-string-output-stream)
                                      (make-string-input-stream "")))))
      (expect turns :to-be 2)))
(it
 "redraws resize wakes only when dimensions change or the frame is dirty"
 (let* ((*editor-state* (%fresh-full-editor-state ""))
        (loom/core/editor-session:*editor-session*
         (editor-state-session *editor-state*))
        (turn-status :timeout)
        (turn-dirty-p nil)
        (next-width 80)
        (next-height 24)
        (render-count 0)
        (buffer (make-array 16 :element-type '(unsigned-byte 8))))
   (expect
    (multiple-value-list
     (loom::%process-loom-wake-events :terminal-session
                                      (editor-state-session *editor-state*)
                                      (list 5)
                                      nil))
    :to-equal
    (list nil nil nil nil nil))
   (with-replaced-function
       (loom::%read-and-dispatch-event-loop-input
        (lambda (&rest arguments)
          (declare (ignore arguments))
          (values turn-status nil nil turn-dirty-p nil)))
     (with-replaced-function
         (loom::%poll-terminal-resize
          (lambda (&rest arguments)
            (declare (ignore arguments))
            (values next-width next-height)))
       (with-replaced-function
           (loom::%render-event-loop-frame
            (lambda (&rest arguments)
              (declare (ignore arguments))
              (incf render-count)))
         (loom::%run-event-loop-turn (make-string-output-stream)
                                     (make-string-input-stream "")
                                     buffer
                                     :decoder
                                     :keymap-state
                                     80
                                     24
                                     :terminal-session
                                     nil (constantly nil))
         (expect render-count :to-be 0)
         (setf next-width 100
               next-height 30)
         (loom::%run-event-loop-turn (make-string-output-stream)
                                     (make-string-input-stream "")
                                     buffer
                                     :decoder
                                     :keymap-state
                                     80
                                     24
                                     :terminal-session
                                     nil (constantly nil))
         (expect render-count :to-be 1)
         (setf turn-status :input)
         (loom::%run-event-loop-turn (make-string-output-stream)
                                     (make-string-input-stream "")
                                     buffer
                                     :decoder
                                     :keymap-state
                                     100
                                     30
                                     :terminal-session
                                     nil (constantly nil))
         (expect render-count :to-be 2)
         (setf turn-status :timeout
               turn-dirty-p t)
         (loom::%run-event-loop-turn (make-string-output-stream)
                                     (make-string-input-stream "")
                                     buffer
                                     :decoder
                                     :keymap-state
                                     100
                                     30
                                     :terminal-session
                                     nil (constantly nil))
         (expect render-count :to-be 3))))))


(it
 "passes decoded non-key input through default routing without key-input hooks"
 (let* ((*editor-state* (%fresh-full-editor-state ""))
        (loom/core/editor-session:*editor-session*
         (editor-state-session *editor-state*))
        (loom/core/editor-session::*session-hooks* (make-hash-table :test #'eq))
        (session (editor-state-session *editor-state*))
        (keymap-state :keymap)
        (event (cl-tty-kit:make-key-event :type :paste :code "pasted"))
        (input-event-count 0)
        (key-input-count 0)
        (default-action-ran nil))
   (loom/core/editor-session:register-session-hook :input-event
                                                   :feature/mouse
                                                   (lambda
                                                       (received-session
                                                        event-type
                                                        payload)
                                                     (expect received-session
                                                             :to-be
                                                             session)
                                                     (expect event-type
                                                             :to-be
                                                             :paste)
                                                     (expect payload
                                                             :to-equal
                                                             "pasted")
                                                     (incf input-event-count)
                                                     :pass))
   (loom/core/editor-session:register-session-hook :key-input
                                                   :feature/mouse
                                                   (lambda
                                                       (received-session
                                                        received-event
                                                        route)
                                                     (declare (ignore
                                                               received-session
                                                               received-event
                                                               route))
                                                     (incf key-input-count)
                                                     :pass))
   (with-replaced-function
    (cl-tty-kit:decode-input-chunk
     (lambda (decoder chunk)
       (declare (ignore decoder chunk))
       (list event)))
    (with-replaced-function
     (loom::%refresh-active-keymap
      (lambda (received-keymap-state)
        (expect received-keymap-state :to-be keymap-state)
        :active-keymap))
     (with-replaced-function
      (loom::%classify-key-event
       (lambda (received-event received-keymap-state active-keymap)
         (expect received-event :to-be event)
         (expect received-keymap-state :to-be keymap-state)
         (expect active-keymap :to-be :active-keymap)
         :decision))
      (with-replaced-function
       (loom::%dispatch-key-event-action
        (lambda (received-event received-keymap-state decision)
          (expect received-event :to-be event)
          (expect received-keymap-state :to-be keymap-state)
          (expect decision :to-be :decision)
          (setf default-action-ran t)
          :handled))
       (loom::%dispatch-input-chunk :decoder #() 0 keymap-state)))))
   (expect input-event-count :to-be 1)
   (expect key-input-count :to-be 0)
   (expect default-action-ran :to-be-truthy)))

(describe "%event-loop wake and render hooks"
          (it "terminates before reading input when a signal wake is ready"
              (let* ((*editor-state* (%fresh-full-editor-state ""))
                     (loom/core/editor-session::*session-hooks*
                      (make-hash-table :test (function eq)))
                     (loom/core/editor-session::*terminal-suspend-requests*
                      (make-hash-table :test (function eq)))
                     (session (editor-state-session *editor-state*))
                     (terminal-session :terminal-session)
                     (buffer
                      (make-array 16 :element-type (quote (unsigned-byte 8)))))
                (loom/core/editor-session:register-session-hook :signal
                                                                :feature/lifecycle
                                                                (lambda
                                                                    (received-session
                                                                     signal-name)
                                                                  (expect
                                                                   received-session
                                                                   :to-be
                                                                   session)
                                                                  (expect
                                                                   signal-name
                                                                   :to-be
                                                                   :term)
                                                                  :terminate))
                (with-replaced-function
                 (loom::%wait-for-editor-input
                  (lambda (stream received-terminal-session)
                    (declare (ignore stream))
                    (expect received-terminal-session :to-be terminal-session)
                    (values t t nil)))
                 (with-replaced-function
                  (loom::%drain-loom-terminal-wake
                   (lambda (received-terminal-session)
                     (expect received-terminal-session :to-be terminal-session)
                     (list 1)))
                  (with-replaced-function
                   (loom::%read-input-octets
                    (lambda (&rest arguments)
                      (declare (ignore arguments))
                      (error
                       "input must not be read after a terminating signal")))
                   (expect
                    (multiple-value-list
                     (loom::%read-and-dispatch-event-loop-input
                      (make-string-input-stream "")
                      buffer
                      :decoder
                      :keymap-state
                      terminal-session
                      nil))
                    :to-equal
                    (list :terminate :sigterm 143 nil nil)))))))
          (it
           "polls forced background turns without waiting and propagates dirty and ready flags"
           (let* ((*editor-state* (%fresh-full-editor-state ""))
                  (loom/core/editor-session::*background-work-states*
                   (make-hash-table :test (function eq)))
                  (loom/core/editor-session::*session-wake-functions*
                   (make-hash-table :test (function eq)))
                  (loom/core/editor-session::*terminal-suspend-requests*
                   (make-hash-table :test (function eq)))
                  (loom/core/editor-session::*session-hooks*
                   (make-hash-table :test (function eq)))
                  (session (editor-state-session *editor-state*))
                  (terminal-session :terminal-session)
                  (buffer
                   (make-array 16 :element-type (quote (unsigned-byte 8))))
                  (poll-count 0)
                  (token nil))
             (setf token (loom/core/editor-session:register-background-work
                          session
                          :feature/lsp
                          (lambda (received-session received-token)
                            (expect received-session :to-be session)
                            (expect received-token :to-be token)
                            (incf poll-count)
                            (if (= poll-count 1)
                                (progn
                                  (expect
                                   (loom/core/editor-session:notify-background-work-ready
                                    session
                                    token)
                                   :to-be
                                   :queued)
                                  (values t nil))
                                (values nil t)))
                          (lambda (received-session received-token)
                            (declare (ignore received-session received-token)))))
             (expect
              (loom/core/editor-session:notify-background-work-ready session
                                                                     token)
              :to-be
              :queued)
             (with-replaced-function
              (loom::%wait-for-editor-input
               (lambda (&rest arguments)
                 (declare (ignore arguments))
                 (error "forced polls must not wait for terminal input")))
              (with-replaced-function
               (loom::%drain-loom-terminal-wake
                (lambda (received-terminal-session)
                  (expect received-terminal-session :to-be terminal-session)
                  nil))
               (expect
                (multiple-value-list
                 (loom::%read-and-dispatch-event-loop-input
                  (make-string-input-stream "")
                  buffer
                  :decoder
                  :keymap-state
                  terminal-session
                  t))
                :to-equal
                (list :timeout nil nil t t))
               (expect
                (multiple-value-list
                 (loom::%read-and-dispatch-event-loop-input
                  (make-string-input-stream "")
                  buffer
                  :decoder
                  :keymap-state
                  terminal-session
                  t))
                :to-equal
                (list :timeout nil nil t nil))))
             (expect poll-count :to-be 2)))
          (it "marks the frame dirty after C-z and SIGTSTP suspend and resume"
              (let* ((*editor-state* (%fresh-full-editor-state ""))
                     (loom/core/editor-session::*session-hooks*
                      (make-hash-table :test (function eq)))
                     (loom/core/editor-session::*terminal-suspend-requests*
                      (make-hash-table :test (function eq)))
                     (loom/core/editor-session::*session-wake-functions*
                      (make-hash-table :test (function eq)))
                     (session (editor-state-session *editor-state*))
                     (suspend-count 0))
                (loom/core/editor-session:register-session-hook :signal
                                                                :feature/lifecycle
                                                                (lambda
                                                                    (received-session
                                                                     signal-name)
                                                                  (expect
                                                                   received-session
                                                                   :to-be
                                                                   session)
                                                                  (expect
                                                                   signal-name
                                                                   :to-be
                                                                   :tstp)
                                                                  :continue))
                (with-replaced-function
                 (loom::%suspend-loom-terminal-session
                  (lambda (received-session terminal-session)
                    (expect received-session :to-be session)
                    (expect terminal-session :to-be :terminal-session)
                    (incf suspend-count)
                    nil))
                 (expect
                  (loom/core/editor-session:request-terminal-suspend session)
                  :to-be
                  :queued)
                 (expect
                  (multiple-value-list
                   (loom::%process-loom-wake-events :terminal-session
                                                    session
                                                    nil
                                                    nil))
                  :to-equal
                  (list nil nil nil t nil))
                 (expect
                  (multiple-value-list
                   (loom::%process-loom-wake-events :terminal-session
                                                    session
                                                    (list 3)
                                                    nil))
                  :to-equal
                  (list nil nil nil t nil)))
                (expect suspend-count :to-be 2)))
          (it "applies render-hook operations through the callable dispatcher"
              (let* ((session (%make-test-editor-session))
                     (loom/core/editor-session::*session-hooks*
                      (make-hash-table :test (function eq)))
                     (snapshot
                      (loom/core/editor-session:make-frame-snapshot 3
                                                                    1
                                                                    #(("a" nil)
                                                                      ("b" nil)
                                                                      ("c" nil))))
                     (result nil))
                (loom/core/editor-session:register-session-hook :render
                                                                :feature/syntax-highlighting
                                                                (lambda
                                                                    (received-session
                                                                     received-snapshot)
                                                                  (expect
                                                                   received-session
                                                                   :to-be
                                                                   session)
                                                                  (expect
                                                                   received-snapshot
                                                                   :to-be
                                                                   snapshot)
                                                                  (list
                                                                   (loom/core/editor-session:make-render-operation
                                                                    :text
                                                                    1
                                                                    0
                                                                    "Z"))))
                (setf result (loom::%apply-render-session-hooks session
                                                                snapshot
                                                                (lambda (text)
                                                                  (values
                                                                   (vector text)
                                                                   (vector 1)))))
                (expect
                 (nth-value 0
                            (loom/core/editor-session:frame-snapshot-cell
                             snapshot
                             1
                             0))
                 :to-equal
                 "b")
                (expect
                 (nth-value 0
                            (loom/core/editor-session:frame-snapshot-cell result
                                                                          1
                                                                          0))
                 :to-equal
                 "Z")))
          (it
 "presents hook output after applying render-hook operations"
 (let* ((*editor-state* (%fresh-full-editor-state "abc"))
        (loom/core/editor-session::*session-hooks*
          (make-hash-table :test (function eq)))
        (session (editor-state-session *editor-state*))
        (hook-ran-p nil)
        (presented-row nil)
        (presented-cursor nil))
   (loom/core/editor-session:register-session-hook
    :render
    :feature/user-init
    (lambda (received-session snapshot)
      (expect received-session :to-be session)
      (expect (loom/core/editor-session:frame-snapshot-p snapshot) :to-be t)
      (setf hook-ran-p t)
      (list (loom/core/editor-session:make-render-operation :text 0 0 "Z")
            (loom/core/editor-session:make-render-operation
             :text 2 0 (format nil "~C!" #\Tab))
            (loom/core/editor-session:make-render-operation :cursor 2 0 t))))
   (with-replaced-function
    (loom/feature/terminal:poll-terminal-sessions
     (lambda (state) (declare (ignore state))))
    (with-replaced-function
     (loom:loom-renderer-present
      (lambda (renderer &key stream cursor)
        (declare (ignore renderer stream))
        (setf presented-cursor cursor
              presented-row
              (cl-tty-kit:screen-row-string
               (%layout-screen *editor-state*)
               0 :start 0 :end 9))))
     (loom::%render-event-loop-frame (make-string-output-stream) #'loom::%render-root-frame)))
   (expect hook-ran-p :to-be-truthy)
   (expect presented-row :to-equal "Zb      !")
   (expect (cl-tty-kit:cursor-x presented-cursor) :to-equal 2)
   (expect (cl-tty-kit:cursor-y presented-cursor) :to-equal 0))))
