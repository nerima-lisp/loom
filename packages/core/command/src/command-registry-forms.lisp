(in-package #:loom/core/command)

(defun %validate-command-metadata
    (name command help help-order mutates mutates-p prompts prompts-p
     needs-region needs-region-p external external-p modes modes-p)
  "Validate command metadata and require every catalog classification field."
  (unless (or (null name) (stringp name))
    (error "COMMAND-SPEC name must be a string or NIL: ~S" name))
  (unless (or (symbolp command) (functionp command))
    (error "COMMAND-SPEC command must be a function designator: ~S" command))
  (unless (or (null help) (stringp help))
    (error "COMMAND-SPEC help must be a string or NIL: ~S" help))
  (unless (or (null help-order) (integerp help-order))
    (error "COMMAND-SPEC help-order must be an integer or NIL: ~S" help-order))
  (unless mutates-p
    (error "COMMAND-SPEC requires :MUTATES metadata"))
  (unless prompts-p
    (error "COMMAND-SPEC requires :PROMPTS metadata"))
  (unless needs-region-p
    (error "COMMAND-SPEC requires :NEEDS-REGION metadata"))
  (unless external-p
    (error "COMMAND-SPEC requires :EXTERNAL metadata"))
  (unless modes-p
    (error "COMMAND-SPEC requires :MODES metadata"))
  (unless (member mutates '(nil t))
    (error "COMMAND-SPEC :MUTATES must be true or false: ~S" mutates))
  (unless (and (listp prompts)
               (every (lambda (prompt)
                        (member prompt '(:free-string :completion :yes-no :numeric)))
                      prompts))
    (error "COMMAND-SPEC :PROMPTS must be a list of prompt kinds: ~S" prompts))
  (unless (member needs-region '(nil t))
    (error "COMMAND-SPEC :NEEDS-REGION must be true or false: ~S" needs-region))
  (unless (and (listp external)
               (every (lambda (identifier)
                        (and (stringp identifier)
                             (plusp (length identifier))
                             (every (lambda (character)
                                      (or (and (char<= #\a character)
                                               (char<= character #\z))
                                          (and (char<= #\0 character)
                                               (char<= character #\9))
                                          (find character "-_.")))
                                    identifier)))
                      external))
    (error "COMMAND-SPEC :EXTERNAL values must be lowercase identifiers: ~S"
           external))
  (unless (and (listp modes) (every #'keywordp modes))
    (error "COMMAND-SPEC :MODES must be a list of mode keywords: ~S" modes))
  (values name command help help-order mutates prompts needs-region external modes))

(defmacro command-spec
    (name command &key keys help help-order
                       (mutates nil mutates-p)
                       (prompts nil prompts-p)
                       (needs-region nil needs-region-p)
                       (external nil external-p)
                       (modes nil modes-p))
  "Describe COMMAND's M-x NAME and its registry metadata."
  (%validate-command-metadata
   name command help help-order
   mutates mutates-p prompts prompts-p
   needs-region needs-region-p external external-p modes modes-p)
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
