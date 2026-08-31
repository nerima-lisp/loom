;;;; src/application/minibuffer-history.lisp
;;;;
;;;; Application layer: minibuffer history snapshot/install. This file keeps
;;;; the serializable history boundary separate from the minibuffer's core
;;;; state/activation protocol in src/application/minibuffer.lisp and from
;;;; interactive history navigation in src/application/minibuffer-input.lisp.
(in-package #:loom)

(defun minibuffer-history-entries (minibuffer)
  "Return MINIBUFFER's recalled input strings, newest first.

The returned list is independent of the underlying CL-HISTORY-KIT store and
can therefore be used as a serializable session value."
  (let ((history (%minibuffer-history minibuffer)))
    (if history
        (history-kit:history-entry-texts
         (history-kit:history-entries history))
        nil)))

(defun minibuffer-set-history-entries (minibuffer entries)
  "Replace MINIBUFFER's recalled input strings with ENTRIES.

ENTRIES must be a list of strings in newest-first order. The underlying
history object, when present, is cleared before the entries are installed.
The minibuffer is returned."
  (unless (and (listp entries) (every #'stringp entries))
    (error "minibuffer history must be a proper list of strings: ~S"
           entries))
  (let ((history (%minibuffer-history minibuffer)))
    (when history
      (history-kit:history-clear history)
      (dolist (entry (reverse entries))
        (history-kit:history-add history entry))))
  minibuffer)
