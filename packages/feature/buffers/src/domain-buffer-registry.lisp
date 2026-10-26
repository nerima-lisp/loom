(in-package #:loom/feature/buffers)

(defstruct
    (buffer-registry (:constructor %make-buffer-registry)
                     (:conc-name %buffer-registry-))
  (buffers nil)
  (close-hook-errors nil))

(defun %make-buffer-registry-state (session)
  (declare (ignore session))
  (%make-buffer-registry))

(register-slice-state :feature/buffers '%make-buffer-registry-state)

(defun registered-buffers (session)
  "Return a copy of the session buffer registry in its current order."
  (copy-list
   (%buffer-registry-buffers (editor-session-slice session :feature/buffers))))

(defun register-buffer (session buffer)
  "Register BUFFER in SESSION once by EQ, prepend new buffers, and return BUFFER."
  (pushnew buffer
           (%buffer-registry-buffers
            (editor-session-slice session :feature/buffers))
           :test
           (function eq))
  buffer)

(defun unregister-buffer (session buffer &key reason)
  "Run the session buffer-close hook once, then remove registered BUFFER and return it.

Hook errors are retained as (BUFFER REASON CONDITION) records in the registry;
removal proceeds after a hook error. Unregistered buffers do not run the hook."
  (let* ((registry (editor-session-slice session :feature/buffers))
         (buffers (%buffer-registry-buffers registry)))
    (when (member buffer buffers :test (function eq))
      (handler-case
          (run-session-hooks :buffer-close session buffer reason)
        (error (condition)
          (push (list buffer reason condition)
                (%buffer-registry-close-hook-errors registry))))
      (setf (%buffer-registry-buffers registry)
            (remove buffer buffers :test (function eq))))
    buffer))
(defun %buffer-path-key (path)
  "Return PATH’s truename string, or its namestring if it does not exist."
  (when path
    (namestring
     (handler-case
         (truename path)
       (file-error () (pathname path))))))
(defun find-buffer-by-name (session name)
  "Return the first buffer named NAME in registry order, or NIL."
  (find name
        (registered-buffers session)
        :key (function buffer-name)
        :test (function string=)))
(defun find-buffer-by-path (session path)
  "Return the first buffer whose file matches PATH.
Existing paths compare by truename; nonexistent paths compare namestrings."
  (let ((path-key (%buffer-path-key path)))
    (when path-key
      (find-if
       (lambda (buffer)
         (let ((buffer-path (buffer-path buffer)))
           (and buffer-path
                (string= path-key (%buffer-path-key buffer-path)))))
       (registered-buffers session)))))
(defun ensure-result-buffer (session name)
  "Return the existing buffer named NAME or create and register it in SESSION."
  (or (find-buffer-by-name session name)
      (register-buffer session (make-buffer :name name))))
