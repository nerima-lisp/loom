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

(defmacro command-spec (name command &key keys)
  "Describe COMMAND's M-x NAME and its optional default key sequence data."
  (unless (or (null name) (stringp name))
    (error "COMMAND-SPEC name must be a string or NIL: ~S" name))
  (unless (symbolp command)
    (error "COMMAND-SPEC command must be a symbol: ~S" command))
  `(list :name ,name :command ',command :keys ',keys))

(defmacro define-command-specs (&body specs)
  "Define the command registry and rulebase from COMMAND-SPEC forms.

Each spec is the single source for the command's extended-command name and
default key sequences. NIL names describe keymap-only commands such as M-x
itself. The explicit registry is used for lookup; the generated rulebase is
an internal implementation detail for command dispatch."
  (let ((entries
          (mapcar
           (lambda (spec)
             (unless (and (consp spec) (eq (first spec) 'command-spec))
               (error "Expected a COMMAND-SPEC form, got: ~S" spec))
             (destructuring-bind (operator name command &key keys) spec
               (declare (ignore operator))
               (unless (or (null name) (stringp name))
                 (error "COMMAND-SPEC name must be a string or NIL: ~S" name))
               (unless (symbolp command)
                 (error "COMMAND-SPEC command must be a symbol: ~S" command))
               (list name command keys)))
           specs)))
    (let* ((names (remove nil (mapcar (function first) entries)))
           (duplicate
             (find-if (lambda (name)
                        (> (count name names :test (function string-equal)) 1))
                      names)))
      (when duplicate
        (error "Duplicate COMMAND-SPEC name: ~S" duplicate)))
    `(progn
       (defparameter *command-specs*
         (list
          ,@(mapcar
             (lambda (entry)
               (destructuring-bind (name command keys) entry
                 `(list :name ,name :command ',command :keys ',keys)))
             entries)))
       (cl-prolog:define-rulebase *extended-command-rulebase*
         ,@(mapcar
            (lambda (entry)
              (destructuring-bind (name command keys) entry
                (declare (ignore keys))
                `((extended-command ,name ,command))))
            (remove nil entries :key (function first)))))))

(progn
  (define-command-specs
    (command-spec "forward-char" forward-char :keys ((:control #\f)))
    (command-spec "backward-char" backward-char :keys ((:control #\b)))
    (command-spec "next-line" next-line :keys ((:control #\n)))
    (command-spec "previous-line" previous-line :keys ((:control #\p)))
    (command-spec "forward-word" forward-word :keys ((:alt #\f)))
    (command-spec "backward-word" backward-word :keys ((:alt #\b)))
    (command-spec "move-beginning-of-line" move-beginning-of-line
                  :keys ((:control #\a)))
    (command-spec "move-end-of-line" move-end-of-line :keys ((:control #\e)))
    (command-spec "beginning-of-buffer" beginning-of-buffer :keys ((:alt #\<)))
    (command-spec "end-of-buffer" end-of-buffer :keys ((:alt #\>)))
    (command-spec "scroll-up-command" scroll-up-command :keys ((:control #\v)))
    (command-spec "scroll-down-command" scroll-down-command :keys ((:alt #\v)))
    (command-spec "delete-char" delete-char :keys ((:control #\d)))
    (command-spec "delete-backward-char" delete-backward-char
                  :keys (:backspace))
    (command-spec "newline" newline-command :keys (:enter))
    (command-spec "open-line" open-line :keys ((:control #\o)))
    (command-spec "kill-line" kill-line :keys ((:control #\k)))
    (command-spec "kill-word" kill-word :keys ((:alt #\d)))
    (command-spec "backward-kill-word" backward-kill-word
                  :keys ((:alt :backspace)))
    (command-spec "kill-region" kill-region :keys ((:control #\w)))
    (command-spec "yank" yank :keys ((:control #\y)))
    (command-spec "set-mark-command" set-mark-command
                  :keys ((:control #\Space)))
    (command-spec "exchange-point-and-mark" exchange-point-and-mark
                  :keys (((:control #\x) (:control #\x))))
    (command-spec "mark-whole-buffer" mark-whole-buffer
                  :keys (((:control #\x) #\h)))
    (command-spec "undo" undo-command
                  :keys (((:control #\x) #\u)))
    (command-spec "search-forward" search-forward :keys ((:control #\s)))
    (command-spec "search-backward" search-backward :keys ((:control #\r)))
    (command-spec "replace-string" replace-string :keys ((:alt #\%)))
    (command-spec "goto-line" goto-line :keys (((:alt #\g) #\g)))
    (command-spec "find-file" find-file
                  :keys (((:control #\x) (:control #\f))))
    (command-spec "save-buffer" save-buffer
                  :keys (((:control #\x) (:control #\s))))
    (command-spec "write-file" write-file
                  :keys (((:control #\x) (:control #\w))))
    (command-spec "split-window-below" split-window-below
                  :keys (((:control #\x) #\2)))
    (command-spec "split-window-right" split-window-right
                  :keys (((:control #\x) #\3)))
    (command-spec "other-window" other-window
                  :keys (((:control #\x) #\o)))
    (command-spec "delete-window" delete-window
                  :keys (((:control #\x) #\0)))
    (command-spec "delete-other-windows" delete-other-windows
                  :keys (((:control #\x) #\1)))
    (command-spec "switch-to-buffer" switch-to-buffer
                  :keys (((:control #\x) #\b)))
    (command-spec "toggle-file-tree" toggle-file-tree
                  :keys (((:control #\x) (:control #\t))))
    (command-spec "file-tree-select-next" file-tree-select-next
                  :keys (((:control #\c) #\n)))
    (command-spec "file-tree-select-previous" file-tree-select-previous
                  :keys (((:control #\c) #\p)))
    (command-spec "file-tree-open-selected" file-tree-open-selected
                  :keys (((:control #\c) #\o)))
    (command-spec "file-tree-create-file" file-tree-create-file-command
                  :keys (((:control #\c) #\c)))
    (command-spec "file-tree-create-directory" file-tree-create-directory-command
                  :keys (((:control #\c) #\d)))
    (command-spec "file-tree-rename" file-tree-rename-command)
    (command-spec "file-tree-delete" file-tree-delete-command)
    (command-spec "keyboard-quit" keyboard-quit :keys ((:control #\g)))
    (command-spec "help" help-command :keys ((:control #\h) :f1))
    (command-spec "save-buffers-kill-terminal" save-buffers-kill-terminal
                  :keys (((:control #\x) (:control #\c))))
    (command-spec nil execute-extended-command :keys ((:alt #\x))))

  (defun %find-extended-command (input)
    "Return the registered command named by INPUT, or NIL."
    (let ((name (string-downcase (string-trim (quote (#\Space #\Tab)) input))))
      (getf
       (find-if (lambda (spec)
                  (and (getf spec :name)
                       (string= name (getf spec :name))))
                *command-specs*)
       :command)))

  (defun execute-extended-command ()
    "Prompt for a registered command and execute it (M-x)."
    (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                   :on-cancel (minibuffer-message minibuffer "Quit"))
        ((input "M-x "))
      (let ((command (%find-extended-command input)))
        (if command
            (funcall command)
            (minibuffer-message
             minibuffer
             (format nil "Unknown command: ~A" input))))))

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

  ;; A CL-PROLOG rulebase keeps the quit-prompt answer table declarative.
  ;; The COMMAND-SPEC macro emits a rulebase as inspectable metadata, while
  ;; %FIND-EXTENDED-COMMAND uses the explicit registry for name lookup.
  (cl-prolog:define-rulebase *quit-answer-rulebase*
    ((quit-action ?answer ?has-path :save-and-continue)
     (:when (and ?has-path (string-equal ?answer "s"))))
    ((quit-action ?answer ?has-path :discard-and-continue)
     (:when (string-equal ?answer "d")))
    ((quit-action ?answer ?has-path :cancel)
     (:when (string-equal ?answer "c"))))

  (defun %quit-answer-action (answer has-path-p)
    "Return the action ANSWER selects for the quit prompt %CONTINUE-QUIT
shows for one modified buffer: :SAVE-AND-CONTINUE, :DISCARD-AND-CONTINUE,
:CANCEL, or :RETRY (an unrecognized answer). HAS-PATH-P is false for a
buffer with no path, whose prompt (\"Discard changes... (d/c)\") never
offers \"s\" in the first place, so an \"s\" answer there falls through to
:RETRY exactly as a genuinely unrecognized answer would."
    (or (cl-prolog:with-prolog-query (?action)
            (*quit-answer-rulebase* `(quit-action ,answer ,has-path-p ?action))
          ?action)
        :retry))

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
                 (:retry (%continue-quit buffers))))
             :on-cancel
             (lambda () (minibuffer-message minibuffer "Quit")))))))

  (defun save-buffers-kill-terminal ()
    "Exit after resolving all modified displayed buffers."
    (%continue-quit (%quit-buffer-list))))
