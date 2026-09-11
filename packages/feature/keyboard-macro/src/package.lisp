(defpackage #:loom/feature/keyboard-macro
  (:use #:cl #:loom #:loom/application)
  (:export
   #:keyboard-macro-event
   #:keyboard-macro-event-p
   #:make-keyboard-macro-event
   #:keyboard-macro-event-kind
   #:keyboard-macro-event-value
   #:keyboard-macro
   #:keyboard-macro-p
   #:make-keyboard-macro
   #:keyboard-macro-events
   #:keyboard-macro-recording-p
   #:keyboard-macro-replaying-p
   #:keyboard-macro-start-recording
   #:keyboard-macro-stop-recording
   #:keyboard-macro-drop
   #:keyboard-macro-record-event
   #:keyboard-macro-remove-last-event
   #:keyboard-macro-begin-replay
   #:keyboard-macro-end-replay
   #:start-kbd-macro
   #:end-kbd-macro
   #:call-last-kbd-macro))
