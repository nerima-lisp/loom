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

  (it "reports an unset mark without changing the visible buffer"
    (%with-selected-minibuffer-buffer (minibuffer buffer "0123456789")
      (loom::narrow-to-region)
      (expect (buffer-visible-text buffer) :to-equal "0123456789")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal
              "The mark is not set now, so no region is active")))

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

(describe
  "narrowing boundary calculations"
  (it "maps offsets across lines and clamps them to text bounds"
    (multiple-value-bind (line column)
        (loom::%text-offset-to-position-values (format nil "ab~%cd") 99)
      (expect line :to-equal 1)
      (expect column :to-equal 2))
    (multiple-value-bind (line column)
        (loom::%text-offset-to-position-values (format nil "ab~%cd") 2)
      (expect line :to-equal 0)
      (expect column :to-equal 2)))

  (it "rejects a narrowing region whose end precedes its start"
    (expect (handler-case
                (progn
                  (loom::%validate-narrow-region-order 1 2 1 1)
                  nil)
              (error () t))
            :to-be-truthy))

  (it "clamps point and mark offsets to the visible region"
    (let ((buffer (make-buffer :initial-content "0123456789")))
      (buffer-narrow-to-region buffer 0 2 0 7)
      (loom::%clamp-buffer-point-and-mark-to-visible-region buffer 0 99)
      (expect buffer :to-have-point (cons 0 2))
      (multiple-value-bind (line column) (buffer-mark buffer)
        (expect line :to-equal 0)
        (expect column :to-equal 7)))))
