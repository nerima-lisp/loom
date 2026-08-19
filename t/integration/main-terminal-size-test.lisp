;;;; t/integration/main-terminal-size-test.lisp
(in-package #:loom/test)

(describe
  "%initial-terminal-size"
  (it
    "returns cl-tty-kit's reported terminal size when available"
    (%with-stubbed-terminal-size (100 40)
      (expect (multiple-value-list (loom::%initial-terminal-size)) :to-equal (list 100 40))))

  (it
    "falls back to 80x24 when the terminal size is unavailable"
    (with-replaced-function (cl-tty-kit:terminal-size (lambda () (values nil nil)))
      (expect (multiple-value-list (loom::%initial-terminal-size)) :to-equal (list 80 24)))))

(describe
  "%poll-terminal-resize"
  (it
    "resizes the renderer and returns the new size when the terminal size changed"
    (let ((renderer (make-loom-renderer 80 24)))
      (%with-stubbed-terminal-size (100 40)
        (expect (multiple-value-list (loom::%poll-terminal-resize renderer 80 24))
                :to-equal (list 100 40))
        (expect (cl-tty-kit:renderer-width
                 (loom::%loom-renderer-cl-tty-renderer renderer))
                :to-equal 100))))

  (it
    "returns the last-seen size unchanged when the terminal size is unavailable"
    (let ((renderer (make-loom-renderer 80 24)))
      (with-replaced-function (cl-tty-kit:terminal-size (lambda () (values nil nil)))
        (expect (multiple-value-list (loom::%poll-terminal-resize renderer 80 24))
                :to-equal (list 80 24)))))

  (it
    "returns the last-seen size unchanged when the terminal size is unchanged"
    (let ((renderer (make-loom-renderer 80 24)))
      (%with-stubbed-terminal-size (80 24)
        (expect (multiple-value-list (loom::%poll-terminal-resize renderer 80 24))
                :to-equal (list 80 24))))))
