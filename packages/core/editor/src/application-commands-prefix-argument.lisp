(in-package #:loom)

(defun prefix-argument-action (descriptor argument)
  "Return the pending prefix action for DESCRIPTOR, or NIL.

The dispatcher uses this single-value representation so that an action whose
VALUE is NIL (universal argument and sign toggling) remains distinguishable
from an ordinary key that is not a prefix action."
  (multiple-value-bind (kind value)
      (%prefix-argument-descriptor-action descriptor argument)
    (and kind (cons kind value))))

(defun apply-prefix-argument-action (kind value)
  (let ((argument (prefix-argument-for-editor)))
    (case kind
      (:universal (loom/core/command:prefix-argument-universal argument))
      (:digit (loom/core/command:prefix-argument-digit argument value))
      (:negative (loom/core/command:prefix-argument-negative argument))
      (otherwise (error "Unknown prefix argument action: ~S" kind)))))

(defun prefix-argument-value-for-editor ()
  (loom/core/command:prefix-argument-value (prefix-argument-for-editor)))

(defun consume-prefix-argument-for-editor ()
  (loom/core/command:prefix-argument-consume (prefix-argument-for-editor)))

(defun universal-argument ()
  (apply-prefix-argument-action :universal nil)
  (loom/core/minibuffer:minibuffer-message
   (loom/core/editor-session:editor-state-minibuffer
    loom/core/editor-session:*editor-state*)
   (format nil "Prefix argument: ~D" (prefix-argument-value-for-editor))))
