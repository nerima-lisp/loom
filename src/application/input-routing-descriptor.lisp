;;;; src/application/input-routing-descriptor.lisp
;;;;
;;;; Key-event routing starts by converting CL-TTY-KIT events into the
;;;; keymap descriptor shape that the editor domain understands.
(in-package #:loom)

(defun %control-special-key-p (type code)
  (and (eq type :special)
       (keywordp code)
       (let ((name (symbol-name code)))
         (and (= (length name) 9)
              (string= "CONTROL-" name :end2 8)))))

(defun %control-special-key-character (code)
  (char-downcase (char (symbol-name code) 8)))

(defun %key-event->descriptor (event)
  "Convert a CL-TTY-KIT:KEY-EVENT into the (MODIFIERS . CODE) descriptor
shape domain/keymap.lisp's protocol expects.

Two different terminal encodings of the same physical Ctrl+letter combo are
unified here. A plain-terminal C0 byte decodes as a :SPECIAL event whose CODE
is a :CONTROL-<letter> keyword with no separate modifier, while kitty CSI-u
decodes the same combo as a :CHARACTER event carrying the letter plus an
explicit :CONTROL modifier. INSTALL-DEFAULT-KEYBINDINGS binds the latter
shape, so a :SPECIAL :CONTROL-<letter> event is rewritten into it here. Every
other event passes through verbatim, wrapped as (MODIFIERS . CODE).

The rewrite keeps whatever modifiers the event already carried. An ESC-prefixed
Ctrl+letter -- how a plain terminal reports C-M-f -- arrives as :SPECIAL
:CONTROL-F with :ALT, and discarding that :ALT would make it indistinguishable
from a bare C-f."
  (let ((type (cl-tty-kit:key-event-type event))
        (code (cl-tty-kit:key-event-code event))
        (modifiers (cl-tty-kit:key-event-modifiers event)))
    (if (%control-special-key-p type code)
        (cons (adjoin :control modifiers)
              (%control-special-key-character code))
        (cons modifiers code))))
