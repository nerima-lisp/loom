(in-package #:loom/application)

(defun install-default-keybindings (keymap)
  "Bind command-spec key sequences to their commands in KEYMAP."
  (dolist (spec *command-specs* keymap)
    (dolist (key-form (getf spec :keys))
      (loom:keymap-define-key keymap
                              (defkeys-key-sequence key-form)
                              (getf spec :command)))))
