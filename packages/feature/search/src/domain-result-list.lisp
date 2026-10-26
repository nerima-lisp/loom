(in-package #:loom/feature/search)
(progn
  (defstruct (result-item (:constructor %make-result-item))
    (file-path nil :read-only t)
    (buffer nil :type (or null loom/core/buffer:buffer) :read-only t)
    (line 0 :type (integer 0 *) :read-only t)
    (column 0 :type (integer 0 *) :read-only t)
    (display-text "" :type string :read-only t))

  (defun make-result-item (file-path line column display-text &key buffer)
    "Create a result item with zero-based LINE and COLUMN coordinates."
    (unless (or (stringp file-path) (pathnamep file-path)
                (and (null file-path) buffer))
      (error "Result item requires a file path or a target buffer: ~S"
             file-path))
    (check-type buffer (or null loom/core/buffer:buffer))
    (check-type line (integer 0 *))
    (check-type column (integer 0 *))
    (check-type display-text string)
    (%make-result-item :file-path file-path :buffer buffer
                       :line line :column column
                       :display-text display-text))

  (defstruct (search-result-list (:constructor %make-search-result-list))
    (buffer nil :read-only t)
    (items #() :type vector :read-only t)
    (cursor -1 :type integer))

  (defstruct (search-result-state (:constructor %make-search-result-state))
    (lists (make-hash-table :test (function eq)) :type hash-table :read-only t)
    active-buffer
    active-occur)

  (defun %make-search-result-state-for-session (session)
    (declare (ignore session))
    (%make-search-result-state))

  (eval-when (:load-toplevel :execute)
    (loom/core/editor-session:register-slice-state
     :feature/search
     (quote %make-search-result-state-for-session))))
