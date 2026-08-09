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

;;; ---------------------------------------------------------------------
;;; Key-event routing
;;; ---------------------------------------------------------------------

(defun %key-event->descriptor (event)
  "Convert a CL-TTY-KIT:KEY-EVENT into the (MODIFIERS . CODE) descriptor
shape domain/keymap.lisp's protocol expects -- see that file's header
comment: it has no CL-TTY-KIT dependency and documents that infrastructure
code decoding real key-event objects is responsible for this conversion
before calling KEYMAP-STATE-DISPATCH.

Two different terminal encodings of the same physical Ctrl+letter combo are
unified into one shape here, the same problem application/minibuffer.lisp's
%CONTROL-G-KEY-P already had to solve for C-g specifically: a plain-terminal
C0 byte decodes as a :SPECIAL event whose CODE is a :CONTROL-<letter> keyword
with no separate modifier, while the kitty CSI-u protocol decodes the same
combo as a :CHARACTER event carrying the letter itself plus an explicit
:CONTROL modifier. INSTALL-DEFAULT-KEYBINDINGS only ever binds the latter
(character + :CONTROL) shape (its CTRL helper), so a :SPECIAL
:CONTROL-<letter> event is rewritten into it here; every other event (plain
characters, arrows, Enter, Backspace, ...) passes through with its own
TYPE/CODE/MODIFIERS verbatim, wrapped as (MODIFIERS . CODE)."
  (let ((type (cl-tty-kit:key-event-type event))
        (code (cl-tty-kit:key-event-code event))
        (modifiers (cl-tty-kit:key-event-modifiers event)))
    (if (and (eq type :special)
             (keywordp code)
             (let ((name (symbol-name code)))
               (and (= (length name) 9) (string= "CONTROL-" name :end2 8))))
        (cons '(:control) (char-downcase (char (symbol-name code) 8)))
        (cons modifiers code))))

(defun record-undo-boundary-for-command (self-insert-p)
  "Call BUFFER-RECORD-UNDO-BOUNDARY on the selected window's buffer when the
command about to run (SELF-INSERT-P: true for SELF-INSERT-COMMAND, false for
anything dispatched via the keymap) differs in kind from the previously
dispatched command, per *EDITOR-STATE*'s LAST-COMMAND-SELF-INSERT-P \(see
application/editor-state.lisp\). This is what makes consecutive
SELF-INSERT-COMMAND invocations -- ordinary typing -- group into one undo
step while switching to any other command starts a new undo group; without
this call site, BUFFER-RECORD-UNDO-BOUNDARY (domain/buffer.lisp) is never
invoked outside of its own unit test, so a single UNDO-COMMAND call would
walk BUFFER-UNDO-LIST all the way back to its start in one shot instead of
stopping at a group boundary. Updates LAST-COMMAND-SELF-INSERT-P for the next
call. Not applied on the minibuffer-input path: the minibuffer has its own
input buffer, not a BUFFER-* undo history, and MINIBUFFER-HANDLE-KEY never
touches the selected window's buffer."
  (unless (eq self-insert-p (editor-state-last-command-self-insert-p *editor-state*))
    (buffer-record-undo-boundary (%selected-buffer)))
  (setf (editor-state-last-command-self-insert-p *editor-state*) self-insert-p))

(defun %dispatch-key-event (event keymap-state)
  "Route one decoded KEY-EVENT: to MINIBUFFER-HANDLE-KEY while the minibuffer
is soliciting input; to a prefix-argument action for C-u, digits, and sign
input; to SELF-INSERT-COMMAND for a plain, unmodified printable :CHARACTER
event when KEYMAP-STATE has no prefix key already accumulated
\(KEYMAP-STATE-SEQUENCE null\); otherwise to KEYMAP-STATE-DISPATCH via
%KEY-EVENT->DESCRIPTOR. Also records undo-group boundaries on the
buffer-editing paths (see %RECORD-UNDO-BOUNDARY-FOR-COMMAND), and consumes a
pending numeric prefix after a complete command rather than after a key that
only begins a multi-key sequence.

The invoked command (or, on the minibuffer path, its ON-CONFIRM callback via
MINIBUFFER-HANDLE-KEY) runs inside a HANDLER-CASE on ERROR: an ordinary,
expected error -- FIND-FILE on a nonexistent path, SAVE-BUFFER to an
unwritable path, a file-tree create/rename against an existing/missing path,
and so on -- is reported in the minibuffer instead of propagating out of the
event loop to MAIN's own top-level HANDLER-CASE, which would otherwise exit
the whole process and discard every unsaved buffer. LOOM-QUIT
\(application/commands-misc.lisp\) is signalled via CL:SIGNAL, not CL:ERROR, and
does not inherit from CL:ERROR, so it passes straight through this
HANDLER-CASE untouched and still reaches %RUN-EVENT-LOOP's own
\(LOOM-QUIT () ...\) clause for a clean exit."
  (let* ((minibuffer (editor-state-minibuffer *editor-state*))
         (minibuffer-was-active (minibuffer-active-p minibuffer))
         (macro (editor-state-keyboard-macro *editor-state*))
         (descriptor (%key-event->descriptor event))
         (prefix-argument (prefix-argument-for-editor))
         (prefix-action
           (and (not minibuffer-was-active)
                (null (keymap-state-sequence keymap-state))
                (prefix-argument-action descriptor prefix-argument)))
         (recording-before
           (and (not minibuffer-was-active)
                macro
                (loom/feature/keyboard-macro:keyboard-macro-recording-p macro)))
         (self-insert-event-p
           (and (not minibuffer-was-active)
                (eq (cl-tty-kit:key-event-type event) :character)
                (not (intersection '(:control :alt)
                                   (cl-tty-kit:key-event-modifiers event)))
                (null prefix-action)
                (null (keymap-state-sequence keymap-state))))
         (dispatched-p nil)
         (dispatch-result nil))
    (handler-case
        (progn
          (cond
            (minibuffer-was-active
             (minibuffer-handle-key minibuffer event))
            (prefix-action
             (apply-prefix-argument-action (car prefix-action)
                                           (cdr prefix-action)))
            (self-insert-event-p
             (record-undo-boundary-for-command t)
             (let ((*current-prefix-argument*
                     (consume-prefix-argument-for-editor)))
               (self-insert-command (cl-tty-kit:key-event-code event))))
            (t
             (record-undo-boundary-for-command nil)
             (unwind-protect
                  (let ((*current-prefix-argument*
                          (prefix-argument-value-for-editor)))
                    (setf dispatch-result
                          (keymap-state-dispatch keymap-state descriptor)))
               (unless (eq dispatch-result :pending)
                 (prefix-argument-reset prefix-argument)))))
          (setf dispatched-p t))
      (error (condition)
        (minibuffer-message minibuffer (format nil "~A" condition))))
    (when (and dispatched-p
               recording-before
               macro
               (loom/feature/keyboard-macro:keyboard-macro-recording-p macro)
               (not (loom/feature/keyboard-macro:keyboard-macro-replaying-p macro)))
      (loom/feature/keyboard-macro:keyboard-macro-record-event
       macro
       (loom/feature/keyboard-macro:make-keyboard-macro-event
        :kind (if self-insert-event-p :self-insert :key)
        :value (if self-insert-event-p
                   (cl-tty-kit:key-event-code event)
                   descriptor))))))

(defun %dispatch-input-chunk (decoder buffer count keymap-state)
  "Decode the first COUNT octets of BUFFER through DECODER and route every key
event they yield to %DISPATCH-KEY-EVENT with KEYMAP-STATE. A completely full
BUFFER is handed to CL-TTY-KIT:DECODE-INPUT-CHUNK as-is, so the common case of
a full read does not copy."
  (let ((chunk (if (= count (length buffer)) buffer (subseq buffer 0 count))))
    (dolist (event (cl-tty-kit:decode-input-chunk decoder chunk))
      (%dispatch-key-event event keymap-state))))
