;;;; src/application/commands-movement.lisp
;;;;
;;;; Application layer: point-movement commands (see
;;;; application/commands-internal.lisp for the shared command-authoring
;;;; convention every commands-*.lisp file follows).
(in-package #:loom)

(defun forward-char ()
  "Move point forward one character, wrapping onto the next line at EOL."
  (let* ((buffer (%selected-buffer))
         (line (buffer-point-line buffer))
         (column (buffer-point-column buffer))
         (line-len (length (buffer-line buffer line))))
    (cond
      ((< column line-len)
       (buffer-set-point buffer line (1+ column)))
      ((< line (1- (buffer-line-count buffer)))
       (buffer-set-point buffer (1+ line) 0))
      (t
       (buffer-set-point buffer line column)))))

(defun backward-char ()
  "Move point backward one character, wrapping onto the previous line at BOL."
  (let* ((buffer (%selected-buffer))
         (line (buffer-point-line buffer))
         (column (buffer-point-column buffer)))
    (cond
      ((> column 0)
       (buffer-set-point buffer line (1- column)))
      ((> line 0)
       (buffer-set-point buffer (1- line) (length (buffer-line buffer (1- line)))))
      (t
       (buffer-set-point buffer line column)))))

(defun next-line ()
  "Move point down one line, clamping column to the new line's length."
  (let ((buffer (%selected-buffer)))
    (buffer-set-point buffer (1+ (buffer-point-line buffer)) (buffer-point-column buffer))))

(defun previous-line ()
  "Move point up one line, clamping column to the new line's length."
  (let ((buffer (%selected-buffer)))
    (buffer-set-point buffer (1- (buffer-point-line buffer)) (buffer-point-column buffer))))

(defun move-beginning-of-line ()
  "Move point to the beginning of the current line."
  (let ((buffer (%selected-buffer)))
    (buffer-set-point buffer (buffer-point-line buffer) 0)))

(defun move-end-of-line ()
  "Move point to the end of the current line."
  (let ((buffer (%selected-buffer)))
    (buffer-set-point buffer (buffer-point-line buffer)
                       (length (buffer-line buffer (buffer-point-line buffer))))))

(defun goto-line ()
  "Prompt for a one-based line number and move point there."
  (let ((minibuffer (editor-state-minibuffer *editor-state*)))
    (minibuffer-activate
     minibuffer "Go to line: "
     :on-confirm
     (lambda (input)
       (handler-case
           (let ((line (parse-integer input)))
             (if (plusp line)
                 (let ((buffer (%selected-buffer)))
                   (buffer-set-point buffer (1- line) (buffer-point-column buffer))
                   (minibuffer-message minibuffer "Moved"))
                 (minibuffer-message minibuffer "Line number must be positive")))
         (parse-error ()
           (minibuffer-message minibuffer "Enter a line number")))))))
