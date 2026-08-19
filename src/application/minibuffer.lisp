;;;; src/application/minibuffer.lisp
;;;;
;;;; Application layer: the minibuffer state/protocol. This file keeps the
;;;; mutable minibuffer state itself plus query operations; activation/message
;;;; lifecycle lives in src/application/minibuffer-activation.lisp, history
;;;; snapshot/install lives in src/application/minibuffer-history.lisp, and
;;;; keystroke classification, completion, and history navigation live in
;;;; src/application/minibuffer-input.lisp.
;;;;
;;;; The minibuffer is the single-line prompt/status area at the bottom of the
;;;; editor, used both for interactive input (find-file, M-x, search, ...) and
;;;; transient status/error messages.
(in-package #:loom)

;;; A minibuffer is a small piece of mutable state: whether it is currently
;;; soliciting input, the prompt/input text of that solicitation, the
;;; ON-CONFIRM/ON-CANCEL callbacks and optional completion function supplied to
;;; the current MINIBUFFER-ACTIVATE call, an optional CL-HISTORY-KIT history
;;; object driving Up/Down recall, and a transient status MESSAGE slot kept
;;; separate from the prompt/input state so MINIBUFFER-MESSAGE cannot affect
;;; MINIBUFFER-ACTIVE-P (see its docstring below). Default conc-name is
;;; overridden to %MINIBUFFER- so the struct's generated accessors never
;;; collide with the protocol's own MINIBUFFER-ACTIVE-P generic, mirroring
;;; MAKE-KEYMAP's %MAKE-KEYMAP precedent in domain/keymap.lisp.
(defstruct (minibuffer (:constructor %make-minibuffer) (:conc-name %minibuffer-))
  (active-p nil)
  (prompt nil)
  (input "")
  (on-confirm nil)
  (on-cancel nil)
  (completion-function nil)
  (history nil)
  (message nil))

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

(defgeneric minibuffer-message-string (minibuffer)
  (:documentation "Return the minibuffer's current transient message, or NIL.")
  (:method (minibuffer)
    (%minibuffer-message minibuffer)))
