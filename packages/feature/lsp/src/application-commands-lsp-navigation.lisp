(in-package #:loom/feature/lsp)

(defun %lsp-push-jump-origin (buffer line column)
  (push (list buffer line column)
        (loom:editor-state-jump-origins loom:*editor-state*)))

(defun %lsp-selected-buffer-for-path (path)
  (let ((selected (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*)))))
    (when (and selected
               (loom:buffer-path selected)
               (equal (namestring (pathname (loom:buffer-path selected)))
                      (namestring (pathname path))))
      selected)))

(defun %lsp-location-buffer (path)
  (and path
       (or (%lsp-selected-buffer-for-path path)
           (loom/feature/file-tree:visit-file path))))

(defun %lsp-goto-location (location)
  "Move point to LOCATION, opening its file when it is not already shown."
  (let* ((path (lsp-uri-path (lsp-location-uri location)))
         (position (lsp-range-start (lsp-location-range location)))
         (buffer (%lsp-location-buffer path)))
    (cond
      ((null path)
       (%lsp-navigation-message
        (format nil "Definition is not a local file: ~A"
                (lsp-location-uri location))))
      ((null buffer)
       (%lsp-navigation-message (format nil "Cannot open ~A" path)))
      (t
       (let ((line (max 0 (min (lsp-position-line position)
                              (1- (loom:buffer-line-count buffer))))))
         (loom:buffer-set-point
          buffer line
          (lsp-character-to-column (loom:buffer-line buffer line)
                                   (lsp-position-character position))))
       buffer))))

(defun %lsp-definition-response (buffer line character locations error-message)
  (cond
    (error-message
     (%lsp-navigation-message
      (format nil "Definition failed: ~A" error-message)))
    ((null locations)
     (%lsp-navigation-message "No definition found"))
    (t
     (%lsp-push-jump-origin buffer line character)
     (%lsp-goto-location (first locations)))))

(defun lsp-find-definition ()
  "Jump to the definition of the symbol at point (M-.).

The position point occupied is pushed first, so LSP-POP-DEFINITION can put it
back even when the jump crossed into another file."
  (multiple-value-bind (session buffer uri line character)
      (%lsp-navigation-context)
    (cond
      ((null session) (%lsp-navigation-message "No LSP session for this buffer"))
      ((not (lsp-session-capability session "definitionProvider"))
       (%lsp-navigation-message "Server does not provide definitions"))
      (t
       (lsp-session-sync-buffer session buffer)
       (lsp-request-definition
        session uri line
        (lsp-column-to-character (loom:buffer-line buffer line) character)
        (lambda (locations error-message)
          (%lsp-definition-response
           buffer line character locations error-message)))
       nil))))

(defun lsp-pop-definition ()
  "Return point to where the last definition jump started (M-,)."
  (let ((origin (pop (loom:editor-state-jump-origins loom:*editor-state*))))
    (if origin
        (destructuring-bind (buffer line column) origin
          (loom/feature/window:window-set-buffer
           (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*)) buffer)
          (loom:buffer-set-point buffer line column))
        (%lsp-navigation-message "No jump to return from")))
  nil)
