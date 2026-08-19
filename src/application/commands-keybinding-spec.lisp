;;;; src/application/commands-keybinding-spec.lisp
;;;;
;;;; Application layer: normalization helpers for command-spec key forms.
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
