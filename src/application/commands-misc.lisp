;;;; src/application/commands-misc.lisp
;;;;
;;;; Application layer: help, quit, and keyboard-quit commands.
;;;; The command catalogue is kept in application/command-definitions.lisp;
;;;; the registry implementation is in application/command-registry.lisp.
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
  (prefix-argument-reset (prefix-argument-for-editor))
  (minibuffer-message (editor-state-minibuffer *editor-state*) "Quit"))

(defun execute-extended-command ()
  "Prompt for a registered command and execute it (M-x)."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((input "M-x "
              :completion-function
              #'loom/application:command-completion-candidates))
    (let ((command (loom/application:find-extended-command input)))
      (if command
          (funcall command)
          (minibuffer-message
           minibuffer
           (format nil "Unknown command: ~A" input))))))

(defun help-command ()
  "Show a compact reference for the primary editor commands."
  (minibuffer-message
   (editor-state-minibuffer *editor-state*)
   "Help: M-x Command  M-: Eval  C-x C-e Eval buffer  M-x lsp-start  M-x lsp-stop  M-x lsp-diagnostics  C-x C-s Save  C-x C-f Open  C-x k Kill  C-x r S Save session  C-x r l Load session  C-x r s Copy region to register  C-x r i Insert register  C-x r SPC Point to register  C-x r j Jump to register  C-x ( Start macro  C-x ) End macro  C-x e Replay macro  C-s Find  C-k Cut  C-y Paste  C-x C-c Exit"))

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
    "Return displayed buffers followed by hidden registered buffers."
    (let ((displayed
            (mapcar (function loom/feature/window:window-buffer)
                    (loom/feature/window:window-tree-windows
                     (editor-state-window-tree *editor-state*))))
          (registered (copy-list (%editor-buffers))))
      (remove-duplicates
       (append displayed registered)
       :test (function eq))))

  ;; A CL-PROLOG rulebase keeps the quit-prompt answer table declarative.
  ;; FIND-EXTENDED-COMMAND uses the explicit registry for name lookup.
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
    "Exit after resolving all modified buffers in the session."
    (%continue-quit (%quit-buffer-list))))
