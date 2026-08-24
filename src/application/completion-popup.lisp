;;;; src/application/completion-popup.lisp
;;;;
;;;; The in-buffer candidate list: a transient overlay the user picks from
;;;; while typing. It is deliberately not an LSP concept -- an item is a
;;;; (LABEL . TEXT) pair and nothing more -- so the renderer and the input
;;;; router can depend on it without depending on a language server.
;;;;
;;;; The minibuffer's own completion (src/application/minibuffer-completion.lisp)
;;;; is a different thing: it completes a command name in the prompt line, not
;;;; a symbol at point in a buffer.
(in-package #:loom)

(defstruct (editor-completion
            (:constructor make-editor-completion (buffer line column items))
            (:conc-name %editor-completion-))
  "A candidate list anchored at LINE/COLUMN in BUFFER.

COLUMN is where the text being completed starts, not where point is: accepting
a candidate replaces everything from there to point, which is what makes the
already-typed prefix disappear instead of being duplicated."
  buffer
  (line 0 :type integer)
  (column 0 :type integer)
  items
  (index 0 :type integer))

(defun editor-completion-item-label (item)
  "Return what the user reads for ITEM, a (LABEL . TEXT) pair."
  (car item))

(defun editor-completion-item-text (item)
  "Return what ITEM inserts."
  (cdr item))

(defun editor-completion-buffer (completion)
  (%editor-completion-buffer completion))

(defun editor-completion-line (completion)
  (%editor-completion-line completion))

(defun editor-completion-column (completion)
  (%editor-completion-column completion))

(defun editor-completion-items (completion)
  (copy-list (%editor-completion-items completion)))

(defun editor-completion-index (completion)
  (%editor-completion-index completion))

(defun editor-completion-selected (completion)
  "Return the currently highlighted item, or NIL for an empty candidate list."
  (nth (%editor-completion-index completion)
       (%editor-completion-items completion)))

(defun editor-completion-move (completion delta)
  "Move the selection DELTA places, wrapping at both ends. Returns COMPLETION.

Wrapping rather than clamping is what makes a short list navigable with one
key: the user never has to notice which end they are at."
  (let ((count (length (%editor-completion-items completion))))
    (when (plusp count)
      (setf (%editor-completion-index completion)
            (mod (+ (%editor-completion-index completion) delta) count))))
  completion)
