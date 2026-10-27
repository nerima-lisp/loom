(in-package #:loom/feature/lsp)
(define-condition lsp-workspace-edit-error (error)
    ((reason :initarg :reason :reader lsp-workspace-edit-error-reason))
  (:report (lambda (condition stream)
             (format stream "LSP WorkspaceEdit rejected: ~A"
                     (lsp-workspace-edit-error-reason condition)))))
(defun %lsp-workspace-edit-refuse (reason)
  (error 'lsp-workspace-edit-error :reason reason))
(defstruct
    (%lsp-workspace-text-edit
     (:constructor %make-lsp-workspace-text-edit (start end new-text)))
  start
  end
  new-text)

(defstruct
    (%lsp-workspace-edit-plan
     (:constructor %make-lsp-workspace-edit-plan (document buffers)))
  document
  buffers
  (edits nil))

(defun %lsp-workspace-edit-utf16-column (text character)
  (when (and (integerp character) (<= 0 character))
    (loop with offset = 0
          for value across text
          for column from 0
          do (cond
               ((= offset character) (return-from %lsp-workspace-edit-utf16-column column))
               ((> offset character) (return-from %lsp-workspace-edit-utf16-column nil)))
             (incf offset (if (> (char-code value) #xffff) 2 1))
          finally (return (and (= offset character) (length text))))))
(defun %lsp-workspace-edit-allowed-keys-p (object allowed)
  (and (hash-table-p object)
       (loop for key being the hash-keys of object
             always (member key allowed :test (function equal)))))

(defun %lsp-workspace-edit-position-offset (buffer object)
  (unless (%lsp-workspace-edit-allowed-keys-p object '("line" "character"))
    (%lsp-workspace-edit-refuse :invalid-position))
  (let ((line (gethash "line" object))
        (character (gethash "character" object)))
    (unless (and (integerp line) (<= 0 line)
                 (integerp character) (<= 0 character)
                 (< line (loom/core/buffer:buffer-line-count buffer)))
      (%lsp-workspace-edit-refuse :invalid-position))
    (let ((column (%lsp-workspace-edit-utf16-column
                   (loom/core/buffer:buffer-line buffer line) character)))
      (unless column (%lsp-workspace-edit-refuse :invalid-position))
      (loom/core/buffer:buffer-position-offset buffer line column))))
(defun %lsp-workspace-edit-range-offsets (buffer object)
  (unless (%lsp-workspace-edit-allowed-keys-p object '("start" "end"))
    (%lsp-workspace-edit-refuse :invalid-position))
  (multiple-value-bind (start present-p) (gethash "start" object)
    (unless present-p (%lsp-workspace-edit-refuse :invalid-position))
    (multiple-value-bind (end end-present-p) (gethash "end" object)
      (unless end-present-p (%lsp-workspace-edit-refuse :invalid-position))
      (let ((start-offset (%lsp-workspace-edit-position-offset buffer start))
            (end-offset (%lsp-workspace-edit-position-offset buffer end)))
        (unless (<= start-offset end-offset)
          (%lsp-workspace-edit-refuse :invalid-position))
        (values start-offset end-offset)))))
(defun %lsp-workspace-edit-parse-text-edit (buffer object)
  (unless (%lsp-workspace-edit-allowed-keys-p object '("range" "newText"))
    (%lsp-workspace-edit-refuse :unsupported-field))
  (let ((range (gethash "range" object))
        (new-text (gethash "newText" object)))
    (unless (and (hash-table-p range) (stringp new-text))
      (%lsp-workspace-edit-refuse :malformed))
    (multiple-value-bind (start end)
        (%lsp-workspace-edit-range-offsets buffer range)
      (%make-lsp-workspace-text-edit start end new-text))))
(defun %lsp-workspace-edit-entries (workspace-edit)
  (unless (hash-table-p workspace-edit) (%lsp-workspace-edit-refuse :malformed))
  (unless (%lsp-workspace-edit-allowed-keys-p workspace-edit '("changes" "documentChanges"))
    (%lsp-workspace-edit-refuse :unsupported-field))
  (let ((entries nil))
    (multiple-value-bind (changes present-p) (gethash "changes" workspace-edit)
      (when present-p
        (unless (hash-table-p changes) (%lsp-workspace-edit-refuse :malformed))
        (maphash (lambda (uri edits)
                   (unless (stringp uri) (%lsp-workspace-edit-refuse :unsupported-uri))
                   (push (list uri nil nil edits) entries))
                 changes)))
    (multiple-value-bind (document-changes present-p)
        (gethash "documentChanges" workspace-edit)
      (when present-p
        (unless (listp document-changes) (%lsp-workspace-edit-refuse :malformed))
        (dolist (change document-changes)
          (unless (hash-table-p change) (%lsp-workspace-edit-refuse :malformed))
          (when (some (lambda (key) (nth-value 1 (gethash key change)))
                      '("kind" "oldUri" "newUri"))
            (%lsp-workspace-edit-refuse :resource-operation))
          (unless (%lsp-workspace-edit-allowed-keys-p change '("textDocument" "edits"))
            (%lsp-workspace-edit-refuse :unsupported-field))
          (let ((text-document (gethash "textDocument" change))
                (edits (gethash "edits" change)))
            (unless (hash-table-p text-document) (%lsp-workspace-edit-refuse :malformed))
            (unless (%lsp-workspace-edit-allowed-keys-p text-document '("uri" "version"))
              (%lsp-workspace-edit-refuse :unsupported-field))
            (multiple-value-bind (uri uri-present-p) (gethash "uri" text-document)
              (multiple-value-bind (version version-present-p) (gethash "version" text-document)
                (unless (and uri-present-p (stringp uri) version-present-p)
                  (%lsp-workspace-edit-refuse :malformed))
                (unless (or (eq version json-kit:+json-null+)
                            (and (integerp version) (<= 0 version)))
                  (%lsp-workspace-edit-refuse :version-mismatch))
                (push (list uri version t edits) entries)))))))
    (nreverse entries)))

(defun %lsp-workspace-edit-document (session editor-session uri)
  (let* ((document (and (stringp uri) (gethash uri (lsp-session-documents session))))
         (path (and document (lsp-uri-path uri)))
         (registered (and editor-session
                          (loom/feature/buffers:registered-buffers editor-session)))
         (indexed-buffer (and path editor-session
                              (loom/feature/buffers:find-buffer-by-path editor-session path)))
         (buffers (and document
                       (copy-list (lsp-document-buffers document)))))
    (unless (and document path (string= uri (lsp-path-uri path))
                 indexed-buffer
                 (member indexed-buffer registered :test (function eq))
                 (member indexed-buffer buffers :test (function eq))
                 (every (lambda (buffer)
                          (and (member buffer registered :test (function eq))
                               (buffer-path buffer)
                               (string= uri (lsp-path-uri (buffer-path buffer)))))
                        buffers))
      (%lsp-workspace-edit-refuse :unsupported-uri))
    (dolist (buffer buffers)
      (unless (string= (loom/core/buffer:buffer-text buffer)
                       (lsp-document-text document))
        (%lsp-workspace-edit-refuse :stale-document)))
    (when (some (function loom/core/buffer:buffer-read-only-p) buffers)
      (%lsp-workspace-edit-refuse :read-only))
    (values document buffers)))

(defun %lsp-workspace-edit-add-entry (plans session editor-session uri version version-present-p edits)
  (unless (listp edits)
    (%lsp-workspace-edit-refuse :malformed))
  (let ((plan (gethash uri plans)))
    (unless plan
      (multiple-value-bind (document buffers)
          (%lsp-workspace-edit-document session editor-session uri)
        (setf plan (%make-lsp-workspace-edit-plan document buffers)
              (gethash uri plans) plan)))
    (when (and version-present-p
               (not (or (eq version json-kit:+json-null+)
                        (= version
                           (lsp-document-version
                            (%lsp-workspace-edit-plan-document plan))))))
      (%lsp-workspace-edit-refuse :version-mismatch))
    (dolist (object edits)
      (let ((edit (%lsp-workspace-edit-parse-text-edit
                   (first (%lsp-workspace-edit-plan-buffers plan)) object)))
        (dolist (buffer (%lsp-workspace-edit-plan-buffers plan))
          (when (and (loom/core/buffer:buffer-narrowed-p buffer)
                     (or (< (%lsp-workspace-text-edit-start edit)
                            (loom/core/buffer:buffer-narrow-start-offset buffer))
                         (> (%lsp-workspace-text-edit-end edit)
                            (loom/core/buffer:buffer-narrow-end-offset buffer))))
            (%lsp-workspace-edit-refuse :narrowing)))
        (push edit (%lsp-workspace-edit-plan-edits plan))))
    plan))
(defun %lsp-workspace-edits-overlap-p (first second)
  (let ((first-start (%lsp-workspace-text-edit-start first))
        (first-end (%lsp-workspace-text-edit-end first))
        (second-start (%lsp-workspace-text-edit-start second)))
    (or (= first-start second-start) (< second-start first-end))))
(defun %lsp-workspace-edit-validate-plan (plan)
  (let ((ascending (sort (copy-list (%lsp-workspace-edit-plan-edits plan)) #'<
                         :key #'%lsp-workspace-text-edit-start)))
    (loop for remaining on ascending
          for first = (first remaining)
          do (dolist (second (rest remaining))
               (when (%lsp-workspace-edits-overlap-p first second)
                 (%lsp-workspace-edit-refuse :overlapping-edits))))
    (setf (%lsp-workspace-edit-plan-edits plan)
          (sort (copy-list ascending) #'> :key #'%lsp-workspace-text-edit-start)))
  plan)
(defun %lsp-workspace-edit-target-offset (point edits)
  (let ((delta 0))
    (dolist
        (edit
         (sort (copy-list edits)
               (function <)
               :key
               (function %lsp-workspace-text-edit-start)))
      (let ((start (%lsp-workspace-text-edit-start edit))
            (end (%lsp-workspace-text-edit-end edit))
            (new-length (length (%lsp-workspace-text-edit-new-text edit))))
        (cond
          ((< point start)
           (return-from %lsp-workspace-edit-target-offset
             (+ point delta)))
          ((= start end) (incf delta new-length))
          ((<= point end)
           (return-from %lsp-workspace-edit-target-offset
             (+ start delta (min (- point start) new-length))))
          (t (incf delta (- new-length (- end start)))))))
    (+ point delta)))

(defun %lsp-workspace-edit-apply-buffer (buffer edits)
  (let ((original-point (loom/core/buffer:buffer-point-offset buffer))
        (changed-p nil))
    (loom/core/buffer:buffer-record-undo-boundary buffer)
    (handler-case
        (progn
          (dolist (edit edits)
            (let* ((start (%lsp-workspace-text-edit-start edit))
                   (end (%lsp-workspace-text-edit-end edit))
                   (start-position (loom/core/buffer:buffer-offset-position buffer start))
                   (end-position (loom/core/buffer:buffer-offset-position buffer end)))
              (buffer-set-point buffer
                                (loom/core/buffer:buffer-position-line start-position)
                                (loom/core/buffer:buffer-position-column start-position))
              (unless (= start end)
                (loom/core/buffer:buffer-delete-region
                 buffer
                 (loom/core/buffer:buffer-position-line start-position)
                 (loom/core/buffer:buffer-position-column start-position)
                 (loom/core/buffer:buffer-position-line end-position)
                 (loom/core/buffer:buffer-position-column end-position)
                 :undo-replacement-p t)
                (setf changed-p t))
              (unless (string= (%lsp-workspace-text-edit-new-text edit) "")
                (loom/core/buffer:buffer-insert-string
                 buffer (%lsp-workspace-text-edit-new-text edit))
                (setf changed-p t))))
          (if changed-p
              (progn
                (loom/core/buffer:buffer-record-undo-boundary buffer)
                (let* ((target (%lsp-workspace-edit-target-offset original-point edits))
                       (position (loom/core/buffer:buffer-offset-position buffer target)))
                  (buffer-set-point buffer
                                    (loom/core/buffer:buffer-position-line position)
                                    (loom/core/buffer:buffer-position-column position))))
            (let ((position (loom/core/buffer:buffer-offset-position buffer original-point)))
              (buffer-set-point buffer
                                (loom/core/buffer:buffer-position-line position)
                                (loom/core/buffer:buffer-position-column position))))
          changed-p)
      (error (condition)
             (when changed-p (loom/core/buffer:buffer-undo buffer))
             (let ((position (loom/core/buffer:buffer-offset-position buffer original-point)))
               (buffer-set-point buffer
                                 (loom/core/buffer:buffer-position-line position)
                                 (loom/core/buffer:buffer-position-column position)))
             (error condition)))))
(defun %lsp-apply-workspace-edit (session editor-session workspace-edit)
  (let ((plans (make-hash-table :test (function equal)))
        (applied nil))
    (handler-case
        (progn
          (dolist (entry (%lsp-workspace-edit-entries workspace-edit))
            (%lsp-workspace-edit-add-entry
             plans session editor-session
             (first entry) (second entry) (third entry) (fourth entry)))
          (maphash (lambda (uri plan)
                     (declare (ignore uri))
                     (%lsp-workspace-edit-validate-plan plan))
                   plans)
          (maphash (lambda (uri plan)
                     (declare (ignore uri))
                     (dolist (buffer (%lsp-workspace-edit-plan-buffers plan))
                       (when (%lsp-workspace-edit-apply-buffer
                              buffer (%lsp-workspace-edit-plan-edits plan))
                         (push (cons plan buffer) applied))))
                   plans)
          (dolist (entry (nreverse applied))
            (lsp-session-sync-buffer session (cdr entry) editor-session))
          t)
      (error (condition)
             (dolist (entry applied)
               (loom/core/buffer:buffer-undo (cdr entry)))
             (dolist (entry applied)
               (lsp-session-sync-buffer session (cdr entry) editor-session))
             (error condition)))))
(defun %lsp-rename-response (session editor-session result error-message)
  (cond
   (error-message
    (%lsp-navigation-message (format nil "Rename failed: ~A" error-message)))
   ((or (null result) (eq result json-kit:+json-null+))
    (%lsp-navigation-message "No rename edits returned"))
   (t
    (handler-case
        (progn
          (%lsp-apply-workspace-edit session editor-session result)
          (%lsp-navigation-message "Rename applied"))
      (lsp-workspace-edit-error (condition)
                                (%lsp-navigation-message
                                 (format nil "Rename rejected: ~A"
                                         (lsp-workspace-edit-error-reason condition))))))))



