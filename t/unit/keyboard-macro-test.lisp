(in-package #:loom/test)

(describe
  "keyboard macro"
  (it
    "records ordered defensive copies while recording"
    (let* ((macro (make-keyboard-macro))
           (descriptor (cons '(:control) #\f)))
      (keyboard-macro-start-recording macro)
      (keyboard-macro-record-event
       macro
       (make-keyboard-macro-event :kind :key :value descriptor))
      (keyboard-macro-record-event
       macro
       (make-keyboard-macro-event :kind :self-insert :value #\a))
      (keyboard-macro-stop-recording macro)
      (setf (cdr descriptor) #\x)
      (let ((events (keyboard-macro-events macro)))
        (expect (length events) :to-equal 2)
        (expect (keyboard-macro-event-kind (first events)) :to-equal :key)
        (expect (keyboard-macro-event-value (first events))
                :to-equal (cons '(:control) #\f))
        (expect (keyboard-macro-event-kind (second events))
                :to-equal :self-insert)
        (expect (keyboard-macro-event-value (second events)) :to-equal #\a)
        (setf (cdr (keyboard-macro-event-value (first events))) #\y)
        (expect (keyboard-macro-event-value (first (keyboard-macro-events macro)))
                :to-equal (cons '(:control) #\f)))))

  (it
    "removes the last event and tracks replay state"
    (let ((macro (make-keyboard-macro)))
      (keyboard-macro-start-recording macro)
      (keyboard-macro-record-event
       macro
       (make-keyboard-macro-event :kind :self-insert :value #\a))
      (keyboard-macro-record-event
       macro
       (make-keyboard-macro-event :kind :self-insert :value #\b))
      (let ((removed (keyboard-macro-remove-last-event macro)))
        (expect (keyboard-macro-event-value removed) :to-equal #\b)
        (expect (length (keyboard-macro-events macro)) :to-equal 1))
      (keyboard-macro-stop-recording macro)
      (keyboard-macro-begin-replay macro)
      (expect (keyboard-macro-replaying-p macro) :to-be t)
      (keyboard-macro-end-replay macro)
      (expect (keyboard-macro-replaying-p macro) :to-be nil)))

  (it
    "does not record while inactive or replaying"
    (let ((macro (make-keyboard-macro)))
      (keyboard-macro-record-event
       macro
       (make-keyboard-macro-event :kind :self-insert :value #\a))
      (expect (keyboard-macro-events macro) :to-be nil)
      (keyboard-macro-start-recording macro)
      (keyboard-macro-begin-replay macro)
      (keyboard-macro-record-event
       macro
       (make-keyboard-macro-event :kind :self-insert :value #\b))
      (expect (keyboard-macro-events macro) :to-be nil))))
