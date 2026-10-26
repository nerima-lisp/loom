(in-package #:loom/feature/lsp)

(defun %lsp-buffer-directory (buffer)
  "Return BUFFER's containing directory, or NIL for an unsaved buffer."
  (let ((path (buffer-path buffer)))
    (and path (make-pathname :name nil :type nil :defaults (pathname path)))))

(defun %lsp-error-message (session)
  (or (lsp-session-last-error session) "unknown LSP error"))

(defun %lsp-command-prompt-string (discovered-command)
  (if discovered-command
      (format nil "LSP command [RET for ~A]: " discovered-command)
      "LSP command: "))

(defun %normalize-lsp-command (typed-command discovered-command)
  (or
   (and typed-command
        (let ((trimmed (string-trim '(#\Space #\Tab) typed-command)))
          (unless (string= trimmed "")
            trimmed)))
   discovered-command))

(defun %lsp-confirm-discovered-command (command root configuration buffer minibuffer)
  (let* ((window (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*)))
         (scroll-line (loom/core/window-tree:window-scroll-line window))
         (scroll-column (loom/core/window-tree:window-scroll-column window))
         (scroll-sub-row (loom/core/window-tree:window-scroll-sub-row window))
         (review (make-buffer
                  :name "*LSP command review*"
                  :initial-content
                  (format nil "Discovered LSP command~%PageDown/C-v: next; PageUp/M-v: previous~%Config: ~A~%Directory: ~A~%Command: ~A~%"
                          configuration root command))))
    ;; The single-line minibuffer truncates long paths; review them in a wrapped buffer.
    (buffer-set-truncate-lines review nil)
    (buffer-set-read-only review t)
    (loom/core/window-tree:window-set-buffer window review)
    (labels ((restore-buffer ()
               (loom/core/window-tree:window-set-buffer window buffer)
               (setf (loom/core/window-tree:window-scroll-line window) scroll-line
                     (loom/core/window-tree:window-scroll-column window) scroll-column
                     (loom/core/window-tree:window-scroll-sub-row window) scroll-sub-row))
             (review-key (key-event)
               (let* ((descriptor (loom/core/command:key-event->descriptor key-event))
                      (movement
                        (cond
                          ((or (equal descriptor '(nil . :page-down))
                               (equal descriptor '((:control) . #\v)))
                           #'next-visual-line-once)
                          ((or (equal descriptor '(nil . :page-up))
                               (equal descriptor '((:alt) . #\v)))
                           #'previous-visual-line-once))))
                 (when movement
                   (dotimes (row (max 1 (1- (loom/core/window-tree:window-height window))))
                     (funcall movement))
                   t))))
      (loom/core/minibuffer:minibuffer-activate minibuffer "Run discovered LSP command? Type yes: "
       :on-key #'review-key
       :on-cancel (lambda ()
                    (restore-buffer)
                    (loom/core/minibuffer:minibuffer-message minibuffer "Quit"))
       :on-confirm (lambda (answer)
                     (restore-buffer)
                     (if (string= answer "yes")
                         (%lsp-start-with-command command root buffer minibuffer)
                         (loom/core/minibuffer:minibuffer-message minibuffer "LSP start cancelled.")))))))

(defun %install-lsp-session (new-session)
  (let ((old-session
         (loom/core/editor-session:editor-state-lsp-session
          loom/core/editor-session:*editor-state*)))
    (setf (loom/core/editor-session:editor-state-lsp-session
           loom/core/editor-session:*editor-state*) new-session)
    (when old-session
      (lsp-session-stop old-session))))

(defun %lsp-start-session (command directory)
  (let ((new-session nil)
        (root-uri (and directory (lsp-path-uri directory))))
    (handler-case
        (progn
          (setf new-session
                (make-lsp-session
                 :command command
                 :directory directory
                 :root-uri root-uri))
          (lsp-session-start new-session)
          (%install-lsp-session new-session)
          (values new-session nil))
      (error (condition)
        (let ((failure
                (or (and new-session
                         (lsp-session-transport-error new-session))
                    condition)))
          (when new-session
            (lsp-session-stop new-session))
          (values nil failure))))))

(defun %lsp-report-start-result (minibuffer session condition)
  (declare (ignore session))
  (if condition
      (loom/core/minibuffer:minibuffer-message
       minibuffer
       (format nil
               "LSP start failed: ~A"
               (if (typep condition (quote lsp-transport-send-exit-error))
                   (format nil
                           "server exited with status ~D"
                           (lsp-transport-send-exit-status condition))
                   condition)))
      (loom/core/minibuffer:minibuffer-message minibuffer "LSP started.")))
