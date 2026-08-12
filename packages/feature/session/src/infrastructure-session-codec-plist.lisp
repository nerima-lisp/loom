;;;; packages/feature/session/src/infrastructure-session-codec-plist.lisp
;;;;
;;;; Fixed-shape plist helpers for session snapshot serialization.
(in-package #:loom/feature/session)

(defparameter *loom-session-version* 5)

(defun %session-plist-value (plist key)
  (loop for tail on plist by #'cddr
        when (eq (first tail) key)
          return (second tail)))

(defun %validate-session-plist (value expected-keys context)
  (unless (and (listp value)
               (evenp (length value))
               (loop for tail on value by #'cddr
                     always (keywordp (first tail))))
    (error "~A: expected a keyword plist, got ~S" context value))
  (let ((keys (loop for tail on value by #'cddr collect (first tail))))
    (unless (and (= (length keys) (length expected-keys))
                 (every (lambda (key) (member key expected-keys :test #'eq)) keys)
                 (every (lambda (key) (member key keys :test #'eq)) expected-keys))
      (error "~A: unexpected or duplicate fields in ~S" context value)))
  value)

(defparameter *loom-session-top-level-keys*
  '(:loom-session :buffers :recent-files :bookmarks :command-history
    :workspaces :current-workspace-index))

(defmacro define-session-plist-codec (name constructor &body fields)
  "Define a fixed-shape plist serializer and reader for a session value.

FIELDS is a sequence of (:KEY ACCESSOR) declarations. Keeping the shape in
one macro invocation makes the serialized data contract visible and prevents
the writer and reader from drifting apart as fields are added."
  (unless (and (symbolp name)
               (symbolp constructor)
               (every (lambda (field)
                        (and (listp field)
                             (= (length field) 2)
                             (keywordp (first field))
                             (symbolp (second field))))
                      fields))
    (error "Invalid session plist codec declaration: ~S ~S ~S"
           name constructor fields))
  (let* ((stem (string-upcase (symbol-name name)))
         (keys (intern (format nil "*LOOM-SESSION-~A-KEYS*" stem)
                       *package*))
         (serializer (intern (format nil "%SESSION-SEXP-~A" stem)
                             *package*))
         (reader (intern (format nil "%SESSION-~A-FROM-SEXP" stem)
                         *package*))
         (key-list (mapcar #'first fields)))
    `(progn
       (defparameter ,keys ',key-list)
       (defun ,serializer (object)
         (list
          ,@(mapcan (lambda (field)
                      (list (first field)
                            `(,(second field) object)))
                    fields)))
       (defun ,reader (value)
         (%validate-session-plist value ,keys
                                  ,(format nil "session ~A" name))
         (,constructor
          ,@(mapcan (lambda (field)
                      (list (first field)
                            `(%session-plist-value value ,(first field))))
                    fields))))))

(define-session-plist-codec buffer make-session-buffer-snapshot
  (:name session-buffer-snapshot-name)
  (:path session-buffer-snapshot-path)
  (:text session-buffer-snapshot-text)
  (:point-line session-buffer-snapshot-point-line)
  (:point-column session-buffer-snapshot-point-column)
  (:mark-line session-buffer-snapshot-mark-line)
  (:mark-column session-buffer-snapshot-mark-column)
  (:modified-p session-buffer-snapshot-modified-p))

(define-session-plist-codec bookmark make-session-bookmark-snapshot
  (:name session-bookmark-snapshot-name)
  (:path session-bookmark-snapshot-path)
  (:buffer-name session-bookmark-snapshot-buffer-name)
  (:line session-bookmark-snapshot-line)
  (:column session-bookmark-snapshot-column))

(define-session-plist-codec workspace make-session-workspace-snapshot
  (:name session-workspace-snapshot-name)
  (:layout session-workspace-snapshot-layout)
  (:selected-window-index session-workspace-snapshot-selected-window-index))
