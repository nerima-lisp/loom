;;;; src/application/editor-state-save-hooks.lisp
;;;;
;;;; Save-hook registration and dispatch for the shared EDITOR-STATE object.
(in-package #:loom)

(defun %add-editor-state-save-hook (hook state reader writer)
  (check-type hook function)
  (unless state
    (error "No editor state is active"))
  (funcall writer (adjoin hook (funcall reader state) :test #'eq) state)
  hook)

(defun %remove-editor-state-save-hook (hook state reader writer)
  (when state
    (funcall writer (remove hook (funcall reader state) :test #'eq) state))
  hook)

(defun %run-editor-state-save-hooks (buffer state reader)
  (when state
    (dolist (hook (copy-list (reverse (funcall reader state))))
      (funcall hook buffer)))
  buffer)

(defmacro define-editor-state-save-hooks (phase slot documentation-tail)
  "Define the add/remove/run hook protocol for PHASE using SLOT."
  (let* ((phase-name (string-downcase (string phase)))
         (add-name (intern (format nil "ADD-~A-SAVE-HOOK" phase) *package*))
         (remove-name (intern (format nil "REMOVE-~A-SAVE-HOOK" phase) *package*))
         (run-name (intern (format nil "RUN-~A-SAVE-HOOKS" phase) *package*))
         (state-slot (intern (format nil "EDITOR-STATE-~A" slot) *package*)))
    `(progn
       (defun ,add-name (hook &optional (state *editor-state*))
         ,(format nil "Register HOOK ~A ordinary saves in STATE.~2%
Hooks receive the buffer about to be saved as their only argument.
Registering the same function twice has no effect."
                  documentation-tail)
         (%add-editor-state-save-hook hook state
                                       #',state-slot
                                       (lambda (value state)
                                         (setf (,state-slot state) value))))

       (defun ,remove-name (hook &optional (state *editor-state*))
         ,(format nil "Remove HOOK from STATE and return HOOK.~2%
Removing a function that is not registered is harmless.")
         (%remove-editor-state-save-hook hook state
                                          #',state-slot
                                          (lambda (value state)
                                            (setf (,state-slot state) value))))

       (defun ,run-name (buffer &optional (state *editor-state*))
         ,(format nil "Run STATE's ~A-save hooks for BUFFER and return BUFFER.~2%
The registration list is copied before dispatch, so hooks may update the
hook list without changing the current pass."
                  phase-name)
         (%run-editor-state-save-hooks buffer state #',state-slot)))))

(define-editor-state-save-hooks BEFORE BEFORE-SAVE-HOOKS "before")
(define-editor-state-save-hooks AFTER AFTER-SAVE-HOOKS "after")
