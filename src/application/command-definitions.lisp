;;;; src/application/command-definitions.lisp
;;;;
;;;; Composition-root catalogue for commands exposed by the editor.  The
;;;; registry implementation lives in application/command-registry.lisp;
;;;; keeping this data separate from command handlers makes the catalogue
;;;; readable and lets keybinding installation consume one declarative model.
(in-package #:loom)

(define-command-specs
  (command-spec "universal-argument" universal-argument
                :keys ((:control #\u)))
  (command-spec "forward-char" forward-char :keys ((:control #\f)))
  (command-spec "backward-char" backward-char :keys ((:control #\b)))
  (command-spec "next-line" next-line :keys ((:control #\n)))
  (command-spec "previous-line" previous-line :keys ((:control #\p)))
  (command-spec "forward-word" forward-word :keys ((:alt #\f)))
  (command-spec "backward-word" backward-word :keys ((:alt #\b)))
  (command-spec "move-beginning-of-line" move-beginning-of-line
                :keys ((:control #\a)))
  (command-spec "move-end-of-line" move-end-of-line :keys ((:control #\e)))
  (command-spec "beginning-of-buffer" beginning-of-buffer :keys ((:alt #\<)))
  (command-spec "end-of-buffer" end-of-buffer :keys ((:alt #\>)))
  (command-spec "scroll-up-command" scroll-up-command :keys ((:control #\v)))
  (command-spec "scroll-down-command" scroll-down-command :keys ((:alt #\v)))
  (command-spec "delete-char" delete-char :keys ((:control #\d)))
  (command-spec "delete-backward-char" delete-backward-char
                :keys (:backspace))
  (command-spec "newline" newline-command :keys (:enter))
  (command-spec "open-line" open-line :keys ((:control #\o)))
  (command-spec "kill-line" kill-line :keys ((:control #\k)))
  (command-spec "kill-word" kill-word :keys ((:alt #\d)))
  (command-spec "backward-kill-word" backward-kill-word
                :keys ((:alt :backspace)))
  (command-spec "indent-for-tab-command"
                loom/feature/mode:indent-for-tab-command
                :keys (:tab))
  (command-spec "comment-line" loom/feature/mode:comment-line
                :keys ((:alt #\;)))
  (command-spec "kill-region" kill-region :keys ((:control #\w)))
  (command-spec "yank" yank :keys ((:control #\y)))
  (command-spec "set-mark-command" set-mark-command
                :keys ((:control #\Space)))
  (command-spec "exchange-point-and-mark" exchange-point-and-mark
                :keys (((:control #\x) (:control #\x))))
  (command-spec "mark-whole-buffer" mark-whole-buffer
                :keys (((:control #\x) #\h)))
  (command-spec "undo" undo-command
                :keys (((:control #\x) #\u)))
  (command-spec "search-forward" loom/feature/search:search-forward
                :keys ((:control #\s)))
  (command-spec "search-backward" loom/feature/search:search-backward
                :keys ((:control #\r)))
  (command-spec "replace-string" loom/feature/search:replace-string
                :keys ((:alt #\%)))
  (command-spec "goto-line" goto-line :keys (((:alt #\g) #\g)))
  (command-spec "find-file" loom/feature/file-tree:find-file
                :keys (((:control #\x) (:control #\f))))
  (command-spec "set-major-mode" loom/feature/mode:set-major-mode)
  (command-spec "project-find-file" loom/feature/project:project-find-file
                :keys (((:control #\x) #\p #\f)))
  (command-spec "project-search" loom/feature/project:project-search
                :keys (((:control #\x) #\p #\s)))
  (command-spec "project-root" loom/feature/project:project-root
                :keys (((:control #\x) #\p #\r)))
  (command-spec "save-buffer" loom/feature/file-tree:save-buffer
                :keys (((:control #\x) (:control #\s))))
  (command-spec "write-file" loom/feature/file-tree:write-file
                :keys (((:control #\x) (:control #\w))))
  (command-spec "split-window-below" loom/feature/window:split-window-below
                :keys (((:control #\x) #\2)))
  (command-spec "split-window-right" loom/feature/window:split-window-right
                :keys (((:control #\x) #\3)))
  (command-spec "other-window" loom/feature/window:other-window
                :keys (((:control #\x) #\o)))
  (command-spec "delete-window" loom/feature/window:delete-window
                :keys (((:control #\x) #\0)))
  (command-spec "delete-other-windows" loom/feature/window:delete-other-windows
                :keys (((:control #\x) #\1)))
  (command-spec "switch-to-buffer" loom/feature/window:switch-to-buffer
                :keys (((:control #\x) #\b)))
  (command-spec "kill-buffer" loom/feature/window:kill-buffer
                :keys (((:control #\x) #\k)))
  (command-spec "save-session" loom/feature/session:save-session
                :keys (((:control #\x) #\r #\S)))
  (command-spec "load-session" loom/feature/session:load-session
                :keys (((:control #\x) #\r #\l)))
  (command-spec "copy-to-register" loom/feature/register:copy-to-register
                :keys (((:control #\x) #\r #\s)))
  (command-spec "insert-register" loom/feature/register:insert-register
                :keys (((:control #\x) #\r #\i)))
  (command-spec "point-to-register" loom/feature/register:point-to-register
                :keys (((:control #\x) #\r #\Space)))
  (command-spec "jump-to-register" loom/feature/register:jump-to-register
                :keys (((:control #\x) #\r #\j)))
  (command-spec "start-kbd-macro" loom/feature/keyboard-macro:start-kbd-macro
                :keys (((:control #\x) #\( )))
  (command-spec "end-kbd-macro" loom/feature/keyboard-macro:end-kbd-macro
                :keys (((:control #\x) #\) )))
  (command-spec "call-last-kbd-macro"
                loom/feature/keyboard-macro:call-last-kbd-macro
                :keys (((:control #\x) #\e)))
  (command-spec "eval-expression" loom/feature/evaluation:eval-expression
                :keys ((:alt #\:)))
  (command-spec "eval-buffer" loom/feature/evaluation:eval-buffer
                :keys (((:control #\x) (:control #\e))))
  (command-spec "lsp-start" loom/feature/lsp:lsp-start)
  (command-spec "lsp-stop" loom/feature/lsp:lsp-stop)
  (command-spec "lsp-diagnostics" loom/feature/lsp:lsp-diagnostics)
  (command-spec "toggle-file-tree" loom/feature/file-tree:toggle-file-tree
                :keys (((:control #\x) (:control #\t))))
  (command-spec "file-tree-select-next" loom/feature/file-tree:file-tree-select-next
                :keys (((:control #\c) #\n)))
  (command-spec "file-tree-select-previous"
                loom/feature/file-tree:file-tree-select-previous
                :keys (((:control #\c) #\p)))
  (command-spec "file-tree-open-selected"
                loom/feature/file-tree:file-tree-open-selected
                :keys (((:control #\c) #\o)))
  (command-spec "file-tree-create-file"
                loom/feature/file-tree:file-tree-create-file-command
                :keys (((:control #\c) #\c)))
  (command-spec "file-tree-create-directory"
                loom/feature/file-tree:file-tree-create-directory-command
                :keys (((:control #\c) #\d)))
  (command-spec "file-tree-rename"
                loom/feature/file-tree:file-tree-rename-command)
  (command-spec "file-tree-delete"
                loom/feature/file-tree:file-tree-delete-command)
  (command-spec "keyboard-quit" keyboard-quit :keys ((:control #\g)))
  (command-spec "help" help-command :keys ((:control #\h) :f1))
  (command-spec "save-buffers-kill-terminal" save-buffers-kill-terminal
                :keys (((:control #\x) (:control #\c))))
  (command-spec nil execute-extended-command :keys ((:alt #\x))))
