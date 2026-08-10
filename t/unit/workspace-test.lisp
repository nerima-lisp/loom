;;;; t/unit/workspace-test.lisp
;;;;
;;;; Workspace domain tests.  These tests exercise the manager without an
;;;; editor state so view ownership and switching rules stay independently
;;;; observable.
(in-package #:loom/test)

(describe "workspace manager"
  (it "starts with one named workspace over the initial window tree"
    (let* ((tree (make-window-tree :scratch 80 24))
           (manager (make-workspace-manager tree :name "main")))
      (expect (workspace-manager-current-name manager) :to-equal "main")
      (expect (workspace-manager-current manager)
              :to-be
              (first (workspace-manager-workspaces manager)))
      (expect (workspace-window-tree
               (workspace-manager-current manager))
              :to-be
              tree)
      (expect (workspace-manager-workspaces manager) :to-have-length 1)))

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

  (it "deletes the active workspace but preserves the final one"
    (let* ((manager (make-workspace-manager
                     (make-window-tree :first 80 24)))
           (second (workspace-manager-create
                    manager (make-window-tree :second 80 24))))
      (workspace-manager-switch-name manager (workspace-name second))
      (expect (workspace-manager-delete manager)
              :to-be
              (workspace-manager-current manager))
      (expect (workspace-manager-current-name manager) :to-equal "main")
      (expect (workspace-manager-workspaces manager) :to-have-length 1)
      (signals error (workspace-manager-delete manager))))

  (it "rejects blank and duplicate workspace names"
    (let ((manager (make-workspace-manager
                    (make-window-tree :scratch 80 24))))
      (signals error
        (make-workspace-manager (make-window-tree :other 80 24)
                                :name "  "))
      (signals error
        (workspace-manager-create manager
                                   (make-window-tree :other 80 24)
                                   :name "MAIN")))))
