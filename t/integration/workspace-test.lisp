;;;; t/integration/workspace-test.lisp
;;;;
;;;; Workspace application commands must exchange complete window trees while
;;;; leaving the view stored in the inactive workspace untouched.
(in-package #:loom/test)

(describe "workspace commands"
  (it "keeps an independent window tree for each workspace"
    (let ((*editor-state* (%fresh-editor-state "one")))
      (let ((first-tree (editor-state-window-tree *editor-state*)))
        (split-window-below)
        (expect (window-tree-windows first-tree) :to-have-length 2)
        (expect (new-workspace) :to-be-truthy)
        (let ((second-tree (editor-state-window-tree *editor-state*)))
          (expect second-tree :not :to-be first-tree)
          (expect (window-tree-windows second-tree) :to-have-length 1)
          (split-window-right)
          (expect (window-tree-windows second-tree) :to-have-length 2)
          (next-workspace)
          (expect (editor-state-window-tree *editor-state*)
                  :to-be
                  first-tree)
          (expect (window-tree-windows first-tree) :to-have-length 2)
          (previous-workspace)
          (expect (editor-state-window-tree *editor-state*)
                  :to-be
                  second-tree)
          (expect (window-tree-windows second-tree) :to-have-length 2)))))

  (it "registers workspace commands in the default keymap"
    (let ((keymap (install-default-keybindings (make-keymap))))
      (expect (keymap-lookup keymap
                            '(((:control) . #\x) (nil . #\t) (nil . #\2)))
              :to-be
              'loom/feature/workspace:new-workspace)
      (expect (keymap-lookup keymap
                            '(((:control) . #\x) (nil . #\t) (nil . #\o)))
              :to-be
              'loom/feature/workspace:switch-workspace)
      (expect (keymap-lookup keymap
                            '(((:control) . #\x) (nil . #\t) (nil . #\k)))
              :to-be
              'loom/feature/workspace:kill-workspace)
      (expect (keymap-lookup keymap
                            '(((:control) . #\x) (nil . #\t) (nil . #\n)))
              :to-be
              'loom/feature/workspace:next-workspace)
      (expect (keymap-lookup keymap
                            '(((:control) . #\x) (nil . #\t) (nil . #\p)))
              :to-be
              'loom/feature/workspace:previous-workspace))))
