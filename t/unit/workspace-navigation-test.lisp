;;;; t/unit/workspace-navigation-test.lisp
;;;;
;;;; Workspace navigation tests. These keep switching and wraparound behavior
;;;; separate from construction and editor-state invariants.
(in-package #:loom/test)

(describe "workspace manager navigation"
  (it "creates, switches, and wraps between independent views"
    (let* ((first-tree (make-window-tree :first 80 24))
           (second-tree (make-window-tree :second 80 24))
           (manager (make-workspace-manager first-tree))
           (created (workspace-manager-create manager second-tree)))
      (expect (workspace-name created) :to-equal "workspace-2")
      (expect (workspace-manager-current-name manager) :to-equal "main")
      (expect (workspace-manager-switch-name manager "workspace-2")
              :to-be
              created)
      (expect (workspace-manager-current-name manager) :to-equal "workspace-2")
      (expect (workspace-manager-current manager) :to-be created)
      (expect (workspace-manager-next manager)
              :to-be
              (first (workspace-manager-workspaces manager)))
      (expect (workspace-manager-current-name manager) :to-equal "main")
      (expect (workspace-manager-previous manager) :to-be created)
      (expect (workspace-manager-current-name manager) :to-equal "workspace-2"))))
