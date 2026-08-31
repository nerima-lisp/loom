;;;; t/unit/workspace-navigation-test.lisp
;;;;
;;;; Workspace navigation tests. These keep switching and wraparound behavior
;;;; separate from construction and editor-state invariants.
(in-package #:loom/test)

(describe "workspace manager navigation"
  (it "returns NIL for an unknown workspace name"
    (let ((manager (make-workspace-manager (make-window-tree :main 80 24))))
      (expect (workspace-manager-switch-name manager "missing") :to-be nil)))

  (it "rejects invalid workspace indexes"
    (let ((manager (make-workspace-manager (make-window-tree :main 80 24))))
      (cl-weave:it-each
          ((-1) (1))
          "rejects workspace index ~D"
          (index)
        (signals error (workspace-manager-switch-index manager index)))))

  (it "rejects blank and duplicate workspace names"
    (let ((manager (make-workspace-manager (make-window-tree :main 80 24))))
      (signals error (workspace-manager-create manager (make-window-tree :blank 80 24)
                                                :name ""))
      (signals error (workspace-manager-create manager (make-window-tree :duplicate 80 24)
                                                :name "main"))))

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
      (expect (workspace-manager-current-name manager) :to-equal "workspace-2")))

  (it "keeps the nearest workspace active after deletion"
    (let* ((manager (make-workspace-manager (make-window-tree :first 80 24)))
           (second (workspace-manager-create
                    manager (make-window-tree :second 80 24) :name "second"))
           (third (workspace-manager-create
                   manager (make-window-tree :third 80 24) :name "third")))
      (declare (ignore second third))
      (workspace-manager-switch-index manager 2)
      (workspace-manager-delete manager 2)
      (expect (workspace-manager-current-name manager) :to-equal "second")
      (workspace-manager-delete manager 0)
      (expect (workspace-manager-current-name manager) :to-equal "second")))

  (it "rejects deletion of the final workspace"
    (let ((manager (make-workspace-manager (make-window-tree :main 80 24))))
      (signals error (workspace-manager-delete manager)))))
