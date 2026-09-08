;;;; src/presentation/layout-windows.lisp
;;;;
;;;; Presentation of window buffers, mode lines, separators, and matching
;;;; parentheses.
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
                        (if (loom/feature/mode:buffer-truncate-lines-p buffer)
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
         (remaining-after-status
           (max 0 (- width
                     (loom-renderer-string-width renderer status-visible))))
         (workspace
           (%layout-mode-line-workspace-suffix
            renderer workspace-name remaining-after-status))
         (remaining
           (max 0 (- remaining-after-status
                    (loom-renderer-string-width renderer workspace))))
         (selected nil))
    (dolist (part (reverse (rest parts)))
      (let ((part-width (loom-renderer-string-width renderer part)))
        (when (<= part-width remaining)
          (push part selected)
          (decf remaining part-width))))
    (when (and (null selected) (plusp remaining))
      (push (%layout-truncate-to-width (car (last parts)) remaining)
            selected))
    (format nil "~A~{~A~}~A" status-visible selected workspace)))

(defun %layout-mode-line (renderer buffer &optional width workspace-name)
  "Return BUFFER's mode line clipped to WIDTH cells from the right."
  (let ((width (or width (loom-renderer-width renderer))))
    (if workspace-name
        (%layout-mode-line-workspace renderer buffer width workspace-name)
        (%layout-truncate-to-width
         (%layout-mode-line-text renderer buffer)
         width))))

(defun %layout-draw-window-buffer (renderer window x-offset &optional height)
  "Draw WINDOW's buffer in whichever line-display mode that buffer selects.

When HEIGHT is supplied, draw only that many rows, leaving the caller to draw
the mode line or another footer in the remaining window rows."
  (let* ((buffer (loom/feature/window:window-buffer window))
         (x (+ x-offset (loom/feature/window:window-x window)))
         (y (loom/feature/window:window-y window))
         (width (loom/feature/window:window-width window))
         (height (or height (loom/feature/window:window-height window))))
    (if (loom/feature/mode:buffer-truncate-lines-p buffer)
        (loom/feature/syntax-highlighting:syntax-draw-buffer
         renderer buffer x y width height
         :start-line (loom/feature/window:window-scroll-line window)
         :start-column (loom/feature/window:window-scroll-column window))
        (%layout-draw-wrapped-buffer
         renderer buffer x y width height
         (loom/feature/window:window-scroll-line window)
         (loom/feature/window:window-scroll-sub-row window)))))

(defun %layout-draw-window-overlays (renderer leaf x-offset)
  (%layout-draw-window-buffer
   renderer leaf x-offset (%layout-window-content-height leaf))
  (%layout-draw-diagnostics renderer leaf x-offset)
  ;; Region is drawn before matching parentheses so the latter remains legible
  ;; when its cells overlap the active region.
  (%layout-draw-region renderer leaf x-offset)
  (%layout-draw-matching-paren renderer leaf x-offset)
  (%layout-draw-isearch renderer leaf x-offset)
  (%layout-draw-completion renderer leaf x-offset))

(defun %layout-draw-window-mode-line (renderer window x-offset selected-p
                                      &optional workspace-name)
  "Draw WINDOW's mode line across its last row when the leaf has an area."
  (let ((width (loom/feature/window:window-width window))
        (height (loom/feature/window:window-height window)))
    (when (and (plusp width) (plusp height))
      (let* ((text (%layout-mode-line
                    renderer (loom/feature/window:window-buffer window) width
                    (and selected-p workspace-name)))
             (padding (make-string
                       (- width (loom-renderer-string-width renderer text))
                       :initial-element #\Space)))
        (loom-renderer-write-string
         renderer
         (+ x-offset (loom/feature/window:window-x window))
         (+ (loom/feature/window:window-y window) (1- height))
         (concatenate 'string text padding)
         :style (if selected-p
                    +layout-mode-line-selected-style+
                    +layout-mode-line-unselected-style+))))))

(defun %layout-draw-window-separator (renderer leaf x-offset)
  (when (and (plusp (loom/feature/window:window-x leaf))
             (plusp (loom/feature/window:window-height leaf)))
    (loom-renderer-draw-vertical-line
     renderer (1- (+ x-offset (loom/feature/window:window-x leaf)))
     (loom/feature/window:window-y leaf)
     (loom/feature/window:window-height leaf)))
  (when (and (plusp (loom/feature/window:window-y leaf))
             (plusp (loom/feature/window:window-width leaf)))
    (loom-renderer-draw-horizontal-line
     renderer (+ x-offset (loom/feature/window:window-x leaf))
     (1- (loom/feature/window:window-y leaf))
     (loom/feature/window:window-width leaf)))
  renderer)

(defun %layout-draw-windows (renderer window-tree x-offset
                             &optional workspace-name)
  "Draw every leaf window and the separators in WINDOW-TREE."
  (let ((leaves (loom/feature/window:window-tree-windows window-tree))
        (selected (loom/feature/window:window-tree-selected-window window-tree)))
    (dolist (leaf leaves)
      (%layout-draw-window-overlays renderer leaf x-offset))
    (dolist (leaf leaves)
      (%layout-draw-window-separator renderer leaf x-offset))
    (dolist (leaf leaves)
      (%layout-draw-window-mode-line renderer leaf x-offset (eq leaf selected)
                                     workspace-name)))
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
                 (%position-to-offset
                  buffer
                  (loom/feature/lsp:lsp-position-line start)
                  (loom/feature/lsp:lsp-position-character start)))
               (end-offset
                 (%position-to-offset
                  buffer
                  (loom/feature/lsp:lsp-position-line end)
                  (loom/feature/lsp:lsp-position-character end)))
               (visible-start (buffer-narrow-start-offset buffer))
               (visible-end (buffer-narrow-end-offset buffer))
               (clipped-start (max start-offset visible-start))
               (clipped-end (min end-offset visible-end)))
          (when (< clipped-start clipped-end)
            (make-buffer-span clipped-start clipped-end)))
      (error () nil))))

(defun %layout-draw-diagnostics (renderer window x-offset)
  (let* ((buffer (loom/feature/window:window-buffer window))
         (diagnostics (%layout-buffer-diagnostics buffer)))
    (dolist (diagnostic diagnostics)
      (let ((span (%layout-lsp-diagnostic-span buffer diagnostic)))
        (when span
          (%layout-draw-span renderer window x-offset span
                             +layout-diagnostic-style+))))))

(defun %layout-draw-region (renderer window x-offset)
  (let ((span (buffer-active-region-span
               (loom/feature/window:window-buffer window))))
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
  (let* ((buffer (loom/feature/window:window-buffer window))
         (start (buffer-narrow-start-offset buffer))
         (text (buffer-visible-text buffer))
         (offset (max 0 (min (length text)
                             (- (buffer-point-offset buffer) start)))))
    (multiple-value-bind (paren match) (%matching-paren-offset text offset)
      (when (and paren match)
        (dolist (local (list paren match))
          (%layout-draw-matching-paren-at
           renderer window x-offset buffer start local))))))
