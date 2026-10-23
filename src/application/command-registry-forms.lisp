(in-package #:loom/application)

(defun %validate-command-metadata
    (name command help help-order mutates prompts needs-region external modes)
  "Validate the literal metadata accepted by COMMAND-SPEC."
  (unless (or (null name) (stringp name))
    (error "COMMAND-SPEC name must be a string or NIL: ~S" name))
  (unless (symbolp command)
    (error "COMMAND-SPEC command must be a symbol: ~S" command))
  (unless (or (null help) (stringp help))
    (error "COMMAND-SPEC help must be a string or NIL: ~S" help))
  (unless (or (null help-order) (integerp help-order))
    (error "COMMAND-SPEC help-order must be an integer or NIL: ~S" help-order))
  (unless (member mutates '(nil t))
    (error "COMMAND-SPEC :MUTATES must be true or false: ~S" mutates))
  (unless (and (listp prompts)
               (every (lambda (prompt)
                        (member prompt '(:free-string :completion :yes-no :numeric)))
                      prompts))
    (error "COMMAND-SPEC :PROMPTS must be a list of prompt kinds: ~S" prompts))
  (unless (member needs-region '(nil t))
    (error "COMMAND-SPEC :NEEDS-REGION must be true or false: ~S" needs-region))
  (unless (and (listp external) (every #'stringp external))
    (error "COMMAND-SPEC :EXTERNAL must be a list of strings: ~S" external))
  (unless (and (listp modes) (every #'keywordp modes))
    (error "COMMAND-SPEC :MODES must be a list of mode keywords: ~S" modes))
  (values name command help help-order mutates prompts needs-region external modes))

(defmacro command-spec
    (name command &key keys help help-order mutates prompts needs-region external
                       (modes '(:all)))
  "Describe COMMAND's M-x NAME and its optional registry metadata."
  (%validate-command-metadata name command help help-order mutates prompts
                              needs-region external modes)
  `(list :name ,name
         :command ',command
         :keys ',keys
         :help ,help
         :help-order ,help-order
         :mutates ,mutates
         :prompts ',prompts
         :needs-region ,needs-region
         :external ',external
         :modes ',modes))

(defmacro command-spec-group (name &body specs)
  "Group related COMMAND-SPEC forms for readability in the composition root."
  (declare (ignore name specs))
  (error "COMMAND-SPEC-GROUP is only valid inside DEFINE-COMMAND-SPECS."))

(defmacro define-command-spec-groups (variable-name &body groups)
  "Define VARIABLE-NAME as declarative COMMAND-SPEC-GROUP forms."
  (%validate-command-spec-entries
   (%collect-command-spec-entries groups))
  `(defparameter ,variable-name ',groups))
