;;;; t/test-helpers-prompts.lisp
(in-package #:loom/test)

(defun %save-buffer-prompt-string (buffer)
  "Return the quit/save prompt for a path-backed BUFFER."
  (format nil "Save ~A? (s/d/c): " (buffer-name buffer)))

(defun %discard-buffer-prompt-string (buffer)
  "Return the quit/discard prompt for a pathless BUFFER."
  (format nil "Discard changes to ~A? (d/c): " (buffer-name buffer)))

(defun %m-x-prompt-string ()
  "Return the extended-command prompt."
  "M-x ")

(defun %search-regex-prompt-string ()
  "Return the regular-expression search prompt."
  "Search (regex): ")

(defun %replace-regex-prompt-string ()
  "Return the regular-expression replace source prompt."
  "Replace (regex): ")

(defun %replace-with-prompt-string ()
  "Return the regular-expression replace destination prompt."
  "With: ")

(defun %goto-line-prompt-string ()
  "Return the goto-line prompt."
  "Go to line: ")

(defun %project-file-prompt-string ()
  "Return the project file selection prompt."
  "Project file: ")

(defun %project-search-prompt-string ()
  "Return the project search prompt."
  "Project search: ")

(defun %major-mode-prompt-string ()
  "Return the major-mode selection prompt."
  "Major mode: ")

(defun %copy-to-register-prompt-string ()
  "Return the register copy prompt."
  "Copy region to register: ")

(defun %insert-register-prompt-string ()
  "Return the register insert prompt."
  "Insert register: ")

(defun %save-session-prompt-string ()
  "Return the session-save path prompt."
  "Save session to: ")

(defun %load-session-prompt-string ()
  "Return the session-load path prompt."
  "Load session: ")

(defun %switch-workspace-prompt-string ()
  "Return the workspace selection prompt."
  "Switch to workspace: ")

(defun %lsp-command-prompt-string (default-command)
  "Return the LSP command prompt for DEFAULT-COMMAND."
  (format nil "LSP command [RET for ~A]: " default-command))

(defmacro %expect-minibuffer-prompt (minibuffer expected-prompt-form)
  "Assert that MINIBUFFER currently shows EXPECTED-PROMPT-FORM."
  `(expect (minibuffer-prompt-string ,minibuffer)
           :to-equal ,expected-prompt-form))
