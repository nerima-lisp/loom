;;;; src/application/commands-keybindings.lisp
;;;;
;;;; Application layer: normalization and installation for the default
;;;; Emacs-style keymap. The command registry is defined separately so the
;;;; user-init feature can consume the same data boundary.
(in-package #:loom/application)

(defun defkeys-single-chord-p (spec)
  "True when SPEC, a DEFKEYS key form, names one chord rather than a
multi-key sequence: a bare atom (an unmodified key) or a (:CONTROL CODE) /
(:ALT CODE) pair."
  (or (atom spec) (member (first spec) (list :control :alt))))

(defun defkeys-chord (spec)
  "Return the runtime key descriptor for one command-spec chord SPEC."
  (if (atom spec)
      (cons nil spec)
      (destructuring-bind (modifier code) spec
        (cons (list modifier) code))))

(defun defkeys-key-sequence (key-form)
  "Normalize command-spec KEY-FORM using DEFKEYS's descriptor convention."
  (mapcar (function defkeys-chord)
          (if (defkeys-single-chord-p key-form) (list key-form) key-form)))

(defun install-default-keybindings (keymap)
  "Bind command-spec key sequences to their commands in KEYMAP."
  (dolist (spec *command-specs* keymap)
    (dolist (key-form (getf spec :keys))
      (loom:keymap-define-key keymap
                              (defkeys-key-sequence key-form)
                              (getf spec :command)))))
