;;;; t/integration/commands-editing-buffer-narrowing-test.lisp
;;;;
;;;; Buffer narrowing and narrowed search integration tests.
(in-package #:loom/test)

(describe
  "narrowing commands"
  (it "narrows mark-whole-buffer and widens through the command layer"
    (%with-selected-minibuffer-buffer (minibuffer buffer "0123456789")
      (buffer-set-point buffer 0 7)
      (buffer-set-mark buffer 0 2)
      (loom::narrow-to-region)
      (expect (buffer-text buffer) :to-equal "0123456789")
      (expect (buffer-visible-text buffer) :to-equal "23456")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Narrowed to the active region")
      (loom::mark-whole-buffer)
      (expect buffer :to-have-point (cons 0 2))
      (multiple-value-bind (mark-line mark-column) (buffer-mark buffer)
        (expect mark-line :to-equal 0)
        (expect mark-column :to-equal 7))
      (loom::widen)
      (expect (buffer-visible-text buffer) :to-equal "0123456789")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Widened buffer"))))

(describe
  "narrowed search commands"
  (it "does not return matches outside the visible region"
    (let ((buffer (make-buffer :initial-content "foo hidden foo")))
      (buffer-narrow-to-region buffer 0 4 0 10)
      (buffer-set-point buffer 0 4)
      (let ((span (buffer-search-forward buffer "hidden")))
        (expect span :to-be-truthy)
        (expect (buffer-span-start span) :to-equal 4)
        (expect (buffer-span-end span) :to-equal 10))
      (expect (buffer-search-forward buffer "foo") :to-be nil)
      (expect (buffer-search-spans buffer "foo" 0) :to-be nil))))
