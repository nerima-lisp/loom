(in-package #:loom/feature/terminal)

(defun %terminal-screen-start-csi (screen)
  (setf (terminal-screen-parser-state screen) :csi
        (terminal-screen-csi-parameters screen) ""
        (terminal-screen-csi-private screen) nil))

(defun %terminal-screen-reverse-index (screen)
  (if (plusp (terminal-screen-cursor-row screen))
      (decf (terminal-screen-cursor-row screen))
      (%terminal-screen-scroll-down screen))
  (setf (terminal-screen-parser-state screen) :ground))

(defun %terminal-screen-handle-escape (screen character)
  (case character
    (#\[ (%terminal-screen-start-csi screen))
    (#\]
     (setf (terminal-screen-parser-state screen) :osc))
    (#\7
     (%terminal-screen-save-cursor screen)
     (setf (terminal-screen-parser-state screen) :ground))
    (#\8
     (%terminal-screen-restore-cursor screen)
     (setf (terminal-screen-parser-state screen) :ground))
    (#\D
     (%terminal-screen-line-feed screen)
     (setf (terminal-screen-parser-state screen) :ground))
    (#\E
     (%terminal-screen-next-line screen)
     (setf (terminal-screen-parser-state screen) :ground))
    (#\M (%terminal-screen-reverse-index screen))
    (#\c
     (%terminal-screen-clear-all screen)
     (setf (terminal-screen-parser-state screen) :ground))
    (otherwise
     (setf (terminal-screen-parser-state screen) :ground))))

(defun %terminal-screen-feed-backspace (screen)
  (setf (terminal-screen-cursor-column screen)
        (max 0 (1- (terminal-screen-cursor-column screen)))
        (terminal-screen-wrap-pending screen) nil))

(defun %terminal-screen-feed-tab (screen)
  (setf (terminal-screen-cursor-column screen)
        (min (1- (terminal-screen-width screen))
             (* 8
                (1+ (floor (terminal-screen-cursor-column screen)
                           8))))
        (terminal-screen-wrap-pending screen) nil))

(defun %terminal-screen-feed-printable-character (screen character)
  (when (and (>= (char-code character) 32)
             (/= (char-code character) 127))
    (%terminal-screen-write-character screen character)))

(defun %terminal-screen-feed-ground-character (screen character)
  (case character
    (#\Esc (setf (terminal-screen-parser-state screen) :escape))
    (#\Return (%terminal-screen-carriage-return screen))
    (#\Newline (%terminal-screen-line-feed screen))
    (#\Backspace (%terminal-screen-feed-backspace screen))
    (#\Tab (%terminal-screen-feed-tab screen))
    (#\Bell nil)
    (otherwise (%terminal-screen-feed-printable-character screen character))))

(defun %terminal-screen-feed-csi-character (screen character)
  (cond
    ((and (zerop (length (terminal-screen-csi-parameters screen)))
          (char= character #\?))
     (setf (terminal-screen-csi-private screen) t))
    ((<= 64 (char-code character) 126)
     (%terminal-screen-csi screen character)
     (setf (terminal-screen-parser-state screen) :ground))
    ((or (digit-char-p character)
         (char= character #\;)
         (char= character #\:))
     (setf (terminal-screen-csi-parameters screen)
           (concatenate 'string
                        (terminal-screen-csi-parameters screen)
                        (string character))))
    (t
     (setf (terminal-screen-parser-state screen) :ground))))

(defun %terminal-screen-feed-osc-character (screen character)
  (cond
    ((char= character #\Bell)
     (setf (terminal-screen-parser-state screen) :ground))
    ((char= character #\Esc)
     (setf (terminal-screen-parser-state screen) :osc-escape))))

(defun %terminal-screen-feed-character (screen character)
  (case (terminal-screen-parser-state screen)
    (:ground (%terminal-screen-feed-ground-character screen character))
    (:escape
     (%terminal-screen-handle-escape screen character))
    (:csi (%terminal-screen-feed-csi-character screen character))
    (:osc (%terminal-screen-feed-osc-character screen character))
    (:osc-escape
     (setf (terminal-screen-parser-state screen) :ground)))
  screen)

(defun terminal-screen-feed (screen text)
  "Apply terminal TEXT to SCREEN and return SCREEN.

The parser keeps partial escape sequences between calls, which is important
because PTY reads may split a CSI sequence across several chunks."
  (check-type text string)
  (loop for character across text
        do (%terminal-screen-feed-character screen character))
  screen)
