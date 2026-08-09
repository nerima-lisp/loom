;;;; packages/core/editor/src/application-commands-movement.lisp
;;;;
;;;; Application layer: point-movement commands (see
;;;; application/commands-internal.lisp for the shared command-authoring
;;;; convention every commands-*.lisp file follows).
(in-package #:loom)

(defun %forward-char-once ()
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

(defun %backward-char-once ()
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

(defun forward-char ()
  "Move point forward, repeating for the active numeric prefix."
  (%repeat-command (%command-prefix-count)
                   #'%forward-char-once
                   #'%backward-char-once))

(defun backward-char ()
  "Move point backward, repeating for the active numeric prefix."
  (%repeat-command (%command-prefix-count)
                   #'%backward-char-once
                   #'%forward-char-once))

(defun %next-line-once ()
  (let ((buffer (%selected-buffer)))
    (buffer-set-point buffer (1+ (buffer-point-line buffer)) (buffer-point-column buffer))))

(defun %previous-line-once ()
  (let ((buffer (%selected-buffer)))
    (buffer-set-point buffer (1- (buffer-point-line buffer)) (buffer-point-column buffer))))

(defun next-line ()
  "Move point down, repeating for the active numeric prefix."
  (%repeat-command (%command-prefix-count)
                   #'%next-line-once
                   #'%previous-line-once))

(defun previous-line ()
  "Move point up, repeating for the active numeric prefix."
  (%repeat-command (%command-prefix-count)
                   #'%previous-line-once
                   #'%next-line-once))

(defun move-beginning-of-line ()
  "Move point to the beginning of the current line."
  (let ((buffer (%selected-buffer)))
    (buffer-set-point buffer (buffer-point-line buffer) 0)))

(defun move-end-of-line ()
  "Move point to the end of the current line."
  (let ((buffer (%selected-buffer)))
    (buffer-set-point buffer (buffer-point-line buffer)
                       (length (buffer-line buffer (buffer-point-line buffer))))))

(defun %word-character-p (character)
  "Return true when CHARACTER belongs to an Emacs-style word."
  (or (alphanumericp character)
      (char= character #\_)))

(defun %forward-word-offset (text offset)
  (let ((length (length text)))
    (loop while (and (< offset length)
                     (not (%word-character-p (char text offset))))
          do (incf offset))
    (loop while (and (< offset length)
                     (%word-character-p (char text offset)))
          do (incf offset))
    offset))

(defun %backward-word-offset (text offset)
  (loop while (and (> offset 0)
                   (not (%word-character-p (char text (1- offset)))))
        do (decf offset))
  (loop while (and (> offset 0)
                   (%word-character-p (char text (1- offset))))
        do (decf offset))
  offset)

(defun %forward-word-once ()
  (let* ((buffer (%selected-buffer))
         (offset (%forward-word-offset (buffer-text buffer)
                                       (buffer-point-offset buffer))))
    (let ((position (buffer-offset-position buffer offset)))
      (buffer-set-point buffer
                        (buffer-position-line position)
                        (buffer-position-column position)))))

(defun %backward-word-once ()
  (let* ((buffer (%selected-buffer))
         (offset (%backward-word-offset (buffer-text buffer)
                                        (buffer-point-offset buffer))))
    (let ((position (buffer-offset-position buffer offset)))
      (buffer-set-point buffer
                        (buffer-position-line position)
                        (buffer-position-column position)))))

(defun forward-word ()
  "Move point forward by words, repeating for the active numeric prefix."
  (%repeat-command (%command-prefix-count)
                   #'%forward-word-once
                   #'%backward-word-once))

(defun backward-word ()
  "Move point backward by words, repeating for the active numeric prefix."
  (%repeat-command (%command-prefix-count)
                   #'%backward-word-once
                   #'%forward-word-once))

(defun beginning-of-buffer ()
  "Move point to the beginning of the buffer (M-<)."
  (buffer-set-point (%selected-buffer) 0 0))

(defun end-of-buffer ()
  "Move point to the end of the buffer (M->)."
  (let* ((buffer (%selected-buffer))
         (position (buffer-offset-position buffer (length (buffer-text buffer)))))
    (buffer-set-point buffer
                      (buffer-position-line position)
                      (buffer-position-column position))))

(defun %scroll-window (delta)
  (let* ((window (%selected-window))
         (buffer (window-buffer window))
         (page (max 1 (1- (window-height window))))
         (max-scroll (max 0 (- (buffer-line-count buffer)
                               (max 1 (window-height window))))))
    (setf (window-scroll-line window)
          (max 0 (min max-scroll
                      (+ (window-scroll-line window) (* delta page)))))))

(defun scroll-up-command ()
  "Scroll down by roughly one page, repeating for the active prefix (C-v)."
  (%repeat-command (%command-prefix-count)
                   (lambda () (%scroll-window 1))
                   (lambda () (%scroll-window -1))))

(defun scroll-down-command ()
  "Scroll up by roughly one page, repeating for the active prefix (M-v)."
  (%repeat-command (%command-prefix-count)
                   (lambda () (%scroll-window -1))
                   (lambda () (%scroll-window 1))))

(defun goto-line ()
  "Prompt for a one-based line number and move point there."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((input "Go to line: "))
    (handler-case
        (let ((line (parse-integer input)))
          (if (plusp line)
              (let ((buffer (%selected-buffer)))
                (buffer-set-point buffer (1- line) (buffer-point-column buffer))
                (minibuffer-message minibuffer "Moved"))
              (minibuffer-message minibuffer "Line number must be positive")))
      (parse-error ()
        (minibuffer-message minibuffer "Enter a line number")))))
