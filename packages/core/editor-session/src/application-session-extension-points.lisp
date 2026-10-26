(in-package #:loom/core/editor-session)

(defstruct
    (startup-file-request
     (:constructor %make-startup-file-request (path line column))
     (:copier nil)
     (:conc-name %startup-file-request-))
  path
  line
  column)

(defstruct
    (startup-context
     (:constructor %make-startup-context-record (argv options file-requests))
     (:copier nil)
     (:conc-name %startup-context-))
  argv
  options
  file-requests)

(defstruct
    (background-work-entry
     (:constructor %make-background-work-entry
                   (token owner poller cancel-function))
     (:copier nil))
  token
  owner
  poller
  cancel-function
  (cancelled-p nil))

(defstruct
    (background-work-state (:constructor %make-background-work-state ())
                           (:copier nil))
  (entries (make-hash-table :test #'eq))
  ready-tokens)

(defvar *cli-options*
  (make-hash-table :test #'equal))

(defvar *terminal-suspend-requests*
  (make-hash-table :test #'eq))

(defvar *background-work-states*
  (make-hash-table :test #'eq))

(defvar *session-wake-functions*
  (make-hash-table :test #'eq))

#+sb-thread
(defvar *session-extension-lock*
  (sb-thread:make-mutex :name "loom-session-extension"))

#-sb-thread
(defvar *session-extension-lock* nil)

(defmacro %with-session-extension-lock (&body body)
  #+sb-thread `(sb-thread:with-mutex (*session-extension-lock*) ,@body)
  #-sb-thread `(progn ,@body))

(defun %copy-option-value (value)
  (if (stringp value)
      (copy-seq value)
      value))

(defun startup-file-request-path (request)
  (check-type request startup-file-request)
  (copy-seq (%startup-file-request-path request)))

(defun startup-file-request-line (request)
  (check-type request startup-file-request)
  (%startup-file-request-line request))

(defun startup-file-request-column (request)
  (check-type request startup-file-request)
  (%startup-file-request-column request))

(defun startup-context-argv (context)
  (check-type context startup-context)
  (mapcar #'copy-seq (%startup-context-argv context)))

(defun startup-context-options (context)
  (check-type context startup-context)
  (let* ((source (%startup-context-options context))
         (copy (make-hash-table :test (hash-table-test source))))
    (maphash
     (lambda (key value)
       (setf (gethash (copy-seq key) copy) (%copy-option-value value)))
     source)
    copy))

(defun startup-context-file-requests (context)
  (check-type context startup-context)
  (mapcar
   (lambda (request)
     (%make-startup-file-request (%startup-file-request-path request)
                                 (%startup-file-request-line request)
                                 (%startup-file-request-column request)))
   (%startup-context-file-requests context)))

(defun register-cli-option (owner long-name value-kind)
  (unless (or (eq owner :feature/lifecycle)
              (eq owner :feature/user-init))
    (error
     "Only :FEATURE/LIFECYCLE and :FEATURE/USER-INIT may register CLI options: ~S"
     owner))
  (unless
      (and (stringp long-name)
           (> (length long-name) 2)
           (string= long-name "--" :end1 2)
           (alpha-char-p (char long-name 2))
           (every
            (lambda (character)
              (or (alphanumericp character) (char= character #\-)))
            (subseq long-name 2)))
    (error "CLI option name must be a long option such as --restore: ~S"
           long-name))
  (unless (member value-kind '(:switch :value) :test #'eq)
    (error "CLI option value kind must be :SWITCH or :VALUE: ~S" value-kind))
  (when (gethash long-name *cli-options*)
    (error "CLI option is already registered: ~A" long-name))
  (setf (gethash (copy-seq long-name) *cli-options*) (cons owner value-kind))
  long-name)

(defun %cli-option-value-kind (long-name)
  (cdr (gethash long-name *cli-options*)))

(defun cli-option-value-kind (long-name)
  (check-type long-name string)
  (%cli-option-value-kind long-name))

(defun make-startup-file-request (path &key (line 1) (column 1))
  (check-type path string)
  (unless (and (integerp line) (plusp line) (integerp column) (plusp column))
    (error "Startup file positions must be positive integers: ~S, ~S"
           line
           column))
  (%make-startup-file-request (copy-seq path) line column))

(defun make-startup-context (argv options file-requests)
  (unless (and (listp argv) (every #'stringp argv))
    (error "Startup context argv must be a list of strings: ~S" argv))
  (check-type options hash-table)
  (unless
      (and (listp file-requests) (every #'startup-file-request-p file-requests))
    (error "Startup context file requests must be startup-file-request values."))
  (let ((options-copy (make-hash-table :test (hash-table-test options))))
    (maphash
     (lambda (key value)
       (check-type key string)
       (unless (or (eq value t) (stringp value))
         (error "Startup option values must be strings or T: ~S" value))
       (setf (gethash (copy-seq key) options-copy) (%copy-option-value value)))
     options)
    (%make-startup-context-record (mapcar #'copy-seq argv)
                                  options-copy
                                  (mapcar
                                   (lambda (request)
                                     (make-startup-file-request
                                      (startup-file-request-path request)
                                      :line
                                      (startup-file-request-line request)
                                      :column
                                      (startup-file-request-column request)))
                                   file-requests))))

(defun set-session-wake-function (session function)
  (check-type session editor-session)
  (unless (or (null function) (functionp function))
    (error "Session wake function must be a function or NIL."))
  (%with-session-extension-lock
   (if function
       (setf (gethash session *session-wake-functions*) function)
       (remhash session *session-wake-functions*)))
  function)

(defun %wake-session (session)
  (let ((function
         (%with-session-extension-lock
          (gethash session *session-wake-functions*))))
    (when function
      (funcall function session))))

(defun request-terminal-suspend (session)
  (check-type session editor-session)
  (let ((new-request-p
         (%with-session-extension-lock
          (unless (gethash session *terminal-suspend-requests*)
            (setf (gethash session *terminal-suspend-requests*) t)
            t))))
    (if new-request-p
        (progn
          (%wake-session session)
          :queued)
        :coalesced)))

(defun consume-terminal-suspend-request (session)
  (check-type session editor-session)
  (%with-session-extension-lock
   (prog1
     (gethash session *terminal-suspend-requests*)
     (remhash session *terminal-suspend-requests*))))

(defun %ensure-background-work-state (session)
  (or (gethash session *background-work-states*)
      (setf (gethash session *background-work-states*) (%make-background-work-state))))

(defun register-background-work (session owner poller cancel-function)
  (check-type session editor-session)
  (unless (keywordp owner)
    (error "Background work owner must be a keyword: ~S" owner))
  (check-type poller function)
  (check-type cancel-function function)
  (let ((token (gensym "BACKGROUND-WORK-")))
    (%with-session-extension-lock
     (setf (gethash token
                    (background-work-state-entries
                     (%ensure-background-work-state session))) (%make-background-work-entry
                                                                token
                                                                owner
                                                                poller
                                                                cancel-function)))
    token))

(defun notify-background-work-ready (session token)
  (check-type session editor-session)
  (let ((wake-p nil)
        (result :ignored))
    (%with-session-extension-lock
     (let ((state (gethash session *background-work-states*)))
       (when (and state (gethash token (background-work-state-entries state)))
         (let ((queue (background-work-state-ready-tokens state)))
           (if (member token queue :test #'eq)
               (setf result :coalesced)
               (progn
                 (setf wake-p (null queue)
                       result :queued
                       (background-work-state-ready-tokens state) (append queue
                                                                          (list
                                                                           token)))))))))
    (when wake-p
      (%wake-session session))
    result))

(defun cancel-background-work (session token)
  (check-type session editor-session)
  (let ((entry nil)
        (cancel-p nil))
    (%with-session-extension-lock
     (let* ((state (gethash session *background-work-states*))
            (candidate
             (and state (gethash token (background-work-state-entries state)))))
       (when candidate
         (setf entry candidate)
         (unless (background-work-entry-cancelled-p candidate)
           (setf (background-work-entry-cancelled-p candidate) t
                 cancel-p t)))))
    (cond
      ((null entry) :ignored)
      (cancel-p
        (funcall (background-work-entry-cancel-function entry) session token)
        :cancelled)
      (t :coalesced))))

(defun %remove-ready-token (state token)
  (setf (background-work-state-ready-tokens state) (remove token
                                                           (background-work-state-ready-tokens
                                                            state)
                                                           :test
                                                           #'eq)))

(defun poll-ready-background-work (session)
  (check-type session editor-session)
  (let ((batch
         (%with-session-extension-lock
          (let ((state (gethash session *background-work-states*)))
            (when state
              (prog1
                (background-work-state-ready-tokens state)
                (setf (background-work-state-ready-tokens state) nil))))))
        (frame-dirty-p nil))
    (dolist (token batch)
      (let ((entry
             (%with-session-extension-lock
              (let ((state (gethash session *background-work-states*)))
                (and state
                     (gethash token (background-work-state-entries state)))))))
        (when entry
          (multiple-value-bind (dirty-p done-p)
              (funcall (background-work-entry-poller entry) session token)
            (unless (and (member dirty-p '(nil t)) (member done-p '(nil t)))
              (error "Background pollers must return two boolean values."))
            (%with-session-extension-lock
             (let* ((state (gethash session *background-work-states*))
                    (current
                     (and state
                          (gethash token (background-work-state-entries state)))))
               (when current
                 (unless (background-work-entry-cancelled-p current)
                   (when dirty-p
                     (setf frame-dirty-p t)))
                 (when done-p
                   (remhash token (background-work-state-entries state))
                   (%remove-ready-token state token)))))))))
    (values frame-dirty-p
            (%with-session-extension-lock
             (let ((state (gethash session *background-work-states*)))
               (and state
                    (not (null (background-work-state-ready-tokens state)))))))))

(defun %background-work-live-p (session)
  (%with-session-extension-lock
   (let ((state (gethash session *background-work-states*)))
     (and state
          (plusp (hash-table-count (background-work-state-entries state)))))))

(defun %background-work-ready-p (session)
  (%with-session-extension-lock
   (let ((state (gethash session *background-work-states*)))
     (and state (not (null (background-work-state-ready-tokens state)))))))

(defun cancel-session-background-work (session)
  (check-type session editor-session)
  (let ((tokens
         (%with-session-extension-lock
          (let ((state (gethash session *background-work-states*)))
            (when state
              (loop for token being the hash-keys of (background-work-state-entries
                                                      state)
                    collect token)))))
        (failures nil))
    (dolist (token tokens)
      (handler-case (cancel-background-work session token)
        (error (condition)
          (push condition failures))))
    (when failures
      (error (first failures)))
    (length tokens)))
