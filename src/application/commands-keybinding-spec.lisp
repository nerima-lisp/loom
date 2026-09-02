;;;; src/application/commands-keybinding-spec.lisp
;;;;
;;;; Application layer: normalization helpers for command-spec key forms.
(in-package #:loom/application)

(defparameter +defkeys-modifiers+ '(:control :alt)
  "The modifier keywords a DEFKEYS chord may carry.")

(defun defkeys-modifier-p (value)
  "Return true when VALUE is a supported DEFKEYS modifier keyword."
  (case value
    ((:control :alt) t)
    (otherwise nil)))

(defun defkeys-single-chord-p (spec)
  "True when SPEC, a DEFKEYS key form, names one chord rather than a
multi-key sequence: a bare atom (an unmodified key) or a modifier-prefixed
list such as (:CONTROL CODE) or (:CONTROL :ALT CODE)."
  (or (atom spec) (defkeys-modifier-p (first spec))))

(defun defkeys-chord (spec)
  "Return the runtime key descriptor for one command-spec chord SPEC.

Every element but the last is a modifier, so (:CONTROL :ALT #\\f) is one chord
rather than a sequence. NORMALIZE-KEY-DESCRIPTOR sorts the modifiers, so the
order written here does not have to match the order a terminal reports.

The shape is checked rather than merely destructured. A variable-length chord
has no arity left to catch a typo like (:CONTROL #\\x :EXTRA), and a key form
that silently binds the wrong chord is worse than one that refuses to load --
user init files reach this through DEFKEYS-KEY-SEQUENCE."
  (if (atom spec)
      (cons nil spec)
      (let ((modifiers (butlast spec))
            (code (car (last spec))))
        (dolist (modifier modifiers)
          (unless (defkeys-modifier-p modifier)
            (error "Key chord modifier must be one of ~S: ~S"
                   +defkeys-modifiers+ spec)))
        (unless (or (characterp code)
                    (and (keywordp code)
                         (not (defkeys-modifier-p code))))
          (error "Key chord code must be a character or a special-key keyword: ~S"
                 spec))
        (cons modifiers code))))

(defun defkeys-key-sequence (key-form)
  "Normalize command-spec KEY-FORM using DEFKEYS's descriptor convention."
  (mapcar (function defkeys-chord)
          (if (defkeys-single-chord-p key-form) (list key-form) key-form)))
