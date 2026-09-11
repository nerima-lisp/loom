(in-package #:loom)

(defstruct (minibuffer (:constructor %make-minibuffer) (:conc-name %minibuffer-))
  (active-p nil)
  (prompt nil)
  (input "")
  (on-confirm nil)
  (on-cancel nil)
  (on-change nil)
  (on-key nil)
  (completion-function nil)
  (history nil)
  (message nil))

(defun make-minibuffer (&key history)
  "Create and return a new, inactive minibuffer. HISTORY, when supplied, is
a CL-HISTORY-KIT history object (as created by CL-HISTORY-KIT:MAKE-HISTORY)
used to drive Up/Down recall while the minibuffer is active."
  (%make-minibuffer :history history))

(defun minibuffer-active-p (minibuffer)
  "Return true if MINIBUFFER is currently prompting for input, i.e. between
a MINIBUFFER-ACTIVATE call and the matching confirm/cancel."
  (%minibuffer-active-p minibuffer))

(defun minibuffer-prompt-string (minibuffer)
  "Return MINIBUFFER's current prompt text (the string passed to
MINIBUFFER-ACTIVATE), or NIL when MINIBUFFER is not active."
  (when (%minibuffer-active-p minibuffer)
    (%minibuffer-prompt minibuffer)))

(defun minibuffer-input-string (minibuffer)
  "Return the text typed into MINIBUFFER so far in the current activation,
as a string. Returns an empty string when MINIBUFFER is not active."
  (if (%minibuffer-active-p minibuffer)
      (%minibuffer-input minibuffer)
      ""))

(defun minibuffer-message-string (minibuffer)
  "Return the minibuffer's current transient message, or NIL."
  (%minibuffer-message minibuffer))
