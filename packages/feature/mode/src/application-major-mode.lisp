;;;; packages/feature/mode/src/application-major-mode.lisp
;;;;
;;;; User-facing mode selection and small mode-aware editing commands.
(in-package #:loom/feature/mode)

(defun major-mode-keymap (mode fallback)
  "Return MODE's local keymap layered over FALLBACK.

FALLBACK is normally the editor's user/global keymap.  The returned object is
cached while the mode registry and fallback object remain unchanged, so global
bindings added after mode activation are still visible through the parent.
"
  (let ((key (or (major-mode-from-name mode) :fundamental)))
    (or (gethash (list *major-mode-registry-version* key fallback)
                 *major-mode-keymap-cache*)
        (setf (gethash (list *major-mode-registry-version* key fallback)
                       *major-mode-keymap-cache*)
              (%build-major-mode-keymap key fallback nil)))))

(defun current-major-mode ()
  "Return the selected buffer's major mode, defaulting to FUNDAMENTAL."
  (if (loom/application:%selected-buffer)
      (loom:buffer-major-mode (loom/application:%selected-buffer))
      :fundamental))

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

(defun buffer-truncate-lines-p (buffer)
  "Return true when BUFFER's long lines should be truncated rather than wrapped.

The buffer stores T, NIL, or :DEFAULT; only :DEFAULT consults the major mode.
The setting belongs to the buffer rather than the window so the same file shown
in two windows cannot disagree with itself."
  (let ((value (loom:buffer-truncate-lines buffer)))
    (if (eq value :default)
        (major-mode-truncate-lines-p (loom:buffer-major-mode buffer))
        value)))

(defun toggle-truncate-lines ()
  "Flip the selected buffer between truncating and wrapping long lines.

The flip resolves the mode default first and then stores the opposite as an
explicit choice, so the first toggle always visibly changes something instead
of setting :DEFAULT's own value."
  (let ((buffer (loom/application:%selected-buffer)))
    (when buffer
      (let ((truncate (not (buffer-truncate-lines-p buffer))))
        (loom:buffer-set-truncate-lines buffer truncate)
        (loom:minibuffer-message
         (loom:editor-state-minibuffer loom:*editor-state*)
         (if truncate "Truncate long lines" "Wrap long lines")))))
  nil)

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

(defun %comment-line-removal-end (line indentation prefix-end)
  (if (and (< prefix-end (length line))
           (char= (char line prefix-end) #\Space))
      (1+ prefix-end)
      prefix-end))

(defun %comment-line-point-after-removal
    (point-column indentation remove-end)
  (let ((removed-width (- remove-end indentation)))
    (cond ((<= point-column indentation) point-column)
          ((<= point-column remove-end) indentation)
          (t (- point-column removed-width)))))

(defun %comment-line-remove (buffer line-number line indentation prefix)
  (let* ((prefix-end (+ indentation (length prefix)))
         (remove-end (%comment-line-removal-end line indentation prefix-end))
         (new-column (%comment-line-point-after-removal
                      (loom:buffer-point-column buffer)
                      indentation
                      remove-end)))
    (loom:buffer-delete-region buffer line-number indentation
                               line-number remove-end)
    (loom:buffer-set-point buffer line-number new-column)))

(defun %comment-line-add (buffer line-number indentation prefix)
  (let* ((insertion (format nil "~A " prefix))
         (new-column (if (>= (loom:buffer-point-column buffer) indentation)
                         (+ (loom:buffer-point-column buffer)
                            (length insertion))
                         (loom:buffer-point-column buffer))))
    (loom:buffer-set-point buffer line-number indentation)
    (loom:buffer-insert-string buffer insertion)
    (loom:buffer-set-point buffer line-number new-column)))

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
              (commented (%major-mode-comment-prefix-at
                           line indentation prefix)))
         (if commented
             (%comment-line-remove buffer line-number line indentation prefix)
             (%comment-line-add buffer line-number indentation prefix))))))
  nil)
