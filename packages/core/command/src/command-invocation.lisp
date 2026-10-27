(in-package #:loom/core/command)

(progn (defvar *last-command-editor-state* nil) (defvar *last-command-id* nil) (defvar *previous-command-id* nil))

(defun %command-trace-key-descriptor (descriptor)
  (let* ((normalized (normalize-key-descriptor descriptor))
         (code (cdr normalized)))
    (json-kit:make-json-object
     (list
      (cons "key"
            (typecase code
              (character (string code))
              (keyword (string-downcase (symbol-name code)))
              (t (error "Unsupported command trace key: ~S" code))))
      (cons "modifiers"
            (mapcar (lambda (modifier)
                      (string-downcase (symbol-name modifier)))
                    (car normalized)))))))

(defun %command-trace-key-entry (key-sequence keymap-name)
  (when keymap-name
    (format nil
            "key:~A"
            (json-kit:stringify
             (json-kit:make-json-object
              (list
               (cons "keymap" keymap-name)
               (cons "sequence"
                     (mapcar #'%command-trace-key-descriptor key-sequence))))))))

(defun invoke-command (id route &rest arguments)
  "Resolve ID, record ROUTE, then call the registered command with ARGUMENTS."
  (unless (member route '(:key :mx :macro :paste :mouse))
    (error "Unsupported command route ~S." route))
  (let ((spec (%find-command-spec-by-id id)))
    (unless spec
      (error "No command is registered with ID ~S." id))
    (let* ((state *editor-state*)
           (*previous-command-id*
             (and (eq state *last-command-editor-state*)
                  *last-command-id*)))
      (setf *last-command-editor-state* state
            *last-command-id* id)
      (let ((trace-error
              (record-command-trace
               id
               route
               (%command-trace-key-entry
                *command-trace-key-sequence*
                *command-trace-keymap-name*)))
            (minibuffer (and *editor-state*
                             (editor-state-minibuffer *editor-state*))))
        (when (and trace-error minibuffer)
          (minibuffer-message minibuffer trace-error)))
      (let ((*current-command-route* route)) (apply (%command-spec-command spec) arguments)))))
(defun previous-command-id () "Return the command ID immediately preceding the current invocation, or NIL." *previous-command-id*)
(defun invoke-key-command (id route sequence keymap-name &rest arguments)
  (unless (member route (list :key :macro))
    (error "Key command route must be :KEY or :MACRO: ~S" route))
  (let ((*command-trace-key-sequence* sequence)
        (*command-trace-keymap-name* keymap-name))
    (apply #'invoke-command id route arguments)))

(defun prefix-argument-action (descriptor argument)
  "Return the pending prefix action for DESCRIPTOR, or NIL.

The dispatcher uses this single-value representation so that an action whose
VALUE is NIL (universal argument and sign toggling) remains distinguishable
from an ordinary key that is not a prefix action."
  (multiple-value-bind (kind value)
      (%prefix-argument-descriptor-action descriptor argument)
    (and kind (cons kind value))))

(defun apply-prefix-argument-action (kind value)
  (let ((argument (prefix-argument-for-editor)))
    (case kind
      (:universal (loom/core/command:prefix-argument-universal argument))
      (:digit (loom/core/command:prefix-argument-digit argument value))
      (:negative (loom/core/command:prefix-argument-negative argument))
      (otherwise (error "Unknown prefix argument action: ~S" kind)))))

(defun prefix-argument-value-for-editor ()
  (loom/core/command:prefix-argument-value (prefix-argument-for-editor)))

(defun consume-prefix-argument-for-editor ()
  (loom/core/command:prefix-argument-consume (prefix-argument-for-editor)))

(defun prefix-argument-for-editor ()
  (or
   (loom/core/editor-session:editor-state-prefix-argument
    loom/core/editor-session:*editor-state*)
   (setf (loom/core/editor-session:editor-state-prefix-argument
          loom/core/editor-session:*editor-state*) (loom/core/command:make-prefix-argument))))

(defun %prefix-argument-descriptor-action (descriptor argument)
  (check-type argument loom/core/command:prefix-argument)
  (let* ((normalized
          (if (and (consp descriptor) (listp (car descriptor)))
              descriptor
              (cons nil descriptor)))
         (modifiers (car normalized))
         (code (cdr normalized))
         (active-p (loom/core/command:prefix-argument-active-p argument))
         (digit (%digit-prefix-descriptor-value modifiers code active-p)))
    (case (%prefix-action-kind modifiers code active-p)
      (:digit (values :digit digit))
      (:universal (values :universal nil))
      (:negative (values :negative nil))
      (otherwise (values nil nil)))))

(defun %prefix-action-kind (modifiers code active-p)
  (cond
    ((%universal-prefix-descriptor-p modifiers code) :universal)
    ((%digit-prefix-descriptor-value modifiers code active-p) :digit)
    ((%negative-prefix-descriptor-p modifiers code active-p) :negative)))

(defun %negative-prefix-descriptor-p (modifiers code active-p)
  (let ((alt-p (%alternate-prefix-descriptor-p modifiers)))
    (and (characterp code)
         (char= code #\-)
         (or alt-p (and active-p (null modifiers))))))

(defun %digit-prefix-descriptor-value (modifiers code active-p)
  (let ((digit (and (characterp code) (digit-char-p code)))
        (alt-p (%alternate-prefix-descriptor-p modifiers)))
    (when (and digit (or alt-p (and active-p (null modifiers))))
      digit)))

(defun %alternate-prefix-descriptor-p (modifiers)
  (and (member :alt modifiers) (not (member :control modifiers))))

(defun %universal-prefix-descriptor-p (modifiers code)
  (and (equal modifiers '(:control)) (characterp code) (char-equal code #\u)))

(defun %self-insert-character (character)
  (editor-state-clear-last-yank *editor-state*)
  (setf (editor-state-last-command-kill-p *editor-state*) nil)
  (let ((text (%repeated-character character (or *current-prefix-argument* 1))))
    (when text
      (buffer-insert-string (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*))) text))))

(defun %repeated-character (character count)
  (when (plusp count)
    (make-string count :initial-element character)))

(defun self-insert-command (character)
  "Insert CHARACTER repeatedly according to the active numeric prefix."
  (%self-insert-character character))
(defun %insert-pasted-text-command (text)
  (unless (stringp text)
    (error "Pasted text must be a string: ~S" text))
  (record-undo-boundary-for-command nil)
  (editor-state-clear-last-yank *editor-state*)
  (setf (editor-state-last-command-kill-p *editor-state*) nil)
  (buffer-insert-string
   (loom/core/window-tree:window-buffer
    (loom/core/window-tree:window-tree-selected-window
     (editor-state-window-tree *editor-state*)))
   text))
(progn
  (register-internal-command
   :core/command "core/self-insert" (function self-insert-command)
   :mutates t :prompts nil :needs-region nil :external nil :modes (list :all))
  (register-internal-command
   :core/command "core/insert-pasted-text"
   (function %insert-pasted-text-command)
   :mutates t :prompts nil :needs-region nil :external nil :modes (list :all)))

(defun record-undo-boundary-for-command (self-insert-p)
  "Record a buffer undo boundary when the command kind changes.

SELF-INSERT-P is true for SELF-INSERT-COMMAND and false for keymap-dispatched
commands. Consecutive self inserts therefore collapse into one undo group,
while switching to any other command starts a new group."
  (unless (eq self-insert-p
              (editor-state-last-command-self-insert-p *editor-state*))
    (buffer-record-undo-boundary (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*)))))
  (setf (editor-state-last-command-self-insert-p *editor-state*) self-insert-p))
