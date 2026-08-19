(in-package #:loom/feature/terminal)

(defparameter +terminal-special-codes+
  '(:enter :backspace :tab :backtab :escape
    :up :down :left :right :home :end :delete :insert :page-up :page-down)
  "Special key codes that have a direct terminal representation.")

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
        ((char= character #\Space) (code-char 0))
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
     (let* ((event-text (cl-tty-kit:key-event-text event))
            (text (if (and event-text (plusp (length event-text)))
                      event-text
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
     (cl-tty-kit:key-event-code event))
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
