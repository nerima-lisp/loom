;;;; packages/core/editor/src/application-commands-movement.lisp
;;;;
;;;; Application layer: point-movement commands (see
;;;; application/commands-internal.lisp for the shared command-authoring
;;;; convention every commands-*.lisp file follows).
(in-package #:loom)

(defun %forward-char-once ()
  (let* ((buffer (%selected-buffer))
         (point (buffer-point-offset buffer))
         (end (buffer-narrow-end-offset buffer)))
    (when (< point end)
      (let ((position (buffer-offset-position buffer (1+ point))))
        (buffer-set-point buffer
                          (buffer-position-line position)
                          (buffer-position-column position))))))

(defun %backward-char-once ()
  (let* ((buffer (%selected-buffer))
         (point (buffer-point-offset buffer))
         (start (buffer-narrow-start-offset buffer)))
    (when (> point start)
      (let ((position (buffer-offset-position buffer (1- point))))
        (buffer-set-point buffer
                          (buffer-position-line position)
                          (buffer-position-column position))))))

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
         (start (buffer-narrow-start-offset buffer))
         (offset (%forward-word-offset
                  (buffer-visible-text buffer)
                  (- (buffer-point-offset buffer) start))))
    (let ((position (buffer-offset-position buffer (+ start offset))))
      (buffer-set-point buffer
                        (buffer-position-line position)
                        (buffer-position-column position)))))

(defun %backward-word-once ()
  (let* ((buffer (%selected-buffer))
         (start (buffer-narrow-start-offset buffer))
         (offset (%backward-word-offset
                  (buffer-visible-text buffer)
                  (- (buffer-point-offset buffer) start))))
    (let ((position (buffer-offset-position buffer (+ start offset))))
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
  (let* ((buffer (%selected-buffer))
         (position (buffer-offset-position buffer
                                           (buffer-narrow-start-offset buffer))))
    (buffer-set-point buffer
                      (buffer-position-line position)
                      (buffer-position-column position))))

(defun end-of-buffer ()
  "Move point to the end of the buffer (M->)."
  (let* ((buffer (%selected-buffer))
         (position (buffer-offset-position buffer
                                           (buffer-narrow-end-offset buffer))))
    (buffer-set-point buffer
                      (buffer-position-line position)
                      (buffer-position-column position))))

(defun %scroll-window (delta)
  (let* ((window (%selected-window))
         (buffer (loom/feature/window:window-buffer window))
         (page (max 1 (1- (loom/feature/window:window-height window))))
         (max-scroll (max 0 (- (buffer-visible-line-count buffer)
                               (max 1 (loom/feature/window:window-height window))))))
    (setf (loom/feature/window:window-scroll-line window)
          (max 0 (min max-scroll
                      (+ (loom/feature/window:window-scroll-line window)
                         (* delta page)))))))

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
                (if (<= line (buffer-visible-line-count buffer))
                    (let* ((start (buffer-offset-position
                                   buffer (buffer-narrow-start-offset buffer)))
                           (target-line (+ (buffer-position-line start)
                                           (1- line))))
                      (buffer-set-point buffer target-line (buffer-point-column buffer))
                      (minibuffer-message minibuffer "Moved"))
                    (minibuffer-message minibuffer "Line is outside the narrowed buffer")))
              (minibuffer-message minibuffer "Line number must be positive")))
      (parse-error ()
        (minibuffer-message minibuffer "Enter a line number")))))
