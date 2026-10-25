(progn
  (defpackage #:loom/core/buffer
    (:use #:cl)
    (:export #:buffer-delete-region #:buffer-insert-string #:buffer-line
             #:buffer-major-mode #:buffer-point-column #:buffer-point-line
             #:buffer-set-major-mode #:buffer-set-point
             #:buffer-set-truncate-lines #:buffer-truncate-lines))
  (defpackage #:loom/core/command
    (:use #:cl)
    (:export #:defkeys-key-sequence #:keymap-define-key #:make-keymap
             #:register-buffer-keymap-provider))
  (defpackage #:loom/core/editor-session
    (:use #:cl)
    (:export #:*editor-state* #:editor-state-minibuffer
             #:editor-state-window-tree #:register-buffer-truncate-policy))
  (defpackage #:loom/core/minibuffer
    (:use #:cl)
    (:export #:minibuffer-message #:with-prompts))
  (defpackage #:loom/core/window-tree
    (:use #:cl)
    (:export #:window-buffer #:window-tree-selected-window))
  (load "packages/feature/mode/src/package.lisp")
  (let ((*package* (find-package "LOOM/FEATURE/MODE")))
    (load "packages/feature/mode/src/domain-major-mode-keywords.lisp")
    (load "packages/feature/mode/src/domain-major-mode-definitions.lisp")
    (load "packages/feature/mode/src/domain-major-mode-registry-support.lisp")
    (load "packages/feature/mode/src/domain-major-mode.lisp")
    (load "packages/feature/mode/src/domain-major-mode-registry.lisp"))
  (defun %mode-tab-width-check (label condition)
    (unless condition
      (error "~A" label))
    (format t "PASS ~A~%" label))
  (let* ((package (find-package "LOOM/FEATURE/MODE"))
         (tab-symbol (find-symbol "MAJOR-MODE-TAB-WIDTH" package))
         (tab-status (nth-value 1 (find-symbol "MAJOR-MODE-TAB-WIDTH" package)))
         (tab-width (and tab-symbol (symbol-function tab-symbol)))
         (indentation-width
           (symbol-function (find-symbol "MAJOR-MODE-INDENTATION-WIDTH" package)))
         (definition
           (symbol-function (find-symbol "MAJOR-MODE-DEFINITION" package)))
         (definitions (symbol-value (find-symbol "+MAJOR-MODE-DEFINITIONS+" package)))
         (register (symbol-function (find-symbol "REGISTER-MAJOR-MODE" package))))
    (%mode-tab-width-check "major-mode-tab-width is exported"
                           (and tab-symbol (eq tab-status :external)))
    (%mode-tab-width-check
     "all built-in definitions carry tab-width 8"
     (and definitions
          (every (lambda (entry)
                   (eql (getf (funcall definition (car entry)) :tab-width) 8))
                 definitions)))
    (%mode-tab-width-check
     "Python keeps indentation width 4 and tab width 8"
     (and (= (funcall indentation-width :python) 4)
          (= (funcall tab-width :python) 8)))
    (funcall register :loom-tab-default :indentation-width 3)
    (%mode-tab-width-check
     "registered mode defaults to tab width 8 independently of indentation width 3"
     (and (= (funcall indentation-width :loom-tab-default) 3)
          (= (funcall tab-width :loom-tab-default) 8)
          (= (getf (funcall definition :loom-tab-default) :tab-width) 8)))
    (funcall register :loom-tab-override :indentation-width 3 :tab-width 6)
    (%mode-tab-width-check
     "registered tab-width override 6 does not change indentation width 3"
     (and (= (funcall indentation-width :loom-tab-override) 3)
          (= (funcall tab-width :loom-tab-override) 6)))
    (%mode-tab-width-check
     "nonpositive tab width is rejected"
     (handler-case
         (progn (funcall register :loom-invalid-tab-width :tab-width 0) nil)
       (error () t))))
  (format t "6 tab-width checks passed.~%"))
