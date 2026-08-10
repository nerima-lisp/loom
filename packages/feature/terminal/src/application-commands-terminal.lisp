(in-package #:loom/feature/terminal)

(defparameter +terminal-special-codes+
  '(:enter :backspace :tab :backtab :escape
    :up :down :left :right :home :end :delete :insert :page-up :page-down)
  "Special key codes that have a direct terminal representation.")

(defun %terminal-session-for-selected-buffer ()
  (terminal-session-for-buffer (%selected-buffer)))

(defun %terminal-event-kind-acceptable-p (event)
  (let ((kind (cl-tty-kit:key-event-kind event)))
    (or (null kind) (member kind '(:press :repeat) :test #'eq))))

(defun %terminal-control-special-p (code)
  (and (keywordp code)
       (let ((name (symbol-name code)))
         (or (string= name "CONTROL-SPACE")
             (and (> (length name) 8)
                  (string= "CONTROL-" name :end2 8))))))

(defun terminal-input-event-p (event)
  "Whether EVENT should be sent to the selected terminal session."
  (let ((session (%terminal-session-for-selected-buffer)))
    (and session
         (terminal-session-alive-p session)
         (%terminal-event-kind-acceptable-p event)
         (case (cl-tty-kit:key-event-type event)
           (:character t)
           (:paste t)
           (:special
            (or (member (cl-tty-kit:key-event-code event)
                        +terminal-special-codes+
                        :test #'eq)
                (%terminal-control-special-p
                 (cl-tty-kit:key-event-code event))))
           (otherwise nil)))))

(defun %terminal-csi (suffix)
  (format nil "~C[~A" (code-char 27) suffix))

(defun %terminal-special-payload (code)
  (case code
    (:enter (string (code-char 13)))
    (:backspace (string (code-char 127)))
    (:tab (string (code-char 9)))
    (:backtab (%terminal-csi "Z"))
    (:escape (string (code-char 27)))
    (:up (%terminal-csi "A"))
    (:down (%terminal-csi "B"))
    (:right (%terminal-csi "C"))
    (:left (%terminal-csi "D"))
    (:home (%terminal-csi "H"))
    (:end (%terminal-csi "F"))
    (:delete (%terminal-csi "3~"))
    (:insert (%terminal-csi "2~"))
    (:page-up (%terminal-csi "5~"))
    (:page-down (%terminal-csi "6~"))))

(defun %terminal-control-character (character)
  (when character
    (let ((downcase (char-downcase character)))
      (cond
        ((and (char>= downcase #\a) (char<= downcase #\z))
         (code-char (1+ (- (char-code downcase) (char-code #\a)))))
        ((char= character #\@) (code-char 0))
        ((char= character #\[) (code-char 27))
        ((char= character #\\) (code-char 28))
        ((char= character #\]) (code-char 29))
        ((char= character #\^) (code-char 30))
        ((char= character #\_) (code-char 31))))))

(defun %terminal-control-special-payload (code)
  (when (%terminal-control-special-p code)
    (let* ((name (symbol-name code))
           (character
             (if (string= name "CONTROL-SPACE")
                 #\Space
                 (char name 8)))
           (control (%terminal-control-character character)))
      (and control (string control)))))

(defun %terminal-event-payload (event)
  (case (cl-tty-kit:key-event-type event)
    (:character
     (let* ((text (or (cl-tty-kit:key-event-text event)
                      (string (cl-tty-kit:key-event-code event))))
            (modifiers (cl-tty-kit:key-event-modifiers event))
            (control (member :control modifiers :test #'eq))
            (alt (member :alt modifiers :test #'eq)))
       (when (and text (plusp (length text)))
         (let ((payload
                 (if control
                     (let ((control-character
                             (%terminal-control-character (char text 0))))
                       (and control-character (string control-character)))
                     text)))
           (and payload
                (if alt
                    (concatenate 'string (string (code-char 27)) payload)
                    payload))))))
    (:paste
     (let ((code (cl-tty-kit:key-event-code event)))
       (if (stringp code) code (princ-to-string code))))
    (:special
     (let ((payload (or (%terminal-special-payload
                         (cl-tty-kit:key-event-code event))
                        (%terminal-control-special-payload
                         (cl-tty-kit:key-event-code event)))))
       (and payload
            (if (member :alt (cl-tty-kit:key-event-modifiers event)
                        :test #'eq)
                (concatenate 'string (string (code-char 27)) payload)
                payload))))))

(defun terminal-handle-key-event (event)
  "Send EVENT to the selected terminal session."
  (let ((session (%terminal-session-for-selected-buffer)))
    (when (and session
               (terminal-input-event-p event))
      (let ((payload (%terminal-event-payload event)))
        (when payload
          (terminal-session-send session payload)
          t)))))

(defun terminal ()
  "Create and select a PTY-backed terminal buffer."
  (handler-case
      (let ((session (start-terminal-session)))
        (push session (editor-state-terminal-sessions *editor-state*))
        (%register-buffer (terminal-session-buffer session))
        (window-set-buffer (%selected-window) (terminal-session-buffer session))
        (multiple-value-bind (columns rows) (cl-tty-kit:terminal-size)
          (terminal-session-resize session columns rows))
        (terminal-session-poll session)
        (minibuffer-message
         (editor-state-minibuffer *editor-state*)
         (if (terminal-session-alive-p session)
             "Terminal started"
             "Terminal exited immediately"))
        session)
    (error (condition)
      (minibuffer-message
       (editor-state-minibuffer *editor-state*)
       (format nil "Terminal failed: ~A" condition))
      nil)))

(defun terminal-stop ()
  "Stop the terminal session shown by the selected buffer."
  (let ((session (%terminal-session-for-selected-buffer)))
    (if session
        (progn
          (stop-terminal-session session)
          (minibuffer-message
           (editor-state-minibuffer *editor-state*)
           "Terminal stopped")
          session)
        (minibuffer-message
         (editor-state-minibuffer *editor-state*)
         "The selected buffer is not a terminal"))))
