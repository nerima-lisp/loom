;;;; packages/core/editor/src/application-commands-kill.lisp
;;;;
;;;; Application layer: kill commands (see
;;;; application/commands-internal.lisp for the shared command-authoring
;;;; convention every commands-*.lisp file follows).
(in-package #:loom)

(defun kill-line ()
  "Kill through successive line ends according to the active prefix."
  (%kill-line-command))

(define-word-kill-command kill-word
  "Kill words around point according to the active prefix (M-d)."
  #'%forward-word-offset
  #'%backward-word-offset)

(define-word-kill-command backward-kill-word
  "Kill backward or forward according to the active prefix (M-Backspace)."
  #'%backward-word-offset
  #'%forward-word-offset
  :prepend-when-positive t)

(define-selected-buffer-command kill-region
  "Kill the region between point and mark, or report no region set."
  %kill-active-region-or-message)

(define-selected-buffer-command kill-ring-save
  "Copy the active region to the kill ring without changing the buffer."
  %copy-active-region-or-message)
