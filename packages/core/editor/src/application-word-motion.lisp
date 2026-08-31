;;;; packages/core/editor/src/application-word-motion.lisp
;;;;
;;;; Application-layer word-boundary helpers shared by movement and kill
;;;; commands. These stay separate from the command entrypoints so both files
;;;; depend on one small text/offset unit instead of depending on each other.
(in-package #:loom)

(defun %word-character-p (character)
  "Return true when CHARACTER belongs to an Emacs-style word."
  (or (alphanumericp character)
      (char= character #\_)))

(defun %forward-word-offset (text offset)
  (let ((length (length text)))
    (loop while (and (< offset length)
                     (not (%word-character-p (char text offset))))
          do (incf offset))
    (loop while (and (< offset length)
                     (%word-character-p (char text offset)))
          do (incf offset))
    offset))

(defun %backward-word-offset (text offset)
  (loop while (and (plusp offset)
                   (not (%word-character-p (char text (1- offset)))))
        do (decf offset))
  (loop while (and (plusp offset)
                   (%word-character-p (char text (1- offset))))
        do (decf offset))
  offset)
