(in-package #:loom/core/command)

(defun %parse-command-spec-form (spec &optional group)
  "Return SPEC normalized as registry fields, including its GROUP."
  (unless (and (consp spec) (eq (first spec) 'command-spec))
    (error "Expected a COMMAND-SPEC form, got: ~S" spec))
  (destructuring-bind
      (operator name command &key keys help help-order
                               (mutates nil mutates-p)
                               (prompts nil prompts-p)
                               (needs-region nil needs-region-p)
                               (external nil external-p)
                               (modes '(:all) modes-p))
      spec
    (declare (ignore operator))
    (%validate-command-metadata
     name command help help-order
     mutates mutates-p prompts prompts-p
     needs-region needs-region-p external external-p modes modes-p)
    (list name command group keys help help-order mutates prompts needs-region
          external modes)))

(defun %command-spec-group-p (spec)
  (and (consp spec)
       (eq (first spec) 'command-spec-group)))

(defun %collect-command-spec-entry (spec &optional group)
  (if (%command-spec-group-p spec)
      (destructuring-bind (operator group-name &body group-specs) spec
        (declare (ignore operator))
        (unless (stringp group-name)
          (error "COMMAND-SPEC-GROUP name must be a string: ~S" group-name))
        (%collect-command-spec-entries group-specs group-name))
      (list (%parse-command-spec-form spec group))))

(defun %collect-command-spec-entries (specs &optional group)
  "Flatten SPECS from DEFINE-COMMAND-SPECS into validated registry entries."
  (mapcan (lambda (spec) (%collect-command-spec-entry spec group)) specs))

(defun %duplicate-command-spec-name (entries)
  "Return the first duplicated non-NIL command name in ENTRIES."
  (let ((names (make-hash-table :test (function equalp))))
    (loop for (name) in entries
          when name
            do (when (gethash name names)
                 (return name))
               (setf (gethash name names) t))))

(defun %validate-command-spec-entries (entries)
  "Signal an error when ENTRIES contains duplicate command names."
  (let ((duplicate (%duplicate-command-spec-name entries)))
    (when duplicate
      (error "Duplicate COMMAND-SPEC name: ~S" duplicate)))
  entries)

(defun %emit-command-spec-entries (entries)
  "Return runtime registry entries for ENTRIES."
  (mapcar
   (lambda (entry)
     (destructuring-bind
         (name command group keys help help-order mutates prompts needs-region
               external modes)
         entry
       (list :name name
             :group group
             :command command
             :keys keys
             :help help
             :help-order help-order
             :mutates mutates
             :prompts prompts
             :needs-region needs-region
             :external external
             :modes modes)))
   entries))

(defun %command-spec-entry-form (entry)
  "Return the source form that constructs one runtime registry entry."
  (destructuring-bind
      (name command group keys help help-order mutates prompts needs-region
            external modes)
      entry
    `(list :name ,name
           :group ,group
           :command ',command
           :keys ',keys
           :help ,help
           :help-order ,help-order
           :mutates ,mutates
           :prompts ',prompts
           :needs-region ,needs-region
           :external ',external
           :modes ',modes)))

(defun build-command-specs (&rest spec-blocks)
  "Return validated runtime registry entries from declarative SPEC-BLOCKS."
  (%emit-command-spec-entries
   (%validate-command-spec-entries
    (%collect-command-spec-entries
     (loop for spec-block in spec-blocks append spec-block)))))

(defmacro define-command-specs (&body specs)
  "Define the command registry from COMMAND-SPEC forms.

Each spec provides an extended-command name and default key sequence data.
NIL names describe keymap-only commands such as M-x itself. The explicit
registry is used for lookup."
  (let ((entries (%validate-command-spec-entries
                  (%collect-command-spec-entries specs))))
    `(defparameter *command-specs*
       (list
        ,@(mapcar #'%command-spec-entry-form
           entries)))))

(defmacro define-command-spec-catalog (&rest spec-blocks)
  "Define the command registry from declarative SPEC-BLOCK variables."
  `(defparameter *command-specs*
       (build-command-specs ,@spec-blocks)))
