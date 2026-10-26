(defpackage #:loom/feature/lang-nix
  (:use #:cl))

(progn
  (loom/feature/mode:register-major-mode
   :nix
   :name "Nix"
   :extensions '("nix")
   :comment-prefix "#" :comment-start "#" :comment-end nil
   :skip-closing-delimiter t
   :indentation-width 2 :tab-width 8
   :truncate-lines t :language-id "nix"
   :keywords '("abort" "assert" "baseNameOf" "builtins" "derivation"
               "dirOf" "else" "false" "fetchTarball" "fetchurl" "if"
               "import" "in" "inherit" "isNull" "let" "map" "null" "or"
               "rec" "removeAttrs" "then" "throw" "toString" "true" "with")))
(progn
  (defun loom/feature/lang-nix::%nix-whitespace-p (character)
    (member character '(#\Space #\Tab #\Return) :test #'char=))

  (defun loom/feature/lang-nix::%nix-line-indentation (line tab-width)
    (loop with column = 0
          for index from 0 below (length line)
          for character = (char line index)
          while (loom/feature/lang-nix::%nix-whitespace-p character)
          do (setf column
                   (if (char= character #\Tab)
                       (+ column (- tab-width (mod column tab-width)))
                     (1+ column)))
          finally (return column)))

  (defun loom/feature/lang-nix::%nix-pair-at-p (line index first second)
    (and (< (1+ index) (length line))
         (char= (char line index) first)
         (char= (char line (1+ index)) second)))

  (defun loom/feature/lang-nix::%nix-triple-quote-at-p (line index)
    (and (< (+ index 2) (length line))
         (char= (char line index) #\')
         (char= (char line (1+ index)) #\')
         (char= (char line (+ index 2)) #\')))

  (defun loom/feature/lang-nix::%nix-word-character-p (character)
    (or (alphanumericp character)
        (member character '(#\- #\_ #\') :test #'char=)))

  (defun loom/feature/lang-nix::%nix-line-tokens
      (line line-number indentation state block-depth)
    (let ((tokens nil)
          (index 0)
          (line-length (length line)))
      (labels ((emit (token)
                     (push (list token line-number indentation) tokens)))
        (loop while (< index line-length)
              for character = (char line index)
              do (cond
                  ((eq state :line-comment)
                   (setf index line-length
                         state :code))
                  ((eq state :block-comment)
                   (cond
                    ((loom/feature/lang-nix::%nix-pair-at-p
                      line index #\/ #\*)
                     (incf block-depth)
                     (incf index 2))
                    ((loom/feature/lang-nix::%nix-pair-at-p
                      line index #\* #\/)
                     (decf block-depth)
                     (incf index 2)
                     (when (zerop block-depth)
                       (setf state :code)))
                    (t (incf index))))
                  ((eq state :double-string)
                   (cond
                    ((char= character #\\)
                     (incf index (if (< (1+ index) line-length) 2 1)))
                    ((char= character #\")
                     (setf state :code)
                     (incf index))
                    (t (incf index))))
                  ((eq state :indented-string)
                   (cond
                    ((loom/feature/lang-nix::%nix-triple-quote-at-p
                      line index)
                     (incf index 3))
                    ((loom/feature/lang-nix::%nix-pair-at-p
                      line index #\' #\')
                     (if (and (< (+ index 2) line-length)
                              (member (char line (+ index 2))
                                      '(#\$ #\\)
                                      :test #'char=))
                         (incf index 3)
                       (setf state :code
                             index (+ index 2))))
                    (t (incf index))))
                  ((char= character #\#)
                   (setf state :line-comment))
                  ((loom/feature/lang-nix::%nix-pair-at-p
                    line index #\/ #\*)
                   (setf state :block-comment
                         block-depth 1)
                   (incf index 2))
                  ((loom/feature/lang-nix::%nix-pair-at-p
                    line index #\' #\')
                   (setf state :indented-string)
                   (incf index 2))
                  ((char= character #\")
                   (setf state :double-string)
                   (incf index))
                  ((loom/feature/lang-nix::%nix-whitespace-p character)
                   (incf index))
                  ((loom/feature/lang-nix::%nix-word-character-p character)
                   (let ((end (1+ index)))
                     (loop while (and (< end line-length)
                                      (loom/feature/lang-nix::%nix-word-character-p
                                       (char line end)))
                           do (incf end))
                     (emit (subseq line index end))
                     (setf index end)))
                  (t
                   (emit character)
                   (incf index))))
        (when (eq state :line-comment)
          (setf state :code))
        (values (nreverse tokens) state block-depth))))

  (defun loom/feature/lang-nix::%nix-line-starts-indented-quote-p (line)
    (let ((start (position-if-not
                  #'loom/feature/lang-nix::%nix-whitespace-p line)))
      (and start
           (loom/feature/lang-nix::%nix-pair-at-p line start #\' #\'))))

  (defun loom/feature/lang-nix::%nix-line-ends-indented-quote-p (line)
    (let ((end (position-if-not
                #'loom/feature/lang-nix::%nix-whitespace-p line
                :from-end t)))
      (and end
           (>= end 1)
           (char= (char line end) #\')
           (char= (char line (1- end)) #\'))))

  (defun loom/feature/lang-nix::%nix-string-line-indentation
      (buffer line-number current-line indentation-width tab-width)
    (let* ((previous-line
            (if (plusp line-number)
                (loom/core/buffer:buffer-line buffer (1- line-number))
              ""))
           (previous-indentation
            (loom/feature/lang-nix::%nix-line-indentation
             previous-line tab-width))
           (change
            (+ (if (loom/feature/lang-nix::%nix-line-ends-indented-quote-p
                    previous-line)
                   1
                 0)
               (if (loom/feature/lang-nix::%nix-line-starts-indented-quote-p
                    current-line)
                   -1
                 0))))
      (max 0 (+ previous-indentation (* change indentation-width)))))

  (defun loom/feature/lang-nix::%nix-update-context-stack
      (stack token line-number indentation)
    (cond
     ((and (characterp token)
           (find token '(#\{ #\[ #\() :test #'char=))
      (cons (list :delimiter token line-number indentation) stack))
     ((and (characterp token)
           (find token '(#\} #\] #\)) :test #'char=))
      (let* ((opener (case token
                       (#\} #\{)
                       (#\] #\[)
                       (#\) #\()))
             (match
              (position-if
               (lambda (context)
                 (and (eq (first context) :delimiter)
                      (char= (second context) opener)))
               stack)))
        (if match
            (nthcdr (1+ match) stack)
          stack)))
     ((and (stringp token) (string= token "let"))
      (cons (list :let token line-number indentation) stack))
     ((and (stringp token) (string= token "in"))
      (let ((match (position-if
                    (lambda (context) (eq (first context) :let))
                    stack)))
        (if match (nthcdr (1+ match) stack) stack)))
     ((and (stringp token) (string= token "if"))
      (cons (list :if token line-number indentation) stack))
     ((and (stringp token) (string= token "else"))
      (let ((match (position-if
                    (lambda (context) (eq (first context) :if))
                    stack)))
        (if match (nthcdr (1+ match) stack) stack)))
     (t stack))))

  (defun loom/feature/lang-nix::%nix-context-indentation
      (stack kind &optional token)
    (loop for context in stack
          when (and (eq (first context) kind)
                    (or (null token)
                        (equal (second context) token)))
            do (return (fourth context))))

  (defun loom/feature/lang-nix::%nix-line-ends-after-with-semicolon-p
      (tokens)
    (let* ((last-semicolon
            (and tokens (position #\; tokens :from-end t)))
           (previous-semicolon
            (and last-semicolon
                 (position #\; tokens :end last-semicolon :from-end t))))
      (and last-semicolon
           (= last-semicolon (1- (length tokens)))
           (loop for token in
                 (subseq tokens
                         (if previous-semicolon
                             (1+ previous-semicolon)
                           0)
                         last-semicolon)
                 thereis (and (stringp token)
                              (or (string= token "with")
                                  (string= token "assert")))))))

  (defun loom/feature/lang-nix::%nix-line-opens-expression-p (tokens)
    (let ((last-token (car (last tokens))))
      (or (and (characterp last-token)
               (find last-token '(#\{ #\[ #\( #\=) :test #'char=))
          (and (stringp last-token)
               (member last-token '("let" "if" "then" "else")
                       :test #'string=))
          (loom/feature/lang-nix::%nix-line-ends-after-with-semicolon-p
           tokens))))

  (defun loom/feature/lang-nix::%nix-indentation-rule
      (buffer line-number)
    (let* ((current-line (loom/core/buffer:buffer-line buffer line-number))
           (indentation-width
            (loom/feature/mode:major-mode-indentation-width :nix))
           (tab-width (loom/feature/mode:major-mode-tab-width :nix))
           (state :code)
           (block-depth 0)
           (tokens nil)
           (previous-line-tokens nil)
           (previous-line-indentation 0))
      (loop for prior-line from 0 below line-number
            for line = (loom/core/buffer:buffer-line buffer prior-line)
            for indentation =
            (loom/feature/lang-nix::%nix-line-indentation line tab-width)
            do (multiple-value-bind (line-tokens next-state next-block-depth)
                   (loom/feature/lang-nix::%nix-line-tokens
                    line prior-line indentation state block-depth)
                 (setf tokens (nconc tokens line-tokens)
                       state next-state
                       block-depth next-block-depth)
                 (when line-tokens
                   (setf previous-line-tokens
                         (mapcar #'first line-tokens)
                         previous-line-indentation indentation))))
      (multiple-value-bind (current-tokens next-state next-block-depth)
          (loom/feature/lang-nix::%nix-line-tokens
           current-line line-number
           (loom/feature/lang-nix::%nix-line-indentation
            current-line tab-width)
           state block-depth)
        (declare (ignore next-state next-block-depth))
        (let* ((target-token
                (and current-tokens (first (first current-tokens))))
               (stack nil))
          (dolist (record tokens)
            (setf stack
                  (loom/feature/lang-nix::%nix-update-context-stack
                   stack (first record) (second record) (third record))))
          (cond
           ((member state '(:double-string :indented-string))
            (loom/feature/lang-nix::%nix-string-line-indentation
             buffer line-number current-line indentation-width tab-width))
           ((and (characterp target-token)
                 (find target-token '(#\} #\] #\)) :test #'char=))
            (or (loom/feature/lang-nix::%nix-context-indentation
                 stack :delimiter
                 (case target-token
                   (#\} #\{)
                   (#\] #\[)
                   (#\) #\())) 0))
           ((and (stringp target-token) (string= target-token "in"))
            (or (loom/feature/lang-nix::%nix-context-indentation
                 stack :let)
                0))
           ((and (stringp target-token)
                 (member target-token '("then" "else") :test #'string=))
            (or (loom/feature/lang-nix::%nix-context-indentation
                 stack :if)
                0))
           ((loom/feature/lang-nix::%nix-line-opens-expression-p
             previous-line-tokens)
            (+ previous-line-indentation indentation-width))
           ((first stack)
            (+ (fourth (first stack)) indentation-width))
           (t previous-line-indentation))))))

  (eval-when (:load-toplevel :execute)
    (loom/feature/mode:register-major-mode-indentation-rule
     :nix
     (function loom/feature/lang-nix::%nix-indentation-rule)))
