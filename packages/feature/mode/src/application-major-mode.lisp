;;;; packages/feature/mode/src/application-major-mode.lisp
;;;;
;;;; User-facing mode selection and small mode-aware editing commands.
(in-package #:loom)

(defun current-major-mode ()
  "Return the selected buffer's major mode, defaulting to FUNDAMENTAL."
  (if (%selected-buffer)
      (buffer-major-mode (%selected-buffer))
      :fundamental))

(defun %major-mode-completion-candidates (input)
  (declare (ignore input))
  (major-mode-names))

(defun set-major-mode ()
  "Prompt for and apply a major mode to the selected buffer."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((input "Major mode: "
               :completion-function #'%major-mode-completion-candidates))
    (let ((mode (major-mode-from-name input)))
      (if (and mode (%selected-buffer))
          (progn
            (buffer-set-major-mode (%selected-buffer) mode)
            (minibuffer-message minibuffer
                                (format nil "Mode: ~A" (major-mode-name mode))))
          (minibuffer-message minibuffer
                              (format nil "Unknown major mode: ~A" input))))))

(defun indent-for-tab-command ()
  "Insert spaces until point reaches the selected mode's indentation stop."
  (let ((buffer (%selected-buffer)))
    (when buffer
      (let* ((width (max 1 (major-mode-indentation-width
                            (buffer-major-mode buffer))))
             (column (buffer-point-column buffer))
             (spaces (- width (mod column width))))
        (buffer-insert-string buffer (make-string spaces :initial-element #\Space)))))
  nil)

(defun %major-mode-line-indentation (line)
  (or (position-if-not (lambda (character)
                         (member character '(#\Space #\Tab) :test #'char=))
                       line)
      (length line)))

(defun %major-mode-comment-prefix-at (line indentation prefix)
  (let ((end (+ indentation (length prefix))))
    (and prefix
         (<= end (length line))
         (string= prefix line :start2 indentation :end2 end))))

(defun comment-line ()
  "Toggle the current line's comment marker according to its major mode."
  (let* ((buffer (%selected-buffer))
         (mode (and buffer (buffer-major-mode buffer)))
         (prefix (and mode (major-mode-comment-prefix mode))))
    (cond
      ((null buffer) nil)
      ((null prefix)
       (minibuffer-message (editor-state-minibuffer *editor-state*)
                           (format nil "Mode ~A has no line comment syntax"
                                   (major-mode-name mode))))
      (t
       (let* ((line-number (buffer-point-line buffer))
              (line (buffer-line buffer line-number))
              (indentation (%major-mode-line-indentation line))
              (prefix-end (+ indentation (length prefix)))
              (commented (%major-mode-comment-prefix-at
                           line indentation prefix))
              (point-column (buffer-point-column buffer)))
         (if commented
             (let* ((remove-end
                      (if (and (< prefix-end (length line))
                               (char= (char line prefix-end) #\Space))
                          (1+ prefix-end)
                          prefix-end))
                    (removed-width (- remove-end indentation))
                    (new-column (cond ((<= point-column indentation)
                                       point-column)
                                      ((<= point-column remove-end)
                                       indentation)
                                      (t (- point-column removed-width)))))
               (buffer-delete-region buffer line-number indentation
                                     line-number remove-end)
               (buffer-set-point buffer line-number new-column))
             (let* ((insertion (format nil "~A " prefix))
                    (insertion-width (length insertion))
                    (new-column (if (>= point-column indentation)
                                    (+ point-column insertion-width)
                                    point-column)))
               (buffer-set-point buffer line-number indentation)
               (buffer-insert-string buffer insertion)
               (buffer-set-point buffer line-number new-column)))))))
  nil)
