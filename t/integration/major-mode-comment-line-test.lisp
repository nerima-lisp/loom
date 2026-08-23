;;;; t/integration/major-mode-comment-line-test.lisp
;;;;
;;;; Comment-line behavior for mode-aware editing commands.
(in-package #:loom/test)

(describe
  "major-mode comment-line integration"
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
    "moves point back after removing a comment beyond the marker"
    (%with-minibuffer-state
        (minibuffer "  # value"
                    (buffer (%selected-test-buffer)))
      (buffer-set-major-mode buffer :python)
      (buffer-set-point buffer 0 9)
      (loom/feature/mode:comment-line)
      (expect (buffer-line buffer 0) :to-equal "  value")
      (expect buffer :to-have-point (cons 0 7))))

  (it
    "does not move point before indentation when adding a comment"
    (%with-minibuffer-state
        (minibuffer "  value"
                    (buffer (%selected-test-buffer)))
      (buffer-set-major-mode buffer :python)
      (buffer-set-point buffer 0 0)
      (loom/feature/mode:comment-line)
      (expect (buffer-line buffer 0) :to-equal "  # value")
      (expect buffer :to-have-point (cons 0 0))))

  (it-each
      ((:nix "# value")
       (:typescript "// value")
       (:typescript-react "// value")
       (:emacs-lisp "; value")
       (:org "# value"))
      "inserts ~A's comment prefix"
      (mode expected)
    (%with-minibuffer-state
        (minibuffer "value" (buffer (%selected-test-buffer)))
      (buffer-set-major-mode buffer mode)
      (buffer-set-point buffer 0 0)
      (loom/feature/mode:comment-line)
      (expect (buffer-line buffer 0) :to-equal expected)))

  (it
    "reports modes without line comment syntax"
    (%with-minibuffer-state
        (minibuffer "value"
                    (buffer (%selected-test-buffer)))
      (buffer-set-major-mode buffer :json)
      (loom/feature/mode:comment-line)
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal
              "Mode JSON has no line comment syntax"))))

(describe
  "toggle-truncate-lines"
  (it-each
      ((:markdown nil)
       (:org nil)
       (:text nil)
       (:common-lisp t)
       (:nix t))
      "starts ~A at truncate-lines ~A"
      (mode expected)
    (%with-minibuffer-state
        (minibuffer "value" (buffer (%selected-test-buffer)))
      (buffer-set-major-mode buffer mode)
      (expect (loom:buffer-truncate-lines buffer) :to-be :default)
      (expect (loom/feature/mode:buffer-truncate-lines-p buffer)
              :to-be expected)))

  (it
    "flips away from the mode default and stays flipped"
    (%with-minibuffer-state
        (minibuffer "value" (buffer (%selected-test-buffer)))
      (buffer-set-major-mode buffer :markdown)
      (loom/feature/mode:toggle-truncate-lines)
      (expect (loom/feature/mode:buffer-truncate-lines-p buffer) :to-be t)
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Truncate long lines")
      (loom/feature/mode:toggle-truncate-lines)
      (expect (loom/feature/mode:buffer-truncate-lines-p buffer) :to-be nil)
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Wrap long lines")))

  (it
    "keeps an explicit choice when the major mode changes"
    (%with-minibuffer-state
        (minibuffer "value" (buffer (%selected-test-buffer)))
      (buffer-set-major-mode buffer :markdown)
      (loom/feature/mode:toggle-truncate-lines)
      (buffer-set-major-mode buffer :common-lisp)
      (expect (loom:buffer-truncate-lines buffer) :to-be t)
      (expect (loom/feature/mode:buffer-truncate-lines-p buffer) :to-be t))))
