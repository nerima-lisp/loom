;;;; packages/feature/mode/src/domain-major-mode.lisp
;;;;
;;;; Read-side major-mode resolution and metadata accessors.  Built-in
;;;; definitions and registry state live in
;;;; domain-major-mode-definitions.lisp; registry state, mutation, and
;;;; validation live in the registry support and registry files.
(in-package #:loom/feature/mode)

(defun %major-mode-token (value)
  (string-downcase
   (string-trim '(#\Space #\Tab #\Newline #\Return)
                (princ-to-string value))))

(defun %major-mode-definition (mode)
  (let ((key (%major-mode-key mode)))
    (or (%dynamic-major-mode-definition key)
        (%static-major-mode-definition key))))

(defun %dynamic-major-mode-key (token)
  (loop for key in *registered-major-mode-order*
        for definition = (%dynamic-major-mode-definition key)
        when (or (string= token (string-downcase (symbol-name key)))
                 (string= token (%major-mode-token (getf definition :name)))
                 (member token (getf definition :aliases) :test #'string=))
          return key))

(defun %static-major-mode-key (name)
  (loop for (key . definition) in +major-mode-definitions+
        when (or (string-equal name (symbol-name key))
                 (string-equal name (getf definition :name))
                 (member name (getf definition :aliases) :test #'string-equal))
          return key))

(defun %major-mode-key (mode)
  (cond
    ((keywordp mode) mode)
    ((symbolp mode) (intern (string-upcase (symbol-name mode)) :keyword))
    ((stringp mode)
     (or (%dynamic-major-mode-key (%major-mode-token mode))
         (%static-major-mode-key mode)))
    (t nil)))

(defun major-mode-known-p (mode)
  "Return true when MODE names a built-in or dynamically registered mode."
  (not (null (%major-mode-definition mode))))

(defun major-mode-from-name (name)
  "Resolve a mode name, including the common short aliases."
  (let ((key (%major-mode-key name)))
    (and (major-mode-known-p key) key)))

(defun major-mode-name (mode)
  "Return the display name for MODE, or NIL for an unknown mode."
  (getf (%major-mode-definition mode) :name))

(defun major-mode-comment-prefix (mode)
  (getf (%major-mode-definition mode) :comment-prefix))

(defun major-mode-indentation-width (mode)
  (or (getf (%major-mode-definition mode) :indentation-width) 2))

(defun major-mode-language-id (mode)
  (getf (%major-mode-definition mode) :language-id))

(defun major-mode-truncate-lines-p (mode)
  "Return true when MODE displays long lines truncated rather than wrapped.

Code modes truncate, because a wrapped line breaks the column alignment the
code was written with; prose modes wrap. A mode that declares nothing, and an
unknown mode, truncate: that is what loom did before the setting existed, and
it is the safer answer for a file whose content is unknown. The absent case
cannot be read off GETF's NIL, since NIL is also a mode's explicit choice."
  (let ((value (getf (%major-mode-definition mode) :truncate-lines :absent)))
    (if (eq value :absent) t value)))

(defun major-mode-keywords (mode)
  (copy-list (getf (%major-mode-definition mode) :keywords)))

(defun major-mode-parent (mode)
  "Return MODE's parent mode, or NIL when MODE is unknown."
  (let ((definition (%major-mode-definition mode)))
    (and definition
         (or (getf definition :parent) :fundamental))))

(defun major-mode-keybindings (mode)
  "Return a copy of MODE's local keybinding specifications."
  (copy-tree (getf (%major-mode-definition mode) :keybindings)))

(defun major-mode-definition (mode)
  "Return a copy of MODE's complete metadata definition."
  (copy-tree (%major-mode-definition mode)))

(defun major-mode-names ()
  "Return built-in names followed by dynamically registered mode names."
  (append (loop for entry in +major-mode-definitions+
                collect (getf (cdr entry) :name))
          (loop for key in *registered-major-mode-order*
                collect (getf (%dynamic-major-mode-definition key) :name))))
