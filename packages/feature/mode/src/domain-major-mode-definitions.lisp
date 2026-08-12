;;;; packages/feature/mode/src/domain-major-mode-definitions.lisp
;;;;
;;;; Built-in major-mode metadata and registry state shared by read- and
;;;; write-side helpers.  Lookup APIs live in domain-major-mode.lisp and
;;;; mutation/validation lives in domain-major-mode-registry.lisp.
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

(defun %static-major-mode-definition (key)
  (cdr (assoc key +major-mode-definitions+)))

(defun %dynamic-major-mode-definition (key)
  (and key (gethash key *registered-major-modes*)))
