;;;; t/unit/workspace-test.lisp
;;;;
;;;; Workspace construction/lifecycle tests and editor-state invariants.
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

  (it-each
      (("blank names"
        (lambda (manager)
          (workspace-manager-create manager
                                    (make-window-tree :other 80 24)
                                    :name "  ")))
       ("duplicate names"
        (lambda (manager)
          (workspace-manager-create manager
                                    (make-window-tree :other 80 24)
                                    :name "MAIN"))))
      "rejects ~A on workspace creation" (name operation)
    (let ((manager (make-workspace-manager
                    (make-window-tree :scratch 80 24))))
      (signals error
        (make-workspace-manager (make-window-tree :other 80 24)
                                :name "  "))
      (signals error
        (funcall operation manager))))

  (it-each
      (("deleting the current workspace keeps the successor active"
        1 1 "third")
       ("deleting an earlier workspace shifts the current index left"
        0 2 "third")
       ("deleting a later workspace keeps the current workspace"
        2 1 "second"))
      "~A" (name delete-index current-index expected-name)
    (let* ((manager (make-workspace-manager
                     (make-window-tree :first 80 24)))
           (second (workspace-manager-create
                    manager (make-window-tree :second 80 24)
                    :name "second"))
           (third (workspace-manager-create
                   manager (make-window-tree :third 80 24)
                   :name "third")))
      (declare (ignore second third))
      (workspace-manager-switch-index manager current-index)
      (expect (workspace-manager-delete manager delete-index)
              :to-be
              (workspace-manager-current manager))
      (expect (workspace-manager-current-name manager)
              :to-equal
              expected-name))))

(describe "editor-state workspace invariant"
  (it "creates a main workspace manager when one is not provided"
    (let* ((buffer (make-buffer :name "*scratch*" :initial-content "hello"))
           (tree (make-window-tree buffer 80 24))
           (state (make-editor-state :window-tree tree)))
      (expect (editor-state-window-tree state) :to-be tree)
      (expect (workspace-manager-current-name
               (editor-state-workspaces state))
              :to-equal "main")
      (expect (workspace-window-tree
               (workspace-manager-current
                (editor-state-workspaces state)))
              :to-be
              tree)
      (expect (workspace-manager-workspaces
               (editor-state-workspaces state))
              :to-have-length 1)))

  (it "preserves an explicit workspace manager"
    (let* ((window-tree (make-window-tree :window 80 24))
           (workspace-tree (make-window-tree :workspace 80 24))
           (manager (make-workspace-manager workspace-tree :name "restored"))
           (state (make-editor-state :window-tree window-tree
                                     :workspaces manager)))
      (expect (editor-state-window-tree state) :to-be window-tree)
      (expect (editor-state-workspaces state) :to-be manager)
      (expect (workspace-manager-current-name manager) :to-equal "restored")
      (expect (workspace-window-tree
               (workspace-manager-current manager))
              :to-be
              workspace-tree))))
