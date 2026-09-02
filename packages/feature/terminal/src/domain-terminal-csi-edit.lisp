(in-package #:loom/feature/terminal)

(defun %terminal-screen-csi-edit-mode-handler (final)
  (cdr (assoc final
              '((#\J . %terminal-screen-clear-display)
                (#\K . %terminal-screen-clear-line)))))

(defun %terminal-screen-csi-edit-count-handler (final)
  (cdr (assoc final
              '((#\P . %terminal-screen-delete-characters)
                (#\@ . %terminal-screen-insert-characters)
                (#\X . %terminal-screen-erase-characters)
                (#\L . %terminal-screen-insert-lines)
                (#\M . %terminal-screen-delete-lines)
                (#\S . %terminal-screen-scroll-up)
                (#\T . %terminal-screen-scroll-down)))))

(defun %terminal-screen-csi-edit-cursor-handler (final)
  (cdr (assoc final
              '((#\s . %terminal-screen-save-cursor)
                (#\u . %terminal-screen-restore-cursor)))))

(defun %terminal-screen-csi-edit (screen final parameters)
  (cond
    ((%terminal-screen-csi-edit-mode-handler final)
     (funcall (%terminal-screen-csi-edit-mode-handler final)
              screen
              (first parameters)))
    ((%terminal-screen-csi-edit-count-handler final)
     (funcall (%terminal-screen-csi-edit-count-handler final)
              screen
              (%terminal-screen-parameter parameters 0 1)))
    ((%terminal-screen-csi-edit-cursor-handler final)
     (funcall (%terminal-screen-csi-edit-cursor-handler final) screen))))
