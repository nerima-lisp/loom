;;;; src/application/command-registry.lisp
;;;;
;;;; Application-layer registry for commands exposed through M-x and for the
;;;; default key descriptors attached to those commands.  The registry is a
;;;; data boundary: command lookup and key normalization consume it, while
;;;; feature packages provide the callable command implementations.
(in-package #:loom/application)

(defparameter *command-specs* nil
  "Registered command metadata used by completion and keymap installation.")

(defmacro command-spec (name command &key keys)
  "Describe COMMAND's M-x NAME and its optional default key sequence data."
  (unless (or (null name) (stringp name))
    (error "COMMAND-SPEC name must be a string or NIL: ~S" name))
  (unless (symbolp command)
    (error "COMMAND-SPEC command must be a symbol: ~S" command))
  `(list :name ,name :command ',command :keys ',keys))

(defmacro define-command-specs (&body specs)
  "Define the command registry from COMMAND-SPEC forms.

Each spec provides an extended-command name and default key sequence data.
NIL names describe keymap-only commands such as M-x itself. The explicit
registry is used for lookup."
  (let ((entries
          (mapcar
           (lambda (spec)
             (unless (and (consp spec) (eq (first spec) 'command-spec))
               (error "Expected a COMMAND-SPEC form, got: ~S" spec))
             (destructuring-bind (operator name command &key keys) spec
               (declare (ignore operator))
               (unless (or (null name) (stringp name))
                 (error "COMMAND-SPEC name must be a string or NIL: ~S" name))
               (unless (symbolp command)
                 (error "COMMAND-SPEC command must be a symbol: ~S" command))
               (list name command keys)))
           specs)))
    (let* ((names (remove nil (mapcar (function first) entries)))
           (duplicate
             (find-if (lambda (name)
                        (> (count name names :test (function string-equal)) 1))
                      names)))
      (when duplicate
        (error "Duplicate COMMAND-SPEC name: ~S" duplicate)))
    `(progn
       (defparameter *command-specs*
         (list
          ,@(mapcar
             (lambda (entry)
               (destructuring-bind (name command keys) entry
                 `(list :name ,name :command ',command :keys ',keys)))
             entries))))))

(defun %command-name-matches-prefix-p (name prefix)
  "Return true when NAME starts with PREFIX, case-insensitively."
  (and name
       (<= (length prefix) (length name))
       (string-equal prefix name
                     :end1 (length prefix)
                     :end2 (length prefix))))

(defun command-completion-candidates (input)
  "Return named command specs whose names begin with INPUT."
  (let ((prefix (string-downcase
                 (string-trim '(#\Space #\Tab) (or input "")))))
    (loop for spec in *command-specs*
          for name = (getf spec :name)
          when (%command-name-matches-prefix-p name prefix)
            collect name)))

(defun find-extended-command (input)
  "Return the registered command named by INPUT, or NIL."
  (let ((name (string-downcase (string-trim '(#\Space #\Tab) input))))
    (getf
     (find-if (lambda (spec)
                (and (getf spec :name)
                     (string= name (getf spec :name))))
              *command-specs*)
     :command)))
