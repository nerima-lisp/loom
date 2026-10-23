(in-package #:loom)

(defun %move-point-to-position (buffer position)
  (buffer-set-point buffer
                    (buffer-position-line position)
                    (buffer-position-column position)))

(defun %move-point-to-offset (buffer offset)
  (%move-point-to-position buffer
                           (buffer-offset-position buffer offset)))

(defmacro define-current-line-boundary-command (name documentation column-form)
  "Define NAME as a command moving point within its current line."
  (let ((buffer (gensym "BUFFER-")))
    `(defun ,name ()
       ,documentation
       (let ((,buffer (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*)))))
         (symbol-macrolet ((buffer ,buffer))
           (buffer-set-point ,buffer
                             (buffer-point-line ,buffer)
                             ,column-form))))))

(defmacro define-buffer-boundary-command (name documentation offset-form)
  "Define NAME as a command moving point to a buffer OFFSET."
  (let ((buffer (gensym "BUFFER-")))
    `(defun ,name ()
       ,documentation
       (let ((,buffer (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*)))))
         (symbol-macrolet ((buffer ,buffer))
           (%move-point-to-offset ,buffer ,offset-form))))))

(defun %forward-char-once ()
  "Move point forward by one character within the narrowing bounds."
  (let* ((buffer (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*))))
         (point (buffer-point-offset buffer))
         (end (buffer-narrow-end-offset buffer)))
    (when (< point end)
      (%move-point-to-offset buffer (1+ point)))))

(defun %backward-char-once ()
  "Move point backward by one character within the narrowing bounds."
  (let* ((buffer (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*))))
         (point (buffer-point-offset buffer))
         (start (buffer-narrow-start-offset buffer)))
    (when (> point start)
      (%move-point-to-offset buffer (1- point)))))

(defun %next-line-once ()
  "Move point down by one logical line."
  (let ((buffer (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*)))))
    (buffer-set-point buffer (1+ (buffer-point-line buffer)) (buffer-point-column buffer))))

(defun %previous-line-once ()
  "Move point up by one logical line."
  (let ((buffer (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*)))))
    (buffer-set-point buffer (1- (buffer-point-line buffer)) (buffer-point-column buffer))))

(defun %run-word-motion-helper (offset-function)
  (let* ((buffer (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*))))
         (start (buffer-narrow-start-offset buffer))
         (offset (funcall offset-function
                          (buffer-visible-text buffer)
                          (- (buffer-point-offset buffer) start))))
    (%move-point-to-offset buffer (+ start offset))))

(defmacro define-word-motion-helper (name offset-function)
  "Define NAME as a one-step word motion helper using OFFSET-FUNCTION."
  `(defun ,name ()
     (%run-word-motion-helper #',offset-function)))

(define-word-motion-helper %forward-word-once %forward-word-offset)
(define-word-motion-helper %backward-word-once %backward-word-offset)
