;;;; t/integration/major-mode-test.lisp
;;;;
;;;; Mode inference at the file boundary and mode-aware editing commands.
(in-package #:loom/test)

(describe
  "file and major-mode integration"
  (it
    "assigns a mode when a file is loaded"
    (host-kit:with-temporary-directory (directory)
      (let ((path (merge-pathnames "script.py" directory)))
        (host-kit:write-file-string "print('hello')" path)
        (let ((buffer (buffer-load path)))
          (expect (buffer-major-mode buffer) :to-be :python)
          (expect (buffer-text buffer) :to-equal "print('hello')")))))

  (it
    "selects a mode and uses its indentation and comment rules"
    (%with-minibuffer-state
        (minibuffer "value" (buffer (%selected-test-buffer)))
      (loom::set-major-mode)
      (expect (minibuffer-prompt-string minibuffer) :to-equal "Major mode: ")
      (funcall (loom::%minibuffer-on-confirm minibuffer) "Python")
      (expect (buffer-major-mode buffer) :to-be :python)

      (buffer-set-point buffer 0 0)
      (loom::indent-for-tab-command)
      (expect (buffer-line buffer 0) :to-equal "    value")

      (buffer-set-point buffer 0 4)
      (loom::comment-line)
      (expect (buffer-line buffer 0) :to-equal "    # value")
      (loom::comment-line)
      (expect (buffer-line buffer 0) :to-equal "    value"))))
