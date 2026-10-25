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
     comment-start comment-end skip-closing-delimiter
     indentation-width tab-width language-id keywords keybindings truncate-lines)
  (list :name (or name (string-capitalize (symbol-name key)))
        :aliases aliases
        :parent (or parent-key :fundamental)
        :extensions extensions
        :filenames filenames
        :comment-prefix comment-prefix
        :comment-start comment-start
        :comment-end comment-end
        :skip-closing-delimiter (and skip-closing-delimiter t)
        :indentation-width indentation-width
        :tab-width tab-width
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
    (name comment-prefix comment-start comment-end
     language-id indentation-width tab-width)
  (%validate-major-mode-text name ":name")
  (%validate-major-mode-text comment-prefix ":comment-prefix")
  (%validate-major-mode-text comment-start ":comment-start")
  (%validate-major-mode-text comment-end ":comment-end")
  (%validate-major-mode-text language-id ":language-id")
  (unless (and (integerp indentation-width) (plusp indentation-width))
    (error "Major-mode indentation width must be a positive integer: ~S"
           indentation-width))
  (unless (and (integerp tab-width) (plusp tab-width))
    (error "Major-mode tab width must be a positive integer: ~S"
           tab-width)))

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
            comment-prefix (comment-start comment-prefix) comment-end
            skip-closing-delimiter
            (indentation-width 2) (tab-width 8) language-id
            keywords keybindings (truncate-lines t))
  "Register an extension-defined major mode and return its canonical key.

KEYBINDINGS is an alist of (KEY-FORM . COMMAND) entries.  KEY-FORM uses the
same single- and multi-chord notation accepted by the global key binding API.
COMMAND may be a function or a callable function symbol."
  (let ((key (%new-major-mode-key mode)))
    (when (%major-mode-definition key)
      (error "Major mode is already defined: ~S" mode))
    (%validate-major-mode-registration-options
     name comment-prefix comment-start comment-end
     language-id indentation-width tab-width)
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
          normalized-filenames comment-prefix comment-start comment-end
          skip-closing-delimiter indentation-width tab-width language-id
          keywords keybindings truncate-lines))))))
(defun register-major-mode-indentation-rule (mode function)
  "Register MODE's line indentation rule and return its canonical key.

FUNCTION is called with BUFFER and a zero-based LINE-NUMBER. It returns a
non-negative indentation column, or NIL to use the preceding line's indentation.
Register extension-defined modes with REGISTER-MAJOR-MODE first."
  (let ((key (or (major-mode-from-name mode)
                 (error "Unknown major mode for indentation rule: ~S" mode))))
    (check-type function function)
    (setf (gethash key *major-mode-indentation-rules*) function)
    key))

(defun unregister-major-mode (mode)
  "Remove a dynamically registered MODE and return its canonical key.
Built-in modes cannot be removed; unknown modes return NIL."
  (let ((key (%major-mode-key mode)))
    (cond
      ((null key) nil)
      ((gethash key *registered-major-modes*)
       (remhash key *registered-major-modes*)
       (remhash key *major-mode-indentation-rules*)
       (setf *registered-major-mode-order*
             (delete key *registered-major-mode-order* :test #'eq))
       (incf *major-mode-registry-version*)
       key)
      ((%static-major-mode-definition key)
       (error "Cannot unregister built-in major mode: ~S" mode))
      (t nil))))
