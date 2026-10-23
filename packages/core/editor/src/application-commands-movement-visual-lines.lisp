(in-package #:loom)

(defun %visual-line-segments (session buffer line width)
  (and *visual-row-layout-function*
       (funcall *visual-row-layout-function* session buffer line width)))

(defun %visual-line-move-context ()
  (let* ((session *editor-state*)
         (window (and session (%selected-window)))
         (buffer (and window (loom/core/window-tree:window-buffer window)))
         (width (and window (loom/core/window-tree:window-width window))))
    (when
        (and session
             window
             buffer
             width
             (plusp width)
             (not (buffer-truncate-lines-p session buffer)))
      (values session buffer window width))))

(defun %move-point-into-segment (buffer line segment goal)
  (let ((start (first segment))
        (widths (third segment)))
    (buffer-set-point buffer
                      line
                      (loop with target-column = start
                            for offset from 1 below (length widths)
                            while (<= (aref widths offset) goal)
                            do (setf target-column (+ start offset))
                            finally (return target-column)))))

(defun %visual-line-move-state (session buffer width)
  (let* ((line (buffer-point-line buffer))
         (text (buffer-line buffer line))
         (column (buffer-point-column buffer))
         (segments (%visual-line-segments session buffer line width)))
    (when segments
      (let* ((index
              (or
               (position-if
                (lambda (segment)
                  (and (<= (first segment) column) (< column (second segment))))
                segments)
               (max 0 (1- (length segments)))))
             (segment (nth index segments))
             (offset
              (max 0
                   (min (- column (first segment))
                        (1- (length (third segment))))))
             (goal (aref (third segment) offset)))
        (values line text segments index goal)))))

(defun %visual-line-move-next (session buffer
                                       width
                                       line
                                       text
                                       segments
                                       index
                                       goal)
  (if (< (1+ index) (length segments))
      (progn
        (%move-point-into-segment buffer line (nth (1+ index) segments) goal)
        t)
      (let ((next-line (1+ line)))
        (if (< next-line (buffer-line-count buffer))
            (let ((next-segments
                   (%visual-line-segments session buffer next-line width)))
              (when next-segments
                (%move-point-into-segment buffer
                                          next-line
                                          (first next-segments)
                                          goal)
                t))
            (progn
              (buffer-set-point buffer line (length text))
              t)))))

(defun %visual-line-move-previous (session buffer
                                           width
                                           line
                                           segments
                                           index
                                           goal)
  (if (plusp index)
      (progn
        (%move-point-into-segment buffer line (nth (1- index) segments) goal)
        t)
      (let ((previous-line (1- line)))
        (if (>= previous-line 0)
            (let ((previous-segments
                   (%visual-line-segments session buffer previous-line width)))
              (when previous-segments
                (%move-point-into-segment buffer
                                          previous-line
                                          (car (last previous-segments))
                                          goal)
                t))
            t))))

(defun %visual-line-move (direction)
  "Move one visual row and return NIL when its layout is unavailable."
  (multiple-value-bind (session buffer window width) (%visual-line-move-context)
    (declare (ignore window))
    (when session
      (multiple-value-bind (line text segments index goal)
          (%visual-line-move-state session buffer width)
        (when segments
          (ecase direction
            (:next
             (%visual-line-move-next session
                                     buffer
                                     width
                                     line
                                     text
                                     segments
                                     index
                                     goal))
            (:previous
             (%visual-line-move-previous session buffer width line segments index goal))))))))

(defun next-visual-line-once ()
  (or (%visual-line-move :next) (%next-line-once)))

(defun previous-visual-line-once ()
  (or (%visual-line-move :previous) (%previous-line-once)))

(defun register-visual-row-layout (owner function)
  (unless (functionp function)
    (error "Visual row layout must be a function"))
  (when
      (and *visual-row-layout-owner*
           (not (equal *visual-row-layout-owner* owner)))
    (error "Visual row layout is already registered by ~S"
           *visual-row-layout-owner*))
  (setf *visual-row-layout-owner* owner
        *visual-row-layout-function* function)
  function)

(defun buffer-truncate-lines-p (session buffer)
  (and *buffer-truncate-policy-function*
       (not (null (funcall *buffer-truncate-policy-function* session buffer)))))
