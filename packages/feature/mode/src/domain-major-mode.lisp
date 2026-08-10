;;;; packages/feature/mode/src/domain-major-mode.lisp
;;;;
;;;; Pure major-mode metadata and path/name resolution.  Editing commands
;;;; consume this domain object, while buffer storage only keeps the selected
;;;; mode identity.
(in-package #:loom/feature/mode)

(defparameter +major-mode-definitions+
  '((:fundamental
     :name "Fundamental"
     :comment-prefix nil
     :indentation-width 2
     :language-id "plaintext"
     :keywords ())
    (:common-lisp
     :name "Common Lisp"
     :comment-prefix ";"
     :indentation-width 2
     :language-id "commonlisp"
     :keywords ("and" "block" "case" "catch" "defclass" "defconstant"
                 "defgeneric" "defmacro" "defmethod" "defpackage"
                 "defparameter" "defstruct" "deftype" "defun" "defvar"
                 "do" "do*" "dolist" "dotimes" "ecase" "else" "eval-when"
                 "flet" "function" "go" "if" "in-package" "labels" "let"
                 "let*" "loop" "macrolet" "multiple-value-bind"
                 "multiple-value-call" "multiple-value-prog1"
                 "multiple-value-setq" "nil" "or" "otherwise" "prog" "prog1"
                 "progn" "progv" "quote" "return" "return-from" "setf"
                 "tagbody" "the" "throw" "typecase" "unless" "unwind-protect"
                 "when" "with-open-file" "with-output-to-string" "with-slots"
                 "with-standard-io-syntax" "write" "t"))
    (:python
     :name "Python"
     :comment-prefix "#"
     :indentation-width 4
     :language-id "python"
     :keywords ("and" "as" "assert" "async" "await" "break" "case"
                 "class" "continue" "def" "del" "elif" "else" "except"
                 "False" "finally" "for" "from" "global" "if" "import"
                 "in" "is" "lambda" "match" "None" "nonlocal" "not" "or"
                 "pass" "raise" "return" "True" "try" "while" "with" "yield"))
    (:rust
     :name "Rust"
     :comment-prefix "//"
     :indentation-width 4
     :language-id "rust"
     :keywords ("as" "async" "await" "break" "const" "continue" "crate"
                 "dyn" "else" "enum" "extern" "fn" "for" "if" "impl"
                 "in" "let" "loop" "match" "mod" "move" "mut" "pub"
                 "ref" "return" "self" "Self" "static" "struct" "super"
                 "trait" "type" "unsafe" "use" "where" "while"))
    (:shell
     :name "Shell"
     :comment-prefix "#"
     :indentation-width 2
     :language-id "shellscript"
     :keywords ("case" "do" "done" "elif" "else" "esac" "fi" "for"
                 "function" "if" "in" "select" "then" "until" "while"))
    (:markdown
     :name "Markdown"
     :comment-prefix "#"
     :indentation-width 2
     :language-id "markdown"
     :keywords ())
    (:json
     :name "JSON"
     :comment-prefix nil
     :indentation-width 2
     :language-id "json"
     :keywords ())
    (:text
     :name "Text"
     :comment-prefix nil
     :indentation-width 2
     :language-id "plaintext"
     :keywords ()))
  "The built-in major modes and the metadata consumed by editor features.")

(defparameter *registered-major-modes* (make-hash-table :test #'eq)
  "Dynamically registered major-mode definitions keyed by canonical keyword.")

(defparameter *registered-major-mode-order* nil
  "Canonical keys for dynamically registered modes, in registration order.")

(defparameter *major-mode-registry-version* 0
  "Monotonic version used to invalidate derived mode keymaps.")

(defun %major-mode-token (value)
  (string-downcase
   (string-trim '(#\Space #\Tab #\Newline #\Return)
                (princ-to-string value))))

(defun %static-major-mode-definition (key)
  (cdr (assoc key +major-mode-definitions+)))

(defun %dynamic-major-mode-definition (key)
  (and key (gethash key *registered-major-modes*)))

(defun %major-mode-definition (mode)
  (let ((key (%major-mode-key mode)))
    (or (%dynamic-major-mode-definition key)
        (%static-major-mode-definition key))))

(defun %major-mode-key (mode)
  (cond
    ((keywordp mode) mode)
    ((symbolp mode) (intern (string-upcase (symbol-name mode)) :keyword))
    ((stringp mode)
     (let ((token (%major-mode-token mode)))
       (or (loop for key in *registered-major-mode-order*
                 for definition = (%dynamic-major-mode-definition key)
                 when (or (string= token (string-downcase (symbol-name key)))
                          (string= token
                                   (%major-mode-token (getf definition :name)))
                          (member token (getf definition :aliases)
                                  :test #'string=))
                   return key)
           (loop for (key . definition) in +major-mode-definitions+
                 when (or (string-equal mode (symbol-name key))
                          (string-equal mode (getf definition :name)))
                   return key))))
    (t nil)))

(defun major-mode-known-p (mode)
  "Return true when MODE names a built-in or dynamically registered mode."
  (not (null (%major-mode-definition mode))))

(defun major-mode-from-name (name)
  "Resolve a mode name, including the common short aliases."
  (let* ((key (%major-mode-key name))
         (text (%major-mode-token name)))
    (or (and (major-mode-known-p key) key)
        (cdr (assoc text
                    '(("lisp" . :common-lisp)
                      ("cl" . :common-lisp)
                      ("common lisp" . :common-lisp)
                      ("sh" . :shell)
                      ("bash" . :shell)
                      ("zsh" . :shell)
                      ("plain text" . :text))
                        :test #'string=)))))

(defun major-mode-name (mode)
  "Return the display name for MODE, or NIL for an unknown mode."
  (getf (%major-mode-definition mode) :name))

(defun major-mode-comment-prefix (mode)
  (getf (%major-mode-definition mode) :comment-prefix))

(defun major-mode-indentation-width (mode)
  (or (getf (%major-mode-definition mode) :indentation-width) 2))

(defun major-mode-language-id (mode)
  (getf (%major-mode-definition mode) :language-id))

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

(defun %new-major-mode-key (mode)
  (unless (or (keywordp mode) (symbolp mode))
    (error "A new major mode must be named by a symbol or keyword: ~S" mode))
  (intern (string-upcase (symbol-name mode)) :keyword))

(defun %normalize-major-mode-string-list (value label &key strip-leading-dot)
  (unless (listp value)
    (error "~A must be a list of strings: ~S" label value))
  (let ((result '()))
    (dolist (item value (nreverse result))
      (unless (stringp item)
        (error "~A must contain only strings: ~S" label item))
      (let ((text (%major-mode-token item)))
        (when (and strip-leading-dot (plusp (length text))
                   (char= (char text 0) #\.))
          (setf text (subseq text 1)))
        (when (zerop (length text))
          (error "~A cannot contain an empty string: ~S" label item))
        (push text result)))))

(defun %validate-major-mode-text (value label)
  (unless (or (null value) (stringp value))
    (error "~A must be a string or NIL: ~S" label value))
  (when (and value
             (zerop (length (string-trim '(#\Space #\Tab #\Newline #\Return)
                                          value))))
    (error "~A cannot be empty: ~S" label value))
  value)

(defun %validate-major-mode-keywords (keywords)
  (unless (listp keywords)
    (error "Major-mode keywords must be a list of strings: ~S" keywords))
  (dolist (keyword keywords)
    (unless (stringp keyword)
      (error "Major-mode keywords must contain only strings: ~S" keyword)))
  (copy-list keywords))

(defun %validate-major-mode-keybindings (keybindings)
  (unless (listp keybindings)
    (error "Major-mode keybindings must be a list: ~S" keybindings))
  (dolist (binding keybindings)
    (unless (and (consp binding) (car binding) (cdr binding))
      (error "Major-mode keybindings must be (KEY-FORM . COMMAND): ~S"
             binding)))
  (copy-tree keybindings))

(defun register-major-mode
    (mode &key name aliases (parent :fundamental) extensions filenames
            comment-prefix (indentation-width 2) language-id keywords
            keybindings)
  "Register an extension-defined major mode and return its canonical key.

KEYBINDINGS is an alist of (KEY-FORM . COMMAND) entries.  KEY-FORM uses the
same single- and multi-chord notation accepted by the global key binding API.
  COMMAND may be a function or a callable function symbol."
  (let ((key (%new-major-mode-key mode)))
    (when (%major-mode-definition key)
      (error "Major mode is already defined: ~S" mode))
    (%validate-major-mode-text name ":name")
    (%validate-major-mode-text comment-prefix ":comment-prefix")
    (%validate-major-mode-text language-id ":language-id")
    (unless (and (integerp indentation-width) (plusp indentation-width))
      (error "Major-mode indentation width must be a positive integer: ~S"
             indentation-width))
    (let* ((parent-key (major-mode-from-name parent))
           (normalized-aliases (%normalize-major-mode-string-list
                                (or aliases '()) ":aliases"))
           (normalized-extensions (%normalize-major-mode-string-list
                                   (or extensions '()) ":extensions"
                                   :strip-leading-dot t))
           (normalized-filenames (%normalize-major-mode-string-list
                                  (or filenames '()) ":filenames"))
           (display-name (or name (string-capitalize (symbol-name key))))
           (definition (list :name display-name
                             :aliases normalized-aliases
                             :parent (or parent-key :fundamental)
                             :extensions normalized-extensions
                             :filenames normalized-filenames
                             :comment-prefix comment-prefix
                             :indentation-width indentation-width
                             :language-id (or language-id
                                               (string-downcase
                                                (symbol-name key)))
                             :keywords (%validate-major-mode-keywords
                                        (or keywords '()))
                             :keybindings (%validate-major-mode-keybindings
                                           (or keybindings '())))))
      (unless parent-key
        (error "Unknown parent major mode: ~S" parent))
      (when (eq parent-key key)
        (error "A major mode cannot inherit from itself: ~S" mode))
      (when (/= (length normalized-aliases)
                (length (remove-duplicates normalized-aliases
                                            :test #'string=)))
        (error "Major-mode aliases must be unique: ~S" aliases))
      (dolist (alias normalized-aliases)
        (let ((existing (%major-mode-key alias)))
          (when (and existing (not (eq existing key)))
            (error "Major-mode alias is already in use: ~S" alias))))
      (setf (gethash key *registered-major-modes*) definition)
      (setf *registered-major-mode-order*
            (append *registered-major-mode-order* (list key)))
      (incf *major-mode-registry-version*)
      key)))

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

(defun %major-mode-path-text (path)
  (typecase path
    (string path)
    (pathname (namestring path))
    (t (princ-to-string path))))

(defun %major-mode-basename (path)
  (let* ((text (string-right-trim '(#\/ #\\) (%major-mode-path-text path)))
         (slash (position #\/ text :from-end t))
         (backslash (position #\\ text :from-end t))
         (separator (cond ((and slash backslash) (max slash backslash))
                          (slash slash)
                          (backslash backslash)
                          (t nil))))
    (if separator
        (subseq text (1+ separator))
        text)))

(defun %major-mode-extension (basename)
  (let ((dot (position #\. basename :from-end t)))
    (and dot
         (< (1+ dot) (length basename))
         (string-downcase (subseq basename (1+ dot))))))

(defun major-mode-for-path (path)
  "Infer a major mode from PATH without accessing the file system."
  (let* ((basename (string-downcase (%major-mode-basename path)))
         (extension (%major-mode-extension basename)))
    (cond
      ((loop for key in *registered-major-mode-order*
             for definition = (%dynamic-major-mode-definition key)
             when (or (member basename (getf definition :filenames)
                              :test #'string=)
                      (and extension
                           (member extension (getf definition :extensions)
                                   :test #'string=)))
               return key))
      ((and extension
            (member extension '("lisp" "lsp" "cl") :test #'string=))
       :common-lisp)
      ((and extension (string= extension "py")) :python)
      ((and extension (string= extension "rs")) :rust)
      ((and extension
            (member extension '("sh" "bash" "zsh") :test #'string=))
       :shell)
      ((and extension
            (member extension '("md" "markdown") :test #'string=))
       :markdown)
      ((and extension (string= extension "json")) :json)
      ((and extension (string= extension "txt")) :text)
      ((member basename '("dockerfile" "makefile") :test #'string=) :shell)
      ((member basename '("readme" "license" "copying") :test #'string=)
       :text)
      (t :fundamental))))
