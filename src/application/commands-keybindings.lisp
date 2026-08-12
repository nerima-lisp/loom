;;;; src/application/commands-keybindings.lisp
;;;;
;;;; Application layer: installation for the default Emacs-style keymap.
;;;; The command-spec normalization helpers live in the sibling
;;;; commands-keybinding-spec.lisp so user-init and major-mode loading can
;;;; reuse that boundary without pulling in the installer loop.
(in-package #:loom/application)

(defun install-default-keybindings (keymap)
  "Bind command-spec key sequences to their commands in KEYMAP."
  (dolist (spec *command-specs* keymap)
    (dolist (key-form (getf spec :keys))
      (loom:keymap-define-key keymap
                              (defkeys-key-sequence key-form)
                              (getf spec :command)))))
