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
      (loom/feature/mode::set-major-mode)
      (expect (minibuffer-prompt-string minibuffer) :to-equal "Major mode: ")
      (funcall (loom::%minibuffer-on-confirm minibuffer) "Python")
      (expect (buffer-major-mode buffer) :to-be :python)

      (buffer-set-point buffer 0 0)
      (loom/feature/mode::indent-for-tab-command)
      (expect (buffer-line buffer 0) :to-equal "    value")

      (buffer-set-point buffer 0 4)
      (loom/feature/mode::comment-line)
      (expect (buffer-line buffer 0) :to-equal "    # value")
      (loom/feature/mode::comment-line)
      (expect (buffer-line buffer 0) :to-equal "    value")))

  (it
    "reports unknown modes and exposes the selected mode"
    (%with-minibuffer-state
        (minibuffer "value"
                    (buffer (%selected-test-buffer)))
      (expect (loom/feature/mode:current-major-mode) :to-be :fundamental)
      (expect (loom/feature/mode::%major-mode-completion-candidates "py")
              :to-contain
              "Python")
      (loom/feature/mode:set-major-mode)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "not-a-mode")
      (expect (loom::%minibuffer-message minibuffer)
              :to-equal
              "Unknown major mode: not-a-mode")))

  (it
    "handles a selected window without a buffer"
    (let* ((state (%fresh-editor-state "" :with-minibuffer t)))
      (setf (editor-state-window-tree state)
            (make-window-tree nil 80 24))
      (let ((*editor-state* state))
        (expect (loom/feature/mode:current-major-mode)
                :to-be
                :fundamental)
        (expect (loom/feature/mode:indent-for-tab-command)
                :to-be
                nil)
        (expect (loom/feature/mode:comment-line)
                :to-be
                nil))))

  (it
    "keeps point positions when removing an indented comment without a gap"
    (%with-minibuffer-state
        (minibuffer "  #value"
                    (buffer (%selected-test-buffer)))
      (buffer-set-major-mode buffer :python)
      (buffer-set-point buffer 0 0)
      (loom/feature/mode:comment-line)
      (expect (buffer-line buffer 0) :to-equal "  value")
      (expect buffer :to-have-point (cons 0 0))))

  (it
    "reports modes without line comment syntax"
    (%with-minibuffer-state
        (minibuffer "value"
                    (buffer (%selected-test-buffer)))
      (buffer-set-major-mode buffer :json)
      (loom/feature/mode:comment-line)
      (expect (loom::%minibuffer-message minibuffer)
              :to-equal
              "Mode JSON has no line comment syntax"))))
