;;;; packages/feature/session/src/domain-session-validation-metadata.lisp
(in-package #:loom/feature/session)

(defun %validate-session-buffer (buffer)
  (unless (typep buffer 'session-buffer-snapshot)
    (error "validate-session-snapshot: invalid buffer snapshot ~S" buffer))
  (unless (and (stringp (session-buffer-snapshot-name buffer))
               (or (null (session-buffer-snapshot-path buffer))
                   (stringp (session-buffer-snapshot-path buffer)))
               (stringp (session-buffer-snapshot-text buffer))
               (%session-nonnegative-integer-p
                (session-buffer-snapshot-point-line buffer))
               (%session-nonnegative-integer-p
                (session-buffer-snapshot-point-column buffer))
               (%session-mark-valid-p
                (session-buffer-snapshot-mark-line buffer)
                (session-buffer-snapshot-mark-column buffer))
               (member (session-buffer-snapshot-modified-p buffer)
                       '(nil t)
                       :test #'eq))
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
    (unless (and (listp recent-files)
                 (every #'%session-nonempty-string-p recent-files))
      (error "validate-session-snapshot: recent files must be a list of non-empty strings"))
    (unless (listp bookmarks)
      (error "validate-session-snapshot: bookmarks must be a list"))
    (mapc #'%validate-session-bookmark bookmarks)
    (let ((names (mapcar #'session-bookmark-snapshot-name bookmarks)))
      (unless (= (length names)
                 (length (remove-duplicates names :test #'string=)))
        (error "validate-session-snapshot: bookmark names must be unique: ~S"
               names)))
    (unless (and (listp command-history)
                 (every #'stringp command-history))
      (error "validate-session-snapshot: command history must be a list of strings")))
  snapshot)
