(in-package #:loom)

(defparameter +layout-mode-line-selected-style+ '(:reverse)
  "Style for the mode line of the selected leaf window.")

(defparameter +layout-mode-line-unselected-style+ '((:fg 8))
  "Style for the mode line of a leaf window that is not selected.")

(defun %layout-buffer-diagnostics (buffer)
  (let ((session (and *editor-state*
                      (editor-state-lsp-session *editor-state*))))
    (when (and session (buffer-path buffer))
      (loom/feature/lsp:lsp-session-diagnostics session buffer))))

(defun %layout-diagnostics-part (diagnostics)
  (when diagnostics
    (let ((counts (list (cons "error" 0)
                        (cons "warning" 0)
                        (cons "info" 0)
                        (cons "hint" 0))))
      (dolist (diagnostic diagnostics)
        (incf (cdr (assoc (loom/feature/lsp:lsp-diagnostic-severity-name
                           (loom/feature/lsp:lsp-diagnostic-severity diagnostic))
                          counts
                          :test #'string=))))
      (with-output-to-string (output)
        (write-string "  Diag:" output)
        (dolist (entry counts)
          (when (plusp (cdr entry))
            (format output " ~A~D"
                    (char (string-upcase (car entry)) 0)
                    (cdr entry))))))))

(defun %layout-mode-line-parts (renderer buffer)
  (let ((parts
          (list (format nil "~A~A"
                        (if (buffer-modified-p buffer) "*" "-")
                        (if (buffer-read-only-p buffer) "%" "-"))
                (format nil " ~A" (buffer-name buffer))
                (format nil "  ~A"
                        (or (loom/feature/mode:major-mode-name
                             (buffer-major-mode buffer))
                            "Fundamental"))
                (format nil "  Ln ~D, Col ~D"
                        (1+ (buffer-visible-point-line buffer))
                        (1+ (%layout-buffer-point-screen-column renderer buffer)))
                (format nil "  ~A"
                        (if (loom/core/editor-session:buffer-truncate-lines-p *editor-state* buffer)
                            "Truncate"
                            "Wrap")))))
    (let ((diagnostics-part
            (%layout-diagnostics-part (%layout-buffer-diagnostics buffer))))
      (if diagnostics-part
          (append parts (list diagnostics-part))
          parts))))

(defun %layout-mode-line-text (renderer buffer &optional workspace-name)
  "Return BUFFER's complete mode line text before width clipping."
  (format nil "~{~A~}~@[  Workspace: ~A~]"
          (%layout-mode-line-parts renderer buffer)
          workspace-name))

(defun %layout-mode-line-workspace-suffix (renderer workspace-name width)
  (let* ((prefix "  Workspace: ")
         (prefix-width (loom-renderer-string-width renderer prefix)))
    (if (>= width prefix-width)
        (concatenate 'string
                     prefix
                     (loom-renderer-truncate-string
                      renderer workspace-name (- width prefix-width)))
        (loom-renderer-truncate-string renderer prefix width))))

(defun %layout-mode-line-workspace (renderer buffer width workspace-name)
  (let* ((all-parts (%layout-mode-line-parts renderer buffer))
         (status (first all-parts))
         (parts (rest all-parts))
         (status-visible (%layout-truncate-to-width status width))
         (prefix-width
           (loom-renderer-string-width renderer "  Workspace: "))
         (remaining
           (max 0 (- width
                    (loom-renderer-string-width renderer status-visible)
                    prefix-width)))
         (name (first parts))
         (mode (second parts))
         (position (third parts))
         (wrap (fourth parts))
         (diagnostics (fifth parts))
         (selected nil)
         (candidates (remove nil (list diagnostics wrap name mode position))))
    (dolist (part candidates)
      (let ((part-width (loom-renderer-string-width renderer part)))
        (when (<= part-width remaining)
          (setf selected (append selected (list part)))
          (decf remaining part-width))))
    (let ((selected-in-display-order
            (remove-if-not (lambda (part)
                             (member part selected :test #'equal))
                           parts)))
      (format nil "~A~{~A~}~A"
            status-visible
            selected-in-display-order
            (%layout-mode-line-workspace-suffix
             renderer workspace-name
             (max 0 (- width
                       (loom-renderer-string-width renderer status-visible)
                       (loom-renderer-string-width renderer
                                                    (format nil "~{~A~}"
                                                            selected-in-display-order)))))))))

(defun %layout-mode-line (renderer buffer &optional width workspace-name)
  "Clip BUFFER's mode line from the right without WORKSPACE-NAME.
With WORKSPACE-NAME, select fields by priority and fit the workspace suffix
into the remaining width."
  (let ((width (or width (loom-renderer-width renderer))))
    (if workspace-name
        (%layout-mode-line-workspace renderer buffer width workspace-name)
        (%layout-truncate-to-width
         (%layout-mode-line-text renderer buffer)
         width))))
(defun %layout-write-window-string (renderer x y text &key style)
  (loom-renderer-write-string renderer x y text :style style))

(defun %layout-draw-window-buffer
    (renderer window x-offset &optional height selected-p)
  "Draw WINDOW's buffer in whichever line-display mode that buffer selects.

When HEIGHT is supplied, draw only that many rows, leaving the caller to draw
the mode line or another footer in the remaining window rows."
  (let* ((buffer (loom/core/window-tree:window-buffer window))
         (x (+ x-offset (loom/core/window-tree:window-x window)))
         (y (loom/core/window-tree:window-y window))
         (width (loom/core/window-tree:window-width window))
         (height (or height (loom/core/window-tree:window-height window)))
         (gutter-width (%layout-window-gutter-width buffer width))
         (body-x (%layout-window-body-x (+ x gutter-width) selected-p))
         (body-width (- width gutter-width))
         (line-count (%layout-buffer-visible-line-count buffer))
         (scroll-line (loom/core/window-tree:window-scroll-line window))
         (scroll-sub-row (loom/core/window-tree:window-scroll-sub-row window))
         (truncate-p
           (loom/core/editor-session:buffer-truncate-lines-p
            *editor-state* buffer)))
    (labels ((draw-number (line row)
               (%layout-write-window-string
                renderer x (+ y row)
                (format nil "~vD " (1- gutter-width) (1+ line))
                :style '((:fg 8))))
             (draw-gutter ()
               (when (plusp gutter-width)
                 (if truncate-p
                     (dotimes (row height)
                       (let ((line (+ scroll-line row)))
                         (when (< line line-count)
                           (draw-number line row))))
                     (let ((row 0)
                           (line scroll-line)
                           (sub-row scroll-sub-row))
                       (loop while (and (< row height) (< line line-count))
                             for segments =
                               (%layout-line-segments
                                renderer buffer line body-width)
                             do (loop for segment-index from sub-row
                                      below (length segments)
                                      while (< row height)
                                      do (when (zerop segment-index)
                                           (draw-number line row))
                                         (incf row))
                                (incf line)
                                (setf sub-row 0)))))))
      (if truncate-p
          (%layout-draw-truncated-buffer
           renderer buffer body-x y body-width height
           scroll-line
           (loom/core/window-tree:window-scroll-column window))
          (%layout-draw-wrapped-buffer
           renderer buffer body-x y body-width height
           scroll-line scroll-sub-row))
      (draw-gutter))))

(defun %layout-draw-truncated-buffer
    (renderer buffer x y width height start-line start-column)
  (let ((mode (buffer-major-mode buffer))
        (line-count (buffer-visible-line-count buffer)))
    (dotimes (row height)
      (let ((line (+ start-line row)))
        (when (< line line-count)
          (loom/feature/syntax-highlighting:syntax-draw-highlighted-line
           renderer
           (nth-value 0 (%layout-buffer-line-display buffer line))
           x (+ y row) width mode start-column))))))

(defun %layout-draw-window-overlays (renderer leaf x-offset selected-p)
  (%layout-draw-window-buffer
   renderer leaf x-offset (%layout-window-content-height leaf) selected-p)
  (%layout-draw-diagnostics renderer leaf x-offset)
  (%layout-draw-region renderer leaf x-offset)
  (%layout-draw-matching-paren renderer leaf x-offset)
  (%layout-draw-isearch renderer leaf x-offset)
  (%layout-draw-completion renderer leaf x-offset))

(defun %layout-draw-window-mode-line (renderer window x-offset selected-p
                                      &optional workspace-name)
  "Draw WINDOW's mode line across its last row when the leaf has an area."
  (let ((width (loom/core/window-tree:window-width window))
        (height (loom/core/window-tree:window-height window)))
    (when (and (plusp width) (plusp height))
      (let* ((text (%layout-mode-line
                    renderer (loom/core/window-tree:window-buffer window) width
                    (and selected-p workspace-name)))
             (padding (make-string
                       (- width (loom-renderer-string-width renderer text))
                       :initial-element #\Space)))
        (%layout-write-window-string
         renderer
         (+ x-offset (loom/core/window-tree:window-x window))
         (+ (loom/core/window-tree:window-y window) (1- height))
         (concatenate 'string text padding)
         :style (if selected-p
                    +layout-mode-line-selected-style+
                    +layout-mode-line-unselected-style+))))))

(defun %layout-draw-window-separator (renderer leaf x-offset)
  (when (and (plusp (loom/core/window-tree:window-x leaf))
             (plusp (loom/core/window-tree:window-height leaf)))
    (loom-renderer-draw-vertical-line
     renderer (1- (+ x-offset (loom/core/window-tree:window-x leaf)))
     (loom/core/window-tree:window-y leaf)
     (loom/core/window-tree:window-height leaf)))
  (when (and (plusp (loom/core/window-tree:window-y leaf))
             (plusp (loom/core/window-tree:window-width leaf)))
    (loom-renderer-draw-horizontal-line
     renderer (+ x-offset (loom/core/window-tree:window-x leaf))
     (1- (loom/core/window-tree:window-y leaf))
     (loom/core/window-tree:window-width leaf)))
  renderer)

(defun %layout-draw-windows (renderer window-tree x-offset
                             &optional workspace-name)
  "Draw every leaf window and the separators in WINDOW-TREE."
  (let ((leaves (loom/core/window-tree:window-tree-windows window-tree))
        (selected (loom/core/window-tree:window-tree-selected-window window-tree)))
    (dolist (leaf leaves)
      (%layout-draw-window-overlays renderer leaf x-offset
                                    (eq leaf selected)))
    (dolist (leaf leaves)
      (%layout-draw-window-separator renderer leaf x-offset))
    (dolist (leaf leaves)
      (%layout-draw-window-mode-line renderer leaf x-offset (eq leaf selected) workspace-name)))
  renderer)

(defparameter +layout-matching-paren-style+ '(:bold (:bg 5) (:fg 0))
  "Style marking the parenthesis at point and the one it pairs with.")

(defparameter +layout-region-style+ '((:bg 2) (:fg 0))
  "Style marking the active region.")

(defparameter +layout-diagnostic-style+ '((:bg 1) (:fg 7))
  "Style marking text covered by an LSP diagnostic.")

(defun %layout-lsp-diagnostic-span (buffer diagnostic)
  (let* ((range (loom/feature/lsp:lsp-diagnostic-range diagnostic))
         (start (loom/feature/lsp:lsp-range-start range))
         (end (loom/feature/lsp:lsp-range-end range)))
    (handler-case
        (let* ((start-offset
                 (buffer-position-offset
                  buffer
                  (loom/feature/lsp:lsp-position-line start)
                  (loom/feature/lsp:lsp-character-to-column
                   (buffer-line buffer (loom/feature/lsp:lsp-position-line start))
                   (loom/feature/lsp:lsp-position-character start))))
               (end-offset
                 (buffer-position-offset
                  buffer
                  (loom/feature/lsp:lsp-position-line end)
                  (loom/feature/lsp:lsp-character-to-column
                   (buffer-line buffer (loom/feature/lsp:lsp-position-line end))
                   (loom/feature/lsp:lsp-position-character end))))
               (visible-start (buffer-narrow-start-offset buffer))
               (visible-end (buffer-narrow-end-offset buffer))
               (clipped-start (max start-offset visible-start))
               (clipped-end (min end-offset visible-end)))
          (when (< clipped-start clipped-end)
            (make-buffer-span clipped-start clipped-end)))
      (error () nil))))

(defun %layout-draw-diagnostics (renderer window x-offset)
  (let* ((buffer (loom/core/window-tree:window-buffer window))
         (diagnostics (%layout-buffer-diagnostics buffer)))
    (dolist (diagnostic diagnostics)
      (let ((span (%layout-lsp-diagnostic-span buffer diagnostic)))
        (when span
          (%layout-draw-span renderer window x-offset span
                             +layout-diagnostic-style+))))))

(defun %layout-draw-region (renderer window x-offset)
  (let ((span (buffer-active-region-span
               (loom/core/window-tree:window-buffer window))))
    (when span
      (%layout-draw-span renderer window x-offset span +layout-region-style+))))

(defun %layout-draw-matching-paren-at (renderer window x-offset buffer start local)
  (let ((position (buffer-visible-offset-position buffer (+ start local))))
    (when position
      (%layout-draw-line-run
       renderer window x-offset
       (buffer-position-line position)
       (buffer-position-column position)
       (1+ (buffer-position-column position))
       +layout-matching-paren-style+))))

(defun %layout-draw-matching-paren (renderer window x-offset)
  "Mark the parenthesis point is adjacent to, together with its partner."
  (let* ((buffer (loom/core/window-tree:window-buffer window))
         (start (buffer-narrow-start-offset buffer))
         (text (buffer-visible-text buffer))
         (offset (max 0 (min (length text)
                             (- (buffer-point-offset buffer) start)))))
    (multiple-value-bind (paren match) (%matching-paren-offset text offset)
      (when (and paren match)
        (dolist (local (list paren match))
          (%layout-draw-matching-paren-at
           renderer window x-offset buffer start local))))))

(defun %visual-row-layout (session buffer logical-line window-width)
  (let ((renderer (editor-state-renderer session)))
    (when renderer
      (let* ((text (buffer-line buffer logical-line))
             (tab-width (%layout-mode-tab-width (buffer-major-mode buffer)))
             (prefix-widths (%loom-renderer-cell-prefix-widths
                             text :tab-width tab-width))
             (body-width
               (- window-width
                  (%layout-window-gutter-width buffer window-width)))
             (ranges (loom-renderer-wrap-segments
                      renderer text body-width :tab-width tab-width)))
        (mapcar
         (lambda (range)
           (let* ((start (car range))
                  (end (cdr range))
                  (segment-start (aref prefix-widths start))
                  (widths (make-array (1+ (- end start)) :initial-element 0)))
             (loop for column from start to end
                   for index from 0
                   do (setf (aref widths index)
                            (- (aref prefix-widths column) segment-start)))
             (list start end widths)))
         ranges)))))

(eval-when (:load-toplevel :execute)
  (register-visual-row-layout :core/presentation
                              (function %visual-row-layout)))

(defvar *layout-trace-last-entry* nil)
(defvar *layout-trace-last-warning-entry* nil)

(defun %layout-window-body-x (body-x selected-p)
  (when selected-p
    (%layout-record-selected-body-x body-x))
  body-x)

(defun %layout-record-selected-body-x (body-x)
  (let ((trace-file (uiop:getenv "LOOM_TRACE_LAYOUT")))
    (if (null trace-file)
        (when (or *layout-trace-last-entry*
                  *layout-trace-last-warning-entry*)
          (setf *layout-trace-last-entry* nil
                *layout-trace-last-warning-entry* nil))
        (unless (and *layout-trace-last-entry*
                     (string= trace-file
                              (car *layout-trace-last-entry*))
                     (eql body-x
                          (cdr *layout-trace-last-entry*)))
          (handler-case
              (progn
                (when (zerop (length trace-file))
                  (error "LOOM_TRACE_LAYOUT path must not be empty"))
                (let* ((trace-path
                         (uiop:parse-native-namestring trace-file))
                       (line
                         (json-kit:stringify
                          (json-kit:make-json-object
                           (list (cons "body_x" body-x))))))
                  (when (wild-pathname-p trace-path)
                    (error "LOOM_TRACE_LAYOUT path must not contain wildcards"))
                  (with-open-file (stream trace-path
                                          :direction :output
                                          :if-exists :append
                                          :if-does-not-exist :create)
                    (write-line line stream)
                    (finish-output stream)))
                (setf *layout-trace-last-entry* (cons trace-file body-x))
                (when (and *layout-trace-last-warning-entry*
                           (string= trace-file
                                    (car *layout-trace-last-warning-entry*))
                           (eql body-x
                                (cdr *layout-trace-last-warning-entry*)))
                  (setf *layout-trace-last-warning-entry* nil))
                nil)
            (error (condition)
              (unless (and *layout-trace-last-warning-entry*
                           (string= trace-file
                                    (car *layout-trace-last-warning-entry*))
                           (eql body-x
                                (cdr *layout-trace-last-warning-entry*)))
                (setf *layout-trace-last-warning-entry*
                      (cons trace-file body-x))
                (handler-case
                    (let ((logger
                            (log-kit:make-logger
                             :name "loom.layout-trace"
                             :handler
                             (log-kit:make-text-handler :stream *error-output*)
                             :level log-kit:+level-warn+)))
                      (log-kit:log-warn
                       logger
                       "Could not append LOOM_TRACE_LAYOUT"
                       :error-type (type-of condition)))
                  (error () nil)))))))))
