(in-package #:loom/feature/search)
(progn
  (defstruct (occur-operation (:constructor %make-occur-operation))
    token
    executor
    result-channel
    cancellation-channel
    cancellation-counter
    buffer
    window-tree
    result-name)

  (defun %occur-scan-text
      (text pattern base-line base-column case-fold-p cancellation-p)
    "Return matching line records and whether cancellation stopped the scan."
    (check-type text string)
    (check-type pattern string)
    (check-type base-line (integer 0 *))
    (check-type base-column (integer 0 *))
    (check-type cancellation-p function)
    (let ((regex (cl-regex-kit:compile-regex
                  pattern :case-insensitive case-fold-p))
          (line-start 0)
          (line-number base-line)
          (first-line-p t)
          (records nil))
      (loop
        (when (funcall cancellation-p)
          (return-from %occur-scan-text (values nil t)))
        (let* ((line-end (position #\Newline text :start line-start))
               (line (subseq text line-start
                             (or line-end (length text))))
               (match
                 (first
                  (cl-regex-kit:all-matches
                   regex line :timeout +regex-search-timeout-seconds+))))
          (when match
            (push (list line-number
                        (+ (if first-line-p base-column 0)
                           (cl-regex-kit:match-start match))
                        line)
                  records))
          (unless line-end
            (return))
          (setf line-start (1+ line-end)
                first-line-p nil)
          (incf line-number)))
      (if (funcall cancellation-p)
          (values nil t)
          (values (nreverse records) nil))))

  (defun %occur-cancellation-requested-p (channel)
    (multiple-value-bind (value ready-p closed-p)
        (cl-concurrent-kit:try-recv channel)
      (declare (ignore value closed-p))
      ready-p))

  (defun %occur-result-items (buffer records)
    (let ((path (loom/core/buffer:buffer-path buffer)))
      (mapcar
       (lambda (record)
         (make-result-item path
                           (first record)
                           (second record)
                           (third record)
                           :buffer (and (null path) buffer)))
       records)))

  (defun %occur-message (text)
    (let* ((editor-state loom/core/editor-session:*editor-state*)
           (minibuffer (and editor-state
                            (loom/core/editor-session:editor-state-minibuffer
                             editor-state))))
      (when minibuffer
        (minibuffer-message minibuffer text))))

  (defun %finish-occur-operation (session operation payload)
    (let* ((state
             (loom/core/editor-session:editor-session-slice
              session :feature/search))
           (active-p
             (eq (search-result-state-active-occur state) operation))
           (dirty-p nil))
      (when active-p
        (setf (search-result-state-active-occur state) nil)
        (case (first payload)
          (:matches
           (let* ((records (second payload))
                  (items (%occur-result-items
                          (occur-operation-buffer operation) records))
                  (result-buffer
                    (publish-result-list
                     session (occur-operation-result-name operation) items))
                  (tree (occur-operation-window-tree operation))
                  (window (and tree
                               (loom/core/window-tree:window-tree-selected-window
                                tree))))
             (when window
               (loom/core/window-tree:window-set-buffer window result-buffer))
             (%occur-message
              (format nil "Found ~D matching line(s)" (length items)))
             (setf dirty-p t)))
          (:cancelled
           (%occur-message "Occur cancelled"))
          (:error
           (%occur-message
            (format nil "Occur failed: ~A" (second payload))))))
      (cl-concurrent-kit:shutdown-executor
       (occur-operation-executor operation) :wait t :cancel-pending t)
      (cl-concurrent-kit:close-channel
       (occur-operation-result-channel operation))
      (cl-concurrent-kit:close-channel
       (occur-operation-cancellation-channel operation))
      (values dirty-p t)))

  (defun %poll-occur-operation (session operation)
    (multiple-value-bind (payload ready-p closed-p)
        (cl-concurrent-kit:try-recv
         (occur-operation-result-channel operation))
      (declare (ignore closed-p))
      (if ready-p
          (%finish-occur-operation
           session operation
           (if (plusp
                (cl-concurrent-kit:atomic-counter-value
                 (occur-operation-cancellation-counter operation)))
               (list :cancelled)
               payload))
          (values nil nil))))

  (defun %occur-cancel-key-p (event)
    (let* ((descriptor (loom/core/command:key-event->descriptor event))
           (modifiers (car descriptor))
           (character (cdr descriptor)))
      (and (equal modifiers (list :control))
           (eql character #\g))))

  (defun %occur-key-input-hook (session event phase)
    (declare (ignore phase))
    (if (member :feature/search
                (loom/core/editor-session:editor-session-slice-names session))
        (let* ((state
                 (loom/core/editor-session:editor-session-slice
                  session :feature/search))
               (operation (search-result-state-active-occur state)))
          (if (and operation (%occur-cancel-key-p event))
              (progn
                (loom/core/editor-session:cancel-background-work
                 session (occur-operation-token operation))
                :handled)
              :pass))
        :pass))

  (eval-when (:load-toplevel :execute)
    (loom/core/editor-session:register-session-hook
     :key-input :feature/search (function %occur-key-input-hook)))

  (defun %start-occur (session buffer pattern)
    (let* ((state
             (loom/core/editor-session:editor-session-slice
              session :feature/search))
           (old-operation (search-result-state-active-occur state))
           (text (buffer-visible-text buffer))
           (start-offset (buffer-narrow-start-offset buffer))
           (start-position (buffer-offset-position buffer start-offset))
           (executor
             (cl-concurrent-kit:make-executor
              :size 1 :name "loom occur worker" :queue-capacity 1))
           (result-channel (cl-concurrent-kit:make-channel :buffer-size 1))
           (cancellation-channel
             (cl-concurrent-kit:make-channel :buffer-size 1))
           (cancellation-counter (cl-concurrent-kit:make-atomic-counter))
           (window-tree
             (and loom/core/editor-session:*editor-state*
                  (editor-state-window-tree
                   loom/core/editor-session:*editor-state*)))
           (operation
             (%make-occur-operation
              :executor executor
              :result-channel result-channel
              :cancellation-channel cancellation-channel
              :cancellation-counter cancellation-counter
              :buffer buffer
              :window-tree window-tree
              :result-name "*Occur*")))
      (when old-operation
        (loom/core/editor-session:cancel-background-work
         session (occur-operation-token old-operation)))
      (setf (search-result-state-active-occur state) operation
            (occur-operation-token operation)
            (loom/core/editor-session:register-background-work
             session :feature/search
             (lambda (poll-session token)
               (declare (ignore token))
               (%poll-occur-operation poll-session operation))
             (lambda (cancel-session token)
               (declare (ignore cancel-session token))
               (cl-concurrent-kit:atomic-counter-incf cancellation-counter)
               (cl-concurrent-kit:send cancellation-channel :cancel))))
      (handler-case
          (multiple-value-bind (promise accepted-p)
              (cl-concurrent-kit:try-submit
               executor
               (lambda ()
                 (let ((cancelled-p nil))
                   (handler-case
                       (multiple-value-bind (records scan-cancelled-p)
                           (%occur-scan-text
                            text pattern
                            (buffer-position-line start-position)
                            (buffer-position-column start-position)
                            (%search-pattern-case-fold-p pattern)
                            (lambda ()
                              (when (and (not cancelled-p)
                                         (%occur-cancellation-requested-p
                                          cancellation-channel))
                                (setf cancelled-p t))
                              cancelled-p))
                         (cl-concurrent-kit:send
                          result-channel
                          (if scan-cancelled-p
                              (list :cancelled)
                              (list :matches records))))
                     (error (condition)
                       (cl-concurrent-kit:send
                        result-channel (list :error condition))))
                   (loom/core/editor-session:notify-background-work-ready
                    session (occur-operation-token operation)))))
            (declare (ignore promise))
            (unless accepted-p
              (cl-concurrent-kit:send
               result-channel (list :error "Unable to schedule occur scan"))
              (loom/core/editor-session:notify-background-work-ready
               session (occur-operation-token operation))))
        (error (condition)
          (cl-concurrent-kit:send result-channel (list :error condition))
          (loom/core/editor-session:notify-background-work-ready
           session (occur-operation-token operation))))
      operation))

  (defun %selected-occur-buffer ()
    (let* ((window-tree (editor-state-window-tree *editor-state*))
           (window
             (and window-tree
                  (loom/core/window-tree:window-tree-selected-window
                   window-tree))))
      (and window
           (loom/core/window-tree:window-buffer window))))

  (defun occur ()
    "List the lines in the selected buffer that match a regular expression."
    (let ((minibuffer (editor-state-minibuffer *editor-state*))
          (buffer (%selected-occur-buffer)))
      (when buffer
        (with-prompts (minibuffer minibuffer
                       :on-cancel (minibuffer-message minibuffer "Quit"))
            ((pattern "List lines matching regexp: "))
          (%start-occur
           loom/core/editor-session:*editor-session* buffer pattern))))))
