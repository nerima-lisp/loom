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

(defun %classify-key-event (event keymap-state)
  "Return the immutable routing decision for EVENT in KEYMAP-STATE."
  (let* ((minibuffer (editor-state-minibuffer *editor-state*))
         (minibuffer-was-active (minibuffer-active-p minibuffer))
         (macro (editor-state-keyboard-macro *editor-state*))
         (descriptor (%key-event->descriptor event))
         (prefix-argument (prefix-argument-for-editor))
         (sequence (keymap-state-sequence keymap-state))
         (prefix-action
           (and (not minibuffer-was-active)
                (null sequence)
                (prefix-argument-action descriptor prefix-argument)))
         (recording-before
           (and (not minibuffer-was-active)
                macro
                (loom/feature/keyboard-macro:keyboard-macro-recording-p macro)))
         (terminal-input-event-p
           (and (not minibuffer-was-active)
                (loom/feature/terminal:terminal-input-event-p event)
                (null sequence)))
         (self-insert-event-p
           (and (not minibuffer-was-active)
                (eq (cl-tty-kit:key-event-type event) :character)
                (not (intersection '(:control :alt)
                                   (cl-tty-kit:key-event-modifiers event)))
                (null prefix-action)
                (null sequence)
                (not terminal-input-event-p)))
         (command
           (and (not minibuffer-was-active)
                (not self-insert-event-p)
                (keymap-lookup
                 (keymap-state-keymap keymap-state)
                 (append sequence (list descriptor)))))
         (terminal-event-p
           (and terminal-input-event-p
                (null command))))
    (%make-input-routing-decision
     :minibuffer minibuffer
     :minibuffer-was-active minibuffer-was-active
     :descriptor descriptor
     :prefix-argument prefix-argument
     :prefix-action prefix-action
     :terminal-event-p terminal-event-p
     :self-insert-event-p self-insert-event-p
     :command command
     :recording-before recording-before)))
