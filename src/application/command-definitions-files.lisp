;;;; src/application/command-definitions-files.lisp
;;;;
;;;; Declarative command catalogue for file and project commands.
(in-package #:loom)

(define-command-spec-groups *files-command-spec-groups*
  (command-spec-group "files and projects"
      (command-spec "find-file" loom/feature/file-tree:find-file
                    :keys (((:control #\x) (:control #\f)))
                    :help "C-x C-f Open"
                    :help-order 15)
      (command-spec "set-major-mode" loom/feature/mode:set-major-mode)
      (command-spec "project-find-file" loom/feature/project:project-find-file
                    :keys (((:control #\x) #\p #\f)))
      (command-spec "project-search" loom/feature/project:project-search
                    :keys (((:control #\x) #\p #\s)))
      (command-spec "project-root" loom/feature/project:project-root
                    :keys (((:control #\x) #\p #\r)))
      (command-spec "save-buffer" loom/feature/file-tree:save-buffer
                    :keys (((:control #\x) (:control #\s)))
                    :help "C-x C-s Save"
                    :help-order 14)
      (command-spec "auto-save-mode" loom/feature/auto-save:auto-save-mode)
      (command-spec "toggle-auto-save" loom/feature/auto-save:toggle-auto-save)
      (command-spec "write-file" loom/feature/file-tree:write-file
                    :keys (((:control #\x) (:control #\w))))
      (command-spec "recent-file" loom/feature/file-tree:recent-file
                    :keys (((:control #\x) #\r #\f))
                    :help "C-x r f Recent file"
                    :help-order 19)))
