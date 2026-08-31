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

(describe
  "%event-loop-background-work-p"
  (it
    "reports no background work for an idle editor state"
    (let ((loom::*editor-state* (make-editor-state)))
      (expect (loom::%event-loop-background-work-p) :to-be nil)))

  (it
    "reports background work when auto-save mode is enabled"
    (let ((loom::*editor-state* (make-editor-state)))
      (setf (editor-state-auto-save-mode-p loom::*editor-state*) t)
      (expect (loom::%event-loop-background-work-p) :to-be t)))

  (it
    "reports background work when auto-save buffers are present"
    (let ((loom::*editor-state* (make-editor-state)))
      (setf (editor-state-auto-save-buffers loom::*editor-state*) (list :buffer))
      (expect (loom::%event-loop-background-work-p) :to-be t))))

(describe
  "%wait-for-editor-input"
  (it
    "returns immediately when no background work is pending"
    (let ((loom::*editor-state* (make-editor-state)))
      (expect (loom::%wait-for-editor-input nil) :to-be t)))

  (it
    "waits for input while background work is pending"
    (let ((loom::*editor-state* (make-editor-state))
          (wait-calls 0))
      (setf (editor-state-auto-save-mode-p loom::*editor-state*) t)
      (with-replaced-function
          (cl-tty-kit:fd-wait
            (lambda (&rest arguments)
              (declare (ignore arguments))
              (incf wait-calls)
              :ready))
        (expect (loom::%wait-for-editor-input :input) :to-be :ready))
      (expect wait-calls :to-be 1)))

  (it
    "continues when waiting for input signals an error"
    (let ((loom::*editor-state* (make-editor-state)))
      (setf (editor-state-auto-save-mode-p loom::*editor-state*) t)
      (with-replaced-function
          (cl-tty-kit:fd-wait
            (lambda (&rest arguments)
              (declare (ignore arguments))
              (error "synthetic wait failure")))
        (expect (loom::%wait-for-editor-input :input) :to-be t)))))
