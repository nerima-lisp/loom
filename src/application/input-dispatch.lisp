(in-package #:loom)

(defun %drain-buffered-octets (buffer start-count input-stream)
  "Read the octets already waiting on INPUT-STREAM into BUFFER, filling it
from index START-COUNT onwards and stopping at (LENGTH BUFFER) octets or as
soon as LISTEN reports nothing more is buffered -- so this never blocks.
Returns the resulting octet count."
  (loop with
        count = start-count
        while (and (< count (length buffer)) (listen input-stream))
        do (let ((byte (read-byte input-stream nil nil)))
             (unless byte
               (loop-finish))
             (setf (aref buffer count) byte)
             (incf count))
        finally (return count)))

(defun %read-input-octets (buffer input-stream)
  "Block until at least one octet is available on INPUT-STREAM, then
drain any additional octets already buffered (checked via LISTEN, so this
never blocks a second time) into BUFFER, up to (LENGTH BUFFER) octets total.
Returns the number of octets actually placed in BUFFER, or NIL at
end-of-file (no octet was read at all)."
  (let ((first (read-byte input-stream nil nil)))
    (when first
      (setf (aref buffer 0) first)
      (%drain-buffered-octets buffer 1 input-stream))))

(defvar *input-dispatch-decoder* nil
  "Decoder of the chunk being dispatched; an evaluation monitor takes its pending input.")

(defvar *input-replay-queue* nil
  "Cons whose CAR holds (:EVENTS . events) and (:OCTETS . octets) items in input order.

Items arrive while an evaluation runs and are dispatched after the current events.")

(defvar *active-evaluation-interruption* nil
  "The running evaluation's interruption state, shared with signal handlers and
the input monitor thread. It is assigned, never rebound, so other threads see it.")

(defvar *evaluation-termination-signal* nil
  "Wake byte 1 (SIGTERM) or 2 (SIGHUP) received during an evaluation, or NIL.

This is kept apart from the interruption reason, which a later forced C-g
replaces, so the loop still terminates with the signal's status.")

(defstruct (%evaluation-interruption
            (:constructor %make-evaluation-interruption
                (&optional on-interrupt
                 &aux (thread sb-thread:*current-thread*)))
            (:copier nil))
  (scope nil)
  ;; The evaluating thread and the evaluator's function that records state at
  ;; the moment an interruption is delivered; see %REQUEST-EVALUATION-INTERRUPTION.
  (thread nil)
  (on-interrupt nil)
  (keyboard-requests 0)
  ;; NIL until the evaluation's end or the D20 watchdog claims the right to
  ;; finish the session; see %CLAIM-EVALUATION-EXIT.
  (exit-claim nil))

(defun %claim-evaluation-exit (state claimant)
  "Atomically record CLAIMANT as the one side that finishes the session after
STATE's evaluation; return true only for the first claimant."
  (null (sb-ext:compare-and-swap (%evaluation-interruption-exit-claim state)
                                 nil
                                 claimant)))

(defun %wait-for-watchdog-exit ()
  ;; The watchdog runs the shutdown and exit-status hooks and then calls
  ;; _exit; it needs nothing from this thread, so waiting cannot deadlock.
  (loop (sleep 1)))

(defun %settle-evaluation-exit (state &optional
                                      (wait-function
                                       (function %wait-for-watchdog-exit)))
  "Claim the session finish for the returning evaluation, or wait for the
watchdog that already claimed it, so the :SHUTDOWN hooks run only once."
  (unless (%claim-evaluation-exit state :evaluation)
    (funcall wait-function)))

(defun %enqueue-input-replay (kind payload)
  (setf (car *input-replay-queue*)
        (append (car *input-replay-queue*) (list (cons kind payload)))))

(defun %evaluation-termination-reason (byte)
  (if (eql byte 1) :sigterm :sighup))

(defun %evaluation-quit-event-p (event)
  (and (typep event 'cl-tty-kit:key-event)
       (string= "C-g" (cl-tty-kit:key-event->string event))))

(defun %request-evaluation-interruption (state &key reason force)
  "Request interruption of STATE's scope, first queueing its ON-INTERRUPT.

SB-THREAD:INTERRUPT-THREAD runs a thread's interruptions first in, first out
(SBCL code/target-thread.lisp: INTERRUPT-THREAD's docstring, %INTERRUPT-THREAD
appends, RUN-INTERRUPTION pops). cl-concurrent-kit delivers an accepted request
as another INTERRUPT-THREAD function that unwinds to the scope boundary, and it
signals OPERATION-INTERRUPTED only after that unwind (src/timeout.lisp
%CALL-WITH-INTERRUPTIBLE-SCOPE). Queueing ON-INTERRUPT before every request
therefore runs it on the evaluating thread before any cleanup the transfer
unwinds, including SBCL's compilation-unit summary. The request stays the
last operation, as signal handlers require."
  (let ((scope (%evaluation-interruption-scope state))
        (on-interrupt (%evaluation-interruption-on-interrupt state)))
    (when (and scope on-interrupt)
      (sb-thread:interrupt-thread (%evaluation-interruption-thread state)
                                  on-interrupt))
    (cl-concurrent-kit:request-interruption scope :reason reason :force force)))

(defun %request-evaluation-keyboard-interruption (state)
  "Request interruption for one C-g on the monitor thread; :CONSUME drops its bytes.

The first C-g is an ordinary request so evaluated cleanup runs. A later C-g, or
one after a termination signal's request, forces the transfer through blocked
or replacing cleanup."
  (sb-thread:barrier (:read))
  (let ((scope (%evaluation-interruption-scope state)))
    (when (and scope
               (%request-evaluation-interruption
                state
                :reason :keyboard
                :force (or (plusp (%evaluation-interruption-keyboard-requests state))
                           (not (null *evaluation-termination-signal*)))))
      (incf (%evaluation-interruption-keyboard-requests state))
      :consume)))

(defun %request-evaluation-signal-interruption (byte start-exit-watchdog)
  "Interrupt the running evaluation for wake BYTE 1 or 2.

Call this as the last operation of a signal handler: an accepted request can be
delivered as soon as interrupts are enabled again. START-EXIT-WATCHDOG receives
the state and BYTE when the first termination signal arrives."
  (let ((state *active-evaluation-interruption*))
    (when state
      (unless *evaluation-termination-signal*
        (setf *evaluation-termination-signal* byte)
        (sb-thread:barrier (:memory))
        (funcall start-exit-watchdog state byte))
      (%request-evaluation-interruption
       state
       :reason (%evaluation-termination-reason byte)
       :force t))))

(defun %call-in-evaluation-scope (state thunk)
  "Run THUNK in an interruptible scope outside the evaluator's error handlers."
  (handler-case
      (cl-concurrent-kit:with-interruptible-scope (scope)
        (setf (%evaluation-interruption-scope state) scope)
        (sb-thread:barrier (:memory))
        ;; A termination signal that arrived before the scope existed found no
        ;; scope to request, so it is honored here instead.
        (if *evaluation-termination-signal*
            (values :interrupted
                    (%evaluation-termination-reason *evaluation-termination-signal*))
            (values :completed (multiple-value-list (funcall thunk)))))
    (cl-concurrent-kit:operation-interrupted (condition)
      (values :interrupted
              (cl-concurrent-kit:operation-interrupted-reason condition)))))

(defun %drain-lisp-buffered-input (input-stream)
  "Return the octets INPUT-STREAM can deliver without blocking, including its buffer."
  (let ((buffer (make-array 4096 :element-type '(unsigned-byte 8)))
        (chunks nil))
    (loop for count = (%drain-buffered-octets buffer 0 input-stream)
          while (plusp count)
          do (push (subseq buffer 0 count) chunks)
          while (= count (length buffer)))
    (apply (function concatenate)
           '(vector (unsigned-byte 8))
           (nreverse chunks))))

(defun %call-with-monitored-evaluation (state fd input-stream thunk)
  (let ((decoder *input-dispatch-decoder*)
        (buffered (%drain-lisp-buffered-input input-stream)))
    ;; Bytes already read by the Lisp stream precede everything the monitor
    ;; reads from FD; decoding them first also leaves the decoder's pending
    ;; state as the monitor's starting state.
    (when (plusp (length buffered))
      (%enqueue-input-replay :events
                             (cl-tty-kit:decode-input-chunk decoder buffered)))
    (multiple-value-bind (retained body-values)
        (cl-tty-kit:call-with-input-monitor
         fd
         (lambda () (%call-in-evaluation-scope state thunk))
         (lambda (event)
           (when (%evaluation-quit-event-p event)
             (%request-evaluation-keyboard-interruption state)))
         :decoder decoder
         ;; ON-FINISH also runs on a nonlocal exit; it is the only replay
         ;; reference, and it runs with interrupts inhibited, so it only queues.
         :on-finish (lambda (octets) (%enqueue-input-replay :octets octets)))
      (declare (ignore retained))
      (values-list body-values))))

(defun %call-with-evaluation-interruption (fd input-stream thunk
                                           &optional on-interrupt)
  "Evaluate THUNK interruptibly, monitoring FD for C-g during input dispatch.

Return :COMPLETED and THUNK's values as a list, or :INTERRUPTED and the reason.
ON-INTERRUPT runs on this thread when an interruption is delivered, before the
unwind. A nested evaluation runs inside the outer one's scope and monitor."
  (if *active-evaluation-interruption*
      (values :completed (multiple-value-list (funcall thunk)))
      (let ((state (%make-evaluation-interruption on-interrupt)))
        (unwind-protect
            (progn
              (setf *active-evaluation-interruption* state)
              (sb-thread:barrier (:memory))
              (if (and fd *input-dispatch-decoder* *input-replay-queue*)
                  (%call-with-monitored-evaluation state fd input-stream thunk)
                  (%call-in-evaluation-scope state thunk)))
          (%settle-evaluation-exit state)
          (setf *active-evaluation-interruption* nil)))))

(defun %dispatch-input-events (events keymap-state)
  "Route decoded key and mouse EVENTS until a termination signal is pending."
  (let ((session (editor-state-session *editor-state*)))
    (dolist (event events)
      (when *evaluation-termination-signal*
        (return))
      (cond
        ((typep event 'cl-tty-kit:mouse-event)
         (handler-case
             (loom/core/editor-session:run-session-hooks
              :input-event
              session
              :mouse
              event)
           (error (condition)
             (minibuffer-message (editor-state-minibuffer *editor-state*)
                                 (princ-to-string condition)))))
        ((typep event 'cl-tty-kit:key-event)
         (let ((event-type (cl-tty-kit:key-event-type event)))
           (if (member event-type (quote (:character :special)) :test (function eq))
               (%dispatch-key-event event keymap-state)
               (handler-case
                   (let ((result
                           (loom/core/editor-session:run-session-hooks
                            :input-event
                            session
                            event-type
                            (if (eq event-type :paste)
                                (or (cl-tty-kit:key-event-text event)
                                    (cl-tty-kit:key-event-code event))
                                (cl-tty-kit:key-event-code event)))))
                     (when (eq result :pass)
                       (%dispatch-key-event event keymap-state nil)))
                 (error (condition)
                   (minibuffer-message (editor-state-minibuffer *editor-state*)
                                       (princ-to-string condition)))))))
        (t
         (let ((logger
                 (log-kit:make-logger
                  :name "loom.input"
                  :handler (log-kit:make-text-handler :stream *error-output*)
                  :level log-kit:+level-warn+)))
           (log-kit:log-warn logger
                             "Discarding unsupported input event"
                             :event-type (type-of event))))))))

(defun %dispatch-input-chunk (decoder buffer count keymap-state)
  "Decode octets and route key and mouse events.

Input read while an evaluation ran is dispatched after the chunk's own events,
in arrival order, through the same DECODER."
  (let* ((chunk
           (if (= count (length buffer))
               buffer
               (subseq buffer 0 count)))
         (*input-dispatch-decoder* decoder)
         (*input-replay-queue* (list nil)))
    (%dispatch-input-events (cl-tty-kit:decode-input-chunk decoder chunk)
                            keymap-state)
    (loop for item = (pop (car *input-replay-queue*))
          while (and item (not *evaluation-termination-signal*))
          do (%dispatch-input-events
              (if (eq (car item) :events)
                  (cdr item)
                  (cl-tty-kit:decode-input-chunk decoder (cdr item)))
              keymap-state))))
