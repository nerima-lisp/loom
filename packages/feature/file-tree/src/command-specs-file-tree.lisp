(in-package #:loom/core/command)
(register-command-spec :feature/file-tree "toggle-file-tree" "toggle-file-tree" #'loom/feature/file-tree:toggle-file-tree
  :keys '((( :control #\x) #\d))
  :keymap :global :group "file tree" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/file-tree "file-tree-select-next" "file-tree-select-next" #'loom/feature/file-tree:file-tree-select-next
  :keys '((( :control #\c) #\n))
  :keymap :file-tree-local :group "file tree" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:file-tree))
(register-command-spec :feature/file-tree "file-tree-select-previous" "file-tree-select-previous" #'loom/feature/file-tree:file-tree-select-previous
  :keys '((( :control #\c) #\p))
  :keymap :file-tree-local :group "file tree" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:file-tree))
(register-command-spec :feature/file-tree "file-tree-open-selected" "file-tree-open-selected" #'loom/feature/file-tree:file-tree-open-selected
  :keys '((( :control #\c) #\o))
  :keymap :file-tree-local :group "file tree" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:file-tree))
(register-command-spec :feature/file-tree "file-tree-create-file" "file-tree-create-file" #'loom/feature/file-tree:file-tree-create-file-command
  :keys '((( :control #\c) #\c))
  :keymap :file-tree-local :group "file tree" :help nil :help-order nil
  :mutates nil :prompts '(:free-string) :needs-region nil :external '() :modes '(:file-tree))
(register-command-spec :feature/file-tree "file-tree-create-directory" "file-tree-create-directory" #'loom/feature/file-tree:file-tree-create-directory-command
  :keys '((( :control #\c) #\d))
  :keymap :file-tree-local :group "file tree" :help nil :help-order nil
  :mutates nil :prompts '(:free-string) :needs-region nil :external '() :modes '(:file-tree))
(register-command-spec :feature/file-tree "file-tree-rename" "file-tree-rename" #'loom/feature/file-tree:file-tree-rename-command
  :keys '()
  :keymap :global :group "file tree" :help nil :help-order nil
  :mutates nil :prompts '(:free-string) :needs-region nil :external '() :modes '(:all))
(register-command-spec :feature/file-tree "file-tree-delete" "file-tree-delete" #'loom/feature/file-tree:file-tree-delete-command
  :keys '()
  :keymap :global :group "file tree" :help nil :help-order nil
  :mutates nil :prompts '() :needs-region nil :external '() :modes '(:all))
(loom/feature/mode:register-major-mode
 :file-tree
 :name "File Tree"
 :keybindings
 (list
  (cons '((:control #\c) #\n)
        #'loom/feature/file-tree:file-tree-select-next)
  (cons '((:control #\c) #\p)
        #'loom/feature/file-tree:file-tree-select-previous)
  (cons '((:control #\c) #\o)
        #'loom/feature/file-tree:file-tree-open-selected)
  (cons '((:control #\c) #\c)
        #'loom/feature/file-tree:file-tree-create-file-command)
  (cons '((:control #\c) #\d)
        #'loom/feature/file-tree:file-tree-create-directory-command)))
