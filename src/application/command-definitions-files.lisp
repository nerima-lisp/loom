(in-package #:loom)

(define-command-spec-groups *files-command-spec-groups*
  (command-spec-group "files and projects"
      (command-spec "find-file" loom/feature/file-tree:find-file
                    :keys (((:control #\x) (:control #\f)))
                    :help "C-x C-f Open"
                    :help-order 15
                    :mutates NIL
                    :prompts (:free-string)
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "set-major-mode" loom/feature/mode:set-major-mode
                    :mutates NIL
                    :prompts (:completion)
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "toggle-truncate-lines"
                    loom/feature/mode:toggle-truncate-lines
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "project-find-file" loom/feature/project:project-find-file
                    :keys (((:control #\x) #\p #\f))
                    :mutates NIL
                    :prompts (:completion)
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "project-search" loom/feature/project:project-search
                    :keys (((:control #\x) #\p #\s))
                    :mutates NIL
                    :prompts (:free-string)
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "project-root" loom/feature/project:project-root
                    :keys (((:control #\x) #\p #\r))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "save-buffer" loom/feature/file-tree:save-buffer
                    :keys (((:control #\x) (:control #\s)))
                    :help "C-x C-s Save"
                    :help-order 14
                    :mutates t
                    :prompts (:free-string)
                    :needs-region NIL
                    :external ("shell")
                    :modes (:all))
      (command-spec "auto-save-mode" loom/feature/auto-save:auto-save-mode
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "toggle-auto-save" loom/feature/auto-save:toggle-auto-save
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "auto-save-current-buffer"
                    loom/feature/auto-save:auto-save-current-buffer
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "write-file" loom/feature/file-tree:write-file
                    :keys (((:control #\x) (:control #\w)))
                    :mutates NIL
                    :prompts (:free-string)
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "recent-file" loom/feature/file-tree:recent-file
                    :keys (((:control #\x) #\r #\f))
                    :help "C-x r f Recent file"
                    :help-order 19
                    :mutates NIL
                    :prompts (:completion)
                    :needs-region NIL
                    :external NIL
                    :modes (:all))))
