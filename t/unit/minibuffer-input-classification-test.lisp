;;;; t/unit/minibuffer-input-classification-test.lisp
;;;;
;;;; Direct key classification coverage for src/application/minibuffer-input.lisp.
(in-package #:loom/test)

(describe
  "%minibuffer-key-kind"
  (it-each
      (("C-g as a C0 :special event" :special :control-g nil :cancel)
       ("C-g as a kitty CSI-u :character event" :character #\g (:control) :cancel)
       ("Backspace" :special :backspace nil :backspace)
       ("Up" :special :up nil :history-previous)
       ("Down" :special :down nil :history-next)
       ("Enter" :special :enter nil :confirm)
       ("Tab" :special :tab nil :complete)
       ("an ordinary character" :character #\a nil :character)
       ("an unhandled special key" :special :left nil :ignore))
      "classifies ~A" (label type code modifiers expected)
    (declare (ignore label))
    (let ((key-event (cl-tty-kit:make-key-event :type type :code code :modifiers modifiers)))
      (expect (loom::%minibuffer-key-kind key-event type code) :to-equal expected))))
