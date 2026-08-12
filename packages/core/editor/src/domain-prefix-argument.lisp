(in-package #:loom)

(defstruct (prefix-argument
            (:constructor %make-prefix-argument))
  (magnitude 1 :type (integer 0 *))
  (active-p nil :type boolean)
  (explicit-p nil :type boolean)
  (negative-p nil :type boolean))

(defun make-prefix-argument ()
  (%make-prefix-argument))

(defun prefix-argument-value (argument)
  (check-type argument prefix-argument)
  (if (prefix-argument-negative-p argument)
      (- (prefix-argument-magnitude argument))
      (prefix-argument-magnitude argument)))

(defun %set-prefix-argument-state (argument magnitude active explicit negative)
  (setf (prefix-argument-magnitude argument) magnitude
        (prefix-argument-active-p argument) active
        (prefix-argument-explicit-p argument) explicit
        (prefix-argument-negative-p argument) negative)
  argument)

(defun %activate-prefix-argument (argument magnitude &key explicit negative)
  (%set-prefix-argument-state argument magnitude t explicit negative))

(defun prefix-argument-universal (argument)
  (check-type argument prefix-argument)
  (if (prefix-argument-active-p argument)
      (setf (prefix-argument-magnitude argument)
            (* 4 (prefix-argument-magnitude argument)))
      (%activate-prefix-argument argument 4))
  argument)

(defun prefix-argument-digit (argument digit)
  (check-type argument prefix-argument)
  (check-type digit (integer 0 9))
  (unless (prefix-argument-active-p argument)
    (%activate-prefix-argument argument 0))
  (setf (prefix-argument-magnitude argument)
        (if (prefix-argument-explicit-p argument)
            (+ (* 10 (prefix-argument-magnitude argument)) digit)
            digit)
        (prefix-argument-explicit-p argument) t)
  argument)

(defun prefix-argument-negative (argument)
  (check-type argument prefix-argument)
  (unless (prefix-argument-active-p argument)
    (%activate-prefix-argument argument 1))
  (setf (prefix-argument-negative-p argument)
        (not (prefix-argument-negative-p argument)))
  argument)

(defun prefix-argument-consume (argument)
  (check-type argument prefix-argument)
  (prog1 (if (prefix-argument-active-p argument)
             (prefix-argument-value argument)
             1)
    (prefix-argument-reset argument)))

(defun prefix-argument-reset (argument)
  (check-type argument prefix-argument)
  (%set-prefix-argument-state argument 1 nil nil nil))
