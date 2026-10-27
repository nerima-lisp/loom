(in-package #:loom/feature/project)

(defun %project-start-path ()
  (let* ((buffer
           (loom/core/window-tree:window-buffer
            (loom/core/window-tree:window-tree-selected-window
             (editor-state-window-tree *editor-state*))))
         (state
           (and *editor-session*
                (editor-session-slice *editor-session* :feature/project)))
         (result-root
           (and buffer
                state
                (eq buffer (project-search-state-result-buffer state))
                (project-search-state-last-root state))))
    (or (and buffer (buffer-path buffer))
        result-root
        (truename "."))))

(defun %project-completion-candidates (input candidates)
  (let ((needle (string-downcase input)))
    (remove-if-not
     (lambda (candidate)
       (or (string= needle "") (search needle (string-downcase candidate))))
     candidates)))

(defun %project-visit-file (root relative-path minibuffer)
  (let* ((path (merge-pathnames relative-path root))
         (existing-path (probe-file path)))
    (cond
      ((and existing-path (host-kit:directory-pathname-p existing-path))
       (minibuffer-message minibuffer "Cannot open project directory"))
      (existing-path
       (let ((buffer (buffer-load existing-path)))
         (register-buffer *editor-session* buffer)
         (window-set-buffer
          (loom/core/window-tree:window-tree-selected-window
           (editor-state-window-tree *editor-state*))
          buffer)))
      (t
       (minibuffer-message minibuffer
                           (format nil "File not found: ~A" relative-path))))))

(defun %project-file-candidates (root)
  (mapcar
   (lambda (path)
     (project-relative-path root path))
   (project-list-files root)))

(defun %project-find-file-at-root (root)
  (let ((candidates (%project-file-candidates root))
        (minibuffer (editor-state-minibuffer *editor-state*)))
    (%activate-project-prompt
     minibuffer "Project file: " :project-file
     (lambda (relative-path)
       (%project-visit-file root relative-path minibuffer))
     :completion-function
     (lambda (input)
       (%project-completion-candidates input candidates))
     :on-cancel (lambda () (minibuffer-message minibuffer "Quit")))))

(defun project-find-file ()
  "Prompt for a file relative to the current project's root and visit it."
  (let ((root (project-find-root (%project-start-path))))
    (if root
        (%project-find-file-at-root root)
        (minibuffer-message (editor-state-minibuffer *editor-state*)
                            "No project root found"))))

(defun %project-search-with-query (root minibuffer query)
  (%project-search-start *editor-session* *editor-state* root minibuffer query))

(defun project-search ()
  "Search every readable project file for a case-sensitive query."
  (%project-search-supersede-active-work *editor-session*)
  (let ((root (project-find-root (%project-start-path)))
        (minibuffer (editor-state-minibuffer *editor-state*)))
    (if root
        (%activate-project-prompt
         minibuffer "Project search: " :project-search
         (lambda (query)
           (%project-search-with-query root minibuffer query))
         :on-cancel (lambda () (minibuffer-message minibuffer "Quit")))
        (minibuffer-message minibuffer "No project root found"))))

(progn
  (defun project-root ()
    "Display the current project's root directory."
    (let ((root (project-find-root (%project-start-path))))
      (minibuffer-message (editor-state-minibuffer *editor-state*)
                          (if root
                              (format nil "Project root: ~A" (namestring root))
                              "No project root found"))))

  (defun %activate-project-prompt
      (minibuffer prompt history-key on-confirm &key on-cancel completion-function)
    (let* ((session *editor-session*)
           (state (and session
                       (member :feature/project
                               (loom/core/editor-session:editor-session-slice-names session))
                       (editor-session-slice session :feature/project))))
      (if (null state)
          (loom/core/minibuffer:minibuffer-activate
           minibuffer prompt
           :on-confirm on-confirm
           :on-cancel on-cancel
           :completion-function completion-function)
        (let ((shared-history
               (loom/core/minibuffer:minibuffer-history-entries minibuffer))
              (histories (project-search-state-prompt-histories state)))
          (loom/core/minibuffer:minibuffer-set-history-entries
           minibuffer (gethash history-key histories))
          (loom/core/minibuffer:minibuffer-activate
           minibuffer prompt
           :on-confirm
           (lambda (input)
             (setf (gethash history-key histories)
                   (loom/core/minibuffer:minibuffer-history-entries
                    minibuffer))
             (loom/core/minibuffer:minibuffer-set-history-entries
              minibuffer shared-history)
             (when on-confirm
               (funcall on-confirm input)))
           :on-cancel
           (lambda ()
             (loom/core/minibuffer:minibuffer-set-history-entries
              minibuffer shared-history)
             (when on-cancel
               (funcall on-cancel)))
           :completion-function completion-function)))))
)
