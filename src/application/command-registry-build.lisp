;;;; src/application/command-registry-build.lisp
;;;;
;;;; Application-layer command registry normalization, validation, and
;;;; composition macros. The declarative COMMAND-SPEC surface lives in
;;;; command-registry-forms.lisp.
(in-package #:loom/application)

(defun %parse-command-spec-form (spec)
  "Return SPEC normalized as (NAME COMMAND KEYS HELP HELP-ORDER)."
  (unless (and (consp spec) (eq (first spec) 'command-spec))
    (error "Expected a COMMAND-SPEC form, got: ~S" spec))
  (destructuring-bind (operator name command &key keys help help-order) spec
    (declare (ignore operator))
    (%validate-command-metadata name command help help-order)
    (list name command keys help help-order)))

(defun %collect-command-spec-entries (specs)
  "Flatten SPECS from DEFINE-COMMAND-SPECS into validated registry entries."
  (mapcan
   (lambda (spec)
     (cond
       ((and (consp spec) (eq (first spec) 'command-spec-group))
        (destructuring-bind (operator group-name &body group-specs) spec
          (declare (ignore operator group-name))
          (%collect-command-spec-entries group-specs)))
       (t
        (list (%parse-command-spec-form spec)))))
   specs))

(defun %validate-command-spec-entries (entries)
  "Signal an error when ENTRIES contains duplicate command names."
  (let* ((names (remove nil (mapcar (function first) entries)))
         (duplicate
           (find-if (lambda (name)
                      (> (count name names :test (function string-equal)) 1))
                    names)))
    (when duplicate
      (error "Duplicate COMMAND-SPEC name: ~S" duplicate)))
  entries)

(defun %emit-command-spec-entries (entries)
  "Return runtime registry entries for ENTRIES."
  (mapcar
   (lambda (entry)
     (destructuring-bind (name command keys help help-order) entry
       (list :name name
             :command command
             :keys keys
             :help help
             :help-order help-order)))
   entries))

(defun %command-spec-entry-form (entry)
  "Return the source form that constructs one runtime registry entry."
  (destructuring-bind (name command keys help help-order) entry
    `(list :name ,name
           :command ',command
           :keys ',keys
           :help ,help
           :help-order ,help-order)))

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
  `(progn
     (defparameter *command-specs*
       (build-command-specs ,@spec-blocks))))
