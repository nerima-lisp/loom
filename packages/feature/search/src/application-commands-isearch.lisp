(in-package #:loom/feature/search)

(defparameter +isearch-prompt+
  "I-search: ")

(defparameter +isearch-backward-prompt+
  "I-search backward: ")

(defparameter +isearch-failing-prompt+
  "Failing I-search: ")

(defparameter +isearch-failing-backward-prompt+
  "Failing I-search backward: ")

(defun %isearch-prompt-for (session)
  (let ((backward (eq (isearch-session-direction session) :backward))
        (failed (isearch-session-failed-p session)))
    (cond
      ((and failed backward) +isearch-failing-backward-prompt+)
      (failed +isearch-failing-prompt+)
      (backward +isearch-backward-prompt+)
      (t +isearch-prompt+))))

(defun %isearch-move-to-match (session)
  "Move point onto SESSION's current match, if it has one.

Point goes to the match start, which is where the non-incremental
SEARCH-FORWARD leaves it too; a failing pattern leaves point exactly where the
last successful one put it."
  (let ((match (isearch-session-match session))
        (buffer (isearch-session-buffer session)))
    (when match
      (let ((position (buffer-offset-position buffer (buffer-span-start match))))
        (buffer-set-point buffer
                          (buffer-position-line position)
                          (buffer-position-column position))))))

(defun %isearch-refresh (session minibuffer)
  "Reflect SESSION's state in point and in the prompt."
  (%isearch-move-to-match session)
  (loom/core/minibuffer:minibuffer-set-prompt minibuffer
                                              (%isearch-prompt-for session)))

(defun %isearch-end ()
  (setf (loom/core/editor-session:editor-state-isearch
         loom/core/editor-session:*editor-state*) nil))

(defun %isearch-restore-origin (session)
  (let* ((buffer (isearch-session-buffer session))
         (position
          (buffer-offset-position buffer
                                  (isearch-session-origin-offset session))))
    (buffer-set-point buffer
                      (buffer-position-line position)
                      (buffer-position-column position))))

(defun %isearch-repeat-key-direction (key-event)
  "Return :FORWARD for a C-s event, :BACKWARD for C-r, and NIL otherwise.

Both terminal encodings of Ctrl+letter are normalized by the same function the
global keymap routes through, so the chord is recognized here exactly when it
would have been recognized there."
  (let ((descriptor (loom/core/command:key-event->descriptor key-event)))
    (when (equal (car descriptor) '(:control))
      (case (cdr descriptor)
        (#\s :forward)
        (#\r :backward)
        (t nil)))))

(defun %isearch-change (session minibuffer input)
  (isearch-apply-pattern session input)
  (%isearch-refresh session minibuffer))

(defun %isearch-key (session minibuffer key-event)
  (let ((repeat (%isearch-repeat-key-direction key-event)))
    (when repeat
      (isearch-repeat session repeat)
      (%isearch-refresh session minibuffer)
      t)))

(defun %isearch-confirm (session input)
  (declare (ignore session input))
  (%isearch-end))

(defun %isearch-cancel (session)
  (%isearch-restore-origin session)
  (%isearch-end))

(defun %isearch-activate-minibuffer (session minibuffer)
  (loom/core/minibuffer:minibuffer-activate minibuffer
                                            (%isearch-prompt-for session)
                                            :on-change
                                            (lambda (input)
                                              (%isearch-change session
                                                               minibuffer
                                                               input))
                                            :on-key
                                            (lambda (key-event)
                                              (%isearch-key session
                                                            minibuffer
                                                            key-event))
                                            :on-confirm
                                            (lambda (input)
                                              (%isearch-confirm session input))
                                            :on-cancel
                                            (lambda ()
                                              (%isearch-cancel session))))

(defun %isearch-start (direction)
  "Open an incremental-search prompt in DIRECTION over the selected buffer."
  (let* ((buffer
          (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*))))
         (minibuffer
          (loom/core/editor-session:editor-state-minibuffer
           loom/core/editor-session:*editor-state*)))
    (when (and buffer minibuffer)
      (let ((session
             (make-isearch-session buffer
                                   (buffer-point-offset buffer)
                                   :direction
                                   direction)))
        (setf (loom/core/editor-session:editor-state-isearch
               loom/core/editor-session:*editor-state*) session)
        (%isearch-activate-minibuffer session minibuffer))))
  nil)

(defun isearch-forward ()
  "Search forward as the pattern is typed (C-s).

Editing the pattern selects a match from the session's search offset; C-s repeats
forward and C-r repeats backward. RET keeps point where the search left it and
files the pattern in the minibuffer history, and C-g puts point back where the
search started. When nothing matches, the prompt says so and point stops
moving."
  (%isearch-start :forward))

(defun isearch-backward ()
  "Search backward as the pattern is typed (C-r). See ISEARCH-FORWARD."
  (%isearch-start :backward))
