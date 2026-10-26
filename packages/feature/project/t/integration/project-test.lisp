(in-package #:loom/test)

(describe
  "project filesystem integration"
  (it
    "finds the root, skips ignored directories, and searches files"
    (host-kit:with-temporary-directory (directory)
      (let* ((root (truename directory))
             (main-path (merge-pathnames "src/main.py" root))
             (ignored-path (merge-pathnames "target/generated.py" root))
             (nested-ignored-path
               (merge-pathnames "src/node_modules/package/index.js" root))
             (hidden-ignored-path (merge-pathnames ".git/objects/blob" root)))
        (ensure-directories-exist main-path)
        (progn
          (ensure-directories-exist ignored-path)
          (host-kit:write-file-string "" (merge-pathnames "flake.nix" root)))
        (ensure-directories-exist nested-ignored-path)
        (ensure-directories-exist hidden-ignored-path)
        (host-kit:write-file-string "" (merge-pathnames "flake.nix" root))
        (host-kit:write-file-string "print('needle')" main-path)
        (host-kit:write-file-string "needle" ignored-path)
        (host-kit:write-file-string "needle" nested-ignored-path)
        (host-kit:write-file-string "needle" hidden-ignored-path)

        (expect (namestring (project-find-root main-path))
                :to-equal
                (namestring root))
        (expect (mapcar (lambda (path) (project-relative-path root path))
                        (project-list-files root))
                :to-equal
                '("flake.nix" "src/main.py"))
        (let ((visited nil)
              (completion-count 0))
          (loom/feature/project::%project-walk-files-cps
           root
           (lambda (path) (push (project-relative-path root path) visited))
           (lambda () (incf completion-count)))
          (expect (sort visited #'string<) :to-equal
                  '("flake.nix" "src/main.py"))
          (expect completion-count :to-be 1))
        (let ((results (project-search-files root "needle")))
          (expect (length results) :to-equal 1)
          (expect (project-relative-path root (getf (first results) :path))
                  :to-equal "src/main.py")))))

  ;; GNU Emacs Manual, “Compilation Mode”: RET visits a listed match and M-g n/p navigate results.
  ;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Compilation-Mode.html
  (it
    "opens project files and searches asynchronously with result-list navigation"
    (host-kit:with-temporary-directory (directory)
      (let* ((root (truename directory))
             (main-path (merge-pathnames "src/main.py" root))
             (ignored-path (merge-pathnames "target/generated.py" root))
             (current (make-buffer :name "current.py"
                                   :path main-path
                                   :initial-content
                                   (format nil "print('needle')~%print('needle again')")))
             (tree (make-window-tree current 80 24))
             (minibuffer (make-minibuffer))
             (*editor-state*
               (make-editor-state :window-tree tree
                                  :minibuffer minibuffer
                                  :keymap (make-keymap)
                                  :file-tree nil
                                  :renderer nil
                                  :session (%make-project-test-session
                                            (list current)
                                            :window-tree tree)
                                  :kill-ring nil))
             (loom/core/editor-session:*editor-session*
              (loom/core/editor-session:editor-state-session *editor-state*)))
        (ensure-directories-exist main-path)
        (ensure-directories-exist ignored-path)
        (host-kit:write-file-string "" (merge-pathnames "flake.nix" root))
        (host-kit:write-file-string
         (format nil "print('needle')~%print('needle again')")
         main-path)
        (host-kit:write-file-string "needle" ignored-path)

        (loom/feature/project::project-find-file)
        (%expect-minibuffer-prompt minibuffer (%project-file-prompt-string))
        (minibuffer-handle-key
         minibuffer
         (cl-tty-kit:make-key-event :type :special :code :tab))
        (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "src/main.py")
        (expect (namestring (buffer-path (%selected-test-buffer)))
                :to-equal
                (namestring main-path))
        (expect (buffer-major-mode (%selected-test-buffer)) :to-be :python)

        (loom/feature/project::project-search)
        (%expect-minibuffer-prompt minibuffer (%project-search-prompt-string))
        (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "needle")
        (let* ((session
                 (loom/core/editor-session:editor-state-session *editor-state*))
               (work
                 (loom/feature/project::project-search-state-active-work
                  (loom/core/editor-session:editor-session-slice
                   session :feature/project))))
          (cl-concurrent-kit:await
           (loom/feature/project::project-search-work-result-promise work))
          (loom/core/editor-session:notify-background-work-ready
           session (loom/feature/project::project-search-work-token work))
          (loom/core/editor-session:poll-ready-background-work session))
        (expect (loom:minibuffer-message-string minibuffer)
                :to-equal
                "Matches: src/main.py:1")
        (expect (count #\Newline (buffer-text (%selected-test-buffer)))
                :to-equal
                1)
        (expect (search "generated.py" (buffer-text (%selected-test-buffer)))
                :to-be
                nil)
        (expect (buffer-text (%selected-test-buffer))
                :to-contain
                "main.py:1:8: print('needle')")
        (loom/feature/search:search-result-visit)
        (expect (%selected-test-buffer) :to-have-point (cons 0 7))
        (loom/feature/search:next-error)
        (expect (%selected-test-buffer) :to-have-point (cons 1 7))
        (loom/feature/search:previous-error)
        (expect (%selected-test-buffer) :to-have-point (cons 0 7))

        (loom/feature/project::project-find-file)
        (minibuffer-handle-key
         minibuffer
         (cl-tty-kit:make-key-event :type :special :code :control-g))
        (expect (loom:minibuffer-message-string minibuffer) :to-equal "Quit")

        (loom/feature/project::project-find-file)
        (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "missing.py")
        (expect (loom:minibuffer-message-string minibuffer)
                :to-equal
                "File not found: missing.py")

        (loom/feature/project::project-search)
        (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "absent")
        (let* ((session
                 (loom/core/editor-session:editor-state-session *editor-state*))
               (work
                 (loom/feature/project::project-search-state-active-work
                  (loom/core/editor-session:editor-session-slice
                   session :feature/project))))
          (cl-concurrent-kit:await
           (loom/feature/project::project-search-work-result-promise work))
          (loom/core/editor-session:notify-background-work-ready
           session (loom/feature/project::project-search-work-token work))
          (loom/core/editor-session:poll-ready-background-work session))
        (expect (loom:minibuffer-message-string minibuffer)
                :to-equal
                "No matches")

        (loom/feature/project::project-root)
        (expect (loom:minibuffer-message-string minibuffer)
                :to-contain
                "Project root:"))))

  (it
    "cancels active project search on C-g and leaves unrelated C-g alone"
    (let* ((current (make-buffer :name "current.py" :initial-content "current"))
           (tree (make-window-tree current 80 24))
           (minibuffer (make-minibuffer))
           (*editor-state*
             (make-editor-state
              :window-tree tree
              :minibuffer minibuffer
              :keymap (make-keymap)
              :file-tree nil
              :renderer nil
              :session
              (%make-project-test-session (list current) :window-tree tree)
              :kill-ring nil))
           (session
             (loom/core/editor-session:editor-state-session *editor-state*))
           (work
             (loom/feature/project::%make-project-search-work
              :root nil
              :query "needle"
              :minibuffer minibuffer
              :editor-state *editor-state*
              :result-promise (cl-concurrent-kit:make-promise)
              :cancellation-counter (cl-concurrent-kit:make-atomic-counter)
              :executor nil))
           (state
             (loom/core/editor-session:editor-session-slice
              session :feature/project))
           (token nil)
           (control-g
             (cl-tty-kit:make-key-event
              :type :special :code :control-g)))
      (setf token
            (loom/core/editor-session:register-background-work
             session
             :feature/project
             (lambda (received-session received-token)
               (declare (ignore received-session received-token))
               (values nil t))
             (lambda (received-session received-token)
               (loom/feature/project::%project-search-cancel-background-work
                received-session received-token work))))
      (setf (loom/feature/project::project-search-work-token work) token
            (loom/feature/project::project-search-state-active-work state) work)
      (expect (loom/core/editor-session:run-session-hooks
               :key-input session control-g :key)
              :to-equal
              :handled)
      (expect (cl-concurrent-kit:atomic-counter-value
               (loom/feature/project::project-search-work-cancellation-counter work))
              :to-equal
              1)
      (expect (loom/feature/project::project-search-state-active-work state)
              :to-be
              nil)
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal
              "Project search canceled")
      (loom/core/editor-session:poll-ready-background-work session)
      (expect (loom/core/editor-session:run-session-hooks
               :key-input session control-g :key)
              :to-equal
              :pass)))
  (it
    "suppresses queued results when C-g arrives before project search polling"
    (host-kit:with-temporary-directory (directory)
      (let* ((root (truename directory))
             (target-path (merge-pathnames "pending.py" root))
             (current (make-buffer :name "current.py" :initial-content "current"))
             (tree (make-window-tree current 80 24))
             (minibuffer (make-minibuffer))
             (*editor-state*
               (make-editor-state
                :window-tree tree
                :minibuffer minibuffer
                :keymap (make-keymap)
                :file-tree nil
                :renderer nil
                :session (%make-project-test-session
                          (list current) :window-tree tree)
                :kill-ring nil))
             (session
               (loom/core/editor-session:editor-state-session *editor-state*))
             (work
               (loom/feature/project::%make-project-search-work
                :root root
                :query "needle"
                :minibuffer minibuffer
                :editor-state *editor-state*
                :result-promise (cl-concurrent-kit:make-promise)
                :cancellation-counter (cl-concurrent-kit:make-atomic-counter)
                :executor nil))
             (state
               (loom/core/editor-session:editor-session-slice
                session :feature/project))
             (control-g
               (cl-tty-kit:make-key-event
                :type :special :code :control-g)))
        (setf (loom/feature/project::project-search-work-token work)
              (loom/core/editor-session:register-background-work
               session
               :feature/project
               (lambda (received-session received-token)
                 (loom/feature/project::%project-search-poll
                  received-session received-token work))
               (lambda (received-session received-token)
                 (loom/feature/project::%project-search-cancel-background-work
                  received-session received-token work)))
              (loom/feature/project::project-search-state-active-work state)
              work)
        (cl-concurrent-kit:deliver
         (loom/feature/project::project-search-work-result-promise work)
         (list :kind :complete
               :results
               (list (list :path target-path
                           :matches (list (list :line 1 :text "needle"))))
               :items
               (list
                (loom/feature/search:make-result-item
                 target-path 0 0 "needle"))))
        (loom/core/editor-session:notify-background-work-ready
         session (loom/feature/project::project-search-work-token work))
        (expect (loom/core/editor-session:run-session-hooks
                 :key-input session control-g :key)
                :to-equal
                :handled)
        (expect (loom/feature/project::project-search-state-active-work state)
                :to-be
                nil)
        (loom/core/editor-session:poll-ready-background-work session)
        (expect (eq (%selected-test-buffer) current) :to-be t)
        (expect (loom:minibuffer-message-string minibuffer)
                :to-equal
                "Project search canceled"))))
  )
