(defpackage #:loom/feature/lang-web
  (:use #:cl))

(progn
  (defparameter loom/feature/lang-web::+typescript-keywords+
    '("abstract" "any" "as" "asserts" "async" "await" "bigint" "boolean"
      "break" "case" "catch" "class" "const" "constructor" "continue"
      "declare" "default" "delete" "do" "else" "enum" "export" "extends"
      "false" "finally" "for" "from" "function" "get" "if" "implements"
      "import" "in" "infer" "instanceof" "interface" "is" "keyof" "let"
      "namespace" "never" "new" "null" "number" "of" "private" "protected"
      "public" "readonly" "return" "satisfies" "set" "static" "string"
      "super" "switch" "symbol" "this" "throw" "true" "try" "type" "typeof"
      "undefined" "unknown" "var" "void" "while" "yield")
    "Keyword vocabulary shared by the TypeScript and TypeScript React modes.")
  (loom/feature/mode:register-major-mode
   :typescript
   :name "TypeScript"
   :aliases '("ts")
   :extensions '("ts" "mts" "cts")
   :comment-prefix "//" :comment-start "//" :comment-end nil
   :skip-closing-delimiter t
   :indentation-width 2 :tab-width 8
   :truncate-lines t :language-id "typescript"
   :keywords loom/feature/lang-web::+typescript-keywords+)
  (loom/feature/mode:register-major-mode
   :typescript-react
   :name "TypeScript React"
   :aliases '("tsx")
   :extensions '("tsx")
   :comment-prefix "//" :comment-start "//" :comment-end nil
   :skip-closing-delimiter t
   :indentation-width 2 :tab-width 8
   :truncate-lines t :language-id "typescriptreact"
   :keywords loom/feature/lang-web::+typescript-keywords+)
  (loom/feature/mode:register-major-mode
   :json
   :name "JSON"
   :extensions '("json")
   :comment-prefix nil :comment-start nil :comment-end nil
   :skip-closing-delimiter t
   :indentation-width 2 :tab-width 8
   :truncate-lines t :language-id "json"
   :keywords nil)
  (loom/feature/mode:register-major-mode
   :javascript
   :name "JavaScript"
   :aliases '("js" "javascript")
   :extensions '("js" "mjs" "cjs")
   :comment-prefix "//" :comment-start "//" :comment-end nil
   :skip-closing-delimiter t
   :language-id "javascript"
   :indentation-width 2 :tab-width 8
   :keywords '("as" "async" "await" "break" "case" "catch" "class" "const"
               "continue" "debugger" "default" "delete" "do" "else" "export"
               "extends" "false" "finally" "for" "from" "function" "get" "if"
               "import" "in" "instanceof" "let" "new" "null" "of" "return"
               "set" "static" "super" "switch" "this" "throw" "true" "try"
               "typeof" "var" "void" "while" "with" "yield"))
  (loom/feature/mode:register-major-mode
   :javascript-react
   :name "JavaScript React"
   :aliases '("jsx")
   :extensions '("jsx")
   :comment-prefix "//" :comment-start "//" :comment-end nil
   :skip-closing-delimiter t
   :language-id "javascriptreact"
   :indentation-width 2 :tab-width 8
   :keywords '("as" "async" "await" "break" "case" "catch" "class" "const"
               "continue" "debugger" "default" "delete" "do" "else" "export"
               "extends" "false" "finally" "for" "from" "function" "get" "if"
               "import" "in" "instanceof" "let" "new" "null" "of" "return"
               "set" "static" "super" "switch" "this" "throw" "true" "try"
               "typeof" "var" "void" "while" "with" "yield"))
  (loom/feature/mode:register-major-mode
   :html
   :name "HTML"
   :extensions '("html" "htm")
   :comment-prefix nil :comment-start "<!--" :comment-end "-->"
   :skip-closing-delimiter t
   :language-id "html"
   :keywords '("article" "body" "button" "div" "doctype" "footer" "form"
               "head" "header" "html" "img" "input" "li" "link" "main" "meta"
               "nav" "ol" "p" "script" "section" "span" "style" "table" "td"
               "th" "title" "tr" "ul"))
  (loom/feature/mode:register-major-mode
   :css
   :name "CSS"
   :extensions '("css")
   :comment-prefix nil :comment-start "/*" :comment-end "*/"
   :skip-closing-delimiter t
   :language-id "css"
   :keywords '("absolute" "auto" "block" "currentColor" "flex" "fixed" "grid"
               "inherit" "initial" "inline" "important" "none" "relative"
               "revert" "static" "sticky" "transparent" "unset" "var"))
  (progn
  (loom/feature/mode:register-major-mode
   :yaml
   :name "YAML"
   :extensions '("yaml" "yml")
   :comment-prefix "#" :comment-start "#" :comment-end nil
   :skip-closing-delimiter t
   :language-id "yaml"
   :keywords '("false" "no" "null" "off" "on" "true" "yes"))
  (defun loom/feature/lang-web::%opening-for-close (character)
    (case character
      (#\) #\()
      (#\] #\[)
      (#\} #\{)))
  (defun loom/feature/lang-web::%line-leading-column (buffer line-number mode)
    (let* ((line (loom/core/buffer:buffer-line buffer line-number))
           (tab-width (max 1 (loom/feature/mode:major-mode-tab-width mode))))
      (loop with column = 0
            for character across line
            while (member character (list #\Space #\Tab) :test (function char=))
            do (incf column (if (char= character #\Tab)
                               (- tab-width (mod column tab-width))
                               1))
            finally (return column))))
  (defun loom/feature/lang-web::%bracket-indentation-rule (buffer line-number)
  (let* ((text (loom/core/buffer:buffer-text buffer))
         (line-start (loom/core/buffer:buffer-position-offset buffer line-number 0))
         (current-line (loom/core/buffer:buffer-line buffer line-number))
         (first-code
           (position-if-not
            (lambda (character)
              (member character (list #\Space #\Tab) :test (function char=)))
            current-line))
         (mode (loom/core/buffer:buffer-major-mode buffer))
         (width (loom/feature/mode:major-mode-indentation-width mode))
         (stack nil)
         (current-line-number 0)
         (string-delimiter nil)
         (escaped-p nil)
         (line-comment-p nil)
         (block-comment-p nil))
    (loop for index from 0 below line-start
          for character = (char text index)
          for next-character =
            (and (< (1+ index) (length text)) (char text (1+ index)))
          do
             (cond
               ((char= character #\Newline)
                (setf line-comment-p nil)
                (when (and string-delimiter
                           (not (char= string-delimiter (code-char 96)))
                           (not escaped-p))
                  (setf string-delimiter nil))
                (setf escaped-p nil)
                (incf current-line-number))
               (line-comment-p nil)
               (block-comment-p
                (when (and (char= character #\*)
                           next-character
                           (char= next-character #\/))
                  (setf block-comment-p nil)))
               (string-delimiter
                (cond
                  (escaped-p (setf escaped-p nil))
                  ((char= character #\\) (setf escaped-p t))
                  ((char= character string-delimiter)
                   (setf string-delimiter nil))))
               ((and (char= character #\/)
                     next-character
                     (char= next-character #\/))
                (setf line-comment-p t))
               ((and (char= character #\/)
                     next-character
                     (char= next-character #\*))
                (setf block-comment-p t))
               ((or (char= character #\")
                    (char= character #\')
                    (char= character (code-char 96)))
                (setf string-delimiter character))
               ((member character (list #\{ #\[ #\() :test (function char=))
                (let ((opening-indent
                        (if stack
                            (+ (cadar stack) width)
                            (loom/feature/lang-web::%line-leading-column
                             buffer current-line-number mode))))
                  (push (list character opening-indent) stack)))
               ((member character (list #\) #\] #\}) :test (function char=))
                (let ((opening
                        (loom/feature/lang-web::%opening-for-close character)))
                  (when (and stack opening (char= opening (caar stack)))
                    (pop stack))))))
    (let ((closing-opener
            (and first-code
                 (not string-delimiter)
                 (not line-comment-p)
                 (not block-comment-p)
                 (loom/feature/lang-web::%opening-for-close
                  (char current-line first-code)))))
      (cond
        ((and stack closing-opener
              (char= closing-opener (caar stack)))
         (cadar stack))
        (stack (+ (cadar stack) width))
        (t nil)))))
  (dolist (mode
           (list :typescript :typescript-react :javascript
                 :javascript-react :json))
    (loom/feature/mode:register-major-mode-indentation-rule
     mode
     (function loom/feature/lang-web::%bracket-indentation-rule)))
  (progn
    (dolist (mode
             (list :typescript :typescript-react :javascript
                   :javascript-react :css))
      (loom/feature/mode:register-major-mode-pair-completion
       mode #\( #\))
      (loom/feature/mode:register-major-mode-pair-completion
       mode #\[ #\])
      (loom/feature/mode:register-major-mode-pair-completion
       mode #\{ #\}))
    (loom/feature/mode:register-major-mode-pair-completion
     :json #\[ #\])
    (loom/feature/mode:register-major-mode-pair-completion
     :json #\{ #\})
    (loom/feature/mode:register-major-mode-pair-completion
     :html #\< #\>)
    (loom/feature/mode:register-major-mode-pair-completion
     :yaml #\[ #\])
    (loom/feature/mode:register-major-mode-pair-completion
     :yaml #\{ #\}))))
