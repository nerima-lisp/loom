;;;; src/application/minibuffer.lisp
;;;;
;;;; Application layer: the minibuffer protocol. Orchestration, not pure
;;;; domain state -- it coordinates keymap input (domain/keymap.lisp) and
;;;; drives CL-HISTORY-KIT directly for Up/Down recall. No separate
;;;; infrastructure/history.lisp adapter exists for this: MAKE-MINIBUFFER and
;;;; MINIBUFFER-HANDLE-KEY already name CL-HISTORY-KIT:MAKE-HISTORY and
;;;; CL-HISTORY-KIT:HISTORY-PREVIOUS/HISTORY-NEXT directly in their
;;;; contracts below, so there is no separate "history" sub-protocol to
;;;; wrap.
;;;;
;;;; The minibuffer is the single-line prompt/status area at the bottom of the
;;;; editor, used both for interactive input (find-file, M-x, search, ...) and
;;;; transient status/error messages.
(in-package #:loom)

;;; A minibuffer is a small piece of mutable state: whether it is currently
;;; soliciting input, the prompt/input text of that solicitation, the
;;; ON-CONFIRM/ON-CANCEL callbacks supplied to the current MINIBUFFER-ACTIVATE
;;; call, an optional CL-HISTORY-KIT history object driving Up/Down recall,
;;; and a transient status MESSAGE slot kept separate from the prompt/input
;;; state so MINIBUFFER-MESSAGE cannot affect MINIBUFFER-ACTIVE-P (see its
;;; docstring below). Default conc-name is overridden to %MINIBUFFER- so the
;;; struct's generated accessors never collide with the protocol's own
;;; MINIBUFFER-ACTIVE-P generic, mirroring MAKE-KEYMAP's %MAKE-KEYMAP
;;; precedent in domain/keymap.lisp.
(defstruct (minibuffer (:constructor %make-minibuffer) (:conc-name %minibuffer-))
  (active-p nil)
  (prompt nil)
  (input "")
  (on-confirm nil)
  (on-cancel nil)
  (history nil)
  (message nil))

(defun %control-g-key-p (key-event)
  "True when KEY-EVENT is a Ctrl-G combination. CL-TTY-KIT reports a plain C0
Ctrl-G byte as a :SPECIAL :CONTROL-G event, but its kitty-protocol CSI-u path
reports letter keys -- Ctrl-G included -- as a :CHARACTER event with :CONTROL
in its modifiers instead (see keys-decode-internals.lisp's %CSI-U-EVENT), so
both shapes are recognized here."
  (or (and (eq (cl-tty-kit:key-event-type key-event) :special)
           (eq (cl-tty-kit:key-event-code key-event) :control-g))
      (and (eq (cl-tty-kit:key-event-type key-event) :character)
           (eql (cl-tty-kit:key-event-code key-event) #\g)
           (member :control (cl-tty-kit:key-event-modifiers key-event)))))

(defun %minibuffer-key-kind (key-event type code)
  "Classify KEY-EVENT -- whose CL-TTY-KIT:KEY-EVENT-TYPE and -CODE the caller
has already read out as TYPE and CODE -- as one of the seven things
MINIBUFFER-HANDLE-KEY does with a keystroke: :CANCEL, :BACKSPACE,
:HISTORY-PREVIOUS, :HISTORY-NEXT, :CONFIRM, :CHARACTER, or :IGNORE for
anything else. Pure: the classification is separated from the mutation so
MINIBUFFER-HANDLE-KEY dispatches on one value rather than re-testing TYPE
and CODE at every branch."
  (cond
    ((%control-g-key-p key-event) :cancel)
    ((and (eq type :special) (eq code :backspace)) :backspace)
    ((and (eq type :special) (eq code :up)) :history-previous)
    ((and (eq type :special) (eq code :down)) :history-next)
    ((and (eq type :special) (eq code :enter)) :confirm)
    ((eq type :character) :character)
    (t :ignore)))

(defun %minibuffer-deactivate (minibuffer)
  "Reset MINIBUFFER to the inactive state, discarding prompt/input/callbacks."
  (setf (%minibuffer-active-p minibuffer) nil
        (%minibuffer-prompt minibuffer) nil
        (%minibuffer-input minibuffer) ""
        (%minibuffer-on-confirm minibuffer) nil
        (%minibuffer-on-cancel minibuffer) nil)
  (let ((history (%minibuffer-history minibuffer)))
    (when history
      (history-kit:history-reset-navigation history)))
  minibuffer)

(defun %minibuffer-recall-history (minibuffer direction)
  "Replace MINIBUFFER's input with the history entry one step DIRECTION away:
:PREVIOUS drives CL-HISTORY-KIT:HISTORY-PREVIOUS, handing it the current input
so a partly typed line comes back on the way down again, and :NEXT drives
HISTORY-NEXT. A MINIBUFFER created without a history object, and a step that
ran off the end of the history, both leave the input untouched."
  (let* ((history (%minibuffer-history minibuffer))
         (recalled (when history
                     (ecase direction
                       (:previous (history-kit:history-previous
                                    history (%minibuffer-input minibuffer)))
                       (:next (history-kit:history-next history))))))
    (when recalled
      (setf (%minibuffer-input minibuffer) recalled))))

(defgeneric make-minibuffer (&key history)
  (:documentation
   "Create and return a new, inactive minibuffer. HISTORY, when supplied, is
a CL-HISTORY-KIT history object (as created by CL-HISTORY-KIT:MAKE-HISTORY)
used to drive Up/Down recall while the minibuffer is active.")
  (:method (&key history)
    (%make-minibuffer :history history)))

(defgeneric minibuffer-active-p (minibuffer)
  (:documentation
   "Return true if MINIBUFFER is currently prompting for input, i.e. between
a MINIBUFFER-ACTIVATE call and the matching confirm/cancel.")
  (:method (minibuffer)
    (%minibuffer-active-p minibuffer)))

(defgeneric minibuffer-prompt-string (minibuffer)
  (:documentation
   "Return MINIBUFFER's current prompt text (the string passed to
MINIBUFFER-ACTIVATE), or NIL when MINIBUFFER is not active.")
  (:method (minibuffer)
    (when (%minibuffer-active-p minibuffer)
      (%minibuffer-prompt minibuffer))))

(defgeneric minibuffer-input-string (minibuffer)
  (:documentation
   "Return the text typed into MINIBUFFER so far in the current activation,
as a string. Returns an empty string when MINIBUFFER is not active.")
  (:method (minibuffer)
    (if (%minibuffer-active-p minibuffer)
        (%minibuffer-input minibuffer)
        "")))

(defgeneric minibuffer-activate (minibuffer prompt &key on-confirm on-cancel)
  (:documentation
   "Begin an interactive input session in MINIBUFFER, displaying PROMPT and
accepting keystrokes via MINIBUFFER-HANDLE-KEY. ON-CONFIRM, when supplied, is
a function of one argument (the final input string) called when the user
confirms the input (e.g. RET). ON-CANCEL, when supplied, is a function of
zero arguments called when the user cancels (e.g. C-g). Returns MINIBUFFER.")
  (:method (minibuffer prompt &key on-confirm on-cancel)
    (let ((history (%minibuffer-history minibuffer)))
      (when history
        (history-kit:history-reset-navigation history)))
    (setf (%minibuffer-active-p minibuffer) t
          (%minibuffer-prompt minibuffer) prompt
          (%minibuffer-input minibuffer) ""
          (%minibuffer-on-confirm minibuffer) on-confirm
          (%minibuffer-on-cancel minibuffer) on-cancel
          (%minibuffer-message minibuffer) nil)
    minibuffer))

(defgeneric minibuffer-handle-key (minibuffer key-event)
  (:documentation
   "Feed one KEY-EVENT (as returned by CL-TTY-KIT:DECODE-INPUT-CHUNK) to an
active MINIBUFFER: ordinary character events are appended to the input,
Backspace/Delete edit it, Up/Down recall history (when MINIBUFFER was created
with one, via CL-HISTORY-KIT:HISTORY-PREVIOUS/HISTORY-NEXT), RET invokes the
ON-CONFIRM callback passed to MINIBUFFER-ACTIVATE after deactivating the
current prompt (so the callback may activate a next prompt),
and C-g invokes ON-CANCEL and deactivates MINIBUFFER. Has no effect if
MINIBUFFER is not active. Returns MINIBUFFER.")
  (:method (minibuffer key-event)
    (when (%minibuffer-active-p minibuffer)
      (let* ((type (cl-tty-kit:key-event-type key-event))
             (code (cl-tty-kit:key-event-code key-event))
             (history (%minibuffer-history minibuffer))
             (kind (%minibuffer-key-kind key-event type code)))
        (case kind
          (:cancel
           (when (%minibuffer-on-cancel minibuffer)
             (funcall (%minibuffer-on-cancel minibuffer)))
           (%minibuffer-deactivate minibuffer))
          (:backspace
           (let ((input (%minibuffer-input minibuffer)))
             (when (plusp (length input))
               (setf (%minibuffer-input minibuffer)
                     (subseq input 0 (1- (length input)))))))
          (:history-previous (%minibuffer-recall-history minibuffer :previous))
          (:history-next (%minibuffer-recall-history minibuffer :next))
          (:confirm
           (let ((input (%minibuffer-input minibuffer))
                 (on-confirm (%minibuffer-on-confirm minibuffer)))
             (when history
               (history-kit:history-add history input))
             (%minibuffer-deactivate minibuffer)
             (when on-confirm
               (funcall on-confirm input))))
          (:character
           (setf (%minibuffer-input minibuffer)
                 (concatenate 'string (%minibuffer-input minibuffer)
                              (string code))))
          (t
           nil))))
    minibuffer))

(defgeneric minibuffer-message (minibuffer text)
  (:documentation
   "Display TEXT in MINIBUFFER as a transient status message: unlike
MINIBUFFER-ACTIVATE, this does not solicit input and does not affect
MINIBUFFER-ACTIVE-P. Returns MINIBUFFER.")
  (:method (minibuffer text)
    (setf (%minibuffer-message minibuffer) text)
    minibuffer))
