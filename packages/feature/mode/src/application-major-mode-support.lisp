(in-package #:loom/feature/mode)

(defparameter *major-mode-keymap-cache*
  (make-hash-table :test #'equal)
  "Derived mode keymaps, keyed by registry version, mode, and global map.")

(defun %major-mode-command-designator (command mode)
  (cond
    ((functionp command) command)
    ((and (symbolp command) (fboundp command) (not (macro-function command)))
     command)
    (t
     (error "Major mode ~S has a non-callable command binding: ~S" mode command))))

(defun %build-major-mode-keymap (mode fallback seen)
  (when (member mode seen :test (function eq))
    (error "Circular major-mode inheritance involving ~S" mode))
  (let* ((parent-mode (major-mode-parent mode))
         (parent-keymap
           (if (and parent-mode (not (eq parent-mode mode)))
               (%build-major-mode-keymap parent-mode fallback (cons mode seen))
               fallback))
         (keymap
           (loom/core/command:make-keymap
            :parent parent-keymap
            :name (string-downcase (symbol-name mode)))))
    (dolist (binding (major-mode-keybindings mode))
      (loom/core/command:keymap-define-key
       keymap
       (loom/core/command:defkeys-key-sequence (car binding))
       (%major-mode-command-designator (cdr binding) mode)))
    (let ((comment-key-sequence
            (defkeys-key-sequence (quote (:alt #\;)))))
      (multiple-value-bind (command-id owner)
          (loom/core/command:keymap-lookup keymap comment-key-sequence)
        (declare (ignore command-id))
        (unless (eq owner keymap)
          (loom/core/command:keymap-define-key
           keymap
           comment-key-sequence
           (quote comment-dwim)))))
    (dolist (key-sequence
              (list (defkeys-key-sequence :tab)
                    (defkeys-key-sequence
                     (quote (:control :alt #\\)))))
      (multiple-value-bind (command-id owner)
          (loom/core/command:keymap-lookup keymap key-sequence)
        (declare (ignore command-id))
        (unless owner
          (loom/core/command:keymap-define-key
           keymap
           key-sequence
           (loom/core/command:command-id-for-function
            (quote indent-for-tab-command))))))
    keymap))

(defun %major-mode-completion-candidates (input)
  (declare (ignore input))
  (major-mode-names))

(defun %major-mode-line-indentation (line)
  (or
   (position-if-not
    (lambda (character)
      (member character '(#\Space #\Tab) :test #'char=))
    line)
   (length line)))

(defun %major-mode-comment-prefix-at (line indentation prefix)
  (and prefix
       (let ((end (+ indentation (length prefix))))
         (and (<= end (length line))
              (string= prefix line :start2 indentation :end2 end)))))
