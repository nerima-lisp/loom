(in-package #:loom/feature/terminal)

;;;; Screen-state operations shared by parser and CSI handlers:
;;;; clearing regions, saving/restoring the cursor, and alternate-screen
;;;; transitions.

(defun %terminal-screen-clear-row (screen row start end)
  (let ((line (aref (terminal-screen-rows screen) row)))
    (loop for column from start below end
          do (setf (char line column) #\Space)))
  screen)

(defun %terminal-screen-clear-all (screen)
  (loop for row below (terminal-screen-height screen)
        do (%terminal-screen-clear-row
            screen row 0 (terminal-screen-width screen)))
  (setf (terminal-screen-cursor-row screen) 0
        (terminal-screen-cursor-column screen) 0
        (terminal-screen-wrap-pending screen) nil)
  screen)

(defun %terminal-screen-clear-display (screen mode)
  (let* ((row (terminal-screen-cursor-row screen))
         (column (terminal-screen-cursor-column screen))
         (height (terminal-screen-height screen))
         (width (terminal-screen-width screen)))
    (case mode
      ((0 nil)
       (%terminal-screen-clear-row screen row column width)
       (loop for current from (1+ row) below height
             do (%terminal-screen-clear-row screen current 0 width)))
      (1
       (loop for current below row
             do (%terminal-screen-clear-row screen current 0 width))
       (%terminal-screen-clear-row screen row 0 (1+ column)))
      ((2 3)
       (%terminal-screen-clear-all screen))))
  (setf (terminal-screen-wrap-pending screen) nil)
  screen)

(defun %terminal-screen-clear-line (screen mode)
  (let ((column (terminal-screen-cursor-column screen))
        (width (terminal-screen-width screen)))
    (case mode
      ((0 nil) (%terminal-screen-clear-row screen
                                           (terminal-screen-cursor-row screen)
                                           column
                                           width))
      (1 (%terminal-screen-clear-row screen
                                     (terminal-screen-cursor-row screen)
                                     0
                                     (1+ column)))
      ((2 3) (%terminal-screen-clear-row screen
                                         (terminal-screen-cursor-row screen)
                                         0
                                         width))))
  (setf (terminal-screen-wrap-pending screen) nil)
  screen)

(defun %terminal-screen-save-cursor (screen)
  (setf (terminal-screen-saved-row screen) (terminal-screen-cursor-row screen)
        (terminal-screen-saved-column screen)
        (terminal-screen-cursor-column screen))
  screen)

(defun %terminal-screen-restore-cursor (screen)
  (setf (terminal-screen-cursor-row screen) (terminal-screen-saved-row screen)
        (terminal-screen-cursor-column screen)
        (terminal-screen-saved-column screen)
        (terminal-screen-wrap-pending screen) nil)
  (%terminal-screen-clamp-cursor screen)
  screen)

(defun %terminal-screen-enter-alternate (screen)
  (unless (terminal-screen-alternate-p screen)
    (setf (terminal-screen-main-rows screen)
          (%terminal-copy-rows (terminal-screen-rows screen)
                               (terminal-screen-width screen)
                               (terminal-screen-height screen))
          (terminal-screen-main-cursor-row screen)
          (terminal-screen-cursor-row screen)
          (terminal-screen-main-cursor-column screen)
          (terminal-screen-cursor-column screen)
          (terminal-screen-rows screen)
          (%terminal-blank-rows (terminal-screen-width screen)
                                (terminal-screen-height screen))
          (terminal-screen-cursor-row screen) 0
          (terminal-screen-cursor-column screen) 0
          (terminal-screen-wrap-pending screen) nil
          (terminal-screen-alternate-p screen) t))
  screen)

(defun %terminal-screen-leave-alternate (screen)
  (when (terminal-screen-alternate-p screen)
    (setf (terminal-screen-rows screen)
          (or (terminal-screen-main-rows screen)
              (%terminal-blank-rows (terminal-screen-width screen)
                                    (terminal-screen-height screen)))
          (terminal-screen-cursor-row screen)
          (terminal-screen-main-cursor-row screen)
          (terminal-screen-cursor-column screen)
          (terminal-screen-main-cursor-column screen)
          (terminal-screen-main-rows screen) nil
          (terminal-screen-alternate-p screen) nil
          (terminal-screen-wrap-pending screen) nil)
    (%terminal-screen-clamp-cursor screen))
  screen)
