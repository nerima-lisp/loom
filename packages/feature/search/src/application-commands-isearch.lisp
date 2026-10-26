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
        (failed (isearch-session-failed-p session))
        (regexp-p (%isearch-regexp-p session)))
    (cond
      ((and regexp-p failed backward) "Failing regexp I-search backward: ")
      ((and regexp-p failed) "Failing regexp I-search: ")
      ((and regexp-p backward) "Regexp I-search backward: ")
      (regexp-p "Regexp I-search: ")
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
  "Return the direction of a C-s or C-r repeat key, if any."
  (let* ((descriptor (loom/core/command:key-event->descriptor key-event))
         (modifiers (car descriptor))
         (character (cdr descriptor)))
    (when (equal modifiers (list :control))
      (case character
        (#\s :forward)
        (#\r :backward)))))

(defun %isearch-change (session minibuffer input)
  (isearch-apply-pattern session input)
  (%isearch-refresh session minibuffer))

(defun %isearch-key (session minibuffer key-event)
  (let* ((descriptor (loom/core/command:key-event->descriptor key-event))
         (modifiers (car descriptor))
         (character (cdr descriptor)))
    (cond
      ((and (equal modifiers (list :alt))
            (eql character #\r))
       (setf (%isearch-regexp-p session)
             (not (%isearch-regexp-p session)))
       (%isearch-change
        session minibuffer
        (loom/core/minibuffer:minibuffer-input-string minibuffer))
       t)
      (t
       (let ((direction (%isearch-repeat-key-direction key-event)))
         (when direction
           (isearch-repeat session direction)
           (%isearch-refresh session minibuffer)
           t))))))

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

(defun %isearch-start (direction &key regexp-p)
  "Open an incremental-search prompt in DIRECTION over the selected buffer."
  (let* ((selected-window
           (loom/core/window-tree:window-tree-selected-window
            (editor-state-window-tree *editor-state*)))
         (buffer (loom/core/window-tree:window-buffer selected-window))
         (minibuffer
           (loom/core/editor-session:editor-state-minibuffer
            loom/core/editor-session:*editor-state*)))
    (when (and buffer minibuffer)
      (let ((session (make-isearch-session buffer
                                          (buffer-point-offset buffer)
                                          :direction direction
                                          :regexp-p regexp-p)))
        (setf (loom/core/editor-session:editor-state-isearch
               loom/core/editor-session:*editor-state*) session)
        (%isearch-activate-minibuffer session minibuffer))))
  nil)

(defun isearch-forward ()
  "Search literal text incrementally (C-s).

C-s repeats forward and C-r repeats backward. M-r toggles between literal and
regexp matching; C-M-s and C-M-r start regexp isearch. RET keeps point at the
match and records the pattern in history. C-g restores the starting point. A
nonmatching pattern leaves point at the last successful match."
  (%isearch-start :forward))

(defun isearch-backward ()
  "Search backward through literal text incrementally (C-r)."
  (%isearch-start :backward))
(defun isearch-forward-regexp ()
  "Search forward incrementally using a regular expression (C-M-s)."
  (%isearch-start :forward :regexp-p t))
(defun isearch-backward-regexp ()
  "Search backward incrementally using a regular expression (C-M-r)."
  (%isearch-start :backward :regexp-p t))
