(in-package #:loom)

(define-condition loom-quit (condition) ()
  (:documentation
   "Signaled by SAVE-BUFFERS-KILL-TERMINAL to ask the main event loop in
src/main.lisp to exit cleanly."))

(progn
  (defun %quit-buffer-list ()
    "Return displayed buffers followed by hidden registered buffers."
    (let ((displayed
            (mapcar (function loom/feature/window:window-buffer)
                    (loom/feature/window:window-tree-windows
                     (editor-state-window-tree *editor-state*))))
          (registered (copy-list (%editor-buffers))))
      (remove-duplicates
       (append displayed registered)
       :test (function eq))))

  (cl-prolog-kit:define-rulebase *quit-answer-rulebase*
    ((quit-action ?answer ?has-path :save-and-continue)
     (:when (and ?has-path (string-equal ?answer "s"))))
    ((quit-action ?answer ?has-path :discard-and-continue)
     (:when (string-equal ?answer "d")))
    ((quit-action ?answer ?has-path :cancel)
     (:when (string-equal ?answer "c"))))

  (defun %quit-answer-action (answer has-path-p)
    "Return the action ANSWER selects for the quit prompt %CONTINUE-QUIT
shows for one modified buffer: :SAVE-AND-CONTINUE, :DISCARD-AND-CONTINUE,
:CANCEL, or :RETRY (an unrecognized answer). HAS-PATH-P is false for a
buffer with no path, whose prompt (\"Discard changes... (d/c)\") never
offers \"s\" in the first place, so an \"s\" answer there falls through to
:RETRY exactly as a genuinely unrecognized answer would."
    (or (cl-prolog-kit:with-prolog-query (?action)
            (*quit-answer-rulebase* `(quit-action ,answer ,has-path-p ?action))
          ?action)
        :retry))

  (defun %quit-prompt-text (buffer)
    "Return the confirmation prompt for modified BUFFER."
    (if (buffer-path buffer)
        (format nil "Save ~A? (s/d/c): " (buffer-name buffer))
        (format nil "Discard changes to ~A? (d/c): " (buffer-name buffer))))

  (defun %continue-quit-prompt (buffers buffer next)
    "Activate the quit prompt for BUFFER and continue with NEXT.
NEXT receives the remaining buffer list after a save or discard, or the
original list when the answer is invalid."
    (let* ((has-path-p (and (buffer-path buffer) t))
           (minibuffer (editor-state-minibuffer *editor-state*)))
      (minibuffer-activate
       minibuffer
       (%quit-prompt-text buffer)
       :on-confirm
       (lambda (answer)
         (ecase (%quit-answer-action answer has-path-p)
           (:save-and-continue
            (buffer-save buffer)
            (funcall next (remove buffer buffers :count 1 :test (function eq))))
           (:discard-and-continue
            (funcall next (remove buffer buffers :count 1 :test (function eq))))
           (:cancel nil)
           (:retry (funcall next buffers))))
       :on-cancel
       (lambda () (minibuffer-message minibuffer "Quit")))))

  (defun %continue-quit (buffers)
    "Prompt for the next modified buffer in BUFFERS, or signal LOOM-QUIT."
    (let ((buffer (find-if (function buffer-modified-p) buffers)))
      (if buffer (%continue-quit-prompt
           buffers buffer
           (lambda (next-buffers)
             (%continue-quit next-buffers))) (signal (quote loom-quit)))))

  (defun save-buffers-kill-terminal ()
    "Exit after resolving all modified buffers in the session."
    (%continue-quit (%quit-buffer-list))))
