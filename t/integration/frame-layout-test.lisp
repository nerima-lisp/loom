;;;; t/integration/frame-layout-test.lisp

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
                         "Ln 1, Col 1  Workspace: main  C-h Help"
                         40)
                        (cl-tty-kit:pad-string "status message" 40))))))

  (it
    "shows the active workspace in the shortcut line"
    (let* ((state (%fresh-layout-state :name "*scratch*" :content "abc"))
           (tree (editor-state-window-tree state)))
      (setf (editor-state-workspaces state)
            (make-workspace-manager tree :name "notes"))
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
    "draws a separator line between two horizontally (top/bottom) split windows"
    (let* ((state (%fresh-layout-state :name "*scratch*" :content "hi"))
           (window-tree (editor-state-window-tree state)))
      (window-split window-tree (window-tree-selected-window window-tree) :horizontal)
      (loom::compose-frame state)
      (let ((screen (%layout-screen state)))
        (expect (cl-tty-kit:screen-row-string screen 1 :start 0 :end 1)
                :to-equal (string (code-char #x2500)))))))
