(in-package #:loom/feature/lsp)

(defun %lsp-push-jump-origin (buffer line column)
  (push (list buffer line column)
        (editor-state-jump-origins *editor-state*)))

(defun %lsp-selected-buffer-for-path (path)
  (let ((selected (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*)))))
    (when (and selected
               (buffer-path selected)
               (equal (namestring (pathname (buffer-path selected)))
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
                              (1- (buffer-line-count buffer))))))
         (buffer-set-point
          buffer line
          (lsp-character-to-column (buffer-line buffer line)
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
        (lsp-column-to-character (buffer-line buffer line) character)
        (lambda (locations error-message)
          (%lsp-definition-response
           buffer line character locations error-message)))
       nil))))
(defun lsp-hover-at-point ()
  "Show the language server's hover information at point."
  (multiple-value-bind (session buffer uri line character)
      (%lsp-navigation-context)
    (cond
      ((null session)
       (%lsp-navigation-message "No LSP session for this buffer"))
      ((not (lsp-session-capability session "hoverProvider"))
       (%lsp-navigation-message "Server does not provide hover"))
      (t
       (lsp-session-sync-buffer session buffer)
       (lsp-request-hover
        session uri line
        (lsp-column-to-character (buffer-line buffer line) character)
        (lambda (content error-message)
          (cond
            (error-message
             (%lsp-navigation-message
              (format nil "Hover failed: ~A" error-message)))
            ((or (null content) (equal content ""))
             (%lsp-navigation-message "No hover information"))
            (t
             (%lsp-navigation-message content)))))
       nil))))

(defun lsp-pop-definition ()
  "Return point to where the last definition jump started (M-,)."
  (let ((origin (pop (editor-state-jump-origins *editor-state*))))
    (if origin
        (destructuring-bind (buffer line column) origin
          (loom/core/window-tree:window-set-buffer
           (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*)) buffer)
          (buffer-set-point buffer line column))
        (%lsp-navigation-message "No jump to return from")))
  nil)
(defun %lsp-reference-line-text (editor-session path line)
  (let ((buffer (loom/feature/buffers:find-buffer-by-path
                 editor-session path)))
    (if buffer
        (if (< line (buffer-line-count buffer))
            (buffer-line buffer line)
            "")
        (handler-case
            (with-open-file (stream path :direction :input)
              (loop repeat line do (read-line stream nil nil))
              (or (read-line stream nil nil) ""))
          (file-error () "")))))
(defun %lsp-reference-result-item (editor-session location)
  (let* ((path (lsp-uri-path (lsp-location-uri location)))
         (position (lsp-range-start (lsp-location-range location)))
         (line (lsp-position-line position))
         (character (lsp-position-character position)))
    (when (and path (<= 0 line) (<= 0 character))
      (let ((text (%lsp-reference-line-text editor-session path line)))
        (loom/feature/search:make-result-item
         path line
         (lsp-character-to-column text character)
         text)))))
(defun %lsp-reference-result-items (editor-session locations)
  (loop for location in locations
        for item = (%lsp-reference-result-item editor-session location)
        when item
          collect item))
(defun %lsp-references-response (editor-session locations error-message)
  (cond
    (error-message
     (%lsp-navigation-message
      (format nil "References failed: ~A" error-message)))
    ((null locations)
     (%lsp-navigation-message "No references found"))
    (t
     (let ((items (%lsp-reference-result-items editor-session locations)))
       (if (null items)
           (%lsp-navigation-message "No local references found")
           (let* ((buffer
                    (loom/feature/search:publish-result-list
                     editor-session "*Loom-References*" items))
                  (window
                    (loom/core/window-tree:window-tree-selected-window
                     (editor-state-window-tree *editor-state*))))
             (loom/core/window-tree:window-set-buffer window buffer)
             (%lsp-navigation-message
              (format nil "References found: ~D" (length items)))
             buffer))))))
(defun lsp-find-references ()
  "Show references for the symbol at point in a result list."
  (multiple-value-bind (session buffer uri line column)
      (%lsp-navigation-context)
    (cond
      ((null session)
       (%lsp-navigation-message "No LSP session for this buffer"))
      ((not (lsp-session-capability session "referencesProvider"))
       (%lsp-navigation-message "Server does not provide references"))
      (t
       (let ((editor-session
               (loom/core/editor-session:editor-state-session *editor-state*)))
         (lsp-session-sync-buffer session buffer)
         (lsp-request-references
          session uri line
          (lsp-column-to-character (buffer-line buffer line) column)
          (lambda (locations error-message)
            (%lsp-references-response
             editor-session locations error-message)))
         nil)))))
(defun lsp-rename ()
  "Prompt for a new name and apply the server's WorkspaceEdit."
  (multiple-value-bind (session buffer uri line column)
      (%lsp-navigation-context)
    (let* ((minibuffer (editor-state-minibuffer *editor-state*))
           (editor-session
            (loom/core/editor-session:editor-state-session *editor-state*)))
      (cond
       ((null session)
        (%lsp-navigation-message "No LSP session for this buffer"))
       ((not (lsp-session-capability session "renameProvider"))
        (%lsp-navigation-message "Server does not provide rename"))
       (t
        (with-prompts
         (minibuffer minibuffer
                     :on-cancel
                     (%lsp-navigation-message "Rename cancelled"))
         ((new-name "Rename to: "))
         (if (string= new-name "")
             (minibuffer-message minibuffer "Rename name cannot be empty")
           (progn
             (lsp-session-sync-buffer session buffer editor-session)
             (lsp-request-rename
              session uri line
              (lsp-column-to-character (buffer-line buffer line) column)
              new-name
              (lambda (result error-message)
                (%lsp-rename-response
                 session editor-session result error-message))))))))))
  )
