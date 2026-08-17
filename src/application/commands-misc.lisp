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

(defun %bookmark-table ()
  "Return the current session's named bookmark table, creating it on demand."
  (or (editor-state-bookmarks *editor-state*)
      (setf (editor-state-bookmarks *editor-state*)
            (make-hash-table :test #'equal))))

(defun %bookmark-name (input)
  "Normalize a minibuffer bookmark name without changing its case."
  (string-trim '(#\Space #\Tab) input))

(defun %bookmark-candidates (input)
  "Return bookmark names matching the typed INPUT prefix."
  (let ((prefix (%bookmark-name input)))
    (sort
     (loop for name being the hash-keys of (%bookmark-table)
           when (or (zerop (length prefix))
                    (and (<= (length prefix) (length name))
                         (string-equal prefix name
                                       :end2 (length prefix))))
             collect name)
     #'string<)))

(defun %bookmark-target-buffer (bookmark)
  "Resolve BOOKMARK to a live buffer, loading its file when necessary."
  (let ((saved-buffer (editor-bookmark-buffer bookmark)))
    (or (and saved-buffer
             (find saved-buffer (%editor-buffers) :test #'eq))
        (let ((path (editor-bookmark-path bookmark)))
          (when path
            (let ((existing-path (probe-file path)))
              (when (and existing-path
                         (not (host-kit:directory-pathname-p existing-path)))
                (let ((buffer (buffer-load existing-path)))
                  (%register-buffer buffer)
                  (remember-recent-file existing-path)
                  buffer))))))))

(defun set-bookmark ()
  "Prompt for a name and save the selected buffer position under it."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((name "Set bookmark: "))
    (let ((bookmark-name (%bookmark-name name))
          (buffer (%selected-buffer)))
      (if (zerop (length bookmark-name))
          (minibuffer-message minibuffer "Bookmark name cannot be empty")
          (progn
            (setf (gethash bookmark-name (%bookmark-table))
                  (make-editor-bookmark
                   :name bookmark-name
                   :buffer buffer
                   :path (editor-path-string (buffer-path buffer))
                   :buffer-name (buffer-name buffer)
                   :line (buffer-point-line buffer)
                   :column (buffer-point-column buffer)))
            (minibuffer-message
             minibuffer
             (format nil "Bookmark set: ~A" bookmark-name)))))))

(defun jump-to-bookmark ()
  "Prompt for a bookmark name and select its saved buffer position."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((name "Jump to bookmark: " :completion-function #'%bookmark-candidates))
    (let* ((bookmark-name (%bookmark-name name))
           (bookmark (gethash bookmark-name (%bookmark-table)))
           (buffer (and bookmark (%bookmark-target-buffer bookmark))))
      (cond
        ((null bookmark)
         (minibuffer-message
          minibuffer
          (format nil "Unknown bookmark: ~A" bookmark-name)))
        ((null buffer)
         (minibuffer-message
          minibuffer
          (format nil "Bookmark target is unavailable: ~A" bookmark-name)))
        (t
         (loom/feature/window:window-set-buffer (%selected-window) buffer)
         (buffer-set-point buffer
                           (editor-bookmark-line bookmark)
                           (editor-bookmark-column bookmark)))))))

(defun delete-bookmark ()
  "Prompt for a bookmark name and remove it from the current session."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((name "Delete bookmark: " :completion-function #'%bookmark-candidates))
    (let ((bookmark-name (%bookmark-name name)))
      (if (remhash bookmark-name (%bookmark-table))
          (minibuffer-message minibuffer
                               (format nil "Deleted bookmark: ~A" bookmark-name))
          (minibuffer-message minibuffer
                               (format nil "Unknown bookmark: ~A" bookmark-name))))))

(defun list-bookmarks ()
  "Display the names of all bookmarks in the current session."
  (let ((names (%bookmark-candidates "")))
    (minibuffer-message
     (editor-state-minibuffer *editor-state*)
     (if names
         (format nil "Bookmarks: ~{~A~^, ~}" names)
         "No bookmarks"))))

(defun help-command ()
  "Show a compact reference for the primary editor commands."
  (minibuffer-message
   (editor-state-minibuffer *editor-state*)
   "Help: M-x Command  M-: Eval  C-x C-e Eval buffer  M-! Pipe command  C-x g Git status  M-x git-diff  M-x git-diff-staged  M-x git-stage-file  M-x git-unstage-file  M-x format-current-buffer  M-x lsp-start  M-x lsp-stop  M-x lsp-diagnostics  C-x C-s Save  C-x C-f Open  C-x k Kill  C-x r S Save session  C-x r l Load session  C-x r f Recent file  C-x r m Set bookmark  C-x r b Jump bookmark  C-x r d Delete bookmark  C-x r s Copy region to register  C-x r i Insert register  C-x r SPC Point to register  C-x r j Jump to register  C-x ( Start macro  C-x ) End macro  C-x e Replay macro  C-s Find  C-k Cut  M-w Copy  C-y Paste  C-x C-u Undo  C-x C-y Redo  M-y Yank previous  C-x C-c Exit"))

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

  ;; A CL-PROLOG-KIT rulebase keeps the quit-prompt answer table declarative.
  ;; FIND-EXTENDED-COMMAND uses the explicit registry for name lookup.
  (cl-prolog-kit:define-rulebase *quit-answer-rulebase*
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
    (or (cl-prolog-kit:with-prolog-query (?action)
            (*quit-answer-rulebase* `(quit-action ,answer ,has-path-p ?action))
          ?action)
        :retry))

  (defun %quit-prompt-text (buffer)
    "Return the confirmation prompt for modified BUFFER."
    (if (buffer-path buffer)
        (format nil "Save ~A? (s/d/c): " (buffer-name buffer))
        (format nil "Discard changes to ~A? (d/c): " (buffer-name buffer))))

  (defun %continue-quit-prompt (buffers buffer next)
    "Activate the quit prompt for BUFFER and continue with NEXT.
NEXT receives the remaining buffer list after a save or discard, or the
original list when the answer is invalid."
    (let* ((has-path-p (and (buffer-path buffer) t))
           (minibuffer (editor-state-minibuffer *editor-state*)))
      (minibuffer-activate
       minibuffer
       (%quit-prompt-text buffer)
       :on-confirm
       (lambda (answer)
         (ecase (%quit-answer-action answer has-path-p)
           (:save-and-continue
            (buffer-save buffer)
            (funcall next (remove buffer buffers :count 1 :test (function eq))))
           (:discard-and-continue
            (funcall next (remove buffer buffers :count 1 :test (function eq))))
           (:cancel nil)
           (:retry (funcall next buffers))))
       :on-cancel
       (lambda () (minibuffer-message minibuffer "Quit")))))

  (defun %continue-quit (buffers)
    "Prompt for the next modified buffer in BUFFERS, or signal LOOM-QUIT."
    (let ((buffer (find-if (function buffer-modified-p) buffers)))
      (if (null buffer)
          (signal (quote loom-quit))
          (%continue-quit-prompt
           buffers buffer
           (lambda (next-buffers)
             (%continue-quit next-buffers))))))

  (defun save-buffers-kill-terminal ()
    "Exit after resolving all modified buffers in the session."
    (%continue-quit (%quit-buffer-list))))
