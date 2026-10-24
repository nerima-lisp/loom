(defpackage #:loom/feature/user-init
  (:use #:cl)
  (:import-from #:loom/core/command
                #:find-extended-command-spec
                #:defkeys-key-sequence
                #:*command-specs*
                #:keymap-define-key)
  (:import-from #:loom/core/editor-session
                #:*editor-state*
                #:editor-state-keymap)
  (:export
   #:define-command
   #:bind-key
   #:load-user-init
   #:register-user-init-package-provider))
