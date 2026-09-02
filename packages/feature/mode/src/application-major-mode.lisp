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
