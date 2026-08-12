(in-package #:loom/feature/terminal)

;;;; Screen write-path operations: cursor clamping, scrolling, line
;;;; transitions, and character insertion. Screen-state control such as
;;;; clearing and alternate-screen management lives in
;;;; domain-terminal-screen-state.lisp.

(defun %terminal-screen-clamp-cursor (screen)
  (setf (terminal-screen-cursor-row screen)
        (%terminal-clamp (terminal-screen-cursor-row screen)
                         0
                         (1- (terminal-screen-height screen)))
        (terminal-screen-cursor-column screen)
        (%terminal-clamp (terminal-screen-cursor-column screen)
                         0
                         (1- (terminal-screen-width screen)))))

(defun %terminal-screen-scroll-up (screen &optional (count 1))
  (let* ((height (terminal-screen-height screen))
         (width (terminal-screen-width screen))
         (count (%terminal-clamp count 0 height))
         (rows (terminal-screen-rows screen)))
    (when (plusp count)
      (loop for row below (- height count)
            do (replace (aref rows row)
                        (aref rows (+ row count))))
      (loop for row from (- height count) below height
            do (setf (aref rows row) (%terminal-blank-row width)))))
  screen)

(defun %terminal-screen-scroll-down (screen &optional (count 1))
  (let* ((height (terminal-screen-height screen))
         (width (terminal-screen-width screen))
         (count (%terminal-clamp count 0 height))
         (rows (terminal-screen-rows screen)))
    (when (plusp count)
      (loop for row from (1- height) downto count
            do (replace (aref rows row)
                        (aref rows (- row count))))
      (loop for row below count
            do (setf (aref rows row) (%terminal-blank-row width)))))
  screen)

(defun %terminal-screen-line-feed (screen)
  (if (= (terminal-screen-cursor-row screen)
         (1- (terminal-screen-height screen)))
      (%terminal-screen-scroll-up screen)
      (incf (terminal-screen-cursor-row screen)))
  (setf (terminal-screen-wrap-pending screen) nil)
  screen)

(defun %terminal-screen-carriage-return (screen)
  (setf (terminal-screen-cursor-column screen) 0
        (terminal-screen-wrap-pending screen) nil)
  screen)

(defun %terminal-screen-next-line (screen)
  (%terminal-screen-carriage-return screen)
  (%terminal-screen-line-feed screen))

(defun %terminal-screen-prepare-write (screen)
  (when (terminal-screen-wrap-pending screen)
    (%terminal-screen-next-line screen))
  screen)

(defun %terminal-screen-write-character (screen character)
  (%terminal-screen-prepare-write screen)
  (setf (char (aref (terminal-screen-rows screen)
                    (terminal-screen-cursor-row screen))
              (terminal-screen-cursor-column screen))
        character)
  (if (= (terminal-screen-cursor-column screen)
         (1- (terminal-screen-width screen)))
      (setf (terminal-screen-wrap-pending screen) t)
      (incf (terminal-screen-cursor-column screen)))
  screen)
