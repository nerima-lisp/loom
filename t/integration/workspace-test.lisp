;;;; t/integration/workspace-test.lisp
;;;;
;;;; Workspace application commands must exchange complete window trees while
;;;; leaving the view stored in the inactive workspace untouched.
(in-package #:loom/test)

(describe "workspace commands"
  (it "keeps an independent window tree for each workspace"
    (%with-minibuffer-state (minibuffer "one")
      (let ((first-tree (editor-state-window-tree *editor-state*)))
        (split-window-below)
        (expect (window-tree-windows first-tree) :to-have-length 2)
        (expect (new-workspace) :to-be-truthy)
        (let ((second-tree (editor-state-window-tree *editor-state*)))
          (expect second-tree :not :to-be first-tree)
          (expect (window-tree-windows second-tree) :to-have-length 1)
          (expect (loom:minibuffer-message-string minibuffer)
                  :to-equal
                  "Workspace: workspace-2")
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

  (it "rejects an editor state without its required workspace manager"
    (let ((*editor-state* (%fresh-editor-state "one")))
      (setf (editor-state-workspaces *editor-state*) nil)
      (signals error
        (loom/feature/workspace::%workspace-manager))))

  (it "reactivates the surviving workspace on delete and refuses the final one"
    (let ((*editor-state* (%fresh-editor-state "one")))
      (let ((first-tree (editor-state-window-tree *editor-state*)))
        (split-window-below)
        (expect (new-workspace) :to-be-truthy)
        (split-window-right)
        (let ((workspace (kill-workspace)))
          (expect workspace
                  :to-be
                  (workspace-manager-current
                   (editor-state-workspaces *editor-state*)))
          (expect (workspace-window-tree workspace)
                  :to-be
                  first-tree)
          (expect (editor-state-window-tree *editor-state*)
                  :to-be
                  first-tree)
          (expect (window-tree-windows first-tree) :to-have-length 2)
          (expect (workspace-manager-workspaces
                   (editor-state-workspaces *editor-state*))
                  :to-have-length 1)
          (expect (kill-workspace) :to-be nil)))))

  (it "prompts for a workspace name, switches to it, and announces the result"
    (%with-minibuffer-state (minibuffer "one")
      (let ((first-tree (editor-state-window-tree *editor-state*)))
        (expect (new-workspace) :to-be-truthy)
        (split-window-right)
        (switch-workspace)
        (%expect-minibuffer-prompt minibuffer (%switch-workspace-prompt-string))
        (%confirm-minibuffer minibuffer "main")
        (expect (editor-state-window-tree *editor-state*)
                :to-be
                first-tree)
        (expect (loom:minibuffer-message-string minibuffer)
                :to-equal
                "Workspace: main"))))

  (it "reports an unknown workspace name without changing the active tree"
    (%with-minibuffer-state (minibuffer "one")
      (let ((first-tree (editor-state-window-tree *editor-state*)))
        (expect (new-workspace) :to-be-truthy)
        (let ((second-tree (editor-state-window-tree *editor-state*)))
          (switch-workspace)
          (%expect-minibuffer-prompt minibuffer (%switch-workspace-prompt-string))
          (%confirm-minibuffer minibuffer "missing")
          (expect (editor-state-window-tree *editor-state*)
                  :to-be
                  second-tree)
          (expect second-tree :not :to-be first-tree)
          (expect (loom:minibuffer-message-string minibuffer)
                  :to-equal
                  "No such workspace: missing"))))

  (it "cancels workspace switching through the minibuffer protocol"
    (%with-minibuffer-state (minibuffer "one")
      (switch-workspace)
      (minibuffer-handle-key minibuffer (%special-key :control-g))
      (expect (minibuffer-message-string minibuffer) :to-equal "Quit")))

  (it-each
      (("new workspace"
        (((:control) . #\x) (nil . #\t) (nil . #\2))
        loom/feature/workspace:new-workspace)
       ("switch workspace"
        (((:control) . #\x) (nil . #\t) (nil . #\o))
        loom/feature/workspace:switch-workspace)
       ("kill workspace"
        (((:control) . #\x) (nil . #\t) (nil . #\k))
        loom/feature/workspace:kill-workspace)
       ("next workspace"
        (((:control) . #\x) (nil . #\t) (nil . #\n))
        loom/feature/workspace:next-workspace)
       ("previous workspace"
        (((:control) . #\x) (nil . #\t) (nil . #\p))
        loom/feature/workspace:previous-workspace))
      "registers ~A in the default keymap" (name key-sequence command)
    (let ((keymap (install-default-keybindings (make-keymap))))
      (expect (keymap-lookup keymap key-sequence)
              :to-be
              command)))))
