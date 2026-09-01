;;;; src/application/input-routing-decision.lisp
;;;;
;;;; Data-only classification for one decoded key event before dispatch.
(in-package #:loom)

(defstruct (input-routing-decision
            (:constructor %make-input-routing-decision))
  "Classify one key event before the mutating dispatch step runs."
  minibuffer
  minibuffer-was-active
  descriptor
  prefix-argument
  prefix-action
  terminal-event-p
  self-insert-event-p
  command
  recording-before)

(defstruct (input-routing-context
            (:constructor %make-input-routing-context))
  minibuffer
  minibuffer-was-active
  macro
  descriptor
  prefix-argument
  sequence)

(defun %terminal-input-event-for-routing-p (event minibuffer-was-active sequence)
  (and (not minibuffer-was-active)
       (loom/feature/terminal:terminal-input-event-p event)
       (null sequence)))

(defun %self-insert-event-for-routing-p
    (event minibuffer-was-active prefix-action sequence terminal-event-p)
  (and (not minibuffer-was-active)
       (eq (cl-tty-kit:key-event-type event) :character)
       (not (intersection '(:control :alt)
                          (cl-tty-kit:key-event-modifiers event)))
       (null prefix-action)
       (null sequence)
       (not terminal-event-p)))

(defun %routing-command (keymap-state sequence descriptor minibuffer-was-active
                         self-insert-event-p)
  (and (not minibuffer-was-active)
       (not self-insert-event-p)
       (keymap-lookup
        (keymap-state-keymap keymap-state)
        (append sequence (list descriptor)))))

(defun %input-routing-context (event keymap-state)
  (let ((minibuffer (editor-state-minibuffer *editor-state*)))
    (%make-input-routing-context
     :minibuffer minibuffer
     :minibuffer-was-active (minibuffer-active-p minibuffer)
     :macro (editor-state-keyboard-macro *editor-state*)
     :descriptor (%key-event->descriptor event)
     :prefix-argument (prefix-argument-for-editor)
     :sequence (keymap-state-sequence keymap-state))))

(defun %input-routing-flags (event keymap-state context)
  (let* ((minibuffer-was-active
           (input-routing-context-minibuffer-was-active context))
         (descriptor (input-routing-context-descriptor context))
         (prefix-argument (input-routing-context-prefix-argument context))
         (sequence (input-routing-context-sequence context))
         (prefix-action
           (and (not minibuffer-was-active)
                (null sequence)
                (prefix-argument-action descriptor prefix-argument)))
         (terminal-input-event-p
           (%terminal-input-event-for-routing-p event minibuffer-was-active
                                                 sequence))
         (self-insert-event-p
           (%self-insert-event-for-routing-p
            event minibuffer-was-active prefix-action sequence
            terminal-input-event-p))
         (command
           (%routing-command keymap-state sequence descriptor
                             minibuffer-was-active self-insert-event-p)))
    (values prefix-action
            (and terminal-input-event-p (null command))
            self-insert-event-p
            command)))

(defun %classify-key-event (event keymap-state)
  "Return the immutable routing decision for EVENT in KEYMAP-STATE."
  (let* ((context (%input-routing-context event keymap-state))
         (minibuffer-was-active
           (input-routing-context-minibuffer-was-active context))
         (macro (input-routing-context-macro context)))
    (multiple-value-bind (prefix-action terminal-event-p self-insert-event-p
                          command)
        (%input-routing-flags event keymap-state context)
      (%make-input-routing-decision
       :minibuffer (input-routing-context-minibuffer context)
       :minibuffer-was-active minibuffer-was-active
       :descriptor (input-routing-context-descriptor context)
       :prefix-argument (input-routing-context-prefix-argument context)
       :prefix-action prefix-action
       :terminal-event-p terminal-event-p
       :self-insert-event-p self-insert-event-p
       :command command
       :recording-before
         (and (not minibuffer-was-active)
              macro
              (loom/feature/keyboard-macro:keyboard-macro-recording-p macro))))))
