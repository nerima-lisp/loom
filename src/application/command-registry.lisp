;;;; src/application/command-registry.lisp
;;;;
;;;; Application-layer runtime registry queries for commands exposed through
;;;; M-x and for the default key descriptors attached to those commands.
(in-package #:loom/application)

(defparameter *command-specs* nil
  "Registered command metadata used by completion and keymap installation.")

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
  (let ((name (string-downcase
               (string-trim '(#\Space #\Tab) (or input "")))))
    (getf
     (find-if (lambda (spec)
                (and (getf spec :name)
                     (string-equal name (getf spec :name))))
              *command-specs*)
     :command)))

(defun %help-spec< (left right)
  "Return true when LEFT should appear before RIGHT in the help summary."
  (< (getf left :help-order) (getf right :help-order)))

(defun help-summary-message ()
  "Return the compact help message derived from registered command metadata."
  (let ((entries
          (sort
           (loop for spec in *command-specs*
                 for help = (getf spec :help)
                 when help collect spec)
           #'%help-spec<)))
    (format nil "Help: ~{~A~^  ~}" (mapcar (lambda (spec) (getf spec :help)) entries))))
