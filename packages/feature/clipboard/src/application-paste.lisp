(in-package #:loom/feature/clipboard)

(defun %clipboard-terminal-modes (session)
  (declare (ignore session))
  (list :bracketed-paste))

(defun %clipboard-input-event (session event-type payload)
  (declare (ignore session))
  (if (and (eq event-type :paste) (stringp payload))
      (progn
        (%record-paste-undo-boundary)
        (invoke-command "core/insert-pasted-text" :paste payload)
        :handled)
      :pass))

(register-session-hook :terminal-modes
                       :feature/clipboard
                       (function %clipboard-terminal-modes))

(register-session-hook :input-event
                       :feature/clipboard
                       (function %clipboard-input-event))
