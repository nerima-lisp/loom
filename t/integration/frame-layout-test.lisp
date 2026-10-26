
(in-package #:loom/test)

(describe
  "compose-frame"
  (it
    "draws the selected window's buffer and the minibuffer's status line when the file-tree is hidden"
    (let* ((state (%fresh-layout-state :name "*scratch*" :content "abc"))
           (minibuffer (editor-state-minibuffer state)))
      (minibuffer-message minibuffer "status message")
      (loom::compose-frame state)
      (let ((screen (%layout-screen state)))
        (expect (cl-tty-kit:screen-to-string screen)
                :to-equal
                (format nil "~A~%~A~%~A~%~A~%~A~%~A"
                        (cl-tty-kit:pad-string "abc" 40)
                        (cl-tty-kit:pad-string "" 40)
                        (cl-tty-kit:pad-string "" 40)
                        (cl-tty-kit:pad-string "" 40)
                        (cl-tty-kit:pad-string
                         (loom::%layout-mode-line
                          (editor-state-renderer state)
                          (window-buffer (%layout-window state))
                          40
                          "main")
                         40)
                        (cl-tty-kit:pad-string "status message" 40))))))
  (it
    "dispatches buffer hit tests through the root presentation provider"
    (let* ((state (%fresh-layout-state :name "*scratch*" :content "abc"))
           (window (%layout-window state))
           (buffer (window-buffer window))
           (session (editor-state-session state)))
      (loom::compose-frame state)
      (let ((result
              (loom/core/editor-session:hit-test-coordinate session 0 0)))
        (expect result :to-be-truthy)
        (expect (loom/core/editor-session:hit-test-result-owner result)
                :to-be
                :core/presentation)
        (expect (loom/core/editor-session:hit-test-result-kind result)
                :to-be
                :buffer-text)
        (expect (loom/core/editor-session:hit-test-result-window result)
                :to-be
                window)
        (expect (loom/core/editor-session:hit-test-result-buffer result)
                :to-be
                buffer)
        (let ((position
                (loom/core/editor-session:hit-test-result-position result)))
          (expect (list (loom/core/buffer:buffer-position-line position)
                        (loom/core/buffer:buffer-position-column position))
                  :to-equal
                  (list 0 0))))))
  (it
    "hit-tests body text beyond the narrowed window tree with the file-tree visible"
    (let* ((state (%fresh-layout-state
                   :name "*scratch*"
                   :content "abcdefghijklmnopqrstuvwxyz")) (*editor-state* state)
           (file-tree (editor-state-file-tree state))
           (window (%layout-window state))
           (buffer (window-buffer window))
           (tree (editor-state-window-tree state))
           (session (editor-state-session state))
           (screen-x 32))
      (file-tree-toggle file-tree)
      (loom::compose-frame state)
      (expect (> screen-x (loom/core/window-tree:window-tree-width tree))
              :to-be-truthy)
      (let ((result
              (loom/core/editor-session:hit-test-coordinate
               session screen-x 0)))
        (expect result :to-be-truthy)
        (expect (loom/core/editor-session:hit-test-result-owner result)
                :to-be
                :core/presentation)
        (expect (loom/core/editor-session:hit-test-result-kind result)
                :to-be
                :buffer-text)
        (expect (loom/core/editor-session:hit-test-result-window result)
                :to-be
                window)
        (expect (loom/core/editor-session:hit-test-result-buffer result)
                :to-be
                buffer)
        (let ((position
                (loom/core/editor-session:hit-test-result-position result)))
          (expect (list (loom/core/buffer:buffer-position-line position)
                        (loom/core/buffer:buffer-position-column position))
                  :to-equal
                  (list 0 8))
          (expect (loom/core/editor-session:hit-test-coordinate session 40 0) :to-be nil)))))

  (it
    "shows the current workspace in the selected mode line"
    (let* ((state (%fresh-layout-state :name "*scratch*" :content "abc"))
           (tree (editor-state-window-tree state)))
      (setf (editor-state-workspaces state)
            (make-workspace-manager tree :name "notes"))
      (loom::compose-frame state)
      (expect (search "Workspace: notes"
                      (cl-tty-kit:screen-row-string
                       (%layout-screen state)
                       4))
              :to-be-truthy)
      (expect (cl-tty-kit:screen-row-string (%layout-screen state) 5)
              :to-equal (cl-tty-kit:pad-string "" 40))))
  (it
 "keeps an exact-width wrapped end-of-line cursor inside the frame"
 (let* ((state (%fresh-layout-state
                :name "*scratch*"
                :content (make-string 40 :initial-element #\x)))
        (*editor-state* state)
        (buffer (window-buffer (%layout-window state))))
   (buffer-set-point buffer 0 40)
   (let ((snapshot (loom::compose-frame state)))
     (multiple-value-bind (cursor-x cursor-y visible-p)
         (loom/core/editor-session:frame-snapshot-cursor snapshot)
       (expect cursor-x :to-equal 39)
       (expect cursor-y :to-equal 0)
       (expect visible-p :to-be-truthy)))))

  (it
    "updates the selected mode line after workspace navigation"
    (let* ((state (%fresh-layout-state :name "*scratch*" :content "abc"))
           (manager (editor-state-workspaces state)))
      (workspace-manager-create
       manager
       (make-window-tree (make-buffer :name "notes") 40 6)
       :name "notes")
      (let ((*editor-state* state))
        (next-workspace))
      (loom::compose-frame state)
      (expect (search "Workspace: notes"
                      (cl-tty-kit:screen-row-string
                       (%layout-screen state)
                       4))
              :to-be-truthy)))

  (it
    "scrolls a selected window so its point remains visible"
    (let* ((state (%fresh-layout-state :content (format nil "one~%two~%three~%four~%five")
                                       :width 20
                                       :height 4))
           (buffer (window-buffer (%layout-window state))))
      (buffer-set-point buffer 4 0)
      (loom::compose-frame state)
      (expect (window-scroll-line (%layout-window state)) :to-equal 3)
      (let ((screen (%layout-screen state)))
        (expect (cl-tty-kit:screen-row-string screen 0 :start 0 :end 4)
                :to-equal "four"))))

  (it
    "draws the file-tree sidebar to the left of the buffer, offsetting the window area by its width"
    (let* ((state (%fresh-layout-state :name "*scratch*" :content "hi"))
           (file-tree (editor-state-file-tree state)))
      (loom/feature/file-tree:file-tree-install-child-lister
       file-tree
       (lambda (path)
         (declare (ignore path))
         '(("/root/a.txt" . :file) ("/root/b.txt" . :file))))
      (file-tree-toggle file-tree)
      (loom::compose-frame state)
      (let ((screen (%layout-screen state)))
        (expect (cl-tty-kit:screen-row-string screen 0 :start 0 :end 5) :to-equal "a.txt")
        (expect (cl-tty-kit:screen-row-string screen 1 :start 0 :end 5) :to-equal "b.txt")
        (expect (cl-tty-kit:screen-row-string screen 0 :start 24 :end 26) :to-equal "hi"))))

  (it
    "draws separator lines between two horizontally split windows"
    (let* ((state (%fresh-layout-state :name "*scratch*" :content "hi"))
           (window-tree (editor-state-window-tree state)))
      (window-split window-tree (window-tree-selected-window window-tree) :vertical)
      (loom::compose-frame state)
      (let ((screen (%layout-screen state)))
        (expect (cl-tty-kit:screen-row-string screen 0 :start 19 :end 20)
                :to-equal (string (code-char #x2502))))))

  (it
    "uses the upper window's mode line at a top/bottom split boundary"
    (let* ((state (%fresh-layout-state :name "*scratch*" :content "hi"))
           (window-tree (editor-state-window-tree state)))
      (window-split window-tree (window-tree-selected-window window-tree) :horizontal)
      (loom::compose-frame state)
      (let ((screen (%layout-screen state)))
        (expect (search "-- *scratch*"
                        (cl-tty-kit:screen-row-string screen 2))
                :to-be-truthy)))))
