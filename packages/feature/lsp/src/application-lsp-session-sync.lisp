(in-package #:loom/feature/lsp)

(defun %lsp-buffer-uri (buffer-or-path)
  (cond
    ((buffer-p buffer-or-path)
     (and (buffer-path buffer-or-path)
          (lsp-path-uri (buffer-path buffer-or-path))))
    ((or (pathnamep buffer-or-path) (stringp buffer-or-path))
     (lsp-path-uri buffer-or-path))
    (t nil)))

(defun %lsp-send-document-change (session uri document text)
  (incf (lsp-document-version document))
  (setf (lsp-document-text document) text)
  (%lsp-send-notification
   session
   "textDocument/didChange"
   (json-kit:make-json-object
    (list
     (cons "textDocument"
           (json-kit:make-json-object
            (list (cons "uri" uri)
                  (cons "version" (lsp-document-version document)))))
     (list "contentChanges" (json-kit:make-json-object
                  (list (cons "text" text))))))))

(defun %lsp-send-document-open (session uri document text)
  (%lsp-send-notification
   session
   "textDocument/didOpen"
   (json-kit:make-json-object
    (list
     (cons "textDocument"
           (json-kit:make-json-object
            (list (cons "uri" uri)
                  (cons "languageId"
                        (lsp-document-language-id document))
                  (cons "version" (lsp-document-version document))
                  (cons "text" text))))))))

(defun %lsp-sync-existing-document (session uri document buffer text)
  (pushnew buffer (lsp-document-buffers document) :test (function eq))
  (unless (string= text (lsp-document-text document))
    (%lsp-send-document-change session uri document text)))

(defun %lsp-sync-new-document (session uri buffer text)
  (let ((document (make-lsp-document uri
                                     (%lsp-language-id
                                      (loom/core/buffer:buffer-major-mode
                                       buffer))
                                     1
                                     text
                                     buffer)))
    (setf (gethash uri (lsp-session-documents session)) document)
    (%lsp-send-document-open session uri document text)))

(progn
  (defun %lsp-send-document-close (session uri)
    (%lsp-send-notification
     session "textDocument/didClose"
     (json-kit:make-json-object
      (list (cons "textDocument"
                  (json-kit:make-json-object (list (cons "uri" uri))))))))

  (defun %lsp-close-document-for-buffer (session uri buffer)
    (let* ((document (and uri (gethash uri (lsp-session-documents session))))
           (buffers (and document (lsp-document-buffers document)))
           (remaining (and buffers (remove buffer buffers :test (function eq)))))
      (when document
        (cond
          ((and buffers (not (member buffer buffers :test (function eq)))) nil)
          (remaining (setf (lsp-document-buffers document) remaining))
          (t
           (unwind-protect
                (when (and (not (lsp-session-closed-p session))
                           (lsp-session-initialized-p session))
                  (%lsp-send-document-close session uri))
             (remhash uri (lsp-session-documents session))
             (remhash uri (lsp-session-diagnostic-table session))))))
      session))

  (defun %lsp-close-buffer-in-other-sessions (editor-session session buffer)
    (let* ((uri (%lsp-buffer-uri buffer))
           (registry
             (and editor-session
                  (member :feature/lsp
                          (loom/core/editor-session:editor-session-slice-names
                           editor-session))
                  (lsp-session-registry-state-sessions
                   (%lsp-session-registry editor-session)))))
      (when (and uri registry)
        (maphash
         (lambda (key registered-session)
           (declare (ignore key))
           (unless (eq registered-session session)
             (let ((document
                     (gethash uri (lsp-session-documents registered-session))))
               (when (and document
                          (member buffer (lsp-document-buffers document)
                                  :test (function eq)))
                 (%lsp-close-document-for-buffer
                  registered-session uri buffer)))))
         registry)))
    session)

  (defun lsp-session-sync-buffer
    (session buffer
     &optional
       (editor-session
         (or *editor-session*
             (and *editor-state*
                  (loom/core/editor-session:editor-state-session
                   *editor-state*)))))
  "For an initialized SESSION and file-backed BUFFER, send didOpen for a new
document or full-text didChange when its text differs."
  (unless (buffer-p buffer)
    (error "LSP buffer synchronization needs a BUFFER: ~S" buffer))
  (let ((uri (%lsp-buffer-uri buffer)))
    (when uri
      (%lsp-close-buffer-in-other-sessions editor-session session buffer)
      (when (lsp-session-initialized-p session)
        (let* ((text (buffer-text buffer))
               (document (gethash uri (lsp-session-documents session))))
          (if document
              (%lsp-sync-existing-document
               session uri document buffer text)
              (%lsp-sync-new-document session uri buffer text))))))
  session))

(defun lsp-session-diagnostics (session buffer-or-path)
  "Return a copy of diagnostics associated with BUFFER-OR-PATH."
  (let ((uri (%lsp-buffer-uri buffer-or-path)))
    (copy-list (and uri (gethash uri (lsp-session-diagnostic-table session))))))
(defun lsp-session-save-buffer
    (session buffer
     &optional
       (editor-session
         (or *editor-session*
             (and *editor-state*
                  (loom/core/editor-session:editor-state-session
                   *editor-state*)))))
  (let ((uri (%lsp-buffer-uri buffer)))
    (when uri
      (lsp-session-sync-buffer session buffer editor-session)
      (when (lsp-session-initialized-p session)
        (%lsp-send-notification
         session
         "textDocument/didSave"
         (json-kit:make-json-object
          (list
           (cons "textDocument"
                 (json-kit:make-json-object (list (cons "uri" uri))))
           (cons "text" (buffer-text buffer)))))))
  session))
(defun lsp-session-close-buffer (session buffer)
  (%lsp-close-document-for-buffer
   session (%lsp-buffer-uri buffer) buffer)
  session)
(defun %lsp-after-save-hook (editor-session buffer)
  (let ((session (lsp-session-for-buffer editor-session buffer)))
    (if session
        (lsp-session-save-buffer session buffer editor-session)
        (%lsp-close-buffer-in-other-sessions editor-session nil buffer))))
(defun %lsp-buffer-close-hook (editor-session buffer &optional reason)
  (declare (ignore reason))
  (%lsp-close-buffer-in-other-sessions editor-session nil buffer))
(eval-when (:load-toplevel :execute)
    (register-session-hook :after-save
                           :feature/lsp
                           (function %lsp-after-save-hook))
    (register-session-hook :buffer-close
                           :feature/lsp
                           (function %lsp-buffer-close-hook)))
