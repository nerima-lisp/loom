(in-package #:loom/application)

(defun %validate-command-options (options)
  "Validate the keyword/value tail of a COMMAND-SPEC form."
  (unless (evenp (length options))
    (error "COMMAND-SPEC options must be keyword/value pairs: ~S" options))
  (loop for (key value) on options by #'cddr
        unless (member key '(:keys :help :help-order) :test #'eq)
          do (error "Unknown COMMAND-SPEC option: ~S" key)
        when (and (eq key :keys)
                  (not (or (null value) (listp value))))
          do (error "COMMAND-SPEC keys must be a list or NIL: ~S" value))
  options)

(defun %validate-command-metadata (name command help help-order
                                    &optional keys)
  "Validate the literal metadata accepted by COMMAND-SPEC."
  (unless (or (null name) (stringp name))
    (error "COMMAND-SPEC name must be a string or NIL: ~S" name))
  (unless (symbolp command)
    (error "COMMAND-SPEC command must be a symbol: ~S" command))
  (unless (or (null help) (stringp help))
    (error "COMMAND-SPEC help must be a string or NIL: ~S" help))
  (unless (or (null help-order) (integerp help-order))
    (error "COMMAND-SPEC help-order must be an integer or NIL: ~S" help-order))
  (unless (or (null keys) (listp keys))
    (error "COMMAND-SPEC keys must be a list or NIL: ~S" keys))
  (values name command keys help help-order))

(defmacro command-spec (name command &rest options)
  "Describe COMMAND's M-x NAME and its optional registry metadata."
  (%validate-command-options options)
  (let ((keys (getf options :keys))
        (help (getf options :help))
        (help-order (getf options :help-order)))
    (%validate-command-metadata name command help help-order keys)
    `(list :name ,name
           :command ',command
           :keys ',keys
           :help ,help
           :help-order ,help-order)))

(defmacro command-spec-group (name &body specs)
  "Group related COMMAND-SPEC forms for readability in the composition root."
  (declare (ignore name specs))
  (error "COMMAND-SPEC-GROUP is only valid inside DEFINE-COMMAND-SPECS."))

(defmacro define-command-spec-groups (variable-name &body groups)
  "Define VARIABLE-NAME as declarative COMMAND-SPEC-GROUP forms."
  (%validate-command-spec-entries
   (%collect-command-spec-entries groups))
  `(defparameter ,variable-name ',groups))
