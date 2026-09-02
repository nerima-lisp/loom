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

(defun %terminal-screen-handle-escape-csi (screen)
  (%terminal-screen-start-csi screen))

(defun %terminal-screen-handle-escape-osc (screen)
  (setf (terminal-screen-parser-state screen) :osc))

(defmacro define-terminal-escape-operation (name operation)
  `(defun ,name (screen)
     (,operation screen)
     (setf (terminal-screen-parser-state screen) :ground)))

(define-terminal-escape-operation
    %terminal-screen-handle-escape-save-cursor
    %terminal-screen-save-cursor)
(define-terminal-escape-operation
    %terminal-screen-handle-escape-restore-cursor
    %terminal-screen-restore-cursor)
(define-terminal-escape-operation
    %terminal-screen-handle-escape-line-feed
    %terminal-screen-line-feed)
(define-terminal-escape-operation
    %terminal-screen-handle-escape-next-line
    %terminal-screen-next-line)

(defun %terminal-screen-handle-escape-reverse-index (screen)
  (%terminal-screen-reverse-index screen))

(defun %terminal-screen-handle-escape-reset (screen)
  (%terminal-screen-clear-all screen)
  (setf (terminal-screen-parser-state screen) :ground))

(defun %terminal-screen-escape-handler (character)
  (cdr (assoc character
              '((#\[ . %terminal-screen-handle-escape-csi)
                (#\] . %terminal-screen-handle-escape-osc)
                (#\7 . %terminal-screen-handle-escape-save-cursor)
                (#\8 . %terminal-screen-handle-escape-restore-cursor)
                (#\D . %terminal-screen-handle-escape-line-feed)
                (#\E . %terminal-screen-handle-escape-next-line)
                (#\M . %terminal-screen-handle-escape-reverse-index)
                (#\c . %terminal-screen-handle-escape-reset)))))

(defun %terminal-screen-handle-escape (screen character)
  (let ((handler (%terminal-screen-escape-handler character)))
    (if handler
        (funcall handler screen)
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

(defun %terminal-screen-feed-ground-control-character (screen character)
  (case character
    (#\Esc (setf (terminal-screen-parser-state screen) :escape) t)
    (#\Return (%terminal-screen-carriage-return screen) t)
    (#\Newline (%terminal-screen-line-feed screen) t)
    (#\Backspace (%terminal-screen-feed-backspace screen) t)
    (#\Tab (%terminal-screen-feed-tab screen) t)
    (#\Bell t)
    (otherwise nil)))

(defun %terminal-screen-feed-ground-character (screen character)
  (unless (%terminal-screen-feed-ground-control-character screen character)
    (%terminal-screen-feed-printable-character screen character)))

(defun %terminal-screen-feed-csi-character (screen character)
  (cond
    ((and (string= (terminal-screen-csi-parameters screen) "")
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
