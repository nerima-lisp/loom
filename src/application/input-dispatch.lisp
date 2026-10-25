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

(defun %dispatch-input-chunk (decoder buffer count keymap-state)
  "Decode octets and route key and non-key events through their hooks."
  (let* ((chunk
           (if (= count (length buffer))
               buffer
               (subseq buffer 0 count)))
         (session (editor-state-session *editor-state*)))
    (dolist (event (cl-tty-kit:decode-input-chunk decoder chunk))
      (let* ((key-event-p (typep event 'cl-tty-kit:key-event))
             (event-type (if key-event-p
                             (cl-tty-kit:key-event-type event)
                             :mouse)))
        (if (and key-event-p
                 (member event-type '(:character :special) :test #'eq))
            (%dispatch-key-event event keymap-state)
            (handler-case
                (let ((result
                        (loom/core/editor-session:run-session-hooks
                         :input-event
                         session
                         event-type
                         (if key-event-p
                             (if (eq event-type :paste)
                                 (or (cl-tty-kit:key-event-text event)
                                     (cl-tty-kit:key-event-code event))
                                 (cl-tty-kit:key-event-code event))
                             event))))
                  (when (and key-event-p (eq result :pass))
                    (%dispatch-key-event event keymap-state nil)))
              (error (condition)
                (minibuffer-message (editor-state-minibuffer *editor-state*)
                                    (princ-to-string condition)))))))))
