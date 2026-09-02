;;;; src/application/commands-bookmark.lisp
;;;;
;;;; Application layer: bookmark commands.
(in-package #:loom)

(define-bookmark-command set-bookmark
    ("Set bookmark: ") (bookmark-name minibuffer)
  (let ((buffer (%selected-buffer)))
    (if (string= bookmark-name "")
        (minibuffer-message minibuffer "Bookmark name cannot be empty")
        (progn
          (setf (gethash bookmark-name (%bookmark-table))
                (make-editor-bookmark
                 :name bookmark-name
                 :buffer buffer
                 :path (editor-path-string (buffer-path buffer))
                 :buffer-name (buffer-name buffer)
                 :line (buffer-point-line buffer)
                 :column (buffer-point-column buffer)))
          (minibuffer-message
           minibuffer
           (format nil "Bookmark set: ~A" bookmark-name))))))

(define-bookmark-command jump-to-bookmark
    ("Jump to bookmark: " :completion-function #'%bookmark-candidates)
    (bookmark-name minibuffer)
  (let* ((bookmark (gethash bookmark-name (%bookmark-table)))
         (buffer (and bookmark (%bookmark-target-buffer bookmark))))
    (cond
      ((null bookmark)
       (minibuffer-message
        minibuffer
        (format nil "Unknown bookmark: ~A" bookmark-name)))
      ((null buffer)
       (minibuffer-message
        minibuffer
        (format nil "Bookmark target is unavailable: ~A" bookmark-name)))
      (t
       (loom/feature/window:window-set-buffer (%selected-window) buffer)
       (buffer-set-point buffer
                         (editor-bookmark-line bookmark)
                         (editor-bookmark-column bookmark))))))

(define-bookmark-command delete-bookmark
    ("Delete bookmark: " :completion-function #'%bookmark-candidates)
    (bookmark-name minibuffer)
  (if (remhash bookmark-name (%bookmark-table))
      (minibuffer-message minibuffer
                          (format nil "Deleted bookmark: ~A" bookmark-name))
      (minibuffer-message minibuffer
                          (format nil "Unknown bookmark: ~A" bookmark-name))))

(defun list-bookmarks ()
  "Display the names of all bookmarks in the current session."
  (let ((names (%bookmark-candidates "")))
    (minibuffer-message
     (editor-state-minibuffer *editor-state*)
     (if names
         (format nil "Bookmarks: ~{~A~^, ~}" names)
         "No bookmarks"))))
