;;;; packages/core/editor/src/application-structural-editing-support.lisp
;;;;
;;;; Shared list-boundary and delimiter helpers for structural editing.
(in-package #:loom)

(defun %structural-list-close (text classes open)
  (let ((end (%sexp-forward-list-end text classes open)))
    (when end
      (1- end))))

(defun %structural-list-bounds (text classes offset)
  "Return (VALUES OPEN CLOSE) for the list enclosing OFFSET.

  CLOSE is the index of the closing character, not one past it. Returns NIL
when point is not inside a list, or when the list it is inside never closes."
  (let ((open (%backward-up-list-offset text offset classes)))
    (when open
      (let ((close (%structural-list-close text classes open)))
        (when close
          (values open close))))))

(defmacro %with-structural-list-bounds ((open close) (text classes offset)
                                         &body body)
  "Evaluate BODY only when OFFSET is inside a complete list."
  `(multiple-value-bind (,open ,close)
       (%structural-list-bounds ,text ,classes ,offset)
     (when ,close
       ,@body)))

(defun %structural-separator-needed-p (text offset)
  "True when inserting a delimiter at OFFSET would abut a token."
  (and (< offset (length text))
       (let ((character (char text offset)))
         (not (or (%sexp-whitespace-p character)
                  (member character +sexp-close-characters+ :test #'char=))))))

(defun %forward-barf-delimiter (text target delimiter)
  "Return DELIMITER positioned after the expression at TARGET."
  (if (%structural-separator-needed-p text target)
      (concatenate 'string delimiter " ")
      delimiter))

(defun %backward-barf-delimiter (text target delimiter)
  "Return DELIMITER positioned before the expression at TARGET."
  (if (and (plusp target)
           (not (%sexp-whitespace-p (char text (1- target)))))
      (concatenate 'string " " delimiter)
      delimiter))
