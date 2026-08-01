;;;; t/layout-test.lisp
;;;;
;;;; Presentation layer: COMPOSE-FRAME against a small (40x6) real renderer
;;;; and real MAKE-BUFFER/MAKE-WINDOW-TREE/MAKE-MINIBUFFER/MAKE-FILE-TREE
;;;; objects -- every layer COMPOSE-FRAME composes is already real by the
;;;; time this file was written, so there is no need for a test double here
;;;; the way t/terminal-renderer-test.lisp once needed FAKE-BUFFER.
;;;;
;;;; COMPOSE-FRAME itself is not exported from the LOOM package (see
;;;; src/presentation/layout.lisp), so it is reached here via LOOM::
;;;; qualification, the same precedent t/file-tree-test.lisp already set for
;;;; LOOM::FILE-TREE-CHILD-LISTER.
(in-package #:loom/test)

(describe
  "compose-frame"
  (it
    "draws the selected window's buffer and the minibuffer's status line when the file-tree is hidden"
    (let* ((buffer (make-buffer :name "*scratch*" :initial-content "abc"))
           (window-tree (make-window-tree buffer 40 6))
           (minibuffer (make-minibuffer))
           (file-tree (make-file-tree "/root/"))
           (renderer (make-loom-renderer 40 6))
           (editor-state (make-editor-state :window-tree window-tree
                                             :minibuffer minibuffer
                                             :keymap (make-keymap)
                                             :file-tree file-tree
                                             :renderer renderer
                                             :kill-ring nil)))
      (minibuffer-message minibuffer "status message")
      (loom::compose-frame editor-state)
      (let ((screen (cl-tty-kit:renderer-screen (loom-renderer-cl-tty-renderer renderer))))
        (expect (cl-tty-kit:screen-to-string screen)
                :to-equal
                (format nil "~A~%~A~%~A~%~A~%~A~%~A"
                        (cl-tty-kit:pad-string "abc" 40)
                        (cl-tty-kit:pad-string "" 40)
                        (cl-tty-kit:pad-string "" 40)
                        (cl-tty-kit:pad-string "" 40)
                        (cl-tty-kit:pad-string "" 40)
                        (cl-tty-kit:pad-string "status message" 40))))))

  (it
    "draws the file-tree sidebar to the left of the buffer, offsetting the window area by its width"
    (let* ((buffer (make-buffer :name "*scratch*" :initial-content "hi"))
           (window-tree (make-window-tree buffer 40 6))
           (minibuffer (make-minibuffer))
           (file-tree (make-file-tree "/root/"))
           (renderer (make-loom-renderer 40 6))
           (editor-state (make-editor-state :window-tree window-tree
                                             :minibuffer minibuffer
                                             :keymap (make-keymap)
                                             :file-tree file-tree
                                             :renderer renderer
                                             :kill-ring nil)))
      (setf (loom::file-tree-child-lister file-tree)
            (lambda (path)
              (declare (ignore path))
              '(("/root/a.txt" . :file) ("/root/b.txt" . :file))))
      (file-tree-toggle file-tree)
      (loom::compose-frame editor-state)
      (let ((screen (cl-tty-kit:renderer-screen (loom-renderer-cl-tty-renderer renderer))))
        ;; File-tree entries at the left edge, one per row.
        (expect (cl-tty-kit:screen-row-string screen 0 :start 0 :end 5) :to-equal "a.txt")
        (expect (cl-tty-kit:screen-row-string screen 1 :start 0 :end 5) :to-equal "b.txt")
        ;; The window area starts right after the 24-column file-tree strip.
        (expect (cl-tty-kit:screen-row-string screen 0 :start 24 :end 26) :to-equal "hi")))))
