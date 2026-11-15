(in-package #:loom/test)

(defun %call-with-input-monitor-probe-pipe (function)
  (multiple-value-bind (read-fd write-fd) (sb-posix:pipe)
    (unwind-protect
         (funcall function read-fd write-fd)
      (sb-posix:close read-fd)
      (sb-posix:close write-fd))))

(defun %input-monitor-probe-replay (octets expected &optional decoder)
  (let* ((*editor-state* (%fresh-full-editor-state ""))
         (session
           (%make-test-editor-session
            (list (%selected-test-buffer))
            :window-tree (editor-state-window-tree *editor-state*)))
         (loom/core/editor-session:*editor-session* session)
         (decoder (or decoder (cl-tty-kit:make-input-decoder
                               :collect-bracketed-paste t)))
         (keymap-state (make-keymap-state (editor-state-keymap *editor-state*))))
    (setf (editor-state-session *editor-state*) session)
    (loom::%dispatch-input-chunk decoder octets (length octets) keymap-state)
    (expect (buffer-line (%selected-test-buffer) 0) :to-equal expected)
    (expect (minibuffer-message-string (editor-state-minibuffer *editor-state*))
            :to-be nil)))

(defun %input-monitor-probe-interrupt (payload &key decoder)
  (%call-with-input-monitor-probe-pipe
   (lambda (read-fd write-fd)
     (let ((caller sb-thread:*current-thread*)
           (never (sb-thread:make-semaphore))
           (tag (gensym "MONITOR-PROBE-QUIT"))
           (helper nil)
           (events nil)
           (retained nil))
       (expect
        (catch tag
          (apply #'cl-tty-kit:call-with-input-monitor
                 read-fd
                 (lambda ()
                   (expect (cl-tty-kit:fd-write-octets write-fd payload)
                           :to-equal (length payload))
                   (sb-thread:wait-on-semaphore never :timeout 2)
                   :quit-not-delivered)
                 (lambda (event)
                   (setf helper sb-thread:*current-thread*)
                   (push event events)
                   (when (and (typep event 'cl-tty-kit:key-event)
                              (string= "C-g" (cl-tty-kit:key-event->string event)))
                     (sb-thread:interrupt-thread
                      caller (lambda () (throw tag :interrupted)))
                     :consume))
                 (append (list :on-finish (lambda (octets) (setf retained octets)))
                         (when decoder (list :decoder decoder)))))
        :to-be :interrupted)
       (expect (sb-thread:thread-alive-p helper) :to-be nil)
       (values retained (nreverse events))))))

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

(describe "input monitor transfer and recovery"
  (dolist (quit-octets
           (list #(7) (sb-ext:string-to-octets
                       (format nil "~C[103;5u" #\Esc)
                       :external-format :utf-8)))
    (let ((quit-octets quit-octets))
      (it (format nil "does not quit again when consumed input ~S is replayed" quit-octets)
        (let* ((paste-text (format nil "p~Cq" (code-char 7)))
               (kept (sb-ext:string-to-octets
                      (format nil "~C[200~~~A~C[201~~a" #\Esc paste-text #\Esc)
                      :external-format :utf-8))
               (payload (concatenate '(simple-array (unsigned-byte 8) (*))
                                     kept quit-octets)))
          (multiple-value-bind (retained events)
              (%input-monitor-probe-interrupt payload)
            (expect retained :to-equalp kept)
            (expect (length events) :to-equal 3)
            (%input-monitor-probe-replay retained (concatenate 'string paste-text "a")))))))

  (it "transfers partial UTF-8 into retained bytes for one replay"
    (let ((decoder (cl-tty-kit:make-input-decoder :collect-bracketed-paste t)))
      (expect (cl-tty-kit:decode-input-chunk decoder #(227 129)) :to-be nil)
      (%call-with-input-monitor-probe-pipe
       (lambda (read-fd write-fd)
         (let ((ready (sb-thread:make-semaphore)))
           (multiple-value-bind (retained body-values diagnostics)
               (cl-tty-kit:call-with-input-monitor
                read-fd
                (lambda ()
                  (expect (cl-tty-kit:fd-write-octets
                           write-fd
                           (make-array 2 :element-type '(unsigned-byte 8)
                                         :initial-contents '(130 122)))
                          :to-equal 2)
                  (expect (sb-thread:wait-on-semaphore ready :timeout 2)
                          :to-be-truthy)
                  :completed)
                (lambda (event)
                  (when (eql #\z (cl-tty-kit:key-event-code event))
                    (sb-thread:signal-semaphore ready)))
                :decoder decoder)
             (expect retained :to-equalp #(227 129 130 122))
             (expect body-values :to-equal '(:completed))
             (expect diagnostics :to-be nil)
             (%input-monitor-probe-replay retained "あz" decoder)))))))

  (it "keeps an initial paste around C-g and replays it through clipboard dispatch"
    (let* ((decoder (cl-tty-kit:make-input-decoder :collect-bracketed-paste t))
           (prefix (sb-ext:string-to-octets
                    (format nil "~C[200~~before" #\Esc) :external-format :utf-8))
           (paste-tail (format nil "p~Cq" (code-char 7)))
           (tail (sb-ext:string-to-octets
                  (format nil "~A~C[201~~a" paste-tail #\Esc)
                  :external-format :utf-8))
           (payload (concatenate '(simple-array (unsigned-byte 8) (*)) tail #(7)))
           (kept (concatenate '(simple-array (unsigned-byte 8) (*)) prefix tail)))
      (expect (cl-tty-kit:decode-input-chunk decoder prefix) :to-be nil)
      (multiple-value-bind (retained events)
          (%input-monitor-probe-interrupt payload :decoder decoder)
        (expect retained :to-equalp kept)
        (expect (length events) :to-equal 3)
        (expect (cl-tty-kit:key-event-type (first events)) :to-be :paste)
        (expect (cl-tty-kit:key-event-code (first events))
                :to-equal (concatenate 'string "before" paste-tail))
        (%input-monitor-probe-replay
         retained (concatenate 'string "before" paste-tail "a") decoder))))

  (it "consumes an escape-prefix C-g across the scope boundary without replay"
    (let ((decoder (cl-tty-kit:make-input-decoder :collect-bracketed-paste t)))
      (expect (cl-tty-kit:decode-input-chunk decoder
                                           (format nil "~C[10" #\Esc))
              :to-be nil)
      (%call-with-input-monitor-probe-pipe
       (lambda (read-fd write-fd)
         (let ((ready (sb-thread:make-semaphore)))
           (multiple-value-bind (retained body-values diagnostics)
               (cl-tty-kit:call-with-input-monitor
                read-fd
                (lambda ()
                  (let ((suffix (sb-ext:string-to-octets "3;5u" :external-format :utf-8)))
                    (expect (cl-tty-kit:fd-write-octets write-fd suffix)
                            :to-equal (length suffix)))
                  (expect (sb-thread:wait-on-semaphore ready :timeout 2)
                          :to-be-truthy)
                  (values 42 :answer))
                (lambda (event)
                  (when (string= "C-g" (cl-tty-kit:key-event->string event))
                    (sb-thread:signal-semaphore ready)
                    :consume))
                :decoder decoder)
             (expect retained :to-equalp #())
             (expect body-values :to-equal '(42 :answer))
             (expect diagnostics :to-be nil)
             (%input-monitor-probe-replay retained "" decoder)
             (let ((events (cl-tty-kit:decode-input-chunk decoder #(122))))
               (expect (length events) :to-equal 1)
               (expect (cl-tty-kit:key-event-code (first events)) :to-be #\z))))))))

  (dolist (carry-prefix '(nil t))
    (let ((carry-prefix carry-prefix))
      (it (format nil "still interrupts after malformed UTF-8 with carried prefix ~S"
                  carry-prefix)
        (let* ((decoder (when carry-prefix
                          (cl-tty-kit:make-input-decoder :collect-bracketed-paste t)))
               (payload (make-array (if carry-prefix 1 3)
                                    :element-type '(unsigned-byte 8)
                                    :initial-contents (if carry-prefix '(7) '(227 129 7)))))
          (when decoder
            (expect (cl-tty-kit:decode-input-chunk decoder #(227 129)) :to-be nil))
          (multiple-value-bind (retained events)
              (%input-monitor-probe-interrupt payload :decoder decoder)
            (expect retained :to-equalp #(227 129))
            (expect (length events) :to-equal 1)
            (expect (cl-tty-kit:key-event->string (first events)) :to-equal "C-g"))))))

  (it "returns evaluation values alongside decoder diagnostics"
    (%call-with-input-monitor-probe-pipe
     (lambda (read-fd write-fd)
       (let ((ready (sb-thread:make-semaphore)))
         (multiple-value-bind (retained body-values diagnostics)
             (cl-tty-kit:call-with-input-monitor
              read-fd
              (lambda ()
                (expect (cl-tty-kit:fd-write-octets
                         write-fd (make-array 3 :element-type '(unsigned-byte 8)
                                               :initial-contents '(227 129 7)))
                        :to-equal 3)
                (expect (sb-thread:wait-on-semaphore ready :timeout 2)
                        :to-be-truthy)
                (values :completed 42))
              (lambda (event)
                (when (string= "C-g" (cl-tty-kit:key-event->string event))
                  (sb-thread:signal-semaphore ready)
                  :consume)))
           (expect retained :to-equalp #(227 129))
           (expect body-values :to-equal '(:completed 42))
           (expect diagnostics :to-be-truthy)
           (expect (listp diagnostics) :to-be-truthy)))))))
(describe "input monitor mouse and paste consumer"
  (it "replays SGR mouse and pasted text through loom after consuming quit"
    (let* ((text "mouse貼付")
           (kept (sb-ext:string-to-octets
                  (format nil "~C[<0;1;1M~C[200~~~A~C[201~~z"
                          #\Esc #\Esc text #\Esc)
                  :external-format :utf-8))
           (payload (concatenate '(simple-array (unsigned-byte 8) (*)) kept #(7))))
      (%call-with-input-monitor-probe-pipe
       (lambda (read-fd write-fd)
         (let ((ready (sb-thread:make-semaphore))
               (events nil))
           (multiple-value-bind (retained body-values diagnostics)
               (cl-tty-kit:call-with-input-monitor
                read-fd
                (lambda ()
                  (expect (cl-tty-kit:fd-write-octets write-fd payload)
                          :to-equal (length payload))
                  (expect (sb-thread:wait-on-semaphore ready :timeout 2)
                          :to-be-truthy)
                  :normal)
                (lambda (event)
                  (push event events)
                  (when (and (typep event 'cl-tty-kit:key-event)
                             (string= "C-g" (cl-tty-kit:key-event->string event)))
                    (sb-thread:signal-semaphore ready)
                    :consume)))
             (expect retained :to-equalp kept)
             (expect body-values :to-equal '(:normal))
             (expect diagnostics :to-be nil)
             (setf events (nreverse events))
             (expect (length events) :to-equal 4)
             (expect (typep (first events) 'cl-tty-kit:mouse-event) :to-be-truthy)
             (expect (cl-tty-kit:key-event-type (second events)) :to-be :paste)
             (expect (cl-tty-kit:key-event-code (second events)) :to-equal text)
             (%input-monitor-probe-replay retained (concatenate 'string text "z")))))))))
