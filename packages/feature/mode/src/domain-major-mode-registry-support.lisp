;;;; packages/feature/mode/src/domain-major-mode-registry-support.lisp

(in-package #:loom/feature/mode)

(defun %new-major-mode-key (mode)
  (unless (or (keywordp mode) (symbolp mode))
    (error "A new major mode must be named by a symbol or keyword: ~S" mode))
  (intern (string-upcase (symbol-name mode)) :keyword))

(defun %normalize-major-mode-string-list (value label &key strip-leading-dot)
  (unless (listp value)
    (error "~A must be a list of strings: ~S" label value))
  (let ((result '()))
    (dolist (item value (nreverse result))
      (unless (stringp item)
        (error "~A must contain only strings: ~S" label item))
      (let ((text (%major-mode-token item)))
        (when (and strip-leading-dot (plusp (length text))
                   (char= (char text 0) #\.))
          (setf text (subseq text 1)))
        (when (zerop (length text))
          (error "~A cannot contain an empty string: ~S" label item))
        (push text result)))))

(defun %validate-major-mode-text (value label)
  (unless (or (null value) (stringp value))
    (error "~A must be a string or NIL: ~S" label value))
  (when (and value
             (zerop (length (string-trim '(#\Space #\Tab #\Newline #\Return)
                                          value))))
    (error "~A cannot be empty: ~S" label value))
  value)

(defun %validate-major-mode-keywords (keywords)
  (unless (listp keywords)
    (error "Major-mode keywords must be a list of strings: ~S" keywords))
  (dolist (keyword keywords)
    (unless (stringp keyword)
      (error "Major-mode keywords must contain only strings: ~S" keyword)))
  (copy-list keywords))

(defun %validate-major-mode-keybindings (keybindings)
  (unless (listp keybindings)
    (error "Major-mode keybindings must be a list: ~S" keybindings))
  (dolist (binding keybindings)
    (unless (and (consp binding) (car binding) (cdr binding))
      (error "Major-mode keybindings must be (KEY-FORM . COMMAND): ~S"
             binding)))
  (copy-tree keybindings))
