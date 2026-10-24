(defpackage #:loom/feature/user-init
  (:use #:cl)
  (:import-from #:loom/core/command
                #:command-spec-id
                #:defkeys-key-sequence
                #:find-extended-command-spec
                #:invoke-command
                #:keymap-define-key
                #:register-command-spec
                #:register-key-command)
  (:import-from #:loom/core/editor-session
                #:*editor-state*
                #:editor-state-keymap)
  (:export
   #:define-command
   #:bind-key
   #:load-user-init
   #:register-user-init-package-provider))
