(in-package #:loom/feature/mode)

(defparameter *major-mode-keymap-cache* (make-hash-table :test #'equal)
  "Derived mode keymaps, keyed by registry version, mode, and global map.")

(defun %major-mode-command-designator (command mode)
  (cond
    ((functionp command) command)
    ((and (symbolp command)
          (fboundp command)
          (not (macro-function command)))
     command)
    (t
     (error "Major mode ~S has a non-callable command binding: ~S"
            mode command))))

(defun %build-major-mode-keymap (mode fallback seen)
  (when (member mode seen :test #'eq)
    (error "Circular major-mode inheritance involving ~S" mode))
  (let* ((parent-mode (major-mode-parent mode))
         (parent-keymap
           (if (and parent-mode (not (eq parent-mode mode)))
               (%build-major-mode-keymap parent-mode fallback (cons mode seen))
               fallback))
         (keymap (loom:make-keymap :parent parent-keymap)))
    (dolist (binding (major-mode-keybindings mode))
      (loom:keymap-define-key
       keymap
       (loom/application:defkeys-key-sequence (car binding))
       (%major-mode-command-designator (cdr binding) mode)))
    keymap))

(defun %major-mode-completion-candidates (input)
  (declare (ignore input))
  (major-mode-names))

(defun %major-mode-line-indentation (line)
  (or (position-if-not (lambda (character)
                         (member character '(#\Space #\Tab) :test #'char=))
                       line)
      (length line)))

(defun %major-mode-comment-prefix-at (line indentation prefix)
  (and prefix
       (let ((end (+ indentation (length prefix))))
         (and (<= end (length line))
              (string= prefix line :start2 indentation :end2 end)))))
