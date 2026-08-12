;;;; t/unit/window-layout-test.lisp
;;;;
;;;; Window layout persistence behavior.
(in-package #:loom/test)

(describe
  "window-tree layout persistence"
  (it
    "serializes and restores nested splits, scroll state, and selection"
    (let* ((tree (make-window-tree :scratch 20 10))
           (left (window-tree-selected-window tree))
           (right (window-split tree left :vertical))
           (bottom (window-split tree right :horizontal)))
      (setf (window-scroll-line bottom) 3)
      (window-tree-select-index tree 2)
      (let* ((layout (window-tree-layout tree))
             (restored (make-window-tree-from-layout
                        layout 20 10
                        :selected-index (window-tree-selected-index tree))))
        (expect layout
                :to-equal
                '(:split :vertical
                  (:leaf :scratch 0)
                  (:split :horizontal
                   (:leaf :scratch 0)
                   (:leaf :scratch 3))))
        (expect (window-tree-layout restored) :to-equal layout)
        (expect (window-tree-selected-index restored) :to-equal 2)
        (expect (window-scroll-line
                 (third (window-tree-windows restored)))
                :to-equal 3)
        (expect (window-tree-select-index restored 0) :to-be restored)
        (expect (window-tree-selected-index restored) :to-equal 0))))

  (it
    "rejects malformed layouts and invalid window selections"
    (let ((tree (make-window-tree :scratch 10 10)))
      (signals error (make-window-tree-from-layout 42 10 10))
      (signals error (make-window-tree-from-layout '(:leaf :scratch) 10 10))
      (signals error
        (make-window-tree-from-layout
         '(:split :vertical (:leaf :scratch 0)) 10 10))
      (signals error
        (make-window-tree-from-layout
         '(:split :diagonal (:leaf :left 0) (:leaf :right 0)) 10 10))
      (signals error (make-window-tree-from-layout '(:unknown) 10 10))
      (signals error
        (make-window-tree-from-layout '(:leaf :scratch 0) 10 10
                                      :selected-index -1))
      (signals error
        (make-window-tree-from-layout '(:leaf :scratch 0) 10 10
                                      :selected-index 1))
      (signals error (window-tree-select-index tree 1))
      (signals error (window-tree-select-index tree -1)))))
