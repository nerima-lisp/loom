(in-package #:loom/test)

(defun %search-char-key (character)
  (cl-tty-kit:make-key-event :type :character :code character))

(defun %search-special-key (code)
  (cl-tty-kit:make-key-event :type :special :code code))

(defun %search-type-string (minibuffer string)
  (loop for character across string
        do (minibuffer-handle-key minibuffer (%search-char-key character))))
