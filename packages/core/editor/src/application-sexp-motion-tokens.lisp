;;;; packages/core/editor/src/application-sexp-motion-tokens.lisp
;;;;
;;;; Application-layer S-expression token boundary helpers.
;;;;
(in-package #:loom)

(defun %sexp-string-run-end (classes start)
  "Return the position just after the string run beginning at START."
  (let ((end start))
    (loop while (and (< end (length classes))
                     (eq (aref classes end) :string))
          do (incf end))
    end))

(defun %sexp-string-run-start (classes end)
  "Return the position where the string run ending before END begins."
  (let ((start (1- end)))
    (loop while (and (plusp start)
                     (eq (aref classes (1- start)) :string))
          do (decf start))
    start))

(defun %sexp-forward-atom-end (text classes start)
  (let ((end (%sexp-atom-end text classes start)))
    (and (> end start) end)))

(defun %sexp-backward-atom-start (text classes end)
  (let ((start (%sexp-atom-start text classes end)))
    (and (< start end) start)))

(defun %forward-sexp-token-end (text classes start)
  "Return the end of the token beginning at START, or NIL."
  (cond
    ((%sexp-close-p text classes start) nil)
    ((%sexp-open-p text classes start)
     (%sexp-forward-list-end text classes start))
    ((eq (aref classes start) :string)
     (%sexp-string-run-end classes start))
    (t (%sexp-forward-atom-end text classes start))))

(defun %backward-sexp-token-start (text classes end)
  "Return the start of the token ending before END, or NIL."
  (let ((last (1- end)))
    (cond
      ((%sexp-open-p text classes last) nil)
      ((%sexp-close-p text classes last)
       (%sexp-backward-list-start text classes end))
      ((eq (aref classes last) :string)
       (%sexp-string-run-start classes end))
      (t (%sexp-backward-atom-start text classes end)))))
