(in-package #:loom/feature/buffers)

(progn
  (defvar *buffer-switch-guard* nil)
  (defvar *buffer-switch-guard-owner* nil)

  (defun register-buffer-switch-guard (owner function)
    "Register OWNER's asynchronous guard for switching to a buffer."
    (unless (keywordp owner)
      (error "Buffer-switch guard owner must be a keyword: ~S" owner))
    (check-type function function)
    (when (and *buffer-switch-guard-owner*
               (not (eq owner *buffer-switch-guard-owner*)))
      (error "Buffer-switch guard is already registered by ~S"
             *buffer-switch-guard-owner*))
    (setf *buffer-switch-guard-owner* owner
          *buffer-switch-guard* function)
    function)

  (defun run-buffer-switch-guard (buffer continuation)
    "Run the registered asynchronous switch guard for BUFFER."
    (if *buffer-switch-guard*
        (funcall *buffer-switch-guard* buffer continuation)
        (funcall continuation)))

  (defun switch-to-buffer ()
    "Prompt for a buffer name and display it in the selected window."
    (with-prompts
     (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel
                 (minibuffer-message minibuffer "Quit"))
     ((name "Switch to buffer: "
            :completion-function
            #'%buffer-name-completion-candidates))
     (let* ((match (find-buffer-by-name *editor-session* name))
            (window (window-tree-selected-window
                     (editor-state-window-tree *editor-state*))))
       (if match
           (let ((continued nil))
             (run-buffer-switch-guard
              match
              (lambda ()
                (unless continued
                  (setf continued t)
                  (window-set-buffer window match)))))
           (minibuffer-message minibuffer
                               (format nil "No such buffer: ~A" name)))))))

(defun kill-buffer ()
  "Prompt for a buffer name and remove it from the session registry."
  (with-prompts
   (minibuffer (editor-state-minibuffer *editor-state*)
               :on-cancel
               (minibuffer-message minibuffer "Quit"))
   ((name "Kill buffer: "
          :completion-function
          #'%buffer-name-completion-candidates))
   (let ((buffer
          (find-buffer-by-name *editor-session* name)))
     (cond
       ((null buffer)
        (minibuffer-message minibuffer (format nil "No such buffer: ~A" name)))
       ((buffer-modified-p buffer) (%prompt-kill-buffer minibuffer buffer))
       (t (%kill-buffer-now buffer))))))

(defun kill-buffer-with-confirmation (buffer &key (on-killed (lambda ()))
                                                  (on-cancelled (lambda ())))
  "Kill BUFFER, asking first when it is modified, and report the outcome.

An unmodified BUFFER is killed at once. A modified one gets KILL-BUFFER's
prompt: s saves and kills, d kills, and c, C-g, or a save error keeps it.
ON-KILLED runs after the kill and ON-CANCELLED otherwise, each at most once.
ON-CANCELLED may run inside the minibuffer's on-cancel callback, which
deactivates the minibuffer afterwards, so it must not open a new prompt."
  (if (buffer-modified-p buffer)
      (%prompt-kill-buffer (editor-state-minibuffer *editor-state*)
                           buffer on-killed on-cancelled)
      (progn
        (%kill-buffer-now buffer)
        (funcall on-killed))))
