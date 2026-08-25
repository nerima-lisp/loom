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
;;;; invoked. A keymap binds a key sequence directly to such a function (see
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
;;;; %SELECTED-WINDOW/%SELECTED-BUFFER and the other helpers below are shared
;;;; by command entry points throughout the tree. Prompt composition macros
;;;; live in commands-prompts.lisp so their compile/load order is explicit and
;;;; independent from editor-state helper functions.
(in-package #:loom/application)

(defun %selected-window ()
  "Return *EDITOR-STATE*'s currently selected window."
  (loom/feature/window:window-tree-selected-window
   (loom:editor-state-window-tree loom:*editor-state*)))

(defun %selected-window-tree ()
  "Return *EDITOR-STATE*'s current window tree."
  (loom:editor-state-window-tree loom:*editor-state*))

(defun %selected-buffer ()
  "Return the buffer displayed in *EDITOR-STATE*'s currently selected window."
  (loom/feature/window:window-buffer (%selected-window)))

(defmacro define-selected-buffer-command (name docstring target)
  "Define NAME as a zero-argument command forwarding the selected buffer to TARGET."
  `(defun ,name ()
     ,docstring
     (,target (%selected-buffer))))

(defmacro define-selected-tree-window-command (name docstring target &rest arguments)
  "Define NAME as a zero-argument command forwarding the selected tree and window to TARGET."
  `(defun ,name ()
     ,docstring
     (,target (%selected-window-tree) (%selected-window) ,@arguments)))

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
