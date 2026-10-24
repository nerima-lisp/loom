(in-package #:loom/core/command)

(defun install-default-keybindings (keymap)
  (dolist (spec (command-specs) keymap)
    (when (%command-spec-catalog-visible-p spec)
      (dolist (key-sequence (%command-spec-keys spec))
        (keymap-define-key keymap key-sequence (command-spec-id spec))))))
