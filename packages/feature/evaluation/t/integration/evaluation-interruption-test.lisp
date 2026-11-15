(in-package #:loom/test)

(defun %call-with-evaluation-pipe (function)
  "Call FUNCTION with a pipe's descriptors and a binary Lisp stream on its reader."
  (multiple-value-bind (read-fd write-fd) (sb-posix:pipe)
    (let ((stream (sb-sys:make-fd-stream read-fd
                                         :input t
                                         :element-type '(unsigned-byte 8)
                                         :buffering :full
                                         :auto-close nil)))
      ;; Closing the fd-stream also closes READ-FD.
      (unwind-protect (funcall function read-fd write-fd stream)
        (close stream)
        (sb-posix:close write-fd)))))

(defun %evaluation-octets (&rest parts)
  (apply (function concatenate)
         '(simple-array (unsigned-byte 8) (*))
         (mapcar (lambda (part)
                   (if (stringp part)
                       (sb-ext:string-to-octets part :external-format :utf-8)
                       (coerce part '(simple-array (unsigned-byte 8) (*)))))
                 parts)))

(defun %spawn-test-thread (function &key name)
  "Like SB-THREAD:MAKE-THREAD, but keep FUNCTION's error for %JOIN-TEST-THREAD.

An unhandled error on a test thread would otherwise end the whole test process
instead of failing the example."
  (sb-thread:make-thread
   (lambda ()
     (handler-case (cons :ok (funcall function))
       (serious-condition (condition)
         (cons :error condition))))
   :name name))

(defun %join-test-thread (thread)
  "Join THREAD from %SPAWN-TEST-THREAD and return its value, or fail the
current example with the thread's error."
  (destructuring-bind (kind . payload) (sb-thread:join-thread thread)
    (if (eq kind :error)
        (error "Test thread ~A failed: ~A" (sb-thread:thread-name thread) payload)
        payload)))

(defun %write-evaluation-octets-later (write-fd octets &optional (delay 0.05))
  "Write OCTETS to WRITE-FD from another thread after DELAY; return the thread
and a cell whose CAR receives the write time."
  (let ((written (list nil)))
    (values
     (%spawn-test-thread
      (lambda ()
        (sleep delay)
        (setf (car written) (get-internal-real-time))
        (cl-tty-kit:fd-write-octets write-fd octets))
      :name "loom evaluation test writer")
     written)))

(defun %evaluation-replay-items ()
  (car loom::*input-replay-queue*))

(defun %monitor-thread-count ()
  (count "cl-tty-kit input monitor"
         (sb-thread:list-all-threads)
         :key (function sb-thread:thread-name)
         :test (function equal)))

(defmacro %with-evaluation-dispatch-context ((decoder) &body body)
  ;; The termination signal stays global because signal requests in these
  ;; tests come from other threads, which do not see a dynamic binding.
  `(let ((loom::*input-dispatch-decoder* ,decoder)
         (loom::*input-replay-queue* (list nil)))
     (setf loom::*evaluation-termination-signal* nil)
     (unwind-protect (progn ,@body)
       (setf loom::*evaluation-termination-signal* nil))))

(defun %interrupting-full-editor-state (initial-content)
  (let* ((buffer (make-buffer :initial-content initial-content))
         (window-tree (make-window-tree buffer 80 24)))
    (make-editor-state :window-tree window-tree
                       :session (%make-test-editor-session (list buffer)
                                                           :window-tree window-tree)
                       :minibuffer (make-minibuffer)
                       :keymap (loom/application:install-default-keybindings
                                (make-keymap))
                       :file-tree (make-file-tree "/root/")
                       :renderer (make-loom-renderer 80 24)
                       :kill-ring nil)))

(defun %wait-for-evaluation-scope ()
  (loop repeat 400
        for state = loom::*active-evaluation-interruption*
        for scope = (and state (loom::%evaluation-interruption-scope state))
        when scope
          return scope
        do (sleep 0.005)))

(defun %request-active-evaluation-interruption ()
  "Request a keyboard interruption of the running evaluation the way the input
monitor does, including the delivery-time callback."
  (%wait-for-evaluation-scope)
  (loom::%request-evaluation-interruption loom::*active-evaluation-interruption*
                                          :reason :keyboard))

(describe
  "evaluation interruption through the input monitor"
  (it "interrupts a looping evaluation within 200ms and replays other keys without C-g"
    (%call-with-evaluation-pipe
     (lambda (read-fd write-fd stream)
       (%with-evaluation-dispatch-context
           ((cl-tty-kit:make-input-decoder :collect-bracketed-paste t))
         (multiple-value-bind (writer written)
             (%write-evaluation-octets-later write-fd (%evaluation-octets "a" #(7) "b"))
           (multiple-value-bind (status reason)
               (loom::%call-with-evaluation-interruption
                read-fd stream (lambda () (loop)))
             (let ((returned (get-internal-real-time)))
               (%join-test-thread writer)
               (expect status :to-be :interrupted)
               (expect reason :to-be :keyboard)
               (expect (< (/ (- returned (car written)) internal-time-units-per-second)
                          0.2)
                       :to-be-truthy)
               (expect (%evaluation-replay-items)
                       :to-equalp (list (cons :octets (%evaluation-octets "ab"))))
               (expect loom::*active-evaluation-interruption* :to-be nil))))))))

  (it "accepts the CSI-u form of C-g"
    (%call-with-evaluation-pipe
     (lambda (read-fd write-fd stream)
       (%with-evaluation-dispatch-context
           ((cl-tty-kit:make-input-decoder :collect-bracketed-paste t))
         (let ((writer (%write-evaluation-octets-later
                        write-fd (%evaluation-octets (format nil "~C[103;5u" #\Esc)))))
           (multiple-value-bind (status reason)
               (loom::%call-with-evaluation-interruption
                read-fd stream (lambda () (loop)))
             (%join-test-thread writer)
             (expect status :to-be :interrupted)
             (expect reason :to-be :keyboard)
             (expect (%evaluation-replay-items)
                     :to-equalp (list (cons :octets (%evaluation-octets))))))))))

  (it "is not caught by handler-case or ignore-errors in the evaluated code"
    (%call-with-evaluation-pipe
     (lambda (read-fd write-fd stream)
       (%with-evaluation-dispatch-context
           ((cl-tty-kit:make-input-decoder :collect-bracketed-paste t))
         (let ((writer (%write-evaluation-octets-later write-fd (%evaluation-octets #(7)))))
           (multiple-value-bind (status reason)
               (loom::%call-with-evaluation-interruption
                read-fd stream
                (lambda ()
                  (handler-case (loop (ignore-errors (sleep 0.01)))
                    (error () :caught))))
             (%join-test-thread writer)
             (expect status :to-be :interrupted)
             (expect reason :to-be :keyboard)))))))

  (it "does not interrupt for 0x07 inside a bracketed paste"
    (%call-with-evaluation-pipe
     (lambda (read-fd write-fd stream)
       (%with-evaluation-dispatch-context
           ((cl-tty-kit:make-input-decoder :collect-bracketed-paste t))
         (let* ((paste (%evaluation-octets (format nil "~C[200~~p" #\Esc) #(7)
                                           (format nil "q~C[201~~" #\Esc)))
                (writer (%write-evaluation-octets-later write-fd paste)))
           (multiple-value-bind (status values)
               (loom::%call-with-evaluation-interruption
                read-fd stream (lambda () (sleep 0.3) :done))
             (%join-test-thread writer)
             (expect status :to-be :completed)
             (expect values :to-equal '(:done))
             (expect (%evaluation-replay-items)
                     :to-equalp (list (cons :octets paste)))))))))

  (it "continues a pending paste and partial UTF-8 from the dispatch decoder"
    (%call-with-evaluation-pipe
     (lambda (read-fd write-fd stream)
       (let ((decoder (cl-tty-kit:make-input-decoder :collect-bracketed-paste t)))
         (expect (cl-tty-kit:decode-input-chunk
                  decoder (%evaluation-octets (format nil "~C[200~~x" #\Esc) #(227 129)))
                 :to-be nil)
         (%with-evaluation-dispatch-context (decoder)
           (let ((writer (%write-evaluation-octets-later
                          write-fd
                          (%evaluation-octets #(130) #(7) (format nil "~C[201~~" #\Esc) #(7)))))
             (multiple-value-bind (status reason)
                 (loom::%call-with-evaluation-interruption
                  read-fd stream (lambda () (loop)))
               (%join-test-thread writer)
               (expect status :to-be :interrupted)
               (expect reason :to-be :keyboard)
               (let ((items (%evaluation-replay-items)))
                 (expect (length items) :to-equal 1)
                 (expect (car (first items)) :to-be :octets)
                 (let ((events (cl-tty-kit:decode-input-chunk decoder (cdr (first items)))))
                   (expect (length events) :to-equal 1)
                   (expect (cl-tty-kit:key-event-type (first events)) :to-be :paste)
                   (expect (cl-tty-kit:key-event-code (first events))
                           :to-equal (format nil "xあ~C" (code-char 7))))))))))))

  (it "replays bytes buffered by the Lisp stream before bytes read by the monitor"
    (%call-with-evaluation-pipe
     (lambda (read-fd write-fd stream)
       (let ((decoder (cl-tty-kit:make-input-decoder :collect-bracketed-paste t)))
         (cl-tty-kit:fd-write-octets write-fd (%evaluation-octets "xyz"))
         (expect (read-byte stream) :to-equal (char-code #\x))
         (%with-evaluation-dispatch-context (decoder)
           (multiple-value-bind (status values)
               (loom::%call-with-evaluation-interruption
                read-fd stream
                (lambda ()
                  (cl-tty-kit:fd-write-octets write-fd (%evaluation-octets "w"))
                  (sleep 0.2)
                  42))
             (expect status :to-be :completed)
             (expect values :to-equal '(42))
             (let ((items (%evaluation-replay-items)))
               (expect (mapcar (function car) items) :to-equal '(:events :octets))
               (expect (mapcar (function cl-tty-kit:key-event-code) (cdr (first items)))
                       :to-equal '(#\y #\z))
               (expect (cdr (second items)) :to-equalp (%evaluation-octets "w")))))))))

  (it "creates one monitor thread only while an evaluation runs"
    (%call-with-evaluation-pipe
     (lambda (read-fd write-fd stream)
       (declare (ignore write-fd))
       (%with-evaluation-dispatch-context
           ((cl-tty-kit:make-input-decoder :collect-bracketed-paste t))
         (let ((before (%monitor-thread-count))
               (during nil))
           (multiple-value-bind (status values)
               (loom::%call-with-evaluation-interruption
                read-fd stream
                (lambda () (setf during (%monitor-thread-count)) :done))
             (expect status :to-be :completed)
             (expect values :to-equal '(:done))
             (expect during :to-equal (1+ before))
             (expect (%monitor-thread-count) :to-equal before)))))))

  (it "runs a nested evaluation inside the outer scope without another monitor"
    (%call-with-evaluation-pipe
     (lambda (read-fd write-fd stream)
       (declare (ignore write-fd))
       (%with-evaluation-dispatch-context
           ((cl-tty-kit:make-input-decoder :collect-bracketed-paste t))
         (let ((outer-count nil)
               (inner nil))
           (multiple-value-bind (status values)
               (loom::%call-with-evaluation-interruption
                read-fd stream
                (lambda ()
                  (setf outer-count (%monitor-thread-count)
                        inner
                        (multiple-value-list
                         (loom::%call-with-evaluation-interruption
                          read-fd stream
                          (lambda () (%monitor-thread-count)))))
                  :outer))
             (expect status :to-be :completed)
             (expect values :to-equal '(:outer))
             (expect inner :to-equal (list :completed (list outer-count)))))))))

  (it "interrupts without a monitor outside input dispatch"
    (let ((requester
            (%spawn-test-thread
             (lambda ()
               (cl-concurrent-kit:request-interruption
                (%wait-for-evaluation-scope) :reason :probe))
             :name "loom evaluation test requester")))
      (multiple-value-bind (status reason)
          (let ((loom::*evaluation-termination-signal* nil))
            (loom::%call-with-evaluation-interruption nil nil (lambda () (loop))))
        (%join-test-thread requester)
        (expect status :to-be :interrupted)
        (expect reason :to-be :probe)))))

(describe
  "evaluation interruption by termination signals"
  (it "ignores a signal request when no evaluation runs"
    (let ((loom::*evaluation-termination-signal* nil)
          (started nil))
      (expect (loom::%request-evaluation-signal-interruption
               1 (lambda (state byte) (setf started (list state byte))))
              :to-be nil)
      (expect loom::*evaluation-termination-signal* :to-be nil)
      (expect started :to-be nil)))

  (it "keeps the termination signal when a later forced C-g replaces the reason"
    (%call-with-evaluation-pipe
     (lambda (read-fd write-fd stream)
       (%with-evaluation-dispatch-context
           ((cl-tty-kit:make-input-decoder :collect-bracketed-paste t))
         (let* ((started nil)
                (signaller
                  (%spawn-test-thread
                   (lambda ()
                     (%wait-for-evaluation-scope)
                     (loom::%request-evaluation-signal-interruption
                      1 (lambda (state byte) (setf started (list state byte))))
                     (sleep 0.05)
                     (cl-tty-kit:fd-write-octets write-fd (%evaluation-octets #(7))))
                   :name "loom evaluation test signaller")))
           (multiple-value-bind (status reason)
               (loom::%call-with-evaluation-interruption
                read-fd stream
                ;; The cleanup blocks after the signal's transfer; only the
                ;; forced C-g can abandon it.
                (lambda () (unwind-protect (loop) (sleep 5))))
             (%join-test-thread signaller)
             (expect status :to-be :interrupted)
             (expect reason :to-be :keyboard)
             (expect loom::*evaluation-termination-signal* :to-equal 1)
             (expect (second started) :to-equal 1)
             (expect (loom::%evaluation-interruption-p (first started)) :to-be-truthy)
             (expect (%evaluation-replay-items)
                     :to-equalp (list (cons :octets (%evaluation-octets))))))))))

  (it "returns interrupted without evaluating after a termination signal"
    (let ((called nil))
      (multiple-value-bind (status reason)
          (let ((loom::*evaluation-termination-signal* 2))
            (loom::%call-with-evaluation-interruption
             nil nil (lambda () (setf called t))))
        (expect status :to-be :interrupted)
        (expect reason :to-be :sighup)
        (expect called :to-be nil))))

  (it "stops dispatching input once a termination signal is pending"
    (let* ((*editor-state* (%interrupting-full-editor-state ""))
           (loom/core/editor-session:*editor-session*
             (editor-state-session *editor-state*))
           (decoder (cl-tty-kit:make-input-decoder :collect-bracketed-paste t))
           (keymap-state (make-keymap-state (editor-state-keymap *editor-state*)))
           (octets (%evaluation-octets "abc")))
      (let ((loom::*evaluation-termination-signal* 1))
        (loom::%dispatch-input-chunk decoder octets (length octets) keymap-state))
      (expect (buffer-text (%selected-test-buffer)) :to-equal "")))

  (it "runs the session shutdown once when the watchdog claims the exit first"
    (let* ((shutdowns 0)
           (waited nil)
           (state (loom::%make-evaluation-interruption))
           (starter (loom::%evaluation-exit-watchdog-starter
                     :terminal
                     :grace-seconds 0.01
                     :exit-function
                     (lambda (editor-state terminal byte)
                       (declare (ignore editor-state))
                       (expect terminal :to-be :terminal)
                       (expect byte :to-equal 1)
                       (incf shutdowns)))))
      (sb-thread:join-thread (funcall starter state 1))
      ;; The returning evaluation loses the claim and must not reach the
      ;; loop's shutdown; WAIT-FUNCTION stands in for waiting on _exit.
      (loom::%settle-evaluation-exit state (lambda () (setf waited t)))
      (unless waited
        (incf shutdowns))
      (expect waited :to-be-truthy)
      (expect shutdowns :to-equal 1)))

  (it "runs the session shutdown once when the evaluation returns before the watchdog"
    (let* ((shutdowns 0)
           (waited nil)
           (state (loom::%make-evaluation-interruption))
           (starter (loom::%evaluation-exit-watchdog-starter
                     :terminal
                     :grace-seconds 0.01
                     :exit-function
                     (lambda (editor-state terminal byte)
                       (declare (ignore editor-state terminal byte))
                       (incf shutdowns)))))
      (loom::%settle-evaluation-exit state (lambda () (setf waited t)))
      (unless waited
        ;; The loop's own shutdown path runs after the evaluation returns.
        (incf shutdowns))
      (sb-thread:join-thread (funcall starter state 2))
      (expect waited :to-be nil)
      (expect shutdowns :to-equal 1)))

  (it "finishes the session from the watchdog thread with recovery and the signal status"
    (dolist (case '((1 143 :sigterm) (2 129 :sighup)))
      (destructuring-bind (byte expected-status reason) case
        (host-kit:with-temporary-directory (directory)
          (let* ((state (%interrupting-full-editor-state "watchdog-recovery"))
                 (terminal-session (loom::%open-loom-terminal-session nil nil))
                 (statuses nil))
            (loom/core/buffer:buffer-mark-modified
             (window-buffer (window-tree-selected-window
                             (editor-state-window-tree state))))
            ;; A fresh thread sees no dynamic binding from this one, as on the
            ;; real watchdog thread. The state directory is bound inside the
            ;; thread because the executable sets it globally at startup.
            (%join-test-thread
             (%spawn-test-thread
              (lambda ()
                (let ((loom/feature/lifecycle:*loom-state-directory* (pathname directory)))
                  (loom::%exit-after-stuck-evaluation
                   state terminal-session byte
                   :exit (lambda (status) (push status statuses)))))
              :name "loom evaluation exit test"))
            (expect statuses :to-equal (list expected-status))
            (let ((files (directory (merge-pathnames "recovery/*.txt" directory))))
              (expect (length files) :to-equal 1)
              (expect (search (format nil "buffer-~(~A~)" reason)
                              (file-namestring (first files)))
                      :to-be-truthy)
              (expect (uiop:read-file-string (first files))
                      :to-equal "watchdog-recovery")))))))

  (it "grants the exit claim to exactly one of two racing claimants"
    (loop repeat 50
          do (let* ((state (loom::%make-evaluation-interruption))
             (results (list nil nil))
             (threads
               (loop for claimant in '(:evaluation :watchdog)
                     for index from 0
                     collect (let ((claimant claimant) (index index))
                               (%spawn-test-thread
                                (lambda ()
                                  (setf (nth index results)
                                        (loom::%claim-evaluation-exit state claimant)))
                                :name "loom evaluation exit claimant")))))
        (mapc (function %join-test-thread) threads)
        (expect (count t results) :to-equal 1)
        (expect (loom::%evaluation-interruption-exit-claim state)
                :to-be (if (first results) :evaluation :watchdog))))))

(defvar *partial-output-written* nil
  "Semaphore the evaluated source signals after writing its partial output.")

(describe
  "interrupted evaluation results"
  (it "keeps partial standard output and reports the interruption"
    ;; Request only after the evaluated code has written its output; the scope
    ;; exists before the first form runs.
    (let* ((*partial-output-written* (sb-thread:make-semaphore))
           (written *partial-output-written*)
           (requester
             (%spawn-test-thread
              (lambda ()
                (unless (sb-thread:wait-on-semaphore written :timeout 5)
                  (error "Evaluation did not write its partial output"))
                (%request-active-evaluation-interruption))
              :name "loom evaluation test requester")))
      (let ((result
              (let ((loom::*evaluation-termination-signal* nil))
                (evaluate-lisp-source
                 "(format t \"partial~%\")
                  (sb-thread:signal-semaphore loom/test::*partial-output-written*)
                  (loop)"
                 :call-with-interruption
                 (lambda (thunk &key on-interrupt)
                   (loom::%call-with-evaluation-interruption
                    nil nil thunk on-interrupt))))))
        (%join-test-thread requester)
        (expect (evaluation-result-interrupted-p result) :to-be-truthy)
        (expect (evaluation-result-success-p result) :to-be nil)
        (expect (evaluation-result-error-message result) :to-be nil)
        (expect (evaluation-result-output result) :to-equal (format nil "partial~%"))
        (expect (evaluation-result-text result)
                :to-equal (format nil "Output:~%partial~%Evaluation interrupted~%")))))

  (it "keeps error output empty when the interruption reaches running code"
    ;; The semaphore is signalled by the running form itself, so the request
    ;; arrives after this form's compilation has finished.
    (let* ((*partial-output-written* (sb-thread:make-semaphore))
           (written *partial-output-written*)
           (requester
             (%spawn-test-thread
              (lambda ()
                (unless (sb-thread:wait-on-semaphore written :timeout 5)
                  (error "Evaluation did not start running"))
                (%request-active-evaluation-interruption))
              :name "loom evaluation test requester")))
      (let ((result
              (let ((loom::*evaluation-termination-signal* nil))
                (evaluate-lisp-source
                 "(progn
                    (sb-thread:signal-semaphore loom/test::*partial-output-written*)
                    (loop))"
                 :call-with-interruption
                 (lambda (thunk &key on-interrupt)
                   (loom::%call-with-evaluation-interruption
                    nil nil thunk on-interrupt))))))
        (%join-test-thread requester)
        (expect (evaluation-result-interrupted-p result) :to-be-truthy)
        (expect (evaluation-result-error-output result) :to-equal "")
        (expect (evaluation-result-text result)
                :to-equal (format nil "Evaluation interrupted~%")))))

  (it "drops only SBCL's aborted-compilation summary after user error output"
    (let* ((*partial-output-written* (sb-thread:make-semaphore))
           (written *partial-output-written*)
           (requester
             (%spawn-test-thread
              (lambda ()
                (unless (sb-thread:wait-on-semaphore written :timeout 5)
                  (error "Evaluation did not write its error output"))
                (%request-active-evaluation-interruption))
              :name "loom evaluation test requester")))
      (let ((result
              (let ((loom::*evaluation-termination-signal* nil))
                (evaluate-lisp-source
                 "(format *error-output* \"user-warning~%\")
                  (sb-thread:signal-semaphore loom/test::*partial-output-written*)
                  (loop)"
                 :call-with-interruption
                 (lambda (thunk &key on-interrupt)
                   (loom::%call-with-evaluation-interruption
                    nil nil thunk on-interrupt))))))
        (%join-test-thread requester)
        (expect (evaluation-result-interrupted-p result) :to-be-truthy)
        (expect (evaluation-result-error-output result)
                :to-equal (format nil "user-warning~%")))))

  (it "shows Evaluation interrupted for eval-buffer and C-x C-e"
    (dolist (command (list (function eval-buffer) (function eval-last-sexp)))
      (let* ((state (%fresh-editor-state "(loop)" :with-minibuffer t))
             (source-buffer (window-buffer
                             (window-tree-selected-window
                              (editor-state-window-tree state))))
             (minibuffer (editor-state-minibuffer state)))
        (loom/core/buffer:buffer-set-point source-buffer 0 6)
        (let ((*editor-state* state)
              (loom/core/editor-session:*editor-session*
                (loom/core/editor-session:editor-state-session state)))
          (loom/core/editor-session:set-evaluation-interrupter
           (lambda (thunk on-interrupt)
             (declare (ignore thunk on-interrupt))
             (values :interrupted :keyboard)))
          (unwind-protect (funcall command)
            (loom/core/editor-session:set-evaluation-interrupter nil))
          (expect (loom:minibuffer-message-string minibuffer)
                  :to-equal "Evaluation interrupted")
          (expect (buffer-text source-buffer) :to-equal "(loop)")))))

  (it "calls the thunk directly when no interrupter is installed"
    (multiple-value-bind (status values)
        (loom/core/editor-session:call-with-evaluation-interrupter
         (lambda () (values 1 2)))
      (expect status :to-be :completed)
      (expect values :to-equal '(1 2)))))

(describe
  "evaluation interruption through terminal dispatch"
  (it "dispatches keys typed during M-: after the evaluation in typing order"
    (%call-with-evaluation-pipe
     (lambda (read-fd write-fd stream)
       (let* ((*editor-state* (%interrupting-full-editor-state ""))
              (loom/core/editor-session:*editor-session*
                (editor-state-session *editor-state*))
              (decoder (cl-tty-kit:make-input-decoder :collect-bracketed-paste t))
              (keymap-state (make-keymap-state (editor-state-keymap *editor-state*)))
              (keys (%evaluation-octets (format nil "~C:(progn (sleep 0.3) 42)~C" #\Esc #\Return)))
              (writer (%write-evaluation-octets-later
                       write-fd (%evaluation-octets "xy") 0.1)))
         (loom/core/editor-session:set-evaluation-interrupter
          (lambda (thunk on-interrupt)
            (loom::%call-with-evaluation-interruption
             read-fd stream thunk on-interrupt)))
         (unwind-protect
              (let ((loom::*evaluation-termination-signal* nil))
                (loom::%dispatch-input-chunk decoder keys (length keys) keymap-state))
           (loom/core/editor-session:set-evaluation-interrupter nil)
           (%join-test-thread writer))
         (expect (buffer-text (%selected-test-buffer)) :to-equal "xy"))))))
