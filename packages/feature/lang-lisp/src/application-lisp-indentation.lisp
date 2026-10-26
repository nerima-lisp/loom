(in-package #:loom)

(defun %lisp-indent-line-start-offset (buffer line-number)
  (loop for previous-line below line-number
        sum (1+ (length (loom/core/buffer:buffer-line buffer previous-line)))))

(defun %lisp-indent-first-code-offset (text classes line-start line-end)
  (loop for position from line-start below line-end
        for class = (aref classes position)
        unless (or (eq class :comment)
                   (and (eq class :code)
                        (%sexp-whitespace-p (char text position))))
          do (return position)
        finally (return line-end)))

(defun %lisp-indent-noncode-line-p (text classes line-start line-end first-code)
  (and (= first-code line-end)
       (or
        (loop for position from line-start below line-end
              thereis (eq (aref classes position) :comment))
        (and (= line-start line-end)
             (< line-start (length text))
             (member (aref classes line-start) (quote (:comment :string)))))))

(defun %lisp-indent-column-at-offset (text offset)
  (let ((newline (position #\Newline text :end offset :from-end t)))
    (- offset
       (if newline
           (1+ newline)
           0))))

(defun %lisp-indent-operator-name (operator)
  (when operator
    (let* ((package-separator (position #\: operator :from-end t))
           (name
            (if package-separator
                (subseq operator (1+ package-separator))
                operator)))
      (string-downcase name))))

(defun %lisp-indent-list-head (text classes open-offset)
  (let* ((head-start (%sexp-skip-forward-filler text classes (1+ open-offset)))
         (head-end
          (and (< head-start (length text))
               (%forward-sexp-offset text head-start classes)))
         (operator
          (and head-end
               (or (eq (aref classes head-start) :atom)
                   (%sexp-code-atom-character-p text classes head-start))
               (subseq text head-start head-end))))
    (values (%lisp-indent-operator-name operator) head-end)))

(defun %lisp-indent-completed-arguments (text classes open-offset target-offset)
  (multiple-value-bind (operator head-end)
      (%lisp-indent-list-head text classes open-offset)
    (let ((position
           (and head-end (%sexp-skip-forward-filler text classes head-end)))
          (first-argument nil)
          (completed-count 0))
      (loop while (and position (< position target-offset))
            do (let ((end (%forward-sexp-offset text position classes)))
                 (unless (and end (<= end target-offset))
                   (return))
                 (unless first-argument
                   (setf first-argument position))
                 (incf completed-count)
                 (setf position (%sexp-skip-forward-filler text classes end))))
      (values operator first-argument completed-count))))

(defun %lisp-indent-flet-definition-p (text classes open-offset)
  (let* ((definition-list-open
          (%backward-up-list-offset text open-offset classes))
         (form-open
          (and definition-list-open
               (%backward-up-list-offset text definition-list-open classes))))
    (when form-open
      (multiple-value-bind (operator head-end)
          (%lisp-indent-list-head text classes form-open)
        (let ((first-argument
               (and head-end (%sexp-skip-forward-filler text classes head-end))))
          (and first-argument
               (= first-argument definition-list-open)
               (member operator '("flet" "labels" "macrolet") :test #'string=)))))))

(defun %lisp-indent-special-form-argument-count (operator)
  (cond
    ((member operator '("progn" "tagbody") :test #'string=) 0)
    ((member operator
             '("block" "catch"
                       "case"
                       "ccase"
                       "ecase"
                       "typecase"
                       "etypecase"
                       "if"
                       "lambda"
                       "let"
                       "let*"
                       "when"
                       "unless"
                       "flet"
                       "labels"
                       "macrolet"
                       "symbol-macrolet"
                       "dolist"
                       "dotimes"
                       "with-slots"
                       "multiple-value-call"
                       "with-output-to-string")
             :test
             #'string=) 1)
    ((member operator '("do" "do*" "multiple-value-bind") :test #'string=) 2)
    ((and operator
          (>= (length operator) 3)
          (string= (subseq operator 0 3) "def")) 2)
    ((and operator
          (>= (length operator) 5)
          (string= (subseq operator 0 5) "with-")) 1)
    (t nil)))

(defun %lisp-indent-open-list (text classes open-offset target-offset)
  (multiple-value-bind (operator first-argument completed-count)
      (%lisp-indent-completed-arguments text classes open-offset target-offset)
    (let* ((special-count
            (if (%lisp-indent-flet-definition-p text classes open-offset)
                1
                (%lisp-indent-special-form-argument-count operator)))
           (open-column (%lisp-indent-column-at-offset text open-offset)))
      (cond
        ((and operator (string= operator "cond"))
         (+ open-column 2))
        ((member operator
                 (list "case" "ccase" "ecase" "typecase" "etypecase")
                 :test (function string=))
         (if (zerop completed-count)
             (+ open-column 4)
             (+ open-column 2)))
        ((member operator
                 (list "defvar" "defparameter" "defconstant")
                 :test (function string=))
         (if (zerop completed-count)
             (+ open-column 4)
             (+ open-column 2)))
        ((and operator (string= operator "loop"))
         (+ open-column 6))
        ((and special-count (>= completed-count special-count))
         (+ open-column 2))
        (first-argument
         (%lisp-indent-column-at-offset text first-argument))
        (t
         (1+ open-column))))))

(defun %lisp-indent-line-rule (buffer line-number)
  (let* ((text (loom/core/buffer:buffer-text buffer))
         (classes (%sexp-syntax-classes text))
         (line-start (%lisp-indent-line-start-offset buffer line-number))
         (line-end
          (or (position #\Newline text :start line-start) (length text)))
         (first-code
          (%lisp-indent-first-code-offset text classes line-start line-end)))
    (cond
      ((or
        (%lisp-indent-noncode-line-p text
                                     classes
                                     line-start
                                     line-end
                                     first-code)
        (and (< first-code line-end)
             (eq (aref classes first-code) :string)
             (not (char= (char text first-code) #\"))))
       nil)
      ((and (< first-code line-end) (%sexp-close-p text classes first-code))
       (let* ((open-offset
              (%backward-up-list-offset text first-code classes))
             (last-expression
              (%backward-sexp-offset text first-code classes)))
        (if open-offset
            (if (and last-expression (> last-expression open-offset))
                (%lisp-indent-column-at-offset text last-expression)
                (%lisp-indent-column-at-offset text open-offset))
            0)))
      (t
       (let ((open-offset (%backward-up-list-offset text line-start classes)))
         (if open-offset
             (%lisp-indent-open-list text classes open-offset line-start)
             0))))))

(eval-when (:load-toplevel :execute)
  (loom/feature/mode:register-major-mode-indentation-rule :common-lisp
                                                          #'%lisp-indent-line-rule)
  (loom/feature/mode:register-major-mode-indentation-rule :emacs-lisp
                                                          #'%lisp-indent-line-rule))
