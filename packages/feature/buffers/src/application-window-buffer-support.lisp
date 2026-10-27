(in-package #:loom/feature/buffers)

(defun %buffer-name-completion-candidates (input)
  "Return all registered buffer names as candidates for INPUT."
  (declare (ignore input))
  (mapcar #'buffer-name (registered-buffers *editor-session*)))

(defun %replace-buffer-in-windows (buffer replacement)
  "Replace BUFFER with REPLACEMENT in every window that displays it."
  (dolist
      (BUFFERS (window-tree-windows (editor-state-window-tree *editor-state*))
              replacement)
    (when (eq (window-buffer BUFFERS) buffer)
      (window-set-buffer BUFFERS replacement))))

(defun %special-buffer-p (buffer)
  "Return whether BUFFER uses the conventional internal-buffer name."
  (let ((name (buffer-name buffer)))
    (and (> (length name) 1)
         (char= (char name 0) #\*)
         (char= (char name (1- (length name))) #\*))))

(defun %kill-buffer-replacement (survivors)
  "Choose an ordinary survivor or a scratch buffer for a killed buffer."
  (or (find-if (lambda (candidate) (not (%special-buffer-p candidate))) survivors)
      (find "*scratch*" survivors :key (function buffer-name) :test (function string=))
      (make-buffer :name "*scratch*")))

(defun %kill-buffer-now (buffer)
  "Remove BUFFER and preserve the window and registry invariants."
  (let* ((session *editor-session*)
         (survivors (remove buffer (registered-buffers session) :test (function eq)))
         (replacement (%kill-buffer-replacement survivors)))
    (unless (member replacement survivors :test (function eq))
      (register-buffer session replacement))
    (%replace-buffer-in-windows buffer replacement)
    (unregister-buffer session buffer :reason :kill-buffer)
    (minibuffer-message (editor-state-minibuffer *editor-state*)
                        (format nil "Killed ~A" (buffer-name buffer)))))

(defun %kill-buffer-prompt-text (buffer)
  "Return the confirmation prompt for modified BUFFER."
  (if (buffer-path buffer)
      (format nil "Save ~A? (s/d/c): " (buffer-name buffer))
      (format nil "Discard changes to ~A? (d/c): " (buffer-name buffer))))

(defun %kill-buffer-answer-action (answer has-path-p)
  "Classify ANSWER for a modified buffer confirmation."
  (cond
    ((and has-path-p (string-equal answer "s")) :save)
    ((string-equal answer "d") :discard)
    ((string-equal answer "c") :cancel)
    (t :retry)))

(defun %prompt-kill-buffer (minibuffer buffer)
  "Ask how to handle modified BUFFER before killing it."
  (let ((has-path-p (not (null (buffer-path buffer)))))
    (minibuffer-activate minibuffer
                         (%kill-buffer-prompt-text buffer)
                         :on-confirm
                         (lambda (answer)
                           (case (%kill-buffer-answer-action answer has-path-p)
                             (:save
                               (buffer-save buffer)
                               (%kill-buffer-now buffer))
                             (:discard (%kill-buffer-now buffer))
                             (:cancel nil)
                             (:retry (%prompt-kill-buffer minibuffer buffer))))
                         :on-cancel
                         (lambda ()
                           (minibuffer-message minibuffer "Quit")))))
