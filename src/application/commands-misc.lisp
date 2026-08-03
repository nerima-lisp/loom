;;;; src/application/commands-misc.lisp
;;;;
;;;; Application layer: the extended-command (M-x) registry, help, quit, and
;;;; keyboard-quit commands (see application/commands-internal.lisp for the
;;;; shared command-authoring convention every commands-*.lisp file follows).
(in-package #:loom)

;; KEYBOARD-QUIT's own cancel path is narrower than it looks: a literal C-g
;; typed while the minibuffer has focus is already handled entirely inside
;; MINIBUFFER-HANDLE-KEY (see its contract in application/minibuffer.lisp --
;; it calls ON-CANCEL and deactivates the minibuffer itself for a C-g
;; KEY-EVENT), so that path never reaches this top-level command at all.
;; MINIBUFFER-HANDLE-KEY's KEY-EVENT is documented as an opaque CL-TTY-KIT
;; object this layer has no business fabricating, and no other public
;; minibuffer operation cancels a prompt programmatically, so this command's
;; only well-defined job is the global-keymap fallback: report "Quit", same
;; as Emacs's top-level C-g when there is nothing else to cancel.
(defun keyboard-quit ()
  "Report a Quit message (C-g)."
  (minibuffer-message (editor-state-minibuffer *editor-state*) "Quit"))

(defmacro define-extended-commands (&body name-command-pairs)
  "Define *EXTENDED-COMMAND-RULEBASE* from NAME-COMMAND-PAIRS, each a
\(STRING-NAME SYMBOL\) pair naming a command invokable by M-x under
STRING-NAME. A single declarative table in place of hand-repeated
CL-PROLOG:DEFINE-RULEBASE clauses, while still compiling down to a real
CL-PROLOG rulebase for %FIND-EXTENDED-COMMAND's query below."
  `(cl-prolog:define-rulebase *extended-command-rulebase*
     ,@(mapcar (lambda (pair)
                 (destructuring-bind (name command) pair
                   `((extended-command ,name ,command))))
               name-command-pairs)))

(progn
  (define-extended-commands
    ("forward-char" forward-char)
    ("backward-char" backward-char)
    ("next-line" next-line)
    ("previous-line" previous-line)
    ("move-beginning-of-line" move-beginning-of-line)
    ("move-end-of-line" move-end-of-line)
    ("delete-char" delete-char)
    ("delete-backward-char" delete-backward-char)
    ("newline" newline-command)
    ("open-line" open-line)
    ("kill-line" kill-line)
    ("kill-region" kill-region)
    ("yank" yank)
    ("set-mark-command" set-mark-command)
    ("undo" undo-command)
    ("search-forward" search-forward)
    ("replace-string" replace-string)
    ("goto-line" goto-line)
    ("find-file" find-file)
    ("save-buffer" save-buffer)
    ("split-window-below" split-window-below)
    ("split-window-right" split-window-right)
    ("other-window" other-window)
    ("switch-to-buffer" switch-to-buffer)
    ("toggle-file-tree" toggle-file-tree)
    ("keyboard-quit" keyboard-quit)
    ("help" help-command)
    ("save-buffers-kill-terminal" save-buffers-kill-terminal))

  (defun %find-extended-command (input)
    "Return the registered command named by INPUT, or NIL."
    (multiple-value-bind (solution foundp)
        (cl-prolog:query-prolog-first
         *extended-command-rulebase*
         `(extended-command ,(string-downcase (string-trim (quote (#\Space #\Tab)) input))
                            ?command))
      (and foundp (cl-prolog:solution-binding (quote ?command) solution))))

  (defun execute-extended-command ()
    "Prompt for a registered command and execute it (M-x)."
    (let ((minibuffer (editor-state-minibuffer *editor-state*)))
      (minibuffer-activate
       minibuffer "M-x "
       :on-confirm
       (lambda (input)
         (let ((command (%find-extended-command input)))
           (if command
               (funcall command)
               (minibuffer-message
                minibuffer
                (format nil "Unknown command: ~A" input))))))))

  (defun help-command ()
    "Show a compact reference for the primary editor commands."
    (minibuffer-message
     (editor-state-minibuffer *editor-state*)
     "Help: M-x Command  C-x C-s Save  C-x C-f Open  C-s Find  C-k Cut  C-y Paste  C-x C-c Exit")))

;; LOOM-QUIT carries no data: it exists only so src/main.lisp's event loop
;; can HANDLER-CASE on a type it, not a plain return value, to tell a real
;; quit apart from every other command's return value. SIGNAL rather than
;; ERROR is deliberate -- an unhandled LOOM-QUIT (e.g. this command called
;; outside the real event loop, such as from a test) is a harmless no-op
;; instead of an unwanted error.
(define-condition loom-quit () ()
  (:documentation
   "Signaled by SAVE-BUFFERS-KILL-TERMINAL to ask the main event loop in
src/main.lisp to exit cleanly."))

(progn
  (defun %quit-buffer-list ()
    "Return each buffer displayed by the current window tree exactly once."
    (remove-duplicates
     (mapcar (function window-buffer)
             (window-tree-windows (editor-state-window-tree *editor-state*)))
     :test (function eq)))

  (defun %quit-answer-action (answer has-path-p)
    "Return the action ANSWER selects for the quit prompt %CONTINUE-QUIT
shows for one modified buffer: :SAVE-AND-CONTINUE, :DISCARD-AND-CONTINUE,
:CANCEL, or :RETRY (an unrecognized answer). HAS-PATH-P is false for a
buffer with no path, whose prompt (\"Discard changes... (d/c)\") never
offers \"s\" in the first place, so an \"s\" answer there falls through to
:RETRY exactly as a genuinely unrecognized answer would."
    (cond ((and has-path-p (string-equal answer "s")) :save-and-continue)
          ((string-equal answer "d") :discard-and-continue)
          ((string-equal answer "c") :cancel)
          (t :retry)))

  (defun %continue-quit (buffers)
    "Prompt for the next modified buffer in BUFFERS, or signal LOOM-QUIT."
    (let ((buffer (find-if (function buffer-modified-p) buffers)))
      (if (null buffer)
          (signal (quote loom-quit))
          (let* ((has-path-p (and (buffer-path buffer) t))
                 (minibuffer (editor-state-minibuffer *editor-state*))
                 (prompt (if has-path-p
                             (format nil "Save ~A? (s/d/c): " (buffer-name buffer))
                             (format nil "Discard changes to ~A? (d/c): " (buffer-name buffer)))))
            (minibuffer-activate
             minibuffer prompt
             :on-confirm
             (lambda (answer)
               (ecase (%quit-answer-action answer has-path-p)
                 (:save-and-continue
                  (buffer-save buffer)
                  (%continue-quit (remove buffer buffers :count 1 :test (function eq))))
                 (:discard-and-continue
                  (%continue-quit (remove buffer buffers :count 1 :test (function eq))))
                 (:cancel nil)
                 (:retry (%continue-quit buffers)))))))))

  (defun save-buffers-kill-terminal ()
    "Exit after resolving all modified displayed buffers."
    (%continue-quit (%quit-buffer-list))))
