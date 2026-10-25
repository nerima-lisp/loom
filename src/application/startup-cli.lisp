(in-package #:loom)

(defun %parse-startup-context (argv)
  "Parse registered lifecycle options and file requests from ARGV.

ARGV excludes the executable name. The returned startup context owns copies of
its arguments, option values, and file paths."
  (unless (and (listp argv) (every #'stringp argv))
    (error "Startup arguments must be a list of strings: ~S" argv))
  (let ((argv-copy (mapcar #'copy-seq argv))
        (options (make-hash-table :test #'equal))
        (file-requests '())
        (position-specified-p nil)
        (position-line 1)
        (position-column 1)
        (options-ended-p nil))
    (labels ((ascii-digit-string-p (value)
               (and (plusp (length value))
                    (loop for character across value
                          always (and (char<= #\0 character)
                                      (char<= character #\9)))))
             (startup-position (argument)
               (when
                   (and (> (length argument) 1)
                        (char= (char argument 0) #\+)
                        (let ((first (char argument 1)))
                          (or (and (char<= #\0 first) (char<= first #\9))
                              (char= first #\:))))
                 (let* ((value (subseq argument 1))
                        (separator (position #\: value))
                        (line-text
                         (if separator
                             (subseq value 0 separator)
                             value))
                        (column-text
                         (and separator (subseq value (1+ separator)))))
                   (unless
                       (and (ascii-digit-string-p line-text)
                            (or (null separator)
                                (ascii-digit-string-p column-text)))
                     (error 'cl-cli:cli-usage-error
                            :message
                            (format nil "Invalid startup position: ~S" argument)))
                   (let ((line (parse-integer line-text))
                         (column
                          (if separator
                              (parse-integer column-text)
                              1)))
                     (unless (and (plusp line) (plusp column))
                       (error 'cl-cli:cli-usage-error
                              :message
                              (format nil
                                      "Startup line and column must be positive: ~S"
                                      argument)))
                     (values line column t)))))
             (add-file-request (path)
               (push
                (loom/core/editor-session:make-startup-file-request
                 (copy-seq path)
                 :line
                 (if (and position-specified-p (null file-requests))
                     position-line
                     1)
                 :column
                 (if (and position-specified-p (null file-requests))
                     position-column
                     1))
                file-requests))
             (parse-option (argument remaining)
               (let* ((separator (position #\= argument))
                      (name
                       (if separator
                           (subseq argument 0 separator)
                           argument))
                      (value-kind
                       (loom/core/editor-session:cli-option-value-kind name))
                      (inline-value-p (not (null separator))))
                 (unless value-kind
                   (error 'cl-cli:cli-unknown-option
                          :option name
                          :message (format nil "Unknown option: ~A" name)))
                 (when (nth-value 1 (gethash name options))
                   (error 'cl-cli:cli-usage-error
                          :message
                          (format nil "Startup option is repeated: ~A" name)))
                 (case value-kind
                   (:switch
                     (when inline-value-p
                       (error 'cl-cli:cli-usage-error
                              :message
                              (format nil
                                      "Startup switch does not take a value: ~A"
                                      name)))
                     (setf (gethash (copy-seq name) options) t)
                     remaining)
                   (:value
                    (multiple-value-bind (value rest)
                        (if inline-value-p
                            (values (subseq argument (1+ separator)) remaining)
                            (if (and remaining
                                     (not (string= (first remaining) "--")))
                                (values (first remaining) (rest remaining))
                                (error 'cl-cli:cli-usage-error
                                       :message
                                       (format nil
                                               "Startup option requires a value: ~A"
                                               name))))
                      (setf (gethash (copy-seq name) options) (copy-seq value))
                      rest))
                   (otherwise
                    (error "Unsupported registered startup option: ~S" name))))))
      (loop while argv-copy
            do (let ((argument (pop argv-copy)))
                 (cond
                   ((and (not options-ended-p) (string= argument "--"))
                    (setf options-ended-p t))
                   ((and (not options-ended-p)
                         (>= (length argument) 2)
                         (string= argument "--" :end1 2))
                    (setf argv-copy (parse-option argument argv-copy)))
                   ((and (not options-ended-p)
                         (plusp (length argument))
                         (char= (char argument 0) #\-))
                    (error 'cl-cli:cli-unknown-option
                           :option argument
                           :message (format nil "Unknown option: ~A" argument)))
                   ((null file-requests)
                    (multiple-value-bind (line column position-p)
                        (startup-position argument)
                      (cond
                        (position-p
                          (when position-specified-p
                            (error 'cl-cli:cli-usage-error
                                   :message
                                   (format nil "Startup position is repeated: ~S"
                                           argument)))
                          (setf position-specified-p t
                                position-line line
                                position-column column))
                        (t (add-file-request argument)))))
                   (t (add-file-request argument)))))
      (when (and position-specified-p (null file-requests))
        (error 'cl-cli:cli-usage-error
               :message
               "A startup position requires a file path."))
      (loom/core/editor-session:make-startup-context (mapcar #'copy-seq argv)
                                                     options
                                                     (nreverse file-requests)))))

(defun %make-loom-app ()
  "Build the CL-CLI application specification for the loom binary."
  (cl-cli:make-app :name
                   "loom"
                   :version
                   (loom-version)
                   :summary
                   "Terminal text editor with Emacs-like keybindings"
                   :positionals
                   (list
                    (cl-cli:make-positional :key
                                            :path
                                            :required-p
                                            nil
                                            :description
                                            "A file to open, or a directory to browse (defaults to \".\")"))
                   :handler
                   (function %run-loom)))

(defparameter *loom-app*
  (%make-loom-app)
  "CL-CLI application spec for the loom binary: a single positional path
argument and no subcommands (the \"root positional\" shape CL-CLI's own
getting-started guide documents for script-style tools), which gets
--help/--version/-h/-V for free instead of main.lisp hand-parsing argv.")
