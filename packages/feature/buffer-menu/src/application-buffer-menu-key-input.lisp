(in-package #:loom/feature/buffer-menu)

;;; Unmodified character keys are routed to self-insert before any keymap is
;;; consulted, so the list's single-letter bindings are dispatched from the
;;; key-input hook instead. The event loop's pending prefix (for example the
;;; C-x of C-x o) is not visible to hooks, so this hook tracks it for list
;;; buffers and leaves keys that continue a prefix to the normal keymap path.

(defvar *buffer-menu-pending-keys* nil
  "Descriptors of the unfinished key sequence typed in a buffer list.")

(defvar *buffer-menu-pending-keymap* nil
  "The active keymap *BUFFER-MENU-PENDING-KEYS* was read against.")

(defun %buffer-menu-plain-character-p (event)
  (and (eq (cl-tty-kit:key-event-type event) :character)
       (null (cl-tty-kit:key-event-modifiers event))))

(defun %buffer-menu-local-command (keymap descriptor)
  "Return the command bound to DESCRIPTOR in the buffer-menu mode keymap."
  (multiple-value-bind (command owner) (keymap-lookup keymap (list descriptor))
    (and (stringp command)
         (eq owner (major-mode-keymap :buffer-menu
                                      (editor-state-keymap *editor-state*)))
         command)))

(defun %invoke-buffer-menu-key (command descriptor)
  "Run COMMAND the way the keymap dispatcher runs a bound key."
  (minibuffer-message (editor-state-minibuffer *editor-state*) nil)
  (editor-state-clear-last-yank *editor-state*)
  (setf (editor-state-last-command-kill-p *editor-state*) nil)
  (invoke-key-command command :key (list descriptor) "buffer-menu"))

(defun %buffer-menu-key-input-hook (session event kind)
  ;; Sessions without editor state (hook unit tests of other slices) pass.
  (let* ((state *editor-state*)
         (tree (and state (editor-state-window-tree state)))
         (buffer (and tree (window-buffer (window-tree-selected-window tree))))
         (minibuffer (and state (editor-state-minibuffer state)))
         (prefix-argument (and state (editor-state-prefix-argument state))))
    (cond
      ((and minibuffer (minibuffer-active-p minibuffer)) :pass)
      ((not (and (eq kind :key)
                 buffer
                 (eq (buffer-major-mode buffer) :buffer-menu)))
       (setf *buffer-menu-pending-keys* nil)
       :pass)
      (t
       (let* ((keymap (keymap-for-buffer session buffer
                                         (editor-state-keymap *editor-state*)))
              (descriptor (key-event->descriptor event))
              (pending (and (eq keymap *buffer-menu-pending-keymap*)
                            *buffer-menu-pending-keys*))
              (command (and (null pending)
                            (%buffer-menu-plain-character-p event)
                            (not (and prefix-argument
                                      (prefix-argument-active-p prefix-argument)))
                            (%buffer-menu-local-command keymap descriptor))))
         (if command
             (progn
               (setf *buffer-menu-pending-keys* nil)
               (%invoke-buffer-menu-key command descriptor)
               :handled)
             (let ((sequence (append pending (list descriptor))))
               (setf *buffer-menu-pending-keymap* keymap
                     *buffer-menu-pending-keys*
                     (and (eq (keymap-lookup keymap sequence) :prefix)
                          sequence))
               :pass)))))))

(eval-when (:load-toplevel :execute)
  (register-session-hook :key-input
                         :feature/buffer-menu
                         #'%buffer-menu-key-input-hook))
