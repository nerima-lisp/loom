;;;; src/application/input-dispatch.lisp
;;;;
;;;; The input boundary translates terminal bytes into application events and
;;;; routes those events to the editor state. It deliberately owns no
;;;; terminal rendering or startup lifecycle; those concerns live in
;;;; event-loop.lisp and startup.lisp respectively.
(in-package #:loom)

;;; ---------------------------------------------------------------------
;;; Raw input reading
;;;
;;; CL-TTY-KIT:DECODE-INPUT-CHUNK accepts either a string or an octet vector
;;; (see infrastructure/terminal-renderer.lisp's sibling library,
;;; input-decode.lisp, for that contract), so this reads octets directly off
;;; *STANDARD-INPUT* via READ-BYTE rather than going through a character
;;; decode first -- SBCL's stdin fd-stream is bivalent (READ-BYTE and
;;; READ-CHAR both work on it), and reading octets sidesteps ever needing to
;;; worry about *STANDARD-INPUT*'s external-format matching what the terminal
;;; actually sent.
;;; ---------------------------------------------------------------------

(defun %drain-buffered-octets (buffer start-count)
  "Read the octets already waiting on *STANDARD-INPUT* into BUFFER, filling it
from index START-COUNT onwards and stopping at (LENGTH BUFFER) octets or as
soon as LISTEN reports nothing more is buffered -- so this never blocks.
Returns the resulting octet count."
  (loop with count = start-count
        while (and (< count (length buffer)) (listen *standard-input*))
        do (let ((byte (read-byte *standard-input* nil nil)))
             (unless byte (loop-finish))
             (setf (aref buffer count) byte)
             (incf count))
        finally (return count)))

(defun %read-input-octets (buffer)
  "Block until at least one octet is available on *STANDARD-INPUT*, then
drain any additional octets already buffered (checked via LISTEN, so this
never blocks a second time) into BUFFER, up to (LENGTH BUFFER) octets total.
Returns the number of octets actually placed in BUFFER, or NIL at
end-of-file (no octet was read at all)."
  (let ((first (read-byte *standard-input* nil nil)))
    (when first
      (setf (aref buffer 0) first)
      (%drain-buffered-octets buffer 1))))

(defun %dispatch-input-chunk (decoder buffer count keymap-state)
  "Decode the first COUNT octets of BUFFER through DECODER and route every key
event they yield to %DISPATCH-KEY-EVENT with KEYMAP-STATE. A completely full
BUFFER is handed to CL-TTY-KIT:DECODE-INPUT-CHUNK as-is, so the common case of
a full read does not copy."
  (let ((chunk (if (= count (length buffer)) buffer (subseq buffer 0 count))))
    (dolist (event (cl-tty-kit:decode-input-chunk decoder chunk))
      (%dispatch-key-event event keymap-state))))
