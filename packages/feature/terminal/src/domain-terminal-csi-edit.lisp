(in-package #:loom/feature/terminal)

(defun %terminal-screen-csi-edit (screen final parameters)
  (let ((first (%terminal-screen-parameter parameters 0 1)))
    (case final
      (#\J
       (%terminal-screen-clear-display screen
                                       (first parameters)))
      (#\K
       (%terminal-screen-clear-line screen
                                    (first parameters)))
      (#\m nil)
      (#\P
       (%terminal-screen-delete-characters screen first))
      (#\@
       (%terminal-screen-insert-characters screen first))
      (#\X
       (%terminal-screen-erase-characters screen first))
      (#\L
       (%terminal-screen-insert-lines screen first))
      (#\M
       (%terminal-screen-delete-lines screen first))
      (#\S
       (%terminal-screen-scroll-up screen first))
      (#\T
       (%terminal-screen-scroll-down screen first))
      (#\s
       (%terminal-screen-save-cursor screen))
      (#\u
       (%terminal-screen-restore-cursor screen))
      (#\r nil))))
