;;;; packages/feature/mode/src/application-major-mode.lisp
;;;;
;;;; User-facing mode selection and small mode-aware editing commands.
(in-package #:loom/feature/mode)

(defun current-major-mode ()
  "Return the selected buffer's major mode, defaulting to FUNDAMENTAL."
  (if (loom/application:%selected-buffer)
      (loom:buffer-major-mode (loom/application:%selected-buffer))
      :fundamental))

(defun %major-mode-completion-candidates (input)
  (declare (ignore input))
  (major-mode-names))

(defun set-major-mode ()
  "Prompt for and apply a major mode to the selected buffer."
  (loom/application:with-prompts
      (minibuffer (loom:editor-state-minibuffer
                                    loom:*editor-state*)
                 :on-cancel (loom:minibuffer-message minibuffer "Quit"))
      ((input "Major mode: "
               :completion-function #'%major-mode-completion-candidates))
    (let ((mode (major-mode-from-name input)))
      (if (and mode (loom/application:%selected-buffer))
          (progn
            (loom:buffer-set-major-mode
             (loom/application:%selected-buffer)
             mode)
            (loom:minibuffer-message minibuffer
                                (format nil "Mode: ~A" (major-mode-name mode))))
          (loom:minibuffer-message minibuffer
                              (format nil "Unknown major mode: ~A" input))))))

(defun indent-for-tab-command ()
  "Insert spaces until point reaches the selected mode's indentation stop."
  (let ((buffer (loom/application:%selected-buffer)))
    (when buffer
      (let* ((width (max 1 (major-mode-indentation-width
                            (loom:buffer-major-mode buffer))))
             (column (loom:buffer-point-column buffer))
             (spaces (- width (mod column width))))
        (loom:buffer-insert-string buffer
                                   (make-string spaces :initial-element #\Space)))))
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
  (let* ((buffer (loom/application:%selected-buffer))
         (mode (and buffer (loom:buffer-major-mode buffer)))
         (prefix (and mode (major-mode-comment-prefix mode))))
    (cond
      ((null buffer) nil)
      ((null prefix)
       (loom:minibuffer-message (loom:editor-state-minibuffer
                                  loom:*editor-state*)
                           (format nil "Mode ~A has no line comment syntax"
                                   (major-mode-name mode))))
      (t
       (let* ((line-number (loom:buffer-point-line buffer))
              (line (loom:buffer-line buffer line-number))
              (indentation (%major-mode-line-indentation line))
              (prefix-end (+ indentation (length prefix)))
              (commented (%major-mode-comment-prefix-at
                           line indentation prefix))
              (point-column (loom:buffer-point-column buffer)))
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
               (loom:buffer-delete-region buffer line-number indentation
                                          line-number remove-end)
               (loom:buffer-set-point buffer line-number new-column))
             (let* ((insertion (format nil "~A " prefix))
                    (insertion-width (length insertion))
                    (new-column (if (>= point-column indentation)
                                    (+ point-column insertion-width)
                                    point-column)))
               (loom:buffer-set-point buffer line-number indentation)
               (loom:buffer-insert-string buffer insertion)
               (loom:buffer-set-point buffer line-number new-column)))))))
  nil)
