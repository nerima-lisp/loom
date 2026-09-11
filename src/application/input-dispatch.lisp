(in-package #:loom)


(defun %drain-buffered-octets (buffer start-count input-stream)
  "Read the octets already waiting on INPUT-STREAM into BUFFER, filling it
from index START-COUNT onwards and stopping at (LENGTH BUFFER) octets or as
soon as LISTEN reports nothing more is buffered -- so this never blocks.
Returns the resulting octet count."
  (loop with count = start-count
        while (and (< count (length buffer)) (listen input-stream))
        do (let ((byte (read-byte input-stream nil nil)))
             (unless byte (loop-finish))
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
  "Decode the first COUNT octets of BUFFER through DECODER and route every key
event they yield to %DISPATCH-KEY-EVENT with KEYMAP-STATE. A completely full
BUFFER is handed to CL-TTY-KIT:DECODE-INPUT-CHUNK as-is, so the common case of
a full read does not copy."
  (let ((chunk (if (= count (length buffer)) buffer (subseq buffer 0 count))))
    (dolist (event (cl-tty-kit:decode-input-chunk decoder chunk))
      (%dispatch-key-event event keymap-state))))
