;;;; packages/feature/keyboard-macro/src/package.lisp
;;;;
;;;; Keyboard macro state and commands are intentionally isolated from input
;;;; dispatch so the domain can be tested without a terminal.
(defpackage #:loom/feature/keyboard-macro
  (:use #:cl #:loom #:loom/application)
  (:export
   ;; Domain API
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
   ;; Application API
   #:start-kbd-macro
   #:end-kbd-macro
   #:call-last-kbd-macro))
