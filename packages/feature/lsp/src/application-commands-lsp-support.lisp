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
  (let* ((window (loom/core/window-tree:window-tree-selected-window
 (loom/core/editor-session:editor-state-window-tree
  loom/core/editor-session:*editor-state*)))
         (scroll-line (loom/feature/window:window-scroll-line window))
         (scroll-column (loom/feature/window:window-scroll-column window))
         (scroll-sub-row (loom/feature/window:window-scroll-sub-row window))
         (review (make-buffer
                  :name "*LSP command review*"
                  :initial-content
                  (format nil "Discovered LSP command~%PageDown/C-v: next; PageUp/M-v: previous~%Config: ~A~%Directory: ~A~%Command: ~A~%"
                          configuration root command))))
    ;; The single-line minibuffer truncates long paths; review them in a wrapped buffer.
    (buffer-set-truncate-lines review nil)
    (buffer-set-read-only review t)
    (loom/feature/window:window-set-buffer window review)
    (labels ((restore-buffer ()
               (loom/feature/window:window-set-buffer window buffer)
               (setf (loom/feature/window:window-scroll-line window) scroll-line
                     (loom/feature/window:window-scroll-column window) scroll-column
                     (loom/feature/window:window-scroll-sub-row window) scroll-sub-row))
             (review-key (key-event)
               (let* ((descriptor (loom/core/command:key-event->descriptor key-event))
                      (movement
                        (cond
                          ((or (equal descriptor '(nil . :page-down))
                               (equal descriptor '((:control) . #\v)))
                           #'loom:next-visual-line-once)
                          ((or (equal descriptor '(nil . :page-up))
                               (equal descriptor '((:alt) . #\v)))
                           #'loom:previous-visual-line-once))))
                 (when movement
                   (dotimes (row (max 1 (1- (loom/feature/window:window-height window))))
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
    (handler-case (progn
                    (setf new-session (make-lsp-session :command
                                                        command
                                                        :directory
                                                        directory
                                                        :root-uri
                                                        root-uri))
                    (lsp-session-start new-session)
                    (%install-lsp-session new-session)
                    (values new-session nil))
      (error (condition)
        (when new-session
          (lsp-session-stop new-session))
        (values nil condition)))))

(defun %lsp-report-start-result (minibuffer session condition)
  (declare (ignore session))
  (if condition
      (loom/core/minibuffer:minibuffer-message minibuffer
                                               (format nil
                                                       "LSP start failed: ~A"
                                                       condition))
      (loom/core/minibuffer:minibuffer-message minibuffer "LSP started.")))
