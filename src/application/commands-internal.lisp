;;;; src/application/commands-internal.lisp
;;;;
;;;; Application layer: commands are the use-case entry points a keymap
;;;; binding invokes, split by concern (movement, editing, search, file,
;;;; window, misc, keybindings) into the sibling application/commands-*.lisp
;;;; files this one is loaded ahead of.
;;;;
;;;; Commands are NOT declared as generic functions: each editable command is
;;;; a plain, ordinary function of zero arguments that reads and mutates
;;;; *EDITOR-STATE* (see application/editor-state.lisp) and the protocol
;;;; operations declared in domain/, infrastructure/, and application/ when
;;;; invoked, e.g.:
;;;;
;;;;   (defun forward-char ()
;;;;     "Move point forward one character in the selected window's buffer."
;;;;     (let ((window (window-tree-selected-window
;;;;                    (editor-state-window-tree *editor-state*))))
;;;;       (buffer-set-point (window-buffer window) ...)))
;;;;
;;;; A keymap binds a key sequence directly to such a function (see
;;;; KEYMAP-DEFINE-KEY), so command names are the vocabulary keymap bindings
;;;; are written against. Commands are named after their Emacs equivalents
;;;; where one exists (FORWARD-CHAR, KILL-LINE, SAVE-BUFFER, ...) so the
;;;; mapping from a keybinding to its behavior stays obvious from
;;;; domain/keymap.lisp alone.
;;;;
;;;; The shared use-case primitives in this file belong to LOOM/APPLICATION.
;;;; Feature commands use that explicit package directly, while the kernel
;;;; package inherits the names for the command files that remain in the
;;;; composition root.
;;;;
;;;; %SELECTED-WINDOW/%SELECTED-BUFFER and the WITH-PROMPTS macro below are
;;;; what every other commands-*.lisp file depends on, which is why this file
;;;; loads first among them: WITH-PROMPTS in particular must be defined before
;;;; any file that expands it is compiled, and its callers are spread across
;;;; the movement, search, file, window, and misc command files.
(in-package #:loom/application)

(defun %selected-window ()
  "Return *EDITOR-STATE*'s currently selected window."
  (loom/feature/window:window-tree-selected-window
   (loom:editor-state-window-tree loom:*editor-state*)))

(defun %selected-buffer ()
  "Return the buffer displayed in *EDITOR-STATE*'s currently selected window."
  (loom/feature/window:window-buffer (%selected-window)))

(defun %editor-buffers ()
  "Return the buffers known to the current editor session."
  (loom:editor-state-buffers loom:*editor-state*))

(defun %register-buffer (buffer)
  "Add BUFFER to the current session's registry unless it is already present."
  (pushnew buffer (loom:editor-state-buffers loom:*editor-state*) :test #'eq)
  buffer)

(defun %unregister-buffer (buffer)
  "Remove BUFFER from the current session's registry."
  (setf (loom:editor-state-buffers loom:*editor-state*)
        (remove buffer
                (loom:editor-state-buffers loom:*editor-state*)
                :test #'eq))
  buffer)

(defun %order-region (point-line point-column mark-line mark-column)
  "Return the region bounds in buffer order.

Positions are compared by line and then by column.  Keeping this pure
ordering operation in the shared application package lets register commands
reuse it without depending on the editor command implementation."
  (if (or (< point-line mark-line)
          (and (= point-line mark-line) (<= point-column mark-column)))
      (values point-line point-column mark-line mark-column)
      (values mark-line mark-column point-line point-column)))

(defmacro with-prompts ((minibuffer-var minibuffer-form &key on-cancel) bindings &body body)
  "Prompt for each (VAR PROMPT-STRING &KEY COMPLETION-FUNCTION) pair in
BINDINGS in turn, binding VAR to the typed input, then run BODY with every VAR
bound and MINIBUFFER-VAR bound to MINIBUFFER-FORM's value (evaluated once).
ON-CANCEL, when supplied, is a form -- evaluated with MINIBUFFER-VAR in scope
-- run if the user
cancels (C-g) at any prompt in the chain, not only the first; it is threaded
into every generated MINIBUFFER-ACTIVATE's :ON-CANCEL, and the keyword is
omitted entirely when ON-CANCEL is absent.

MINIBUFFER-ACTIVATE returns immediately; the typed answer only arrives later,
asynchronously, through its :ON-CONFIRM callback. A second, dependent prompt
therefore cannot be issued until the first one's callback runs -- the
continuation-passing chain REPLACE-STRING needs (prompt for the text to
replace, THEN prompt for its replacement) is unavoidable by construction.
WITH-PROMPTS is that chain written once, as a macro that expands BINDINGS
into nested MINIBUFFER-ACTIVATE/:ON-CONFIRM continuations, so a multi-prompt
command reads top-to-bottom like ordinary sequential code instead of as a
hand-nested pyramid of lambdas."
  (labels ((expand-bindings (bindings)
             (if bindings
                 (destructuring-bind (var prompt &key completion-function)
                     (first bindings)
                   `(loom:minibuffer-activate ,minibuffer-var ,prompt
                                         :on-confirm (lambda (,var)
                                                       ,(expand-bindings (rest bindings)))
                                         ,@(when completion-function
                                             `(:completion-function
                                               ,completion-function))
                                         ,@(when on-cancel
                                             `(:on-cancel (lambda () ,on-cancel)))))
                 `(progn ,@body))))
    `(let ((,minibuffer-var ,minibuffer-form))
       ,(expand-bindings bindings))))
