;;;; packages/feature/keyboard-macro/src/domain-keyboard-macro.lisp
;;;;
;;;; Domain layer: a keyboard macro is an ordered value object made from
;;;; already-decoded key descriptors.  It contains no keymap or terminal
;;;; knowledge; replay is an application concern.
(in-package #:loom)

(defstruct (keyboard-macro-event
            (:constructor make-keyboard-macro-event (&key kind value)))
  "One recorded input event.

KIND is :SELF-INSERT for a literal character or :KEY for a keymap
descriptor.  VALUE is the character or canonical descriptor respectively."
  kind
  value)

(defstruct (keyboard-macro
            (:constructor %make-keyboard-macro
                (event-list recording-p replaying-p)))
  "The last keyboard macro and its transient recording/replay state."
  (event-list nil)
  (recording-p nil)
  (replaying-p nil))

(defun make-keyboard-macro ()
  "Create an empty keyboard macro state."
  (%make-keyboard-macro nil nil nil))

(defun keyboard-macro-events (macro)
  "Return a defensive copy of MACRO's recorded events."
  (check-type macro keyboard-macro)
  (mapcar (lambda (event)
            (make-keyboard-macro-event
             :kind (keyboard-macro-event-kind event)
             :value (copy-tree (keyboard-macro-event-value event))))
          (keyboard-macro-event-list macro)))

(defun keyboard-macro-start-recording (macro)
  "Clear MACRO and begin recording."
  (check-type macro keyboard-macro)
  (setf (keyboard-macro-event-list macro) nil
        (keyboard-macro-recording-p macro) t)
  macro)

(defun keyboard-macro-stop-recording (macro)
  "Stop recording while preserving the recorded event list."
  (check-type macro keyboard-macro)
  (setf (keyboard-macro-recording-p macro) nil)
  macro)

(defun keyboard-macro-drop (macro)
  "Clear MACRO and leave it inactive."
  (check-type macro keyboard-macro)
  (setf (keyboard-macro-event-list macro) nil
        (keyboard-macro-recording-p macro) nil
        (keyboard-macro-replaying-p macro) nil)
  macro)

(defun keyboard-macro-record-event (macro event)
  "Append EVENT to MACRO when it is actively recording."
  (check-type macro keyboard-macro)
  (check-type event keyboard-macro-event)
  (when (and (keyboard-macro-recording-p macro)
             (not (keyboard-macro-replaying-p macro)))
    (setf (keyboard-macro-event-list macro)
          (nconc (keyboard-macro-event-list macro)
                 (list (make-keyboard-macro-event
                        :kind (keyboard-macro-event-kind event)
                        :value (copy-tree (keyboard-macro-event-value event)))))))
  macro)

(defun keyboard-macro-remove-last-event (macro)
  "Remove and return the last recorded event, or NIL when MACRO is empty."
  (check-type macro keyboard-macro)
  (let ((last (car (last (keyboard-macro-event-list macro)))))
    (when last
      (setf (keyboard-macro-event-list macro)
            (butlast (keyboard-macro-event-list macro))))
    last))

(defun keyboard-macro-begin-replay (macro)
  "Mark MACRO as replaying and return it."
  (check-type macro keyboard-macro)
  (setf (keyboard-macro-replaying-p macro) t)
  macro)

(defun keyboard-macro-end-replay (macro)
  "Clear MACRO's replaying flag and return it."
  (check-type macro keyboard-macro)
  (setf (keyboard-macro-replaying-p macro) nil)
  macro)
