(in-package #:loom)

(define-command-spec-groups *file-tree-command-spec-groups*
  (command-spec-group "file tree"
      (command-spec "toggle-file-tree" loom/feature/file-tree:toggle-file-tree
                    :keys (((:control #\x) (:control #\t)))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "file-tree-select-next"
                    loom/feature/file-tree:file-tree-select-next
                    :keys (((:control #\c) #\n))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "file-tree-select-previous"
                    loom/feature/file-tree:file-tree-select-previous
                    :keys (((:control #\c) #\p))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "file-tree-open-selected"
                    loom/feature/file-tree:file-tree-open-selected
                    :keys (((:control #\c) #\o))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "file-tree-create-file"
                    loom/feature/file-tree:file-tree-create-file-command
                    :keys (((:control #\c) #\c))
                    :mutates NIL
                    :prompts (:free-string)
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "file-tree-create-directory"
                    loom/feature/file-tree:file-tree-create-directory-command
                    :keys (((:control #\c) #\d))
                    :mutates NIL
                    :prompts (:free-string)
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "file-tree-rename"
                    loom/feature/file-tree:file-tree-rename-command
                    :mutates NIL
                    :prompts (:free-string)
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "file-tree-delete"
                    loom/feature/file-tree:file-tree-delete-command
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))))
