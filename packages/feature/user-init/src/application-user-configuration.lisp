;;;; packages/feature/user-init/src/application-user-configuration.lisp
;;;;
;;;; Application-layer API for startup extensions. These operations validate
;;;; all user input before changing the command registry or live keymap.
(in-package #:loom/feature/user-init)

(defun %resolve-user-command (command)
  "Resolve a user command name or callable designator."
  (cond
    ((stringp command)
     (or (loom/application:find-extended-command command)
         (error "Unknown user command: ~S" command)))
    ((functionp command)
     command)
    ((and (symbolp command)
          (fboundp command)
          (null (macro-function command)))
     command)
    (t
     (error "User command is not callable: ~S" command))))

(defun %normalize-user-command-keys (keys)
  "Return copied raw KEYS and their runtime keymap representations."
  (unless (listp keys)
    (error "User command :KEYS must be a proper list: ~S" keys))
  (let ((raw-keys (copy-tree keys))
        (normalized-keys '()))
    (dolist (key-form keys)
      (unless key-form
        (error "User command key forms cannot be NIL."))
      (handler-case
          (push (loom/application:defkeys-key-sequence key-form)
                normalized-keys)
        (error (condition)
          (error "Invalid user command key form ~S: ~A"
                 key-form
                 condition))))
    (values raw-keys (nreverse normalized-keys))))

(defun %user-command-name-in-use-p (name)
  "Return true when NAME already exists in the M-x command registry."
  (find-if (lambda (spec)
             (and (getf spec :name)
                  (string-equal name (getf spec :name))))
           loom/application:*command-specs*))

(defun define-command (name command &key keys)
  "Register a user command NAME and optionally bind its default KEYS.

NAME is case-insensitive in M-x and COMMAND may be a function, a callable
symbol, or the name of an already registered command. When an editor is
active, the new key sequences are also installed in its live keymap."
  (unless (stringp name)
    (error "User command name must be a string: ~S" name))
  (let ((canonical-name (string-downcase
                         (string-trim '(#\Space #\Tab) name))))
    (when (zerop (length canonical-name))
      (error "User command name cannot be empty."))
    (let ((resolved-command (%resolve-user-command command)))
      (multiple-value-bind (raw-keys normalized-keys)
          (%normalize-user-command-keys keys)
        (when (%user-command-name-in-use-p canonical-name)
          (error "User command name is already registered: ~S"
                 canonical-name))
        (setf loom/application:*command-specs*
              (append loom/application:*command-specs*
                      (list (list :name canonical-name
                                  :command resolved-command
                                  :keys raw-keys))))
        (when *editor-state*
          (dolist (key-sequence normalized-keys)
            (keymap-define-key (editor-state-keymap *editor-state*)
                               key-sequence
                               resolved-command)))
        resolved-command))))

(defun bind-key (key-form command)
  "Bind KEY-FORM to COMMAND in the active editor's keymap.

Unlike DEFINE-COMMAND, this does not add a command to the M-x registry."
  (unless *editor-state*
    (error "BIND-KEY requires an active editor state."))
  (let ((resolved-command (%resolve-user-command command)))
    (multiple-value-bind (ignored normalized-keys)
        (%normalize-user-command-keys (list key-form))
      (declare (ignore ignored))
      (keymap-define-key (editor-state-keymap *editor-state*)
                         (first normalized-keys)
                         resolved-command)
      resolved-command)))
