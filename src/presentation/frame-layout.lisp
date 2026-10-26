(in-package #:loom)


(defun %layout-compute-regions (width height file-tree-visible-p)
  "Compute the row/column geometry COMPOSE-FRAME draws into, given the
renderer's WIDTH/HEIGHT and whether the file-tree sidebar is visible.
Returns (VALUES CONTENT-HEIGHT MINIBUFFER-ROW FILE-TREE-WIDTH
WINDOW-AREA-WIDTH), leaving COMPOSE-FRAME itself to only sequence the draw
calls against them."
  (let* ((content-height (max 0 (1- height)))
         (minibuffer-row (%layout-minibuffer-row height))
         (file-tree-width (%layout-file-tree-width file-tree-visible-p width))
         (window-area-width (max 0 (- width file-tree-width))))
    (values content-height minibuffer-row file-tree-width window-area-width)))

(defun %layout-draw-frame-content (renderer file-tree file-tree-visible
                                    file-tree-width window-area-width
                                    content-height window-tree
                                    &optional workspace-name)
  (when file-tree-visible
    (%layout-draw-file-tree renderer file-tree file-tree-width content-height))
  (loom/core/window-tree:window-tree-resize
   window-tree window-area-width content-height)
  (dolist (window (loom/core/window-tree:window-tree-windows window-tree))
    (%layout-keep-point-visible renderer window))
  (%layout-draw-windows renderer window-tree file-tree-width workspace-name))

(defun %layout-draw-frame-footer (renderer editor-state width minibuffer-row)
  (%layout-draw-minibuffer renderer (editor-state-minibuffer editor-state)
                            width minibuffer-row))

(defun compose-frame (editor-state)
  "Compose the current editor frame and return its immutable cell snapshot."
  (let* ((renderer (editor-state-renderer editor-state))
         (width (loom-renderer-width renderer))
         (height (loom-renderer-height renderer))
         (file-tree (editor-state-file-tree editor-state))
         (file-tree-visible
           (loom/feature/file-tree:file-tree-visible-p file-tree))
         (window-tree (editor-state-window-tree editor-state))
         (workspace-manager (editor-state-workspaces editor-state))
         (workspace-name
           (and workspace-manager
                (loom/feature/workspace:workspace-manager-current-name
                 workspace-manager))))
    (multiple-value-bind (content-height minibuffer-row file-tree-width
                           window-area-width)
        (%layout-compute-regions width height file-tree-visible)
      (loom-renderer-clear renderer)
      (%layout-draw-frame-content renderer file-tree file-tree-visible
                                   file-tree-width window-area-width content-height
                                   window-tree workspace-name)
      (%layout-draw-frame-footer renderer editor-state width minibuffer-row)
      (let ((cursor (editor-cursor editor-state)))
        (loom/core/editor-session:make-frame-snapshot
         width height (%loom-renderer-frame-cells renderer)
         :cursor
         (list (cl-tty-kit:cursor-x cursor)
               (cl-tty-kit:cursor-y cursor)
               (cl-tty-kit:cursor-visible-p cursor)))))))

(defun %presentation-state-for-session (session)
  (when (and *editor-state*
             (eq session (editor-state-session *editor-state*)))
    *editor-state*))

(defun %presentation-buffer-position (buffer visible-line source-column)
  (let* ((visible-start (loom/core/buffer:buffer-narrow-start-offset buffer))
         (start-position
           (loom/core/buffer:buffer-offset-position buffer visible-start))
         (absolute-line
           (+ (loom/core/buffer:buffer-position-line start-position)
              visible-line))
         (absolute-column
           (+ source-column
              (if (zerop visible-line)
                  (loom/core/buffer:buffer-position-column start-position)
                  0)))
         (absolute-offset
           (loom/core/buffer:buffer-position-offset
            buffer absolute-line absolute-column)))
    (loom/core/buffer:buffer-visible-offset-position buffer absolute-offset)))

(defun %presentation-source-column (mapping display-column)
  (loop for source-column from 0 below (length mapping)
        when (> (aref mapping source-column) display-column)
          return (max 0 (1- source-column))
        finally (return (1- (length mapping)))))

(defun %presentation-line-position (buffer line display-column)
  (multiple-value-bind (text mapping)
      (%layout-buffer-line-display buffer line)
    (when (< display-column (length text))
      (%presentation-buffer-position
       buffer line (%presentation-source-column mapping display-column)))))

(defun %presentation-window-buffer-position
    (session renderer window row body-column body-width)
  (let* ((buffer (loom/core/window-tree:window-buffer window))
         (line-count (loom/core/buffer:buffer-visible-line-count buffer))
         (scroll-line (loom/core/window-tree:window-scroll-line window))
         (truncate-p
           (loom/core/editor-session:buffer-truncate-lines-p session buffer)))
    (if truncate-p
        (let ((line (+ scroll-line row)))
          (when (< line line-count)
            (multiple-value-bind (text mapping)
                (%layout-buffer-line-display buffer line)
              (let* ((display-column
                       (loom-renderer-segment-column
                        renderer text (cons 0 (length text))
                        (+ (loom/core/window-tree:window-scroll-column window)
                           body-column))))
                (when (< display-column (length text))
                  (%presentation-buffer-position
                   buffer line
                   (%presentation-source-column mapping display-column)))))))
        (let ((line scroll-line)
              (sub-row (loom/core/window-tree:window-scroll-sub-row window))
              (visible-row 0))
          (progn
            (loop while (< line line-count)
                  for text = (nth-value 0 (%layout-buffer-line-display buffer line))
                  for segments = (%layout-line-segments renderer buffer line body-width)
                  do (progn
                       (loop for segment-index from sub-row below (length segments)
                             do (progn
                                  (when (= visible-row row)
                                    (let* ((segment (nth segment-index segments))
                                           (segment-width
                                             (loom-renderer-segment-cells
                                              renderer text segment (cdr segment))))
                                      (when (< body-column segment-width)
                                        (let ((display-column
                                                (loom-renderer-segment-column
                                                 renderer text segment body-column)))
                                          (return-from
                                           %presentation-window-buffer-position
                                            (%presentation-line-position
                                             buffer line display-column))))))
                                  (incf visible-row)))
                       (incf line)
                       (setf sub-row 0)))
          nil)))))

(defun %presentation-window-hit-test
    (session state renderer window screen-x screen-y)
  (let* ((window-x (+ (%layout-file-tree-width
                      (and state
                           (loom/feature/file-tree:file-tree-visible-p
                            (editor-state-file-tree state)))
                      (if state (loom-renderer-width renderer) screen-x))
                     (loom/core/window-tree:window-x window)))
         (window-y (loom/core/window-tree:window-y window))
         (window-width (loom/core/window-tree:window-width window))
         (window-height (loom/core/window-tree:window-height window))
         (row (- screen-y window-y))
         (column (- screen-x window-x)))
    (when (and (<= window-x screen-x) (< screen-x (+ window-x window-width))
               (<= window-y screen-y) (< screen-y (+ window-y window-height)))
      (let* ((buffer (loom/core/window-tree:window-buffer window))
             (kind (if (= row (1- window-height))
                       :mode-line
                       :window-blank))
             (gutter-width (%layout-window-gutter-width buffer window-width))
             (body-width (- window-width gutter-width)))
        (when (and (< row (1- window-height))
                   (>= column gutter-width)
                   (plusp body-width))
          (let ((position
                  (%presentation-window-buffer-position
                   session renderer window row (- column gutter-width)
                   body-width)))
            (when position
              (return-from %presentation-window-hit-test
                (loom/core/editor-session:make-hit-test-result
                 :core/presentation :buffer-text
                 :window window :buffer buffer :position position)))))
        (loom/core/editor-session:make-hit-test-result
         :core/presentation kind :window window)))))

(defun %presentation-hit-test-provider (session screen-x screen-y)
  (let ((state (%presentation-state-for-session session)))
    (when state
      (let* ((window-tree
               (loom/core/editor-session:editor-session-slice
                session :core/window-tree))
             (renderer (editor-state-renderer state))
             (frame-width (loom-renderer-width renderer))
             (frame-height (loom-renderer-height renderer)))
        (when (and (<= 0 screen-x) (< screen-x frame-width)
                   (<= 0 screen-y) (< screen-y frame-height))
          (dolist (window (loom/core/window-tree:window-tree-windows window-tree))
            (let ((result (%presentation-window-hit-test
                           session state renderer window screen-x screen-y)))
              (when result
                (return-from %presentation-hit-test-provider result))))
          nil)))))

(eval-when (:load-toplevel :execute)
  (loom/core/editor-session:register-hit-test-provider
   :core/presentation 0 (function %presentation-hit-test-provider)))
