;;;; packages/feature/mode/src/domain-major-mode-registry.lisp
;;;;
;;;; Dynamic major-mode registration, validation, and removal.  This keeps
;;;; write-side concerns separate from the static definitions and read APIs in
;;;; domain-major-mode.lisp.
(in-package #:loom/feature/mode)

(defun %validate-major-mode-parent-and-aliases (key parent-key aliases)
  (unless parent-key
    (error "Unknown parent major mode: ~S" parent-key))
  (when (eq parent-key key)
    (error "A major mode cannot inherit from itself: ~S" key))
  (when (/= (length aliases)
            (length (remove-duplicates aliases :test #'string=)))
    (error "Major-mode aliases must be unique: ~S" aliases))
  (dolist (alias aliases)
    (let ((existing (%major-mode-key alias)))
      (when (and existing (not (eq existing key)))
        (error "Major-mode alias is already in use: ~S" alias))))
  parent-key)

(defun %make-major-mode-definition
    (key name parent-key aliases extensions filenames comment-prefix
     indentation-width language-id keywords keybindings truncate-lines)
  (list :name (or name (string-capitalize (symbol-name key)))
        :aliases aliases
        :parent (or parent-key :fundamental)
        :extensions extensions
        :filenames filenames
        :comment-prefix comment-prefix
        :indentation-width indentation-width
        :truncate-lines (and truncate-lines t)
        :language-id (or language-id (string-downcase (symbol-name key)))
        :keywords (%validate-major-mode-keywords (or keywords '()))
        :keybindings (%validate-major-mode-keybindings (or keybindings '()))))

(defun %register-major-mode-definition (key definition)
  (setf (gethash key *registered-major-modes*) definition)
  (setf *registered-major-mode-order*
        (append *registered-major-mode-order* (list key)))
  (incf *major-mode-registry-version*)
  key)

(defun %validate-major-mode-registration-options
    (name comment-prefix language-id indentation-width)
  (%validate-major-mode-text name ":name")
  (%validate-major-mode-text comment-prefix ":comment-prefix")
  (%validate-major-mode-text language-id ":language-id")
  (unless (and (integerp indentation-width) (plusp indentation-width))
    (error "Major-mode indentation width must be a positive integer: ~S"
           indentation-width)))

(defun %normalize-major-mode-registration-lists
    (aliases extensions filenames)
  (values (%normalize-major-mode-string-list
           (or aliases '()) ":aliases")
          (%normalize-major-mode-string-list
           (or extensions '()) ":extensions" :strip-leading-dot t)
          (%normalize-major-mode-string-list
           (or filenames '()) ":filenames")))

(defun register-major-mode
    (mode &key name aliases (parent :fundamental) extensions filenames
            comment-prefix (indentation-width 2) language-id keywords
            keybindings (truncate-lines t))
  "Register an extension-defined major mode and return its canonical key.

KEYBINDINGS is an alist of (KEY-FORM . COMMAND) entries.  KEY-FORM uses the
same single- and multi-chord notation accepted by the global key binding API.
  COMMAND may be a function or a callable function symbol."
  (let ((key (%new-major-mode-key mode)))
    (when (%major-mode-definition key)
      (error "Major mode is already defined: ~S" mode))
    (%validate-major-mode-registration-options
     name comment-prefix language-id indentation-width)
    (let ((parent-key (major-mode-from-name parent)))
      (multiple-value-bind (normalized-aliases normalized-extensions
                            normalized-filenames)
          (%normalize-major-mode-registration-lists
           aliases extensions filenames)
        (%validate-major-mode-parent-and-aliases
         key parent-key normalized-aliases)
        (%register-major-mode-definition
         key
         (%make-major-mode-definition
          key name parent-key normalized-aliases normalized-extensions
          normalized-filenames comment-prefix indentation-width language-id
          keywords keybindings truncate-lines))))))

(defun unregister-major-mode (mode)
  "Remove a dynamically registered MODE and return its canonical key.
Built-in modes cannot be removed; unknown modes return NIL."
  (let ((key (%major-mode-key mode)))
    (cond
      ((null key) nil)
      ((gethash key *registered-major-modes*)
       (remhash key *registered-major-modes*)
       (setf *registered-major-mode-order*
             (delete key *registered-major-mode-order* :test #'eq))
       (incf *major-mode-registry-version*)
       key)
      ((%static-major-mode-definition key)
       (error "Cannot unregister built-in major mode: ~S" mode))
      (t nil))))
