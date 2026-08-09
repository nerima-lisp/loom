;;;; packages/feature/mode/src/domain-major-mode.lisp
;;;;
;;;; Pure major-mode metadata and path/name resolution.  Editing commands
;;;; consume this domain object, while buffer storage only keeps the selected
;;;; mode identity.
(in-package #:loom)

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

(defun %major-mode-key (mode)
  (cond
    ((keywordp mode) mode)
    ((symbolp mode) (intern (string-upcase (symbol-name mode)) :keyword))
    ((stringp mode)
     (or (loop for (key . definition) in +major-mode-definitions+
               when (string-equal mode (symbol-name key))
                 return key)
         (loop for (key . definition) in +major-mode-definitions+
               when (string-equal mode (getf definition :name))
                 return key)))
    (t nil)))

(defun %major-mode-definition (mode)
  (cdr (assoc (%major-mode-key mode) +major-mode-definitions+)))

(defun major-mode-known-p (mode)
  "Return true when MODE names one of the built-in major modes."
  (not (null (%major-mode-definition mode))))

(defun major-mode-from-name (name)
  "Resolve a mode name, including the common short aliases."
  (let* ((key (%major-mode-key name))
         (text (string-downcase (princ-to-string name))))
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
  (copy-list (or (getf (%major-mode-definition mode) :keywords) '())))

(defun major-mode-names ()
  "Return display names in the same order as the built-in mode catalog."
  (loop for entry in +major-mode-definitions+
        collect (getf (cdr entry) :name)))

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
