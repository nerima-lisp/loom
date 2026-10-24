(defpackage #:loom/feature/project
  (:use #:cl)
  (:import-from #:loom/core/buffer
                #:buffer-load
                #:buffer-path
                #:buffer-text)
  (:import-from #:loom/core/editor-session
                #:*editor-session*
                #:*editor-state*
                #:editor-state-minibuffer
                #:editor-state-window-tree)
  (:import-from #:loom/core/minibuffer
                #:minibuffer-message
                #:with-prompts)
  (:import-from #:loom/core/window-tree
                #:window-set-buffer)
  (:import-from #:loom/feature/buffers
                #:register-buffer)
  (:export #:project-marker-names
           #:project-ignored-directory-names
           #:project-marker-name-p
           #:project-directory-path
           #:project-parent-directory
           #:project-root-for-path
           #:project-relative-path
           #:project-search-lines
           #:project-find-root
           #:project-list-files
           #:project-search-files
           #:project-find-file
           #:project-search
           #:project-root))
