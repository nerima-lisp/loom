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

(defun %zap-to-char-target-offset (text point character count)
  (cond
    ((plusp count)
     (loop with start = point
           repeat
           count
           for target = (position character text :start start)
           do (if target
                  (setf start (1+ target))
                  (return-from %zap-to-char-target-offset
                    nil))
           finally (return (1- start))))
    ((minusp count)
     (loop with
           end = point
           repeat (- count)
           for target = (position character text :end end :from-end t)
           do (if target
                  (setf end target)
                  (return-from %zap-to-char-target-offset
                    nil))
           finally (return end)))))

(defun zap-to-char ()
  "Kill through the Nth occurrence of a prompted character."
  (let ((count (%kill-ring-command-prefix-count))
        (coalesce-p (editor-state-last-command-kill-p *editor-state*)))
    (%clear-last-yank)
    (setf (editor-state-last-command-kill-p *editor-state*) nil)
    (with-prompts
     (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel
                 (minibuffer-message minibuffer "Quit"))
     ((character "Zap to char: " :input-kind :char))
     (let* ((buffer (%selected-kill-ring-buffer))
            (narrow-start (buffer-narrow-start-offset buffer))
            (point (- (buffer-point-offset buffer) narrow-start))
            (target
             (%zap-to-char-target-offset (buffer-visible-text buffer)
                                         point
                                         (char character 0)
                                         count)))
       (cond
         ((zerop count) nil)
         (target
           (kill-between-offsets buffer
                                 (+ narrow-start
                                    (if (plusp count)
                                        point
                                        target))
                                 (+ narrow-start
                                    (if (plusp count)
                                        (1+ target)
                                        point))
                                 :prepend
                                 (minusp count)
                                 :coalesce
                                 coalesce-p)
           (setf (editor-state-last-command-kill-p *editor-state*) t))
         (t
          (minibuffer-message minibuffer
                              (format nil "Search failed: \"~A\"" character))))))))
