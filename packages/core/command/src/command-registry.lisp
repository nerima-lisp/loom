(in-package #:loom/core/command)

(defparameter *command-trace-sequence* 0 "Current per-process sequence number for LOOM_TRACE_COMMANDS events.")

(defun %normalized-command-name (input)
  "Return INPUT trimmed and normalized for command lookup."
  (string-downcase
   (string-trim '(#\Space #\Tab) (or input ""))))
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
(defun %catalog-key-name (code)
  "Return CODE as a readable catalog key string."
  (typecase code
    (character (string code))
    (keyword (%catalog-symbol-name code))
    (t (error "Unsupported catalog key code: ~S" code))))
(defun %help-spec< (left right)
  (< (%command-spec-help-order left) (%command-spec-help-order right)))

(defun %help-specs ()
  (remove-if-not #'%command-spec-help (command-specs)))
(defun %command-keybinding-json (key-sequence keymap)
  (json-kit:make-json-object
   (list
    (cons "keymap" (%catalog-symbol-name keymap))
    (cons "sequence"
          (mapcar
           (lambda (descriptor)
             (let* ((normalized (normalize-key-descriptor descriptor))
                    (code (cdr normalized)))
               (json-kit:make-json-object
                (list
                 (cons "modifiers"
                       (mapcar #'%catalog-symbol-name (car normalized)))
                 (cons "key" (%catalog-key-name code))))))
           key-sequence)))))

(defun %help-messages (specs)
  (mapcar #'%command-spec-help specs))

(defun help-summary-message ()
  (let ((entries
          (stable-sort (copy-list (%help-specs)) #'%help-spec<)))
    (format nil "Help: ~{~A~^  ~}" (%help-messages entries))))
(defun %command-spec-json (spec)
  (json-kit:make-json-object
   (list
    (cons "id" (%command-spec-id spec))
    (cons "owner" (%catalog-symbol-name (%command-spec-owner spec)))
    (cons "name" (or (%command-spec-name spec) (%command-spec-legacy-name spec) json-kit:+json-null+))
    (cons "mx-eligible"
          (if (%command-spec-name spec) t json-kit:+json-false+))
    (cons "group" (or (%command-spec-group spec) json-kit:+json-null+))
    (cons "keymap" (%catalog-symbol-name (%command-spec-keymap spec)))
    (cons "keys"
          (mapcar
           (lambda (key-sequence)
             (%command-keybinding-json
              key-sequence
              (%command-spec-keymap spec)))
           (%command-spec-keys spec)))
    (cons "mutates"
          (if (%command-spec-mutates spec) t json-kit:+json-false+))
    (cons "prompts"
          (mapcar #'%catalog-symbol-name (%command-spec-prompts spec)))
    (cons "needs-region"
          (if (%command-spec-needs-region spec) t json-kit:+json-false+))
    (cons "external" (%command-spec-external spec))
    (cons "modes"
          (mapcar #'%catalog-symbol-name (%command-spec-modes spec))))))
(defun command-catalog-json ()
  (let ((visible
          (remove-if-not #'%command-spec-catalog-visible-p
                         (command-specs))))
    (json-kit:stringify
     (mapcar #'%command-spec-json
             (stable-sort
              visible
              (lambda (left right)
                (let ((left-owner
                        (%catalog-symbol-name (%command-spec-owner left)))
                      (right-owner
                        (%catalog-symbol-name (%command-spec-owner right))))
                  (if (string-equal left-owner right-owner)
                      (string-lessp (%command-spec-id left)
                                    (%command-spec-id right))
                      (string-lessp left-owner right-owner)))))))))
(defun record-command-trace (id route &optional entry)
  (unless (keywordp route)
    (error "Command trace route must be a keyword: ~S" route))
  (let* ((trace-file (uiop:getenv "LOOM_TRACE_COMMANDS"))
         (spec (%find-command-spec-by-id id)))
    (when (and trace-file spec (%command-spec-trace-visible-p spec))
      (handler-case
          (progn
            (when (zerop (length trace-file))
              (error "LOOM_TRACE_COMMANDS path must not be empty"))
            (let* ((trace-path (uiop:parse-native-namestring trace-file))
                   (prefix-state
                     (and *editor-state*
                          (prefix-argument-for-editor)))
                   (trace-sequence (1+ *command-trace-sequence*))
                   (fields
                     (list
                      (cons "command" (%command-spec-id spec))
                      (cons "route" (%catalog-symbol-name route))
                      (cons "seq" trace-sequence)
                      (cons "pid" (sb-posix:getpid))
                      (cons "prefix"
                            (if prefix-state
                                (prefix-argument-value prefix-state)
                                json-kit:+json-null+))
                      (cons "prefix-explicit"
                            (if (and prefix-state
                                     (prefix-argument-explicit-p prefix-state))
                                t
                                json-kit:+json-false+))))
                   (line
                     (json-kit:stringify
                      (json-kit:make-json-object
                       (if entry
                           (append fields (list (cons "entry" entry)))
                           fields)))))
              (when (wild-pathname-p trace-path)
                (error "LOOM_TRACE_COMMANDS path must not contain wildcards"))
              (with-open-file (stream trace-path
                                      :direction :output
                                      :if-exists :append
                                      :if-does-not-exist :create)
                (write-line line stream)
                (finish-output stream))
              (setf *command-trace-sequence* trace-sequence)
              nil))
        (error (condition)
          (format nil "Could not append LOOM_TRACE_COMMANDS to ~A: ~A"
                  trace-file condition))))))
