;;;; packages/feature/project/src/application-commands-project.lisp
;;;;
;;;; Project navigation and search commands.  The commands depend on the
;;;; project domain and filesystem operations, while the editor state remains in
;;;; the src/<DDD> composition root.
(in-package #:loom/feature/project)

(defun %project-start-path ()
  (let ((buffer (loom/application:%selected-buffer)))
    (or (and buffer (buffer-path buffer))
        (truename "."))))

(defun %project-completion-candidates (input candidates)
  (let ((needle (string-downcase input)))
    (remove-if-not (lambda (candidate)
                     (or (string= needle "")
                         (search needle (string-downcase candidate))))
                   candidates)))

(defun %project-visit-file (root relative-path minibuffer)
  (let ((path (merge-pathnames relative-path root)))
    (if (probe-file path)
        (let ((buffer (buffer-load path)))
          (loom/application:%register-buffer buffer)
          (loom/feature/window:window-set-buffer
           (loom/application:%selected-window)
           buffer))
        (minibuffer-message minibuffer
                            (format nil "File not found: ~A"
                                    relative-path)))))

(defun project-find-file ()
  "Prompt for a file relative to the current project's root and visit it."
  (let ((root (project-find-root (%project-start-path))))
    (if root (let ((candidates
                (mapcar (lambda (path) (project-relative-path root path))
                        (project-list-files root))))
          (loom/application:with-prompts
              (minibuffer (editor-state-minibuffer *editor-state*)
                         :on-cancel (minibuffer-message minibuffer "Quit"))
              ((relative-path
                 "Project file: "
                 :completion-function
                 (lambda (input)
                   (%project-completion-candidates input candidates))))
            (%project-visit-file root relative-path minibuffer))) (minibuffer-message (editor-state-minibuffer *editor-state*)
                            "No project root found"))))

(defun %project-search-summary (root result)
  (let* ((path (getf result :path))
         (matches (getf result :matches))
         (first-match (first matches)))
    (format nil "~A:~D"
            (project-relative-path root path)
            (getf first-match :line))))

(defun %project-search-message (root results)
  (if results
      (format nil
              "Matches: ~{~A~^, ~}"
              (mapcar (lambda (result)
                        (%project-search-summary root result))
                      results))
      "No matches"))

(defun %project-search-with-query (root minibuffer query)
  (let ((results (project-search-files root query)))
    (minibuffer-message minibuffer (%project-search-message root results))
    results))

(defun project-search ()
  "Search every readable project file for a case-sensitive query."
  (let ((root (project-find-root (%project-start-path))))
    (if root (loom/application:with-prompts
            (minibuffer (editor-state-minibuffer *editor-state*)
                        :on-cancel (minibuffer-message minibuffer "Quit"))
          ((query "Project search: "))
          (%project-search-with-query root minibuffer query)) (minibuffer-message (editor-state-minibuffer *editor-state*)
                            "No project root found"))))

(defun project-root ()
  "Display the current project's root directory."
  (let ((root (project-find-root (%project-start-path))))
    (minibuffer-message (editor-state-minibuffer *editor-state*)
                        (if root
                            (format nil "Project root: ~A" (namestring root))
                            "No project root found"))))
