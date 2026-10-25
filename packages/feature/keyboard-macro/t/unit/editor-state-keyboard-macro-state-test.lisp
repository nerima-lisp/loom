(in-package #:loom/test)

(describe "editor-state keyboard macro defaults" (it "creates the default keyboard macro state" (let* ((buffer (make-buffer :name "*scratch*")) (tree (make-window-tree buffer 80 24)) (state (make-editor-state :window-tree tree :session (%make-test-editor-session (list buffer) :window-tree tree)))) (expect (editor-state-keyboard-macro state) :to-be-truthy))))
