;;;; packages/feature/multiple-cursors/src/application-multiple-cursor-support.lisp
;;;;
;;;; Shared application-layer helpers for multiple-cursor commands and edit
;;;; protocol operations.
(in-package #:loom/feature/multiple-cursors)

(defun %multiple-cursor-set-for-buffer (buffer)
  (let ((set (and *editor-state*
                  (editor-state-multiple-cursors *editor-state*))))
    (and set
         (eq buffer (multiple-cursor-set-buffer set))
         set)))

(defun multiple-cursors-active-p (&optional buffer)
  "Return true when a multiple-cursor set exists, optionally for BUFFER."
  (let ((set (and *editor-state*
                  (editor-state-multiple-cursors *editor-state*))))
    (not (null
          (and set
               (or (null buffer)
                   (eq buffer (multiple-cursor-set-buffer set))))))))

(defun multiple-cursors-reset ()
  "Clear the transient multiple-cursor set and return NIL."
  (when *editor-state*
    (setf (editor-state-multiple-cursors *editor-state*) nil))
  nil)

(defun multiple-cursor-offsets-for-buffer (buffer)
  "Return the non-primary cursor offsets belonging to BUFFER."
  (let ((set (%multiple-cursor-set-for-buffer buffer)))
    (if set
        (remove (multiple-cursor-set-primary-offset set)
                (multiple-cursor-set-offsets set)
                :test #'=)
        nil)))

(defun multiple-cursors-preserving-command-p (command)
  "Return true when COMMAND is allowed to keep the cursor set active."
  (not (null
        (member command
                '(multiple-cursors-add-next-line
                  multiple-cursors-edit-lines
                  multiple-cursors-clear
                  delete-char
                  delete-backward-char
                  yank
                  yank-pop)
                :test #'eq))))

(defun %line-column-offset (buffer line column)
  (loop with offset = 0
        for preceding-line below line
        do (incf offset
                 (1+ (length (buffer-line buffer preceding-line))))
        finally (return (+ offset column))))

(defun %line-column-offset-at-column (buffer line column)
  (let ((line-length (length (buffer-line buffer line))))
    (%line-column-offset buffer line (min column line-length))))

(defun %clamp-offset-to-visible-region (buffer offset)
  (max (buffer-narrow-start-offset buffer)
       (min offset (buffer-narrow-end-offset buffer))))

(defun %multiple-cursor-message (text)
  (when (and *editor-state* (editor-state-minibuffer *editor-state*))
    (minibuffer-message (editor-state-minibuffer *editor-state*) text)))

(defun %set-multiple-cursors (buffer offsets primary-offset)
  (setf (editor-state-multiple-cursors *editor-state*)
        (make-multiple-cursor-set buffer offsets
                                  :primary-offset primary-offset)))

(defun %cursor-set-last-line-and-column (buffer set)
  (let* ((last-offset (car (last (multiple-cursor-set-offsets set))))
         (position (buffer-offset-position buffer last-offset)))
    (values (buffer-position-line position)
            (buffer-position-column position))))
