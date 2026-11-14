(in-package #:loom/test)

(defun %call-with-input-monitor-probe-pipe (function)
  (multiple-value-bind (read-fd write-fd) (sb-posix:pipe)
    (unwind-protect
         (funcall function read-fd write-fd)
      (sb-posix:close read-fd)
      (sb-posix:close write-fd))))

(describe "cl-tty-kit input monitor consumer contract"
  (it "replays monitored UTF-8 after pending input through loom dispatch"
    (%call-with-input-monitor-probe-pipe
     (lambda (read-fd write-fd)
       (let* ((caller sb-thread:*current-thread*)
              (ready (sb-thread:make-semaphore))
              (payload (sb-ext:string-to-octets "aあz" :external-format :utf-8))
              (helper nil)
              (finish-thread nil)
              (finished nil)
              (finish-count 0))
         (multiple-value-bind (octets body-values)
             (cl-tty-kit:call-with-input-monitor
              read-fd
              (lambda ()
                (expect sb-thread:*current-thread* :to-be caller)
                (expect (cl-tty-kit:fd-write-octets write-fd payload)
                        :to-equal (length payload))
                (expect (sb-thread:wait-on-semaphore ready :timeout 2)
                        :to-be-truthy)
                (values :normal 42))
              (lambda (event)
                (setf helper sb-thread:*current-thread*)
                (when (eql #\z (cl-tty-kit:key-event-code event))
                  (sb-thread:signal-semaphore ready)))
              :on-finish
              (lambda (octets)
                (incf finish-count)
                (setf finished octets
                      finish-thread sb-thread:*current-thread*)))
           (expect octets :to-equalp payload)
           (expect finished :to-be octets)
           (expect finish-count :to-equal 1)
           (expect finish-thread :to-be caller)
           (expect body-values :to-equal '(:normal 42))
           (expect helper :to-be-truthy)
           (expect (eq helper caller) :to-be nil)
           (expect (sb-thread:thread-alive-p helper) :to-be nil)
           (let* ((*editor-state* (%fresh-full-editor-state ""))
                  (loom/core/editor-session:*editor-session*
                    (editor-state-session *editor-state*))
                  (decoder (cl-tty-kit:make-input-decoder
                            :collect-bracketed-paste t))
                  (keymap-state (make-keymap-state
                                 (editor-state-keymap *editor-state*))))
             (loom::%dispatch-input-chunk decoder #(112) 1 keymap-state)
             (loom::%dispatch-input-chunk decoder octets (length octets)
                                         keymap-state)
             (expect (buffer-line (%selected-test-buffer) 0)
                     :to-equal "paあz")))))))

  (dolist (quit-octets (list #(7)
                           (sb-ext:string-to-octets
                            (format nil "~C[103;5u" #\Esc)
                            :external-format :utf-8)))
    (let ((quit-octets quit-octets))
      (it (format nil "recovers paste bytes after asynchronous quit ~S" quit-octets)
        (%call-with-input-monitor-probe-pipe
         (lambda (read-fd write-fd)
           (let* ((caller sb-thread:*current-thread*)
                  (never (sb-thread:make-semaphore))
                  (paste-text (format nil "p~Cq" (code-char 7)))
                  (payload
                    (concatenate
                     '(simple-array (unsigned-byte 8) (*))
                     (sb-ext:string-to-octets
                      (format nil "~C[200~~~A~C[201~~a" #\Esc paste-text #\Esc)
                      :external-format :utf-8)
                     quit-octets))
                  (tag (gensym "INPUT-MONITOR-QUIT"))
                  (helper nil)
                  (events nil)
                  (finished nil)
                  (finish-count 0)
                  (finish-thread nil))
             (expect
              (catch tag
                (cl-tty-kit:call-with-input-monitor
                 read-fd
                 (lambda ()
                   (expect (cl-tty-kit:fd-write-octets write-fd payload)
                           :to-equal (length payload))
                   (sb-thread:wait-on-semaphore never :timeout 2)
                   :quit-not-delivered)
                 (lambda (event)
                   (setf helper sb-thread:*current-thread*)
                   (push event events)
                   (when (string= "C-g" (cl-tty-kit:key-event->string event))
                     (sb-thread:interrupt-thread
                      caller (lambda () (throw tag :interrupted)))))
                 :on-finish
                 (lambda (octets)
                   (incf finish-count)
                   (setf finished octets
                         finish-thread sb-thread:*current-thread*))))
              :to-be :interrupted)
             (expect finished :to-equalp payload)
             (expect finish-count :to-equal 1)
             (expect finish-thread :to-be caller)
             (expect (sb-thread:thread-alive-p helper) :to-be nil)
             (let ((events (nreverse events)))
               (expect (length events) :to-equal 3)
               (expect (cl-tty-kit:key-event-type (first events)) :to-be :paste)
               (expect (cl-tty-kit:key-event-code (first events))
                       :to-equal paste-text)
               (expect (cl-tty-kit:key-event-code (second events)) :to-be #\a)
               (expect (cl-tty-kit:key-event->string (third events)) :to-equal "C-g")))))))))
