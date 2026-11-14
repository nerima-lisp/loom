(in-package #:loom/feature/buffer-menu)

(defun buffer-menu-special-name-p (name)
  "Return true when NAME uses the *NAME* convention of internal buffers."
  (and (> (length name) 1)
       (char= (char name 0) #\*)
       (char= (char name (1- (length name))) #\*)))

(defun buffer-menu-abbreviate-path (path home)
  "Return PATH with a leading HOME directory replaced by ~, or \"\" for NIL."
  (cond
    ((null path) "")
    ((or (null home) (zerop (length home))) path)
    (t
     (let ((prefix (if (char= (char home (1- (length home))) #\/)
                       home
                       (concatenate 'string home "/"))))
       (cond
         ((string= path (subseq prefix 0 (1- (length prefix)))) "~")
         ((and (> (length path) (length prefix))
               (string= prefix path :end2 (length prefix)))
          (concatenate 'string "~/" (subseq path (length prefix))))
         (t path))))))

(defun buffer-menu-mark-char (mark)
  "Return the column-0 character for MARK: :DELETE, :SAVE, or NIL."
  (ecase mark
    (:delete #\D)
    (:save #\S)
    ((nil) #\Space)))

(defun %buffer-menu-pad (text width)
  (format nil "~vA" width text))

(defun buffer-menu-format-lines (rows)
  "Return ROWS as newline-separated lines, one per row and no header.

Each row is a list (MARK CURRENT-P READ-ONLY-P MODIFIED-P NAME SIZE MODE PATH).
Column 0 holds the mark, columns 2-4 the current, read-only, and modified
flags, then the name, the right-aligned size, the mode, and PATH. Column
widths come from the widest value in ROWS; trailing spaces are dropped."
  (let ((name-width 0)
        (size-width 0)
        (mode-width 0))
    (dolist (row rows)
      (destructuring-bind (mark current-p read-only-p modified-p name size mode path)
          row
        (declare (ignore mark current-p read-only-p modified-p path))
        (setf name-width (max name-width (length name))
              size-width (max size-width (length (princ-to-string size)))
              mode-width (max mode-width (length mode)))))
    (format nil "~{~A~^~%~}"
            (mapcar
             (lambda (row)
               (destructuring-bind (mark current-p read-only-p modified-p name size mode path)
                   row
                 (string-right-trim
                  " "
                  (format nil "~C ~C~C~C ~A ~vD ~A ~A"
                          (buffer-menu-mark-char mark)
                          (if current-p #\. #\Space)
                          (if read-only-p #\% #\Space)
                          (if modified-p #\* #\Space)
                          (%buffer-menu-pad name name-width)
                          size-width size
                          (%buffer-menu-pad mode mode-width)
                          path))))
             rows))))
