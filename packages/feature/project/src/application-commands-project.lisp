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
  (let ((path (merge-pathnames relative-path root)))
    (if (probe-file path)
        (let ((buffer (buffer-load path)))
          (register-buffer *editor-session* buffer)
          (window-set-buffer
           (loom/core/window-tree:window-tree-selected-window
            (editor-state-window-tree *editor-state*))
           buffer))
        (minibuffer-message minibuffer
                            (format nil "File not found: ~A" relative-path)))))

(defun %project-file-candidates (root)
  (mapcar
   (lambda (path)
     (project-relative-path root path))
   (project-list-files root)))

(defun %project-find-file-at-root (root)
  (let ((candidates (%project-file-candidates root)))
    (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel
                 (minibuffer-message minibuffer "Quit"))
     ((relative-path "Project file: "
                     :completion-function
                     (lambda (input)
                       (%project-completion-candidates input candidates))))
     (%project-visit-file root relative-path minibuffer))))

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
  (let ((root (project-find-root (%project-start-path))))
    (if root
        (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                     :on-cancel
                     (minibuffer-message minibuffer "Quit"))
         ((query "Project search: "))
         (%project-search-with-query root minibuffer query))
        (minibuffer-message (editor-state-minibuffer *editor-state*)
                            "No project root found"))))

(defun project-root ()
  "Display the current project's root directory."
  (let ((root (project-find-root (%project-start-path))))
    (minibuffer-message (editor-state-minibuffer *editor-state*)
                        (if root
                            (format nil "Project root: ~A" (namestring root))
                            "No project root found"))))
