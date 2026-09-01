;;;; packages/core/editor/src/application-sexp-motion-support.lisp
;;;;
;;;; Internal scanning primitives for S-expression motion.
;;;;
(in-package #:loom)

(defun %sexp-skip-forward-filler (text classes offset)
  "Return the first index at or after OFFSET that begins something readable."
  (let ((length (length text)))
    (loop while (and (< offset length)
                     (or (eq (aref classes offset) :comment)
                         (and (%sexp-code-p classes offset)
                              (%sexp-whitespace-p (char text offset)))))
          do (incf offset))
    offset))

(defun %sexp-skip-backward-filler (text classes offset)
  "Return the first index at or before OFFSET that ends something readable."
  (loop while (and (plusp offset)
                   (or (eq (aref classes (1- offset)) :comment)
                       (and (%sexp-code-p classes (1- offset))
                            (%sexp-whitespace-p (char text (1- offset))))))
        do (decf offset))
  offset)

(defun %sexp-forward-list-depth-step (text classes position depth)
  (cond
    ((%sexp-open-p text classes position) (values (1+ depth) nil))
    ((%sexp-close-p text classes position)
     (let ((next-depth (1- depth)))
       (values next-depth (zerop next-depth))))
    (t (values depth nil))))

(defun %sexp-forward-list-end (text classes offset)
  "Return the index just past the list opening at OFFSET, or NIL if unbalanced."
  (let ((length (length text))
        (depth 0)
        (position offset))
    (loop while (< position length)
          do (multiple-value-bind (next-depth complete)
                 (%sexp-forward-list-depth-step text classes position depth)
               (setf depth next-depth)
               (when complete
                 (return-from %sexp-forward-list-end (1+ position)))
               (incf position)))
    nil))

(defun %sexp-backward-list-depth-step (text classes position depth)
  (cond
    ((%sexp-close-p text classes position) (values (1+ depth) nil))
    ((%sexp-open-p text classes position)
     (let ((next-depth (1- depth)))
       (values next-depth (zerop next-depth))))
    (t (values depth nil))))

(defun %sexp-backward-list-start (text classes offset)
  "Return the index of the list whose closing character ends at OFFSET.

OFFSET is exclusive, as a backward motion's starting point always is. Returns
NIL when the parentheses do not balance."
  (let ((depth 0)
        (position (1- offset)))
    (loop while (>= position 0)
          do (multiple-value-bind (next-depth complete)
                 (%sexp-backward-list-depth-step text classes position depth)
               (setf depth next-depth)
               (when complete
                 (return-from %sexp-backward-list-start position)))
             (decf position))
    nil))

(defun %sexp-atom-character-p (text classes offset)
  (or (eq (aref classes offset) :atom)
      (and (%sexp-code-p classes offset)
           (not (%sexp-whitespace-p (char text offset)))
           (not (%sexp-open-p text classes offset))
           (not (%sexp-close-p text classes offset))
           (not (char= (char text offset) #\")))))

(defun %sexp-atom-end (text classes offset)
  (let ((length (length text)))
    (loop while (and (< offset length)
                     (%sexp-atom-character-p text classes offset))
          do (incf offset))
    offset))

(defun %sexp-atom-start (text classes offset)
  (loop while (and (plusp offset)
                   (%sexp-atom-character-p text classes (1- offset)))
        do (decf offset))
  offset)
