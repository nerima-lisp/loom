(in-package #:loom/feature/mouse)

(progn
  (defun %mouse-visible-position-offset (buffer position)
    (let ((line (buffer-position-line position))
          (column (buffer-position-column position)))
      (+ (buffer-narrow-start-offset buffer)
         (loop for visible-line below line
               sum (1+ (length (buffer-visible-line buffer visible-line))))
         column)))

  (defun %mouse-set-point-from-hit (hit)
    (let* ((buffer (hit-test-result-buffer hit))
           (position (hit-test-result-position hit))
           (offset (%mouse-visible-position-offset buffer position))
           (absolute (buffer-offset-position buffer offset)))
      (buffer-set-point buffer
                        (buffer-position-line absolute)
                        (buffer-position-column absolute))
      buffer))

  (defun %mouse-select-window (window)
    (let* ((tree (editor-state-window-tree *editor-state*))
           (index (position window (window-tree-windows tree) :test #'eq)))
      (when index
        (window-tree-select-index tree index)
        t)))

  (defun %mouse-file-tree-hit-test (session screen-x screen-y)
    (let* ((state *editor-state*)
           (tree (and state (editor-state-file-tree state))))
      ;; The sidebar starts at (0, 0), is at most 24 columns wide, and draws
      ;; one visible file-tree entry per row.
      (when (and tree
                 (eq session (editor-state-session state))
                 (file-tree-visible-p tree)
                 (<= 0 screen-x) (< screen-x 24)
                 (<= 0 screen-y)
                 (< screen-y
                    (window-tree-height
                     (editor-state-window-tree state))))
        (let ((entry (nth screen-y (file-tree-entries tree))))
          (when entry
            (make-hit-test-result :feature/mouse :feature-item
                                  :target (car entry)))))))

  (defun %mouse-open-file-tree-target (target)
    (let* ((tree (editor-state-file-tree *editor-state*))
           (entries (file-tree-entries tree))
           (paths (mapcar #'car entries))
           (target-index (position target paths :test #'equal))
           (selected-index
             (position (file-tree-selected-path tree) paths :test #'equal)))
      (when target-index
        (unless selected-index
          (file-tree-move-selection tree :down)
          (setf selected-index 0))
        (loop while (< selected-index target-index)
              do (file-tree-move-selection tree :down)
                 (incf selected-index))
        (loop while (> selected-index target-index)
              do (file-tree-move-selection tree :up)
                 (decf selected-index))
        (invoke-command "file-tree-open-selected" :mouse))))

  (defun %mouse-place-point-and-mark (hit)
    (let* ((buffer (%mouse-set-point-from-hit hit))
           (line (buffer-point-line buffer))
           (column (buffer-point-column buffer)))
      (buffer-set-mark buffer line column)))

  (defun %mouse-extend-mark (hit)
    (let ((buffer (%mouse-set-point-from-hit hit)))
      (unless (buffer-mark-active-p buffer)
        (buffer-set-mark buffer
                         (buffer-point-line buffer)
                         (buffer-point-column buffer)))))

  (defun %mouse-finish-mark (buffer)
    (multiple-value-bind (mark-line mark-column)
        (buffer-mark buffer)
      (unless (and (eql mark-line (buffer-point-line buffer))
                   (eql mark-column (buffer-point-column buffer)))
        (return-from %mouse-finish-mark buffer)))
    (buffer-deactivate-mark buffer))

  (defun %mouse-scroll-window (window button)
    (case button
      (:wheel-up
       (invoke-command "scroll-down-command" :mouse))
      (:wheel-down
       (invoke-command "scroll-up-command" :mouse))
      (:wheel-left
       (setf (window-scroll-column window)
             (max 0 (1- (window-scroll-column window)))))
      (:wheel-right
       (incf (window-scroll-column window)))))

  (defun %mouse-handle-event-command (event)
    (when (typep event 'mouse-event)
      (let* ((action (mouse-event-action event))
             (button (mouse-event-button event))
             (hit (hit-test-coordinate
                   (editor-state-session *editor-state*)
                   (mouse-event-x event)
                   (mouse-event-y event)))
             (kind (and hit (hit-test-result-kind hit)))
             (window (and hit (hit-test-result-window hit))))
        (when window
          (%mouse-select-window window))
        (cond
          ((and hit
                (eq kind :feature-item)
                (eq action :press)
                (eq button :left))
           (%mouse-open-file-tree-target (hit-test-result-target hit)))
          ((and hit
                (eq action :press)
                (eq button :left)
                (eq kind :buffer-text))
           (%mouse-place-point-and-mark hit))
          ((and hit
                (eq action :drag)
                (eq button :left)
                (eq kind :buffer-text))
           (%mouse-extend-mark hit))
          ((and hit
                (eq action :release)
                (eq button :left)
                window)
           (%mouse-finish-mark (window-buffer window)))
          ((and hit
                (member action '(:scroll :press) :test #'eq)
                (member button
                        '(:wheel-up :wheel-down :wheel-left :wheel-right)
                        :test #'eq)
                window)
           (%mouse-scroll-window window button))))))

  (defun %mouse-input-event-hook (session event-type event)
    (if (and (eq event-type :mouse)
             *editor-state*
             (eq session (editor-state-session *editor-state*)))
        (progn
          (invoke-command "mouse-event" :mouse event)
          :handled)
        :pass))

  (defun %mouse-terminal-modes-hook (_session)
    '(:mouse-sgr :mouse-button-event))

  (eval-when (:load-toplevel :execute)
    (register-hit-test-provider :feature/mouse 100
                                #'%mouse-file-tree-hit-test)
    (register-session-hook :input-event :feature/mouse
                           #'%mouse-input-event-hook)
    (register-session-hook :terminal-modes :feature/mouse
                           #'%mouse-terminal-modes-hook)
    (loom/core/command::%register-command-spec
     :feature/mouse "mouse-event" nil
     (function %mouse-handle-event-command)
     :keys nil :keymap :global :group nil
     :help nil :help-order nil
     :mutates t :prompts nil :needs-region nil :external nil :modes '(:all)
     :catalog-visible-p nil :trace-visible-p t)))
