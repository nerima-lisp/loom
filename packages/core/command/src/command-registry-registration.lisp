(in-package #:loom/core/command)

(defstruct
    (command-spec-record
     (:constructor %make-command-spec-record
                   (owner id
                          name
                          legacy-name
                          group
                          command
                          keys
                          keymap
                          help
                          help-order
                          mutates
                          prompts
                          needs-region
                          external
                          modes
                          catalog-visible-p
                          trace-visible-p))
     (:conc-name %command-spec-))
  owner
  id
  name
  legacy-name
  group
  command
  keys
  keymap
  help
  help-order
  mutates
  prompts
  needs-region
  external
  modes
  catalog-visible-p
  trace-visible-p)

(defvar *registered-command-specs*
  nil)

(defvar *command-trace-key-sequence*
  nil)

(defvar *command-trace-keymap-name*
  nil)
(defvar *current-command-route* nil "Route of the currently invoked command.")

(defun command-spec-id (spec)
  (copy-seq (%command-spec-id spec)))

(defun command-spec-name (spec)
  (let ((name (%command-spec-name spec)))
    (and name (copy-seq name))))

(defun %command-function (command)
  (cond
    ((and (symbolp command) (fboundp command)) (symbol-function command))
    ((functionp command) command)
    (t (error "Command must be a function designator: ~S" command))))

(defun %normalize-command-name (name)
  (when name
    (let ((normalized (string-downcase (string-trim '(#\Space #\Tab) name))))
      (when (zerop (length normalized))
        (error "Command name cannot be empty."))
      normalized)))

(defun %normalize-command-keys (keys)
  (unless (listp keys)
    (error "Command keys must be a list: ~S" keys))
  (mapcar
   (lambda (key-form)
     (unless key-form
       (error "Command key forms cannot be NIL."))
     (mapcar #'normalize-key-descriptor (defkeys-key-sequence key-form)))
   keys))

(defun %key-sequence-conflict-p (left right)
  (let ((shorter
         (if (<= (length left) (length right))
             left
             right))
        (longer
         (if (<= (length left) (length right))
             right
             left)))
    (equal shorter (subseq longer 0 (length shorter)))))

(defun %command-spec-registration-equal-p (left right &optional (compare-command-p t))
  (and (equal (%command-spec-owner left) (%command-spec-owner right))
       (equal (%command-spec-id left) (%command-spec-id right))
       (and (equal (%command-spec-name left) (%command-spec-name right))
            (equal (%command-spec-legacy-name left)
                   (%command-spec-legacy-name right)))
       (equal (%command-spec-group left) (%command-spec-group right))
       (or (not compare-command-p)
           (eq (%command-spec-command left) (%command-spec-command right)))
       (equal (%command-spec-keys left) (%command-spec-keys right))
       (eq (%command-spec-keymap left) (%command-spec-keymap right))
       (equal (%command-spec-help left) (%command-spec-help right))
       (eql (%command-spec-help-order left) (%command-spec-help-order right))
       (equal (%command-spec-mutates left) (%command-spec-mutates right))
       (equal (%command-spec-prompts left) (%command-spec-prompts right))
       (equal (%command-spec-needs-region left)
              (%command-spec-needs-region right))
       (equal (%command-spec-external left) (%command-spec-external right))
       (equal (%command-spec-modes left) (%command-spec-modes right))
       (eql (%command-spec-catalog-visible-p left)
            (%command-spec-catalog-visible-p right))
       (eql (%command-spec-trace-visible-p left)
            (%command-spec-trace-visible-p right))))

(defun %command-name-registration (name)
  (and name
       (find name
             *registered-command-specs*
             :key
             #'%command-spec-name
             :test
             #'string-equal)))

(defun %check-command-name-collision (candidate)
  (let* ((name (%command-spec-name candidate))
         (existing (%command-name-registration name)))
    (when
        (and existing
             (not (%command-spec-registration-equal-p candidate existing)))
      (error
       "Command name ~S is already registered by ~S (~A); cannot register ~S (~A)."
       name
       (%command-spec-owner existing)
       (%command-spec-id existing)
       (%command-spec-owner candidate)
       (%command-spec-id candidate)))))

(defun %check-command-key-collisions (candidate)
  (let ((keymap (%command-spec-keymap candidate))
        (keys (%command-spec-keys candidate)))
    (loop for tail on keys
          for sequence = (first tail)
          do (dolist (other (rest tail))
               (when (%key-sequence-conflict-p sequence other)
                 (error "Command ~A registers colliding keys in ~S: ~S and ~S."
                        (%command-spec-id candidate)
                        keymap
                        sequence
                        other)))
          do (dolist (existing *registered-command-specs*)
               (when (eq keymap (%command-spec-keymap existing))
                 (dolist (other (%command-spec-keys existing))
                   (when (%key-sequence-conflict-p sequence other)
                     (error "Key collision in ~S between ~A and ~A: ~S and ~S."
                            keymap
                            (%command-spec-id existing)
                            (%command-spec-id candidate)
                            other
                            sequence))))))))

(defun register-command-spec
    (owner id name command &key keys (keymap :global) group help help-order
                               (mutates nil mutates-p)
                               (prompts nil prompts-p)
                               (needs-region nil needs-region-p)
                               (external nil external-p)
                               (modes nil modes-p)
                               (catalog-visible-p t)
                               (trace-visible-p t))
  "Register one immutable command definition, returning its opaque spec."
  (unless (and mutates-p prompts-p needs-region-p external-p modes-p)
    (error "Command registration requires all five metadata keys."))
  (%register-command-spec
   owner id name command :keys keys :keymap keymap :group group :help help
   :help-order help-order :mutates mutates :prompts prompts
   :needs-region needs-region :external external :modes modes
   :catalog-visible-p catalog-visible-p :trace-visible-p trace-visible-p))

(defun register-key-command (owner id command keymap keys &rest metadata)
  "Register a key-only command with stable identity and required metadata."
  (apply #'register-command-spec
         owner
         id
         nil
         command
         :keys
         keys
         :keymap
         keymap
         metadata))

(defun register-internal-command (owner id command &rest metadata)
  (apply #'%register-command-spec
         owner
         id
         nil
         command
         :catalog-visible-p
         nil
         :trace-visible-p
         nil
         metadata))

(defun command-specs ()
  (copy-list *registered-command-specs*))

(defun find-command-spec (id)
  (%find-command-spec-by-id id))

(defun %find-command-spec-by-id (id)
  (find id *registered-command-specs* :key #'%command-spec-id :test #'equal))

(defun find-command-spec-for-function (command)
  (let ((function (%command-function command)))
    (find function
          *registered-command-specs*
          :key #'%command-spec-command
          :test #'eq)))

(defun command-id-for-function (command)
  (let ((spec (find-command-spec-for-function command)))
    (or (and spec (%command-spec-id spec))
        (error "No registered command spec for callable ~S." command))))

(defun find-extended-command-spec (input)
  (let ((name (%normalized-command-name input)))
    (find-if (lambda (spec)
               (and (%command-spec-name spec)
                    (string-equal name (%command-spec-name spec))))
             (command-specs))))

(defun command-completion-candidates (input)
  (let ((prefix (%normalized-command-name input)))
    (stable-sort
     (remove-if-not
      (lambda (spec)
        (and (%command-spec-name spec)
             (%command-name-matches-prefix-p
              (%command-spec-name spec)
              prefix)))
      (command-specs))
     #'string-lessp
     :key #'%command-spec-name)))

(defun command-completion-names (input)
  (mapcar #'%command-spec-name (command-completion-candidates input)))

(defun %register-command-spec
    (owner id name command
     &key keys (keymap :global) group help help-order
       (mutates nil mutates-p)
       (prompts nil prompts-p)
       (needs-region nil needs-region-p)
       (external nil external-p)
       (modes nil modes-p)
       (catalog-visible-p t)
       (trace-visible-p t))
  (unless (and mutates-p prompts-p needs-region-p external-p modes-p)
    (error "Command registration requires all five metadata keys."))
  (%validate-command-metadata
   name command help help-order
   mutates mutates-p prompts prompts-p
   needs-region needs-region-p external external-p modes modes-p)
  (unless (keywordp owner)
    (error "Command owner must be a keyword: ~S" owner))
  (unless (keywordp keymap)
    (error "Command keymap must be a keyword: ~S" keymap))
  (unless (and (stringp id)
               (plusp (length (string-trim
                               (list (code-char 32) (code-char 9))
                               id)))
               (member catalog-visible-p (list nil t))
               (member trace-visible-p (list nil t)))
    (error "Command ID and visibility flags are invalid: ~S, ~S, ~S"
           id catalog-visible-p trace-visible-p))
  (unless (or (null group) (stringp group))
    (error "Command group must be a string or NIL: ~S" group))
  (let* ((command-id
           (copy-seq
            (string-trim (list (code-char 32) (code-char 9)) id)))
         (normalized-name (%normalize-command-name name))
         (function (%command-function command))
         (normalized-keys (%normalize-command-keys keys))
         (candidate
           (%make-command-spec-record owner command-id normalized-name (and (symbolp command) (%catalog-symbol-name command)) (and group (copy-seq group)) function normalized-keys keymap (and help (copy-seq help)) help-order mutates (copy-list prompts) needs-region (mapcar (function copy-seq) external) (copy-list modes) catalog-visible-p trace-visible-p))
         (existing
           (find command-id *registered-command-specs*
                 :key (function %command-spec-id)
                 :test (function equal))))
    (when existing
      (if (and (eq owner (%command-spec-owner existing))
               (%command-spec-registration-equal-p candidate existing nil))
          (if (eq function (%command-spec-command existing))
              (return-from %register-command-spec existing)
              (progn
                (setf *registered-command-specs*
                      (substitute candidate existing *registered-command-specs*
                                  :test (function eq)))
                (return-from %register-command-spec candidate)))
          (error "Command ID ~S is already registered by ~S; cannot register it for ~S."
                 command-id (%command-spec-owner existing) owner)))
    (%check-command-name-collision candidate)
    (%check-command-key-collisions candidate)
    (push candidate *registered-command-specs*)
    candidate))
