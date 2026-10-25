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

(describe
  "major-mode comment-dwim protocol"
  (it
    "appends a mode comment delimiter after the last nonblank character"
    (%with-minibuffer-state
        (minibuffer "  value  " (buffer (%selected-test-buffer)))
      (buffer-set-major-mode buffer :python)
      (buffer-set-point buffer 0 0)
      (loom/feature/mode:comment-dwim)
      (expect (buffer-line buffer 0) :to-equal "  value #  ")
      (expect buffer :to-have-point (cons 0 9))))

  (it
    "moves point to an existing inline comment delimiter"
    (%with-minibuffer-state
        (minibuffer "value # existing" (buffer (%selected-test-buffer)))
      (buffer-set-major-mode buffer :python)
      (buffer-set-point buffer 0 0)
      (loom/feature/mode:comment-dwim)
      (expect (buffer-line buffer 0) :to-equal "value # existing")
      (expect buffer :to-have-point (cons 0 7))))

  (it
    "keeps a current-line comment and moves point after its marker"
    (%with-minibuffer-state
        (minibuffer "  # existing" (buffer (%selected-test-buffer)))
      (buffer-set-major-mode buffer :python)
      (buffer-set-point buffer 0 0)
      (loom/feature/mode:comment-dwim)
      (expect (buffer-line buffer 0) :to-equal "  # existing")
      (expect buffer :to-have-point (cons 0 3))))

  (it
    "keeps a current-line block comment and moves point inside it"
    (%with-registered-major-modes (:loom-test-block-comment)
      (register-major-mode
       :loom-test-block-comment
       :name "Loom Test Block Comment"
       :comment-start "/*"
       :comment-end "*/")
      (%with-minibuffer-state
          (minibuffer "  /* existing */" (buffer (%selected-test-buffer)))
        (buffer-set-major-mode buffer :loom-test-block-comment)
        (buffer-set-point buffer 0 0)
        (loom/feature/mode:comment-dwim)
        (expect (buffer-line buffer 0) :to-equal "  /* existing */")
        (expect buffer :to-have-point (cons 0 4)))))

  (it
    "comments and uncomments every line in an active line-comment region"
    (%with-minibuffer-state
        (minibuffer "  # first
second
third" (buffer (%selected-test-buffer)))
      (buffer-set-major-mode buffer :python)
      (loom/core/buffer:buffer-set-mark buffer 0 0)
      (buffer-set-point buffer 1 6)
      (loom/feature/mode:comment-dwim)
      (expect (buffer-line buffer 0) :to-equal "  # # first")
      (expect (buffer-line buffer 1) :to-equal "# second")
      (expect (buffer-point-line buffer) :to-equal 1)
      (expect (buffer-point-column buffer) :to-equal 8)
      (expect (multiple-value-list (loom/core/buffer:buffer-mark buffer))
              :to-equal
              '(0 0))
      (expect (loom/core/buffer:buffer-mark-active-p buffer) :to-be t)
      (loom/feature/mode:comment-dwim)
      (expect (buffer-line buffer 0) :to-equal "  # first")
      (expect (buffer-line buffer 1) :to-equal "second")
      (expect (buffer-point-line buffer) :to-equal 1)
      (expect (buffer-point-column buffer) :to-equal 6)
      (expect (multiple-value-list (loom/core/buffer:buffer-mark buffer))
              :to-equal
              '(0 0))
      (expect (loom/core/buffer:buffer-mark-active-p buffer) :to-be t)))

  (it
    "wraps and unwraps an active region with block comment metadata"
    (%with-registered-major-modes (:loom-test-block-comment)
      (register-major-mode
       :loom-test-block-comment
       :name "Loom Test Block Comment"
       :comment-start "/*"
       :comment-end "*/")
      (%with-minibuffer-state
          (minibuffer "first
second
outside" (buffer (%selected-test-buffer)))
        (buffer-set-major-mode buffer :loom-test-block-comment)
        (loom/core/buffer:buffer-set-mark buffer 0 1)
        (buffer-set-point buffer 1 3)
        (loom/feature/mode:comment-dwim)
        (expect (buffer-line buffer 0) :to-equal "f/*irst")
        (expect (buffer-line buffer 1) :to-equal "sec*/ond")
        (expect (buffer-point-line buffer) :to-equal 1)
        (expect (buffer-point-column buffer) :to-equal 3)
        (expect (multiple-value-list (loom/core/buffer:buffer-mark buffer))
                :to-equal
                '(0 3))
        (expect (loom/core/buffer:buffer-mark-active-p buffer) :to-be t)
        (loom/feature/mode:comment-dwim)
        (expect (buffer-line buffer 0) :to-equal "first")
        (expect (buffer-line buffer 1) :to-equal "second")
        (expect (buffer-point-line buffer) :to-equal 1)
        (expect (buffer-point-column buffer) :to-equal 3)
        (expect (multiple-value-list (loom/core/buffer:buffer-mark buffer))
                :to-equal
                '(0 1))
        (expect (loom/core/buffer:buffer-mark-active-p buffer) :to-be t))))

  (it
    "keeps the no-comment mode message"
    (%with-minibuffer-state
        (minibuffer "value" (buffer (%selected-test-buffer)))
      (buffer-set-major-mode buffer :json)
      (loom/feature/mode:comment-dwim)
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal
              "Mode JSON has no line comment syntax")))

  (it
    "keeps M-x comment-line and dispatches mode-local M-; to comment-dwim"
    (%with-minibuffer-state
        (minibuffer "value" (buffer (%selected-test-buffer)))
      (buffer-set-major-mode buffer :python)
      (buffer-set-point buffer 0 0)
      (let ((spec
              (loom/core/command:find-extended-command-spec "comment-line")))
        (expect (loom/core/command:command-spec-name spec)
                :to-equal
                "comment-line")
        (expect (loom/core/command:find-extended-command-spec "comment-dwim")
                :to-be
                nil)
        (loom/core/command:invoke-command
         (loom/core/command:command-spec-id spec)
         :mx)
        (expect (buffer-line buffer 0) :to-equal "# value")
        (loom/core/command:invoke-command
         (loom/core/command:command-spec-id spec)
         :mx)
        (expect (buffer-line buffer 0) :to-equal "value"))
      (let* ((global-keymap
               (loom/application:install-default-keybindings
                (loom/core/editor-session:editor-state-keymap *editor-state*)))
             (mode-keymap
               (loom/feature/mode:major-mode-keymap :python global-keymap))
             (keymap-state
               (loom/core/command:make-keymap-state mode-keymap)))
        (loom::%dispatch-key-event
         (cl-tty-kit:make-key-event
          :type :character
          :code #\;
          :modifiers (list :alt))
         keymap-state))
      (expect (buffer-line buffer 0) :to-equal "value #")
      (expect buffer :to-have-point (cons 0 7)))))
