(defpackage #:loom/feature/lang-lisp
  (:use #:cl))

(progn
  (loom/feature/mode:register-major-mode
   :common-lisp
   :name "Common Lisp"
   :aliases '("lisp" "cl" "common lisp")
   :extensions '("lisp" "lsp" "cl")
   :comment-prefix ";" :comment-start ";" :comment-end nil
   :skip-closing-delimiter t
   :indentation-width 2 :tab-width 8
   :truncate-lines t :language-id "commonlisp"
   :keywords '("and" "block" "case" "catch" "defclass" "defconstant"
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
  (loom/feature/mode:register-major-mode
   :emacs-lisp
   :name "Emacs Lisp"
   :aliases '("el" "elisp")
   :extensions '("el")
   :comment-prefix ";" :comment-start ";" :comment-end nil
   :skip-closing-delimiter t
   :indentation-width 2 :tab-width 8
   :truncate-lines t :language-id "emacs-lisp"
   :keywords '("and" "catch" "cl-defmacro" "cl-defun" "cond"
               "condition-case" "defcustom" "defface" "defgroup"
               "defmacro" "defsubst" "defun" "defvar" "defvar-local"
               "dolist" "dotimes" "if" "ignore-errors" "interactive"
               "lambda" "let" "let*" "nil" "or" "pcase" "prog1" "progn"
               "provide" "require" "save-excursion" "save-restriction"
               "setq" "setq-default" "t" "throw" "unless"
               "unwind-protect" "when" "while" "with-current-buffer"
               "with-temp-buffer")))
