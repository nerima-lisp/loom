;;;; t/integration/session-workspace-application-test.lisp

(in-package #:loom/test)

(describe "session application workspace round-trip"
  (it
    "restores every named workspace with its independent layout and active workspace"
    (let* ((main-buffer (make-buffer :name "*main-buffer*" :initial-content "main"))
           (notes-buffer (make-buffer :name "*notes-buffer*" :initial-content "notes"))
           (main-tree (make-window-tree main-buffer 20 8))
           (notes-tree (make-window-tree notes-buffer 20 8))
           (notes-second
             (window-split notes-tree
                           (window-tree-selected-window notes-tree)
                           :vertical))
           (manager
             (make-workspace-manager-from-workspaces
              (list (make-workspace :name "main" :window-tree main-tree)
                    (make-workspace :name "notes" :window-tree notes-tree))
              :current-index 1))
           (state
             (make-editor-state
              :window-tree notes-tree
              :workspaces manager
              :minibuffer (make-minibuffer)
              :keymap (make-keymap)
              :file-tree (make-file-tree "/root/")
              :buffers (list main-buffer notes-buffer)
              :kill-ring nil
              :recent-files nil
              :bookmarks nil)))
      (setf (window-scroll-line (first (window-tree-windows main-tree))) 2
            (window-scroll-line (first (window-tree-windows notes-tree))) 3
            (window-scroll-line notes-second) 4)
      (window-tree-select-index notes-tree 1)
      (let ((*editor-state* state))
        (let ((snapshot (loom/feature/session::%session-snapshot-from-state)))
          (expect (session-snapshot-current-workspace-index snapshot) :to-equal 1)
          (expect (mapcar #'session-workspace-snapshot-name
                          (session-snapshot-workspaces snapshot))
                  :to-equal '("main" "notes"))
          (loom/feature/session::%restore-session-snapshot snapshot)
          (let* ((restored-manager (editor-state-workspaces *editor-state*))
                 (restored-workspaces
                   (workspace-manager-workspaces restored-manager))
                 (restored-main (first restored-workspaces))
                 (restored-notes (second restored-workspaces))
                 (restored-main-tree (workspace-window-tree restored-main))
                 (restored-notes-tree (workspace-window-tree restored-notes))
                 (restored-notes-windows
                   (window-tree-windows restored-notes-tree)))
            (expect (length restored-workspaces) :to-equal 2)
            (expect (workspace-manager-current-index restored-manager) :to-equal 1)
            (expect (workspace-manager-current-name restored-manager) :to-equal "notes")
            (expect (editor-state-window-tree *editor-state*)
                    :to-be restored-notes-tree)
            (expect (length (window-tree-windows restored-main-tree)) :to-equal 1)
            (expect (length restored-notes-windows) :to-equal 2)
            (expect (buffer-name
                     (window-buffer (first (window-tree-windows restored-main-tree))))
                    :to-equal "*main-buffer*")
            (expect (buffer-name (window-buffer (first restored-notes-windows)))
                    :to-equal "*notes-buffer*")
            (expect (window-scroll-line
                     (first (window-tree-windows restored-main-tree)))
                    :to-equal 2)
            (expect (window-scroll-line (first restored-notes-windows)) :to-equal 3)
            (expect (window-scroll-line (second restored-notes-windows)) :to-equal 4)
            (expect (window-tree-selected-index restored-notes-tree) :to-equal 1)))))))
