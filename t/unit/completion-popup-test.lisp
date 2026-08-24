;;;; t/unit/completion-popup-test.lisp
;;;;
;;;; The candidate list value: selection movement and item accessors.
(in-package #:loom/test)

(defun %sample-completion (&optional (items '(("alpha" . "alpha")
                                              ("beta" . "b")
                                              ("gamma" . "g"))))
  (make-editor-completion (make-buffer :initial-content "") 0 0 items))

(describe
  "editor-completion"
  (it
    "starts on the first candidate"
    (let ((completion (%sample-completion)))
      (expect (editor-completion-index completion) :to-equal 0)
      (expect (editor-completion-item-label
               (editor-completion-selected completion))
              :to-equal "alpha")))

  (it
    "reads a candidate's label and inserted text separately"
    (let ((item (second (editor-completion-items (%sample-completion)))))
      (expect (editor-completion-item-label item) :to-equal "beta")
      (expect (editor-completion-item-text item) :to-equal "b")))

  (it-each
      ((1 1 "beta")
       (2 2 "gamma")
       (3 0 "alpha")
       (-1 2 "gamma")
       (-4 2 "gamma"))
      "moving ~D lands on index ~D (~A)"
      (delta expected-index expected-label)
    (let ((completion (%sample-completion)))
      (editor-completion-move completion delta)
      (expect (editor-completion-index completion) :to-equal expected-index)
      (expect (editor-completion-item-label
               (editor-completion-selected completion))
              :to-equal expected-label)))

  (it
    "leaves an empty candidate list alone rather than dividing by its length"
    (let ((completion (%sample-completion '())))
      (editor-completion-move completion 1)
      (expect (editor-completion-index completion) :to-equal 0)
      (expect (editor-completion-selected completion) :to-be nil)))

  (it
    "hands back a copy of its items"
    (let ((completion (%sample-completion)))
      (setf (first (editor-completion-items completion)) '("mutated" . "m"))
      (expect (editor-completion-item-label
               (editor-completion-selected completion))
              :to-equal "alpha"))))
