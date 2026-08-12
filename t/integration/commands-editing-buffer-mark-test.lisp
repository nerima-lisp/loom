;;;; t/integration/commands-editing-buffer-mark-test.lisp
;;;;
;;;; Mark command integration tests.
(in-package #:loom/test)

(describe
  "mark commands"
  (it
    "set-mark-command sets mark to point's current position"
    (%with-selected-buffer-state (buffer "hello")
      (buffer-set-point buffer 0 3)
      (loom::set-mark-command)
      (multiple-value-bind (mark-line mark-column) (buffer-mark buffer)
        (expect mark-line :to-equal 0)
        (expect mark-column :to-equal 3))))

  (it
    "exchanges point and mark and marks the whole buffer"
    (%with-selected-buffer-state (buffer "hello")
      (buffer-set-point buffer 0 2)
      (buffer-set-mark buffer 0 4)
      (loom::exchange-point-and-mark)
      (expect buffer :to-have-point (cons 0 4))
      (multiple-value-bind (mark-line mark-column) (buffer-mark buffer)
        (expect mark-line :to-equal 0)
        (expect mark-column :to-equal 2))
      (loom::mark-whole-buffer)
      (expect buffer :to-have-point (cons 0 0))
      (multiple-value-bind (mark-line mark-column) (buffer-mark buffer)
        (expect mark-line :to-equal 0)
        (expect mark-column :to-equal 5))))

  (it
    "reports when exchanging point and mark before setting the mark"
    (%with-minibuffer-state (minibuffer "hello")
      (loom::exchange-point-and-mark)
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "The mark is not set"))))
