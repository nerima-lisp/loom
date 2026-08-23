;;;; packages/feature/mode/src/package.lisp
;;;;
;;;; Major-mode values and mode commands form one feature boundary.
(defpackage #:loom/feature/mode
  (:use #:cl #:loom #:loom/application)
  (:export
   ;; Domain API
   #:major-mode-known-p
   #:major-mode-from-name
   #:major-mode-name
   #:major-mode-comment-prefix
   #:major-mode-indentation-width
   #:major-mode-language-id
   #:major-mode-keywords
   #:major-mode-truncate-lines-p
   #:buffer-truncate-lines-p
   #:major-mode-names
   #:major-mode-for-path
   #:major-mode-parent
   #:major-mode-keybindings
   #:major-mode-definition
   #:register-major-mode
   #:unregister-major-mode
   ;; Application API
   #:major-mode-keymap
   #:current-major-mode
   #:set-major-mode
   #:indent-for-tab-command
   #:comment-line
   #:toggle-truncate-lines))
