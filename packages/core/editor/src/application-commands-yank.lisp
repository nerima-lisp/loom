;;;; packages/core/editor/src/application-commands-yank.lisp
;;;;
;;;; Application layer: yank commands (see
;;;; application/commands-internal.lisp for the shared command-authoring
;;;; convention every commands-*.lisp file follows).
(in-package #:loom)

(defun yank ()
  "Insert the most recently killed text, repeating for the active prefix."
  (%clear-last-yank)
  (setf (editor-state-last-command-kill-p *editor-state*) nil)
  (with-nonnegative-command-prefix (count)
    (let ((text (first (editor-state-kill-ring *editor-state*)))
          (buffer (%selected-buffer)))
      (when (and text (plusp count))
        (%perform-yank buffer text count)))))

(defun yank-pop ()
  "Replace the previous yank with the next entry in the kill ring."
  (setf (editor-state-last-command-kill-p *editor-state*) nil)
  (let ((buffer (%selected-buffer)))
    (multiple-value-bind (ring start ranges index repeat-count)
        (%yank-pop-context buffer)
      (if ring
          (%perform-yank-pop buffer ring start ranges index repeat-count)
          (minibuffer-message
           (editor-state-minibuffer *editor-state*)
           "Previous command was not a yank")))))
