;;;; t/unit/minibuffer-input-history-test.lisp
;;;;
;;;; History navigation for src/application/minibuffer-input.lisp.
(in-package #:loom/test)

(describe
  "minibuffer history recall"
  (it
    "walks history newest-first and replaces the current input each step"
    (let* ((history (history-kit:make-history))
           (minibuffer (make-minibuffer :history history)))
      (history-kit:history-add history "first")
      (history-kit:history-add history "second")
      (minibuffer-activate minibuffer "M-x ")
      (minibuffer-handle-key minibuffer (%special-key :up))
      (expect (minibuffer-input-string minibuffer) :to-equal "second")
      (minibuffer-handle-key minibuffer (%special-key :up))
      (expect (minibuffer-input-string minibuffer) :to-equal "first")
      (minibuffer-handle-key minibuffer (%special-key :down))
      (expect (minibuffer-input-string minibuffer) :to-equal "second")))

  (it
    "adds confirmed input to history and resets navigation on activation"
    (let* ((history (history-kit:make-history))
           (minibuffer (make-minibuffer :history history))
           (confirmed nil))
      (minibuffer-activate minibuffer "M-x "
                           :on-confirm (lambda (input) (setf confirmed input)))
      (%type-string minibuffer "a")
      (minibuffer-handle-key minibuffer (%special-key :enter))
      (expect confirmed :to-equal "a")
      (minibuffer-activate minibuffer "M-x ")
      (minibuffer-handle-key minibuffer (%special-key :up))
      (expect (minibuffer-input-string minibuffer) :to-equal "a")))

  (it
    "ignores an unrecognized special key"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-activate minibuffer "M-x ")
      (%type-string minibuffer "ab")
      (minibuffer-handle-key minibuffer (%special-key :left))
      (expect (minibuffer-input-string minibuffer) :to-equal "ab"))))
