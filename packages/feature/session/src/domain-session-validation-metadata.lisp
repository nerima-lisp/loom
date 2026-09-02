;;;; packages/feature/session/src/domain-session-validation-metadata.lisp
(in-package #:loom/feature/session)

(defun %validate-session-list (value predicate message)
  (unless (and (listp value) (every predicate value))
    (error "validate-session-snapshot: ~A" message))
  value)

(defun %validate-session-unique-names (objects name-reader message)
  (let ((names (mapcar name-reader objects)))
    (unless (= (length names)
               (length (remove-duplicates names :test #'string=)))
      (error "validate-session-snapshot: ~A: ~S" message names)))
  objects)

(defun %session-buffer-identity-valid-p (buffer)
  (and (stringp (session-buffer-snapshot-name buffer))
       (or (null (session-buffer-snapshot-path buffer))
           (stringp (session-buffer-snapshot-path buffer)))
       (stringp (session-buffer-snapshot-text buffer))))

(defun %session-buffer-position-valid-p (buffer)
  (and (%session-nonnegative-integer-p
        (session-buffer-snapshot-point-line buffer))
       (%session-nonnegative-integer-p
        (session-buffer-snapshot-point-column buffer))
       (%session-mark-valid-p
        (session-buffer-snapshot-mark-line buffer)
        (session-buffer-snapshot-mark-column buffer))))

(defun %session-buffer-state-valid-p (buffer)
  (member (session-buffer-snapshot-modified-p buffer)
          '(nil t)
          :test #'eq))

(defun %validate-session-buffer (buffer)
  (unless (typep buffer 'session-buffer-snapshot)
    (error "validate-session-snapshot: invalid buffer snapshot ~S" buffer))
  (unless (and (%session-buffer-identity-valid-p buffer)
               (%session-buffer-position-valid-p buffer)
               (%session-buffer-state-valid-p buffer))
    (error "validate-session-snapshot: malformed buffer snapshot ~S" buffer))
  buffer)

(defun %validate-session-bookmark (bookmark)
  (unless (typep bookmark 'session-bookmark-snapshot)
    (error "validate-session-snapshot: invalid bookmark snapshot ~S"
           bookmark))
  (unless (and (%session-nonempty-string-p
                (session-bookmark-snapshot-name bookmark))
               (%session-optional-string-p
                (session-bookmark-snapshot-path bookmark))
               (%session-optional-string-p
                (session-bookmark-snapshot-buffer-name bookmark))
               (%session-nonnegative-integer-p
                (session-bookmark-snapshot-line bookmark))
               (%session-nonnegative-integer-p
                (session-bookmark-snapshot-column bookmark)))
    (error "validate-session-snapshot: malformed bookmark snapshot ~S"
           bookmark))
  bookmark)

(defun %validate-session-metadata (snapshot)
  "Validate the session collections that do not describe window trees."
  (let ((recent-files (session-snapshot-recent-files snapshot))
        (bookmarks (session-snapshot-bookmarks snapshot))
        (command-history (session-snapshot-command-history snapshot)))
    (%validate-session-list
     recent-files #'%session-nonempty-string-p
     "recent files must be a list of non-empty strings")
    (unless (listp bookmarks)
      (error "validate-session-snapshot: bookmarks must be a list"))
    (mapc #'%validate-session-bookmark bookmarks)
    (%validate-session-unique-names
     bookmarks #'session-bookmark-snapshot-name
     "bookmark names must be unique")
    (%validate-session-list
     command-history #'stringp
     "command history must be a list of strings"))
  snapshot)
