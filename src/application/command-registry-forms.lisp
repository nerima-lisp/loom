;;;; src/application/command-registry-forms.lisp
;;;;
;;;; Application-layer declarative command registry forms. These macros define
;;;; the DSL surface that command catalog files write against; normalization
;;;; and validation live in command-registry-build.lisp.
(in-package #:loom/application)

(defun %validate-command-metadata (name command help help-order)
  "Validate the literal metadata accepted by COMMAND-SPEC."
  (unless (or (null name) (stringp name))
    (error "COMMAND-SPEC name must be a string or NIL: ~S" name))
  (unless (symbolp command)
    (error "COMMAND-SPEC command must be a symbol: ~S" command))
  (unless (or (null help) (stringp help))
    (error "COMMAND-SPEC help must be a string or NIL: ~S" help))
  (unless (or (null help-order) (integerp help-order))
    (error "COMMAND-SPEC help-order must be an integer or NIL: ~S" help-order))
  (values name command help help-order))

(defmacro command-spec (name command &key keys help help-order)
  "Describe COMMAND's M-x NAME and its optional registry metadata."
  (%validate-command-metadata name command help help-order)
  `(list :name ,name
         :command ',command
         :keys ',keys
         :help ,help
         :help-order ,help-order))

(defmacro command-spec-group (name &body specs)
  "Group related COMMAND-SPEC forms for readability in the composition root."
  (declare (ignore name specs))
  (error "COMMAND-SPEC-GROUP is only valid inside DEFINE-COMMAND-SPECS."))

(defmacro define-command-spec-groups (variable-name &body groups)
  "Define VARIABLE-NAME as declarative COMMAND-SPEC-GROUP forms."
  (%validate-command-spec-entries
   (%collect-command-spec-entries groups))
  `(defparameter ,variable-name ',groups))
