(in-package #:loom/core/command)

(defstruct
    (keymap-state (:constructor %make-keymap-state) (:conc-name %keymap-state-))
  (keymap nil)
  (root-keymap nil)
  (sequence nil))

(defun keymap-state-use-keymap (state keymap)
  "Select KEYMAP for STATE and clear pending keys if it changes."
  (check-type state keymap-state)
  (check-type keymap keymap)
  (unless (eq (%keymap-state-keymap state) keymap)
    (setf (%keymap-state-sequence state) nil))
  (setf (%keymap-state-keymap state) keymap)
  state)

(defun keymap-state-sequence (state)
  "Return the accumulated key sequence for STATE."
  (%keymap-state-sequence state))

(defun make-keymap-state (keymap)
  "Create and return a new dispatch state for KEYMAP that tracks
in-progress prefix-key accumulation across successive KEYMAP-STATE-DISPATCH
calls, starting with no keys accumulated."
  (%make-keymap-state :keymap keymap :root-keymap keymap :sequence nil))

(defun keymap-state-dispatch (state key-event command-invoker)
  "Feed KEY-EVENT into STATE and invoke bindings through COMMAND-INVOKER.

COMMAND-INVOKER receives the command, normalized key sequence, and owning
keymap name. Prefixes return :PENDING and unbound keys return NIL."
  (setf (%keymap-state-sequence state) (append (%keymap-state-sequence state)
                                               (list key-event)))
  (multiple-value-bind (result owner)
      (keymap-lookup (%keymap-state-keymap state)
                     (%keymap-state-sequence state))
    (cond
      ((eq result :prefix) :pending)
      ((null result)
        (setf (%keymap-state-sequence state) nil)
        nil)
      (t
       (let ((sequence
              (mapcar #'normalize-key-descriptor (%keymap-state-sequence state))))
         (setf (%keymap-state-sequence state) nil)
         (funcall command-invoker result sequence (keymap-name owner)))))))

(defvar *buffer-keymap-providers* nil)

(defun register-buffer-keymap-provider (owner function &key (priority 0))
  "Register OWNER's buffer keymap provider at PRIORITY.

Providers run in ascending priority order. Each receives the map returned by
the preceding provider, so later providers can layer a local map over it."
  (unless (functionp function)
    (error "Buffer keymap provider must be a function"))
  (unless (integerp priority)
    (error "Buffer keymap provider priority must be an integer: ~S" priority))
  (when (find owner *buffer-keymap-providers* :key #'first :test #'equal)
    (error "Buffer keymap provider owner is already registered: ~S" owner))
  (setf *buffer-keymap-providers*
        (append *buffer-keymap-providers*
                (list (list owner priority function))))
  function)

(defun keymap-for-buffer (session buffer fallback)
  (check-type fallback keymap)
  (if (null buffer)
      fallback
      (let ((keymap fallback))
        (dolist (provider
                  (stable-sort (copy-list *buffer-keymap-providers*)
                               #'< :key #'second))
          (let ((provided
                  (funcall (third provider) session buffer keymap)))
            (cond
              ((null provided) nil)
              ((keymap-p provided)
               (setf keymap provided))
              (t
               (error "Buffer keymap provider returned a non-keymap value: ~S"
                      provided)))))
        keymap)))
