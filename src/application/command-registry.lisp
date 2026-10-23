(in-package #:loom/application)

(defparameter *command-specs* nil
  "Registered command metadata used by completion and keymap installation.")
(defparameter *command-trace-sequence* 0
  "Next sequence number source for LOOM_TRACE_COMMANDS events.")

(defun %normalized-command-name (input)
  "Return INPUT trimmed and normalized for command lookup."
  (string-downcase
   (string-trim '(#\Space #\Tab) (or input ""))))
(defun %catalog-json-object (members)
  "Build an ordered JSON object from MEMBERS."
  (json-kit:make-json-object members))

(defun %command-name-matches-prefix-p (name prefix)
  "Return true when NAME starts with PREFIX, case-insensitively."
  (and name
       (<= (length prefix) (length name))
       (string-equal prefix name
                     :end1 (length prefix)
                     :end2 (length prefix))))
(defun %catalog-symbol-name (symbol)
  "Return SYMBOL's name in lower case for the JSON catalog."
  (string-downcase (symbol-name symbol)))

(defun command-completion-candidates (input)
  "Return registered command names matching the normalized INPUT prefix."
  (let ((prefix (%normalized-command-name input)))
    (loop for spec in *command-specs*
          for name = (getf spec :name)
          when (%command-name-matches-prefix-p name prefix)
            collect name)))

(defun %command-spec-named-p (spec name)
  (and (getf spec :name)
       (string-equal name (getf spec :name))))
(defun %catalog-key-name (code)
  "Return CODE as a readable catalog key string."
  (typecase code
    (character (string code))
    (keyword (%catalog-symbol-name code))
    (t (error "Unsupported catalog key code: ~S" code))))
(defun find-extended-command-spec (input)
  "Return the registered command spec named by INPUT, or NIL."
  (let ((name (%normalized-command-name input)))
    (find-if (lambda (spec)
               (%command-spec-named-p spec name))
             *command-specs*)))

(defun find-extended-command (input)
  "Return the registered command named by INPUT, or NIL."
  (getf (find-extended-command-spec input) :command))

(defun %help-spec< (left right)
  "Return true when LEFT should appear before RIGHT in the help summary."
  (< (getf left :help-order) (getf right :help-order)))

(defun %help-specs ()
  "Return registered command specs that contribute to the help summary."
  (loop for spec in *command-specs*
        when (getf spec :help)
          collect spec))
(defun %command-keybinding-json (key-form)
  "Return KEY-FORM as one global key binding JSON object."
  (%catalog-json-object
   (list (cons "keymap" "global")
         (cons "sequence"
               (mapcar
                (lambda (descriptor)
                  (%catalog-json-object
                   (list (cons "modifiers"
                               (mapcar #'%catalog-symbol-name (car descriptor)))
                         (cons "key" (%catalog-key-name (cdr descriptor))))))
                (defkeys-key-sequence key-form))))))

(defun %help-messages (specs)
  "Extract help messages from sorted SPECS."
  (mapcar (lambda (spec) (getf spec :help)) specs))

(defun help-summary-message ()
  "Return the compact help message derived from registered command metadata."
  (let ((entries
          (stable-sort
           (copy-list
            (%help-specs))
           #'%help-spec<)))
    (format nil "Help: ~{~A~^  ~}" (%help-messages entries))))
(defun %command-spec-json (spec)
  "Return SPEC as an ordered JSON object with its catalog metadata."
  (%catalog-json-object
   (list (cons "name" (or (getf spec :name) json-kit:+json-null+))
         (cons "group" (or (getf spec :group) json-kit:+json-null+))
         (cons "keys" (mapcar #'%command-keybinding-json (getf spec :keys)))
         (cons "mutates" (if (getf spec :mutates)
                              t
                              json-kit:+json-false+))
         (cons "prompts"
               (mapcar #'%catalog-symbol-name (getf spec :prompts)))
         (cons "needs-region" (if (getf spec :needs-region)
                                   t
                                   json-kit:+json-false+))
         (cons "external" (getf spec :external))
         (cons "modes"
               (mapcar #'%catalog-symbol-name (getf spec :modes))))))
(defun command-catalog-json ()
  "Return the registered command catalogue as a JSON array string."
  (json-kit:stringify (mapcar #'%command-spec-json *command-specs*)))
(defun record-command-trace (command route)
  "Append one JSONL event for registered COMMAND when tracing is enabled.
Return a diagnostic string if the event cannot be written."
  (unless (member route '(:key :mx))
    (error "Unknown command trace route: ~S" route))
  (let* ((trace-file (uiop:getenv "LOOM_TRACE_COMMANDS"))
         (spec (find-if (lambda (entry)
                          (eq command (getf entry :command)))
                        *command-specs*)))
    (when (and trace-file spec)
      (let* ((sequence (1+ *command-trace-sequence*))
             (command-name
               (or (getf spec :name)
                   (string-downcase (symbol-name command))))
             (line
               (json-kit:stringify
                (%catalog-json-object
                 (list (cons "command" command-name)
                       (cons "route" (%catalog-symbol-name route))
                       (cons "seq" sequence))))))
        (setf *command-trace-sequence* sequence)
        (handler-case
            (progn
              (with-open-file (stream trace-file
                                      :direction :output
                                      :if-exists :append
                                      :if-does-not-exist :create)
                (write-string line stream)
                (terpri stream)
                (finish-output stream))
              nil)
          (error (condition)
            (format nil "Could not append LOOM_TRACE_COMMANDS to ~A: ~A"
                    trace-file condition)))))))
