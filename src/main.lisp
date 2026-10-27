(in-package #:loom)

(defun %cli-control-request-p (arguments &optional (options-ended-p nil))
  (when arguments
    (let ((argument (first arguments)))
      (cond
        ((and (not options-ended-p) (string= argument "--"))
         (%cli-control-request-p (rest arguments) t))
        ((and (not options-ended-p)
              (member argument
                      (list "--dump-catalog" "--help" "-h" "--version" "-V")
                      :test
                      (function string=))) t)
        ((and (not options-ended-p)
              (>= (length argument) 2)
              (string= argument "--" :end1 2)
              (not (position #\= argument))
              (eq (loom/core/editor-session:cli-option-value-kind argument)
                  :value))
         (%cli-control-request-p (cddr arguments) options-ended-p))
        (t (%cli-control-request-p (rest arguments) options-ended-p))))))

(defun %apply-render-session-hooks (session snapshot glyph-layout-function)
  "Apply immutable render-hook operations to SNAPSHOT for direct callers."
  (let* ((operations
           (loop for result in (loom/core/editor-session:run-session-hooks :render
                                                                           session
                                                                           snapshot)
                 append result))
         (tabbed-operations
           (loop for operation in operations
                 append (when (loom/core/editor-session:render-operation-p
                               operation)
                          (let ((text
                                  (loom/core/editor-session:render-operation-text
                                   operation)))
                            (when (and text (find (code-char 9) text))
                              (list
                               (cons
                                text
                                (loom/core/editor-session:render-operation-x
                                 operation)))))))))
    (loom/core/editor-session:apply-render-operations
     snapshot
     operations
     (lambda (text)
       (let ((tabbed-operation (first tabbed-operations)))
         (if (and tabbed-operation
                  (string= text (car tabbed-operation)))
             (progn
               (pop tabbed-operations)
               (funcall
                glyph-layout-function
                (nth-value
                 0
                 (%loom-renderer-expand-tabs
                  text :start-column (cdr tabbed-operation)))))
             (funcall glyph-layout-function text)))))))

(defun %render-root-frame (stream)
  (let* ((editor-state *editor-state*)
         (session (editor-state-session editor-state))
         (renderer (editor-state-renderer editor-state))
         (snapshot
          (%apply-render-session-hooks
           session
           (compose-frame editor-state)
           (function %loom-renderer-frame-glyph-layout)))
         (width
          (loom/core/editor-session:frame-snapshot-width snapshot))
         (height
          (loom/core/editor-session:frame-snapshot-height snapshot))
         (cells
          (let ((cells (make-array (* width height))))
            (dotimes (y height cells)
              (dotimes (x width)
                (setf (aref cells (+ (* y width) x))
                      (multiple-value-list
                       (loom/core/editor-session:frame-snapshot-cell
                        snapshot x y))))))))
    (multiple-value-bind (cursor-x cursor-y cursor-visible-p)
        (loom/core/editor-session:frame-snapshot-cursor snapshot)
      (let ((cursor
             (when cursor-x
               (cl-tty-kit:make-cursor :x cursor-x :y cursor-y
                                       :visible cursor-visible-p))))
        (loom-renderer-load-frame-cells renderer width height cells)
        (loom-renderer-present renderer :stream stream :cursor cursor)))))

(defun %main-exit-code (&optional (argv (uiop:raw-command-line-arguments)))
  "Return the CLI exit code for ARGV without terminating the current process."
  (let ((*event-loop-render-function* (function %render-root-frame))
        (arguments (rest argv)))
    (cond
      ((equal arguments (list "--dump-catalog"))
       (write-line (loom/core/command:command-catalog-json))
       0)
      ((%cli-control-request-p arguments)
       (cl-cli:run-app *loom-app* :argv argv))
      (t (handler-case
             (%run-loom (%parse-startup-context arguments)
                        :render-frame-function *event-loop-render-function*)
           (cl-cli:cli-usage-error (condition)
             (format *error-output* "~&~A~%~%"
                     (cl-cli:cli-error-message condition))
             (cl-cli:print-app-help *loom-app* *error-output*)
             64))))))

(defun main ()
  "Dispatch UIOP's raw command-line arguments through the startup CLI boundary."
  (uiop:quit (%main-exit-code)))

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

(defun %presentation-window-hit-test
    (session state renderer window screen-x screen-y)
  (let* ((file-tree (and state (editor-state-file-tree state)))
         (window-x
           (+ (%layout-file-tree-width
               (and file-tree
                    (loom/feature/file-tree:file-tree-visible-p file-tree))
               (if state (loom-renderer-width renderer) screen-x))
              (loom/core/window-tree:window-x window)))
         (window-y (loom/core/window-tree:window-y window))
         (window-width (loom/core/window-tree:window-width window))
         (window-height (loom/core/window-tree:window-height window)))
    (multiple-value-bind (row column kind)
        (%presentation-hit-test-window-cell
         screen-x screen-y window-x window-y window-width window-height)
      (when row
        (let* ((buffer (loom/core/window-tree:window-buffer window))
               (gutter-width (%layout-window-gutter-width buffer window-width))
               (body-width (- window-width gutter-width)))
          (when (and (eq kind :window-blank)
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
           :core/presentation kind :window window))))))

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

(defun %presentation-line-position (buffer line display-column)
  (multiple-value-bind (text mapping)
      (%layout-buffer-line-display buffer line)
    (when (< display-column (length text))
      (%presentation-buffer-position
       buffer line (%presentation-source-column mapping display-column)))))

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

(defun %presentation-state-for-session (session)
  (when (and *editor-state*
             (eq session (editor-state-session *editor-state*)))
    *editor-state*))

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
                 workspace-manager)))
         (buffer-cell-function (function %layout-buffer-cell)))
    (multiple-value-bind (content-height minibuffer-row file-tree-width
                           window-area-width)
        (%layout-compute-regions width height file-tree-visible)
      (loom-renderer-clear renderer)
      (%layout-draw-frame-content renderer file-tree file-tree-visible
                                   file-tree-width window-area-width content-height
                                   window-tree buffer-cell-function workspace-name)
      (%layout-draw-frame-footer renderer editor-state width minibuffer-row)
      (let ((cursor (editor-cursor editor-state)))
        (loom/core/editor-session:make-frame-snapshot
         width height (%loom-renderer-frame-cells renderer)
         :cursor
         (list (cl-tty-kit:cursor-x cursor)
               (cl-tty-kit:cursor-y cursor)
               (cl-tty-kit:cursor-visible-p cursor)))))))

(defun %layout-draw-frame-footer (renderer editor-state width minibuffer-row)
  (%layout-draw-minibuffer renderer (editor-state-minibuffer editor-state)
                            width minibuffer-row))

(defun %layout-draw-frame-content (renderer file-tree file-tree-visible
                                    file-tree-width window-area-width
                                    content-height window-tree buffer-cell-function
                                    &optional workspace-name)
  (when file-tree-visible
    (%layout-draw-file-tree renderer file-tree file-tree-width content-height))
  (loom/core/window-tree:window-tree-resize
   window-tree window-area-width content-height)
  (dolist (window (loom/core/window-tree:window-tree-windows window-tree))
    (%layout-keep-point-visible renderer window))
  (%layout-draw-windows renderer window-tree file-tree-width
                        buffer-cell-function workspace-name))

(defun editor-cursor (editor-state)
  "Return the terminal cursor for EDITOR-STATE: the active minibuffer's input
position when a prompt is up, otherwise point in the selected window."
  (let* ((renderer (editor-state-renderer editor-state))
         (minibuffer (editor-state-minibuffer editor-state))
         (file-tree (editor-state-file-tree editor-state))
         (x-offset (%layout-file-tree-width
                    (and file-tree
                         (loom/feature/file-tree:file-tree-visible-p file-tree))
                    (loom-renderer-width renderer)))
         (window (loom/core/window-tree:window-tree-selected-window
                  (editor-state-window-tree editor-state))))
    (or (and minibuffer (%minibuffer-cursor renderer minibuffer))
        (%selected-window-cursor renderer window x-offset))))

(defun %selected-window-cursor (renderer window x-offset)
  "Return the cursor for WINDOW, offset by the file-tree width X-OFFSET."
  (multiple-value-bind (x y)
      (%selected-window-cursor-geometry renderer window x-offset)
    (if (and x y)
        (cl-tty-kit:make-cursor :x x :y y)
        (cl-tty-kit:make-cursor :visible nil))))

(defun %selected-window-cursor-geometry (renderer window x-offset)
  "Return the selected window cursor position, or NIL when it has no area."
  (let ((width (loom/core/window-tree:window-width window))
        (height (%layout-window-content-height window)))
    (unless (or (zerop width) (zerop height))
      (%window-cursor-position renderer window x-offset))))

(defun %window-cursor-position (renderer window x-offset)
  (let* ((buffer (loom/core/window-tree:window-buffer window))
         (line (buffer-visible-point-line buffer))
         (column (buffer-visible-point-column buffer))
         (window-x (loom/core/window-tree:window-x window)))
    (multiple-value-bind (screen-column screen-row gutter-width)
        (%layout-buffer-cell renderer window buffer line column)
      (values (min (+ x-offset window-x gutter-width screen-column)
                   (+ x-offset window-x
                      (1- (loom/core/window-tree:window-width window))))
              (+ (loom/core/window-tree:window-y window) screen-row)))))

(defun %layout-buffer-cell (renderer window buffer line column)
  "Return LINE/COLUMN's (COLUMN, ROW) within WINDOW's text body.

The completion popup and cursor both use this geometry so they stay anchored to
the same body cells."
  (let* ((window-width (loom/core/window-tree:window-width window))
         (gutter-width (%layout-window-gutter-width buffer window-width))
         (body-width (- window-width gutter-width)))
    (multiple-value-bind (column row)
        (if (loom/core/editor-session:buffer-truncate-lines-p *editor-state* buffer)
            (%truncated-cell renderer window buffer line column)
            (%wrapped-cell renderer window buffer body-width line column))
      (values column row gutter-width))))

(defun %minibuffer-cursor (renderer minibuffer)
  "Return the terminal cursor for an active MINIBUFFER, or NIL when it is not
accepting input.

The minibuffer has no point of its own -- MINIBUFFER-HANDLE-KEY only appends
and backspaces -- so the cursor belongs after the whole prompt-plus-input line
that %LAYOUT-DRAW-MINIBUFFER draws."
  (when (minibuffer-active-p minibuffer)
    (let* ((width (loom-renderer-width renderer))
           (text (%layout-minibuffer-line minibuffer))
           (column (%layout-screen-column renderer text (length text))))
      (cl-tty-kit:make-cursor
       :x (min column (max 0 (1- width)))
       :y (%layout-minibuffer-row (loom-renderer-height renderer))))))

(eval-when (:load-toplevel :execute)
  (setf *layout-buffer-cell-function* (function %layout-buffer-cell)
        *startup-load-user-init-function*
        (lambda ()
          (loom/feature/user-init:load-user-init))
        *startup-renderer-invalidate-function*
        (lambda (state)
          (loom-renderer-invalidate (editor-state-renderer state))))
  (loom/core/editor-session:register-hit-test-provider
   :core/presentation 0 (function %presentation-hit-test-provider)))

(defun %truncated-cell (renderer window buffer line column)
  "Return LINE/COLUMN's cell and row inside a one-row-per-line window."
  (multiple-value-bind (text mapping)
      (%layout-buffer-line-display buffer line)
    (values (- (%layout-screen-column
                renderer text
                (aref mapping (min (max column 0) (1- (length mapping)))))
               (loom/core/window-tree:window-scroll-column window))
            (- line (loom/core/window-tree:window-scroll-line window)))))

(defun %wrapped-cell (renderer window buffer width line column)
  "Return LINE/COLUMN's (COLUMN ROW) inside a window that wraps long lines.

The row is counted from the window's own (line, segment) origin, which
%LAYOUT-KEEP-WRAPPED-POINT-VISIBLE has already moved to keep point on screen;
the walk is therefore bounded by the window height."
  (multiple-value-bind (text mapping)
      (%layout-buffer-line-display buffer line)
    (let* ((display-column
             (aref mapping (min (max column 0) (1- (length mapping)))))
           (segments (loom-renderer-wrap-segments renderer text width))
           (index (%loom-segment-index segments display-column))
           (segment (nth index segments)))
      (values (loom-renderer-segment-cells
               renderer text segment display-column)
              (or (%layout-rows-between
                   renderer buffer width
                   (loom/core/window-tree:window-scroll-line window)
                   (loom/core/window-tree:window-scroll-sub-row window)
                   line index
                   (%layout-window-content-height window))
                  0)))))

(defun %layout-completion-labels (renderer items first visible)
  (loop for offset below visible
        collect (loom-renderer-truncate-string
                 renderer
                 (editor-completion-item-label
                  (nth (+ first offset) items))
                 +layout-completion-width+)))

(defun %layout-completion-rows (renderer completion)
  "Return visible labels and the selected row within them."
  (let* ((items (editor-completion-items completion))
         (count (length items))
         (visible (min count +layout-completion-rows+))
         (index (editor-completion-index completion))
         (first (%layout-completion-first-index index count visible)))
    (values (%layout-completion-labels renderer items first visible)
            (- index first))))

(defun %layout-completion-popup-item-count (completion)
  (min (length (editor-completion-items completion))
       +layout-completion-rows+))

(defun %layout-completion-origin
    (renderer window completion height &optional buffer-cell-function)
  "Return a popup origin when the anchor row is visible, its column is
nonnegative, and vertical placement fits; otherwise return NIL."
  (multiple-value-bind (column row)
      (funcall (or buffer-cell-function *layout-buffer-cell-function*)
               renderer
               window
               (loom/core/window-tree:window-buffer window)
               (editor-completion-line completion)
               (editor-completion-column completion))
    (when (and (<= 0 row) (< row height) (<= 0 column))
      (let ((popup-row (%layout-completion-popup-row
                       row
                       (%layout-completion-popup-item-count completion)
                       height)))
        (when popup-row
          (values column popup-row))))))

(defun %layout-active-completion (window)
  (let ((completion (and *editor-state*
                         (editor-state-completion *editor-state*))))
    (when (and completion
               (eq (editor-completion-buffer completion)
                   (loom/core/window-tree:window-buffer window))
               (editor-completion-items completion))
      completion)))

(defun %layout-completion-cells (renderer rows width column)
  (min (- width (min column (1- width)))
       (loop for text in rows
             maximize (loom-renderer-string-width renderer text))))

(defun %layout-draw-completion-row (renderer x y offset text selected cells)
  (loom-renderer-write-string
   renderer x (+ y offset)
   (cl-tty-kit:pad-string
    (loom-renderer-truncate-string renderer text cells)
    cells)
   :style (if (= offset selected)
              +layout-completion-selected-style+
              +layout-completion-style+)))

(defun %layout-draw-completion-popup (renderer window x-offset rows selected
                                       column row gutter-width)
  (let* ((window-width (loom/core/window-tree:window-width window))
         (width (- window-width gutter-width))
         (x (+ x-offset (loom/core/window-tree:window-x window)
               gutter-width (min column (1- width))))
         (y (+ row (loom/core/window-tree:window-y window)))
         (cells (%layout-completion-cells renderer rows width column)))
    (loop for text in rows
          for offset from 0
          do (%layout-draw-completion-row
              renderer x y offset text selected cells))))

(defun %layout-draw-completion-content
    (renderer window x-offset completion buffer-cell-function)
  (let* ((buffer (editor-completion-buffer completion))
         (window-width (loom/core/window-tree:window-width window))
         (gutter-width (%layout-window-gutter-width buffer window-width))
         (width (- window-width gutter-width))
         (height (%layout-window-content-height window)))
    (when (and (plusp width) (plusp height))
      (multiple-value-bind (rows selected)
          (%layout-completion-rows renderer completion)
        (multiple-value-bind (column row)
            (%layout-completion-origin renderer window completion height
                                       buffer-cell-function)
          (when column
            (%layout-draw-completion-popup
             renderer window x-offset rows selected column row gutter-width)))))))

(defun %layout-draw-completion
    (renderer window x-offset &optional buffer-cell-function)
  "Draw the active completion popup for WINDOW."
  (let ((completion (%layout-active-completion window)))
    (when completion
      (%layout-draw-completion-content
       renderer window x-offset completion
       (or buffer-cell-function *layout-buffer-cell-function*)))))

(defun %layout-buffer-diagnostics (buffer)
  (let* ((editor-session
          (and *editor-state*
               (loom/core/editor-session:editor-state-session *editor-state*)))
         (session
          (and editor-session
               (loom/feature/lsp:lsp-session-for-buffer
                editor-session buffer))))
    (when session
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
                            "Wrap"))
                (format nil "~@[  ~A~]"
                        (loom/feature/files:file-format-indicator buffer)))))
    (let ((diagnostics-part
            (%layout-diagnostics-part (%layout-buffer-diagnostics buffer))))
      (if diagnostics-part
          (append parts (list diagnostics-part))
          parts))))

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
         (format-indicator (fifth parts))
         (diagnostics (sixth parts))
         (selected nil)
         (candidates
           (remove nil
                   (list diagnostics format-indicator wrap name mode position))))
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

(defun %layout-draw-window-overlays
    (renderer leaf x-offset selected-p buffer-cell-function)
  (let* ((buffer (loom/core/window-tree:window-buffer leaf))
         (mode (buffer-major-mode buffer))
         (display-lines
           (when (or (eq mode :markdown) (eq mode :org))
             (loom/feature/mode:major-mode-display-lines
              (buffer-visible-text buffer)
              mode))))
    (%layout-draw-window-buffer
     renderer leaf x-offset (%layout-window-content-height leaf) selected-p)
    (%layout-draw-mode-display-lines
     renderer leaf buffer x-offset display-lines)
    (%layout-draw-diagnostics renderer leaf x-offset)
    (%layout-draw-region renderer leaf x-offset)
    (%layout-draw-matching-paren renderer leaf x-offset)
    (%layout-draw-isearch renderer leaf x-offset)
    (%layout-draw-completion renderer leaf x-offset buffer-cell-function)))

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
                             buffer-cell-function &optional workspace-name)
  "Draw every leaf window and the separators in WINDOW-TREE."
  (let ((leaves (loom/core/window-tree:window-tree-windows window-tree))
        (selected (loom/core/window-tree:window-tree-selected-window window-tree)))
    (dolist (leaf leaves)
      (%layout-draw-window-overlays renderer leaf x-offset
                                    (eq leaf selected) buffer-cell-function))
    (dolist (leaf leaves)
      (%layout-draw-window-separator renderer leaf x-offset))
    (dolist (leaf leaves)
      (%layout-draw-window-mode-line renderer leaf x-offset (eq leaf selected) workspace-name)))
  renderer)

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

(eval-when (:load-toplevel :execute)
  (register-visual-row-layout :core/presentation
                              (function %visual-row-layout)))
