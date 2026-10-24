(in-package #:loom/feature/user-init)

(defun %resolve-user-command (command)
  "Resolve COMMAND to a callable designator or a registered command ID."
  (cond
    ((stringp command)
     (let ((spec (loom/core/command:find-extended-command-spec command)))
       (if spec
           (values nil (loom/core/command:command-spec-id spec))
           (error "Unknown user command: ~S" command))))
    ((functionp command)
     (values command nil))
    ((and (symbolp command) (fboundp command) (null (macro-function command)))
     (values command nil))
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
      (handler-case (push (loom/core/command:defkeys-key-sequence key-form)
                          normalized-keys)
        (error (condition)
          (error "Invalid user command key form ~S: ~A" key-form condition))))
    (values raw-keys (nreverse normalized-keys))))

(defun %user-key-command-id (key-sequence)
  "Return a stable key-only command ID for normalized KEY-SEQUENCE."
  (labels ((descriptor-id (descriptor)
             (let* ((modifiers
                      (sort (copy-list (car descriptor))
                            #'string<
                            :key #'symbol-name))
                    (code (cdr descriptor))
                    (code-name
                      (typecase code
                        (character
                         (concatenate
                          'string "u"
                          (string-downcase
                           (format nil "~X" (char-code code)))))
                        (keyword
                         (concatenate
                          'string "k"
                          (string-downcase (symbol-name code))))
                        (t
                         (error "Unsupported user key descriptor: ~S"
                                descriptor)))))
               (format nil "~{~A~}~A"
                       (mapcar
                        (lambda (modifier)
                          (concatenate
                           'string
                           (string-downcase (symbol-name modifier))
                           "-"))
                        modifiers)
                       code-name))))
    (format nil "user-init/key/~{~A~^/~}"
            (mapcar #'descriptor-id key-sequence))))

(defun define-command (name command &key keys)
  "Register a user command NAME and optionally bind its default KEYS.

NAME is case-insensitive in M-x and COMMAND may be a function, a callable
symbol, or the name of an already registered command. When an editor is
active, the new key sequences are also installed in its live keymap."
  (unless (stringp name)
    (error "User command name must be a string: ~S" name))
  (let ((canonical-name (string-downcase (string-trim '(#\Space #\Tab) name))))
    (when (string= canonical-name "")
      (error "User command name cannot be empty."))
    (multiple-value-bind (command-designator registered-id)
        (%resolve-user-command command)
      (let* ((command-function
               (if registered-id
                   (lambda (&rest arguments)
                     (apply #'loom/core/command:invoke-command
                            registered-id :mx arguments))
                   command-designator))
             (id (concatenate 'string "user-init/" canonical-name)))
        (multiple-value-bind (raw-keys normalized-keys)
            (%normalize-user-command-keys keys)
          (loom/core/command:register-command-spec
           :feature/user-init id canonical-name command-function
           :keys raw-keys :keymap :global :group nil :help nil :help-order nil
           :mutates nil :prompts nil :needs-region nil :external nil
           :modes '(:all))
          (when loom/core/editor-session:*editor-state*
            (dolist (key-sequence normalized-keys)
              (loom/core/command:keymap-define-key
               (loom/core/editor-session:editor-state-keymap
                loom/core/editor-session:*editor-state*)
               key-sequence
               id)))
          id)))))

(defun bind-key (key-form command)
  "Bind KEY-FORM to COMMAND in the active editor's keymap.

A callable COMMAND is registered as a key-only command with no M-x name."
  (unless loom/core/editor-session:*editor-state*
    (error "BIND-KEY requires an active editor state."))
  (multiple-value-bind (raw-keys normalized-keys)
      (%normalize-user-command-keys (list key-form))
    (multiple-value-bind (command-designator registered-id)
        (%resolve-user-command command)
      (let* ((keymap
               (loom/core/editor-session:editor-state-keymap
                loom/core/editor-session:*editor-state*))
             (key-sequence (first normalized-keys))
             (id (or registered-id (%user-key-command-id key-sequence))))
        (unless registered-id
          (loom/core/command:register-key-command
           :feature/user-init id command-designator :global raw-keys
           :group nil :help nil :help-order nil
           :mutates nil :prompts nil :needs-region nil :external nil :modes '(:all)))
        (loom/core/command:keymap-define-key keymap key-sequence id)
        id))))
