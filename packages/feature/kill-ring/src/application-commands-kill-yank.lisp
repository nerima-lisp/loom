(in-package #:loom/feature/kill-ring)

(defun yank ()
  "Insert the most recently killed text, repeating for the active prefix."
  (%clear-last-yank)
  (setf (editor-state-last-command-kill-p *editor-state*) nil)
  (let ((count (max 0 (%kill-ring-command-prefix-count))))
    (let ((text (first (editor-state-kill-ring *editor-state*)))
          (buffer (%selected-kill-ring-buffer)))
      (when (and text (plusp count))
        (%perform-yank buffer text count)))))

(defun yank-pop ()
  "Replace the previous yank, advancing through the kill ring by the numeric prefix.
The default is one entry; negative values reverse direction, zero keeps the
same entry, and the index wraps around the ring."
  (setf (editor-state-last-command-kill-p *editor-state*) nil)
  (let ((buffer (%selected-kill-ring-buffer)))
    (multiple-value-bind (ring start ranges index repeat-count)
        (%yank-pop-context buffer)
      (if ring
          (%perform-yank-pop buffer ring start ranges index repeat-count)
          (minibuffer-message (editor-state-minibuffer *editor-state*)
                              "Previous command was not a yank")))))

(defun kill-ring-save ()
  "Copy the active region to the kill ring without changing the buffer."
  (%copy-active-region-or-message (%selected-kill-ring-buffer)))

(defun kill-region ()
  "Kill the region between point and mark, or report no region set."
  (%kill-active-region-or-message (%selected-kill-ring-buffer)))

(define-word-kill-command backward-kill-word
                          "Kill backward or forward according to the active prefix (M-Backspace)."
                          #'%backward-word-offset
                          #'%forward-word-offset
                          :prepend-when-positive
                          t)

(define-word-kill-command kill-word
                          "Kill words around point according to the active prefix (M-d)."
                          #'%forward-word-offset
                          #'%backward-word-offset)

(defun kill-line ()
  "Kill through successive line ends according to the active prefix."
  (%kill-line-command))
