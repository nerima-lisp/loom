(in-package #:loom/feature/mode)

(defun %major-mode-token (value)
  (string-downcase
   (string-trim '(#\Space #\Tab #\Newline #\Return)
                (princ-to-string value))))

(defun %major-mode-definition (mode)
  (let ((key (%major-mode-key mode)))
    (or (%dynamic-major-mode-definition key)
        (%static-major-mode-definition key))))

(defun %major-mode-definition-matches-token-p (token key definition)
  (or (string= token (string-downcase (symbol-name key)))
      (string= token (%major-mode-token (getf definition :name)))
      (member token (getf definition :aliases) :test #'string=)))

(defun %major-mode-key-from-definitions (token definitions)
  (loop for (key . definition) in definitions
        when (%major-mode-definition-matches-token-p token key definition)
          return key))

(progn
  (defun major-mode-comment-start (mode)
    (getf (%major-mode-definition mode) :comment-start))
  (defun major-mode-comment-end (mode)
    (getf (%major-mode-definition mode) :comment-end))
  (defun major-mode-skip-closing-delimiter-p (mode)
    (not (null (getf (%major-mode-definition mode)
                     :skip-closing-delimiter)))))

(defun %dynamic-major-mode-key (token)
  (loop for key in *registered-major-mode-order*
        for definition = (%dynamic-major-mode-definition key)
        when (%major-mode-definition-matches-token-p token key definition)
          return key))

(defun %static-major-mode-key (token)
  (%major-mode-key-from-definitions token +major-mode-definitions+))

(defun %major-mode-key (mode)
  (cond
    ((keywordp mode) mode)
    ((symbolp mode) (intern (string-upcase (symbol-name mode)) :keyword))
    ((stringp mode)
     (or (%dynamic-major-mode-key (%major-mode-token mode))
         (%static-major-mode-key (%major-mode-token mode))))
    (t nil)))

(defun major-mode-known-p (mode)
  "Return true when MODE names a built-in or dynamically registered mode."
  (not (null (%major-mode-definition mode))))

(defun major-mode-from-name (name)
  "Resolve a mode name, including the common short aliases."
  (let ((key (%major-mode-key name)))
    (when (and key (%major-mode-definition key)) key)))

(defun major-mode-name (mode)
  "Return the display name for MODE, or NIL for an unknown mode."
  (getf (%major-mode-definition mode) :name))

(defun major-mode-comment-prefix (mode)
  (getf (%major-mode-definition mode) :comment-prefix))

(defun major-mode-indentation-width (mode)
  (or (getf (%major-mode-definition mode) :indentation-width) 2))
(defun major-mode-tab-width (mode)
  "Return MODE’s tab-stop width, defaulting to 8 cells."
  (or (getf (%major-mode-definition mode) :tab-width) 8))

(defun major-mode-language-id (mode)
  (getf (%major-mode-definition mode) :language-id))

(defun major-mode-truncate-lines-p (mode)
  "Return MODE's long-line truncation default.
An absent setting or an unknown mode defaults to T; an explicit NIL wraps."
  (let ((value (getf (%major-mode-definition mode) :truncate-lines :absent)))
    (cond ((eq value :absent) t)
          (t value))))

(defun major-mode-keywords (mode)
  (copy-list (getf (%major-mode-definition mode) :keywords)))

(defun major-mode-parent (mode)
  "Return MODE's parent mode, or NIL when MODE is unknown."
  (let ((definition (%major-mode-definition mode)))
    (and definition
         (or (getf definition :parent) :fundamental))))

(defun major-mode-keybindings (mode)
  "Return a copy of MODE's local keybinding specifications."
  (copy-tree (getf (%major-mode-definition mode) :keybindings)))

(defun major-mode-definition (mode)
  "Return a copy of MODE's complete metadata definition."
  (copy-tree (%major-mode-definition mode)))

(defun major-mode-names ()
  "Return built-in names followed by dynamically registered mode names."
  (append (loop for entry in +major-mode-definitions+
                collect (getf (cdr entry) :name))
          (loop for key in *registered-major-mode-order*
                collect (getf (%dynamic-major-mode-definition key) :name))))

(defun %plain-major-mode-display-lines (source)
  (let ((start 0)
        (length (length source))
        (lines nil))
    (loop for newline = (position #\Newline source :start start)
          do (progn
               (let ((end (or newline length)))
                 (when (and (> end start)
                            (char= (char source (1- end)) #\Return))
                   (decf end))
                 (push (list (list :plain (subseq source start end)))
                       lines))
               (unless newline
                 (return (nreverse lines)))
               (setf start (1+ newline))))))

(defun major-mode-display-lines (source mode)
  "Return display runs per source line through MODE's provider or plain text."
  (check-type source string)
  (let* ((key (major-mode-from-name mode))
         (provider
           (and key
                (gethash key *major-mode-display-lines-providers*))))
    (if provider
        (funcall provider source key)
        (%plain-major-mode-display-lines source))))
