(in-package #:loom/feature/project)

(defun %make-project-search-state-for-session (session)
  (declare (ignore session))
  (%make-project-search-state))

(progn
  (defstruct (project-search-state
              (:constructor %make-project-search-state ()))
    active-work
    last-root
    result-buffer)

  (defstruct (project-search-work
              (:constructor %make-project-search-work
                  (&key root query minibuffer editor-state result-promise
                        cancellation-counter executor)))
    root
    query
    minibuffer
    editor-state
    result-promise
    cancellation-counter
    executor
    token)

  (register-slice-state :feature/project '%make-project-search-state-for-session)

  (defun %project-search-summary (root result)
    (let* ((path (getf result :path))
           (matches (getf result :matches))
           (first-match (first matches)))
      (format nil
              "~A:~D"
              (project-relative-path root path)
              (getf first-match :line))))

  (defun %project-search-message (root results)
    (if results
        (format nil
                "Matches: ~{~A~^, ~}"
                (mapcar
                 (lambda (result)
                   (%project-search-summary root result))
                 results))
        "No matches"))

  (defun %project-search-cancelled-p (work)
    (plusp
     (cl-concurrent-kit:atomic-counter-value
      (project-search-work-cancellation-counter work))))

  (defun %project-search-directory-files (root work)
    (let ((directories (list (project-directory-path root)))
          (files nil))
      (loop while directories
            for directory = (pop directories)
            do (when (%project-search-cancelled-p work)
                 (return-from %project-search-directory-files
                   (values nil t)))
               (dolist (entry
                        (loom/feature/file-tree:loom-fs-list-directory
                         directory))
                 (when (%project-search-cancelled-p work)
                   (return-from %project-search-directory-files
                     (values nil t)))
                 (destructuring-bind (path . kind) entry
                   (cond
                     ((eq kind :file)
                      (push path files))
                     ((and (eq kind :directory)
                           (not (%project-ignored-directory-p path)))
                      (push path directories))))))
      (values (sort files #'string< :key #'namestring) nil)))

  (defun %project-search-file-results (path query work)
    (let ((content
            (ignore-errors
              (buffer-text (buffer-load path)))))
      (when content
        (let ((matches nil)
              (items nil))
          (with-input-from-string (stream content)
            (loop for zero-based-line from 0
                  for line = (read-line stream nil nil)
                  while line
                  do (when (%project-search-cancelled-p work)
                       (return-from %project-search-file-results
                         (values nil nil t)))
                     (unless (string= query "")
                       (let ((column (search query line)))
                         (when column
                           (push (list :line (1+ zero-based-line)
                                       :text line)
                                 matches)
                           (push
                            (loom/feature/search:make-result-item
                             path zero-based-line column line)
                            items))))))
          (values (nreverse matches) (nreverse items) nil)))))

  (defun %project-search-run (root query work)
    (when (string= query "")
      (return-from %project-search-run
        (list :kind :complete :results nil :items nil)))
    (multiple-value-bind (files cancelled-p)
        (%project-search-directory-files root work)
      (when cancelled-p
        (return-from %project-search-run (list :kind :cancelled)))
      (let ((results nil)
            (items nil))
        (dolist (path files)
          (when (%project-search-cancelled-p work)
            (return-from %project-search-run
              (list :kind :cancelled)))
          (multiple-value-bind (matches file-items file-cancelled-p)
              (%project-search-file-results path query work)
            (when file-cancelled-p
              (return-from %project-search-run
                (list :kind :cancelled)))
            (when matches
              (push (list :path path :matches matches) results))
            (dolist (item file-items)
              (push item items))))
        (list :kind :complete
              :results (nreverse results)
              :items (nreverse items)))))

  (defun %project-search-shutdown-executor (work cancel-pending)
    (let ((executor (project-search-work-executor work)))
      (when (and executor
                 (not (cl-concurrent-kit:executor-shutdown-p executor)))
        (cl-concurrent-kit:shutdown-executor
         executor :wait nil :cancel-pending cancel-pending))))

  (defun %project-search-worker (session token work)
    (let ((outcome
            (handler-case
                (%project-search-run
                 (project-search-work-root work)
                 (project-search-work-query work)
                 work)
              (error (condition)
                (list :kind :error :condition condition)))))
      (cl-concurrent-kit:deliver
       (project-search-work-result-promise work)
       outcome)
      (loom/core/editor-session:notify-background-work-ready session token)))

  (defun %project-search-cancel-background-work (session token work)
    (cl-concurrent-kit:atomic-counter-incf
     (project-search-work-cancellation-counter work))
    (let ((state
            (loom/core/editor-session:editor-session-slice
             session :feature/project)))
      (when (eq (project-search-state-active-work state) work)
        (setf (project-search-state-active-work state) nil)
        (minibuffer-message
         (project-search-work-minibuffer work)
         "Project search canceled")))
    (%project-search-shutdown-executor work nil)
    (loom/core/editor-session:notify-background-work-ready session token))

  (defun %project-search-poll (session token work)
    (declare (ignore token))
    (unless (cl-concurrent-kit:promise-settled-p
             (project-search-work-result-promise work))
      (return-from %project-search-poll (values nil nil)))
    (let* ((outcome
             (cl-concurrent-kit:await
              (project-search-work-result-promise work)))
           (state
             (loom/core/editor-session:editor-session-slice
              session :feature/project))
           (active-p
             (eq (project-search-state-active-work state) work)))
      (when active-p
        (setf (project-search-state-active-work state) nil)
        (case (getf outcome :kind)
          (:complete
           (let* ((items (getf outcome :items))
                  (result-buffer
                    (loom/feature/search:publish-result-list
                     session "*Project Search*" items))
                  (editor-state
                    (project-search-work-editor-state work))
                  (window-tree
                    (editor-state-window-tree editor-state))
                  (window
                    (and window-tree
                         (loom/core/window-tree:window-tree-selected-window
                          window-tree))))
             (setf (project-search-state-last-root state)
                   (project-search-work-root work)
                   (project-search-state-result-buffer state)
                   result-buffer)
             (when (and items window)
               (window-set-buffer window result-buffer))
             (minibuffer-message
              (project-search-work-minibuffer work)
              (%project-search-message
               (project-search-work-root work)
               (getf outcome :results)))))
          (:cancelled
           (minibuffer-message
            (project-search-work-minibuffer work)
            "Project search canceled"))
          (:error
           (minibuffer-message
            (project-search-work-minibuffer work)
            (format nil "Project search failed: ~A"
                    (or (getf outcome :condition)
                        (getf outcome :message)
                        "unknown error")))))
      (%project-search-shutdown-executor work t)
      (values active-p t))))
  (defun %project-search-cancel-active-work (session)
    (let* ((state
             (loom/core/editor-session:editor-session-slice
              session :feature/project))
           (work (project-search-state-active-work state)))
      (when work
        (loom/core/editor-session:cancel-background-work
         session (project-search-work-token work)))
      work))
  (defun %project-search-supersede-active-work (session)
    (let* ((state
             (loom/core/editor-session:editor-session-slice
              session :feature/project))
           (work (project-search-state-active-work state)))
      (when work
        (setf (project-search-state-active-work state) nil)
        (loom/core/editor-session:cancel-background-work
         session (project-search-work-token work)))
      work))
  (defun %project-search-deliver-start-error (session token work condition)
    (cl-concurrent-kit:deliver
     (project-search-work-result-promise work)
     (list :kind :error :condition condition))
    (loom/core/editor-session:notify-background-work-ready session token))
  (defun %project-search-start (session editor-state root minibuffer query)
    (let ((executor
            (handler-case
                (cl-concurrent-kit:make-executor
                 :size 1 :name "loom project search" :queue-capacity 1)
              (error (condition)
                (minibuffer-message
                 minibuffer
                 (format nil "Project search failed: ~A" condition))
                (return-from %project-search-start nil)))))
      (let* ((state
               (loom/core/editor-session:editor-session-slice
                session :feature/project))
             (work
               (%make-project-search-work
                :root root
                :query query
                :minibuffer minibuffer
                :editor-state editor-state
                :result-promise (cl-concurrent-kit:make-promise)
                :cancellation-counter
                (cl-concurrent-kit:make-atomic-counter)
                :executor executor)))
        (setf (project-search-state-active-work state) work
              (project-search-state-last-root state) root)
        (handler-case
            (setf (project-search-work-token work)
                  (loom/core/editor-session:register-background-work
                   session
                   :feature/project
                   (lambda (received-session token)
                     (%project-search-poll received-session token work))
                   (lambda (received-session token)
                     (%project-search-cancel-background-work
                      received-session token work))))
          (error (condition)
            (setf (project-search-state-active-work state) nil)
            (%project-search-shutdown-executor work t)
            (minibuffer-message
             minibuffer
             (format nil "Project search failed: ~A" condition))
            (return-from %project-search-start nil)))
        (handler-case
            (multiple-value-bind (task-promise accepted-p)
                (cl-concurrent-kit:try-submit
                 executor
                 (lambda ()
                   (%project-search-worker
                    session (project-search-work-token work) work)))
              (declare (ignore task-promise))
              (unless accepted-p
                (%project-search-deliver-start-error
                 session
                 (project-search-work-token work)
                 work
                 "Could not start project search")))
          (error (condition)
            (%project-search-deliver-start-error
             session (project-search-work-token work) work condition)))
        (minibuffer-message minibuffer "Searching project...")
        work)))
  (defun %project-search-key-input (session event route)
    (if (member :feature/project
                (loom/core/editor-session:editor-session-slice-names session))
        (let ((work
                (project-search-state-active-work
                 (loom/core/editor-session:editor-session-slice
                  session :feature/project))))
          (if (and work
                   (eq route :key)
                   (eq (cl-tty-kit:key-event-type event) :special)
                   (eq (cl-tty-kit:key-event-code event) :control-g))
              (progn
                (%project-search-cancel-active-work session)
                :handled)
              :pass))
        :pass))
  (eval-when (:load-toplevel :execute)
    (register-session-hook
     :key-input :feature/project #'%project-search-key-input)))
