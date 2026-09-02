(in-package #:loom/feature/terminal)

(defparameter +terminal-special-codes+
  '(:enter :backspace :tab :backtab :escape
    :up :down :left :right :home :end :delete :insert :page-up :page-down)
  "Special key codes that have a direct terminal representation.")

(defparameter +terminal-special-payload-suffixes+
  '((:backtab . "Z")
    (:up . "A") (:down . "B") (:right . "C") (:left . "D")
    (:home . "H") (:end . "F") (:delete . "3~") (:insert . "2~")
    (:page-up . "5~") (:page-down . "6~"))
  "CSI suffixes for special keys whose payload is an escape sequence.")

(defun %terminal-csi (suffix)
  (format nil "~C[~A" (code-char 27) suffix))

(defun %terminal-special-payload (code)
  (case code
    (:enter (string (code-char 13)))
    (:backspace (string (code-char 127)))
    (:tab (string (code-char 9)))
    (:escape (string (code-char 27)))
    (otherwise
     (let ((suffix (cdr (assoc code +terminal-special-payload-suffixes+))))
       (and suffix (%terminal-csi suffix))))))

(defun %terminal-control-letter (character)
  (when (and (char>= character #\a) (char<= character #\z))
    (code-char (1+ (- (char-code character) (char-code #\a))))))

(defun %terminal-control-punctuation (character)
  (case character
    ((#\Space #\@) (code-char 0))
    (#\[ (code-char 27))
    (#\\ (code-char 28))
    (#\] (code-char 29))
    (#\^ (code-char 30))
    (#\_ (code-char 31))))

(defun %terminal-control-character (character)
  (when character
    (let ((downcase (char-downcase character)))
      (or (%terminal-control-letter downcase)
          (%terminal-control-punctuation character)))))

(defun %terminal-control-special-payload (code)
  (when (%terminal-control-special-p code)
    (let* ((name (symbol-name code))
           (character
             (if (string= name "CONTROL-SPACE")
                 #\Space
                 (char name 8)))
           (control (%terminal-control-character character)))
      (and control (string control)))))

(defun %terminal-alt-prefix (payload modifiers)
  (and payload
       (if (member :alt modifiers :test #'eq)
           (concatenate 'string (string (code-char 27)) payload)
           payload)))

(defun %terminal-event-text (event)
  (let ((text (cl-tty-kit:key-event-text event)))
    (if (and text (string/= text ""))
        text
        (string (cl-tty-kit:key-event-code event)))))

(defun %terminal-character-payload-for-text (text modifiers)
  (when (string/= text "")
    (let ((payload
            (if (member :control modifiers :test #'eq)
                (let ((control-character
                        (%terminal-control-character (char text 0))))
                  (and control-character (string control-character)))
                text)))
      (%terminal-alt-prefix payload modifiers))))

(defun %terminal-character-payload (event)
  (%terminal-character-payload-for-text
   (%terminal-event-text event)
   (cl-tty-kit:key-event-modifiers event)))

(defun %terminal-special-event-payload (event)
  (let ((payload (or (%terminal-special-payload
                      (cl-tty-kit:key-event-code event))
                     (%terminal-control-special-payload
                      (cl-tty-kit:key-event-code event)))))
    (%terminal-alt-prefix payload (cl-tty-kit:key-event-modifiers event))))

(defun %terminal-event-payload (event)
  (case (cl-tty-kit:key-event-type event)
    (:character (%terminal-character-payload event))
    (:paste
     (cl-tty-kit:key-event-code event))
    (:special (%terminal-special-event-payload event))))
