(in-package #:loom/feature/buffer-menu)

(defun %buffer-menu-message (text)
  (minibuffer-message (editor-state-minibuffer *editor-state*) text))

(defun %call-with-buffer-menu (function)
  "Call FUNCTION with the selected window's list buffer, its state, and the
buffer on the line at point (NIL past the last entry)."
  (let* ((tree (editor-state-window-tree *editor-state*))
         (list-buffer (window-buffer (window-tree-selected-window tree)))
         (state (gethash list-buffer *buffer-menu-states*)))
    (if state
        (let ((entries (buffer-menu-state-entries state))
              (line (buffer-point-line list-buffer)))
          (funcall function list-buffer state
                   (and (< line (length entries)) (aref entries line))))
        (%buffer-menu-message "Not in a buffer list"))))

(defmacro %with-buffer-menu ((list-buffer state entry) &body body)
  `(%call-with-buffer-menu
    (lambda (,list-buffer ,state ,entry)
      (declare (ignorable ,list-buffer ,state ,entry))
      ,@body)))

(defun %move-buffer-menu-line (list-buffer state delta)
  (let ((last (1- (length (buffer-menu-state-entries state)))))
    (buffer-set-point list-buffer
                      (max 0 (min last (+ (buffer-point-line list-buffer) delta)))
                      0)))

(defun buffer-menu-next-line ()
  "Move to the next line of the buffer list."
  (%with-buffer-menu (list-buffer state entry)
    (%move-buffer-menu-line list-buffer state 1)))

(defun buffer-menu-previous-line ()
  "Move to the previous line of the buffer list."
  (%with-buffer-menu (list-buffer state entry)
    (%move-buffer-menu-line list-buffer state -1)))

(defun %set-buffer-menu-mark (list-buffer state mark)
  "Give the line at point MARK, replacing its mark, then move down a line."
  (let* ((line (buffer-point-line list-buffer))
         (entries (buffer-menu-state-entries state))
         (marks (buffer-menu-state-marks state)))
    (when (< line (length entries))
      (if mark
          (setf (gethash (aref entries line) marks) mark)
          (remhash (aref entries line) marks))
      (buffer-set-read-only list-buffer nil)
      (unwind-protect
           (progn
             (buffer-delete-region list-buffer line 0 line 1)
             (buffer-set-point list-buffer line 0)
             (buffer-insert-string list-buffer
                                   (string (buffer-menu-mark-char mark)))
             (buffer-mark-saved list-buffer))
        (buffer-set-read-only list-buffer t))
      (buffer-set-point list-buffer line 0)
      (%move-buffer-menu-line list-buffer state 1))))

(defun buffer-menu-delete ()
  "Mark the buffer on this line for killing by x."
  (%with-buffer-menu (list-buffer state entry)
    (%set-buffer-menu-mark list-buffer state :delete)))

(defun buffer-menu-save ()
  "Mark the buffer on this line for saving by x."
  (%with-buffer-menu (list-buffer state entry)
    (%set-buffer-menu-mark list-buffer state :save)))

(defun buffer-menu-unmark ()
  "Remove the mark from this line."
  (%with-buffer-menu (list-buffer state entry)
    (%set-buffer-menu-mark list-buffer state nil)))

(defun %show-buffer-in-window (window buffer)
  "Display BUFFER in WINDOW after the registered buffer-switch guard agrees."
  (let ((continued nil))
    (run-buffer-switch-guard
     buffer
     (lambda ()
       (unless continued
         (setf continued t)
         (window-set-buffer window buffer))))))

(defun %live-entry-or-report (entry)
  (cond
    ((null entry) (%buffer-menu-message "No buffer on this line") nil)
    ((%buffer-menu-live-p entry) entry)
    (t (%buffer-menu-message "Buffer has been killed") nil)))

(defun buffer-menu-this-window ()
  "Show the buffer on this line in the selected window."
  (%with-buffer-menu (list-buffer state entry)
    (let ((target (%live-entry-or-report entry)))
      (when target
        (%show-buffer-in-window
         (window-tree-selected-window (editor-state-window-tree *editor-state*))
         target)))))

(defun buffer-menu-other-window ()
  "Show the buffer on this line in another window and select that window."
  (%with-buffer-menu (list-buffer state entry)
    (let ((target (%live-entry-or-report entry)))
      (when target
        (let* ((tree (editor-state-window-tree *editor-state*))
               (list-window (window-tree-selected-window tree))
               (other (if (rest (window-tree-windows tree))
                          (%window-after (window-tree-windows tree) list-window)
                          (prog1 (window-split tree list-window :horizontal)
                            (%select-window tree list-window))))
               (continued nil))
          (run-buffer-switch-guard
           target
           (lambda ()
             (unless continued
               (setf continued t)
               (window-set-buffer other target)
               (%select-window tree other)))))))))

(defun buffer-menu-revert ()
  "Rebuild the buffer list, keeping marks and the buffer at point."
  (%with-buffer-menu (list-buffer state entry)
    (%refresh-buffer-menu list-buffer state)))

(defun %marked-buffers (state mark list-buffer)
  (loop for buffer across (buffer-menu-state-entries state)
        when (and (eq (gethash buffer (buffer-menu-state-marks state)) mark)
                  (not (eq buffer list-buffer)))
          collect buffer))

(defun buffer-menu-execute ()
  "Save the S lines, then kill the D lines, from top to bottom.

A save answered n keeps its mark and continues. A cancelled save or kill
(c, C-g, or an error) stops; the remaining marks stay. The list is rebuilt
afterwards without replacing the last message."
  (%with-buffer-menu (list-buffer state entry)
    (let ((marks (buffer-menu-state-marks state))
          (deletes (%marked-buffers state :delete list-buffer)))
      (labels ((finish ()
                 (%refresh-buffer-menu list-buffer state))
               (kill-next (remaining)
                 (let ((buffer (first remaining)))
                   (cond
                     ((null remaining) (finish))
                     ((not (%buffer-menu-live-p buffer))
                      (kill-next (rest remaining)))
                     (t
                      (kill-buffer-with-confirmation
                       buffer
                       :on-killed (lambda ()
                                    (remhash buffer marks)
                                    (kill-next (rest remaining)))
                       :on-cancelled #'finish)))))
               (save-next (remaining)
                 (let ((buffer (first remaining)))
                   (cond
                     ((null remaining) (kill-next deletes))
                     ((not (%buffer-menu-live-p buffer))
                      (save-next (rest remaining)))
                     (t
                      (confirm-save-buffer
                       buffer
                       :on-saved (lambda ()
                                   (remhash buffer marks)
                                   (save-next (rest remaining)))
                       :on-skipped (lambda () (save-next (rest remaining)))
                       :on-cancelled #'finish))))))
        (save-next (%marked-buffers state :save list-buffer))))))

(defun %fallback-buffer (list-buffer)
  (find-if (lambda (buffer)
             (and (not (eq buffer list-buffer))
                  (not (buffer-menu-special-name-p (buffer-name buffer)))))
           (reverse (registered-buffers *editor-session*))))

(defun buffer-menu-quit ()
  "Close the window list-buffers created, or restore the buffer it replaced."
  (%with-buffer-menu (list-buffer state entry)
    (let* ((tree (editor-state-window-tree *editor-state*))
           (windows (window-tree-windows tree))
           (window (buffer-menu-state-list-window state))
           (origin (buffer-menu-state-origin-window state)))
      (if (and (buffer-menu-state-created-p state)
               (member window windows :test #'eq)
               (rest windows))
          (progn
            (window-delete tree window)
            (when (member origin (window-tree-windows tree) :test #'eq)
              (%select-window tree origin)))
          (let ((target
                  (find-if #'%buffer-menu-live-p
                           (list (if (buffer-menu-state-created-p state)
                                     (buffer-menu-state-origin-buffer state)
                                     (buffer-menu-state-previous-buffer state))
                                 (%fallback-buffer list-buffer)))))
            (when target
              (%show-buffer-in-window (window-tree-selected-window tree)
                                      target)))))))
