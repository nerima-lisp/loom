(in-package #:loom/test)

(defun %loom-test-parent-dispatch-command (hit)
  (setf (symbol-value hit) :parent))

(defun %loom-test-child-dispatch-command (hit)
  (setf (symbol-value hit) :child))

(defun %loom-test-global-dispatch-command (hit)
  (setf (symbol-value hit) :global))

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
      (%expect-minibuffer-prompt minibuffer (%major-mode-prompt-string))
      (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "Python")
      (expect (buffer-major-mode buffer) :to-be :python)

      (buffer-set-point buffer 0 0)
      (loom/feature/mode::indent-for-tab-command)
      (expect (buffer-line buffer 0) :to-equal "value")

      (buffer-set-point buffer 0 4)
      (loom/feature/mode::comment-line)
      (expect (buffer-line buffer 0) :to-equal "# value")
      (loom/feature/mode::comment-line)
      (expect (buffer-line buffer 0) :to-equal "value")))

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
      (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "not-a-mode")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal
              "Unknown major mode: not-a-mode")))

  (it
    "reports cancellation while selecting a major mode"
    (%with-minibuffer-state
        (minibuffer "value"
                    (buffer (%selected-test-buffer)))
      (loom/feature/mode:set-major-mode)
      (funcall (loom/core/minibuffer::%minibuffer-on-cancel minibuffer))
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal
              "Quit")))

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
    "rejects non-callable major-mode key bindings"
    (%with-registered-major-modes (:loom-test-invalid-binding)
      (register-major-mode
       :loom-test-invalid-binding
       :keybindings '(("C-c i" . 42)))
      (signals error
        (loom/feature/mode:major-mode-keymap
         :loom-test-invalid-binding))))

  (it
    "reports the end of whitespace-only lines as their indentation"
    (expect (loom/feature/mode::%major-mode-line-indentation
             (format nil " ~C" #\Tab))
            :to-equal
            2)))
;; Match Emacs' mode-specific indentation and region indentation conventions:
;; https://www.gnu.org/software/emacs/manual/html_node/elisp/Mode_002dSpecific-Indent.html
;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Indentation-Commands.html
(describe
  "major-mode indentation protocol"
  (it
    "indents Python and Rust from the previous line"
    (dolist (mode '(:python :rust))
      (%with-minibuffer-state
          (minibuffer "first
    body
run" (buffer (%selected-test-buffer)))
        (buffer-set-major-mode buffer mode)
        (buffer-set-point buffer 2 0)
        (let ((keymap-state
                (loom/core/command:make-keymap-state
                 (loom/core/editor-session:editor-state-keymap *editor-state*))))
          (loom::%dispatch-key-event
           (cl-tty-kit:make-key-event :type :special :code :tab)
           keymap-state))
        (expect (buffer-line buffer 2) :to-equal "    run"))))

  (it-each
    (("if ready; then" "fi" "  run")
     ("while ready; do" "done" "  run")
     ("{" "}" "  run")
     ("case $x in" "esac" "  run")
     ("echo then" "fi" "run")
     ("if ready; then # note" "fi" "  run"))
    "indents Shell blocks opened by ~A before ~A (body ~A)"
    (opener closer expected-body)
    (%with-minibuffer-state
        (minibuffer (format nil "~A~%run~%~A" opener closer)
                    (buffer (%selected-test-buffer)))
      (buffer-set-major-mode buffer :shell)
      (buffer-set-point buffer 1 0)
      (loom/feature/mode:indent-for-tab-command)
      (expect (buffer-line buffer 1) :to-equal expected-body)
      (buffer-set-point buffer 2 0)
      (loom/feature/mode:indent-for-tab-command)
      (expect (buffer-line buffer 2) :to-equal closer)))

  (it
    "registers a mode-specific indentation rule through the public protocol"
    (%with-registered-major-modes (:loom-test-indentation)
      (register-major-mode :loom-test-indentation)
      (expect
       (register-major-mode-indentation-rule
        :loom-test-indentation
        (lambda (buffer line-number)
          (declare (ignore buffer line-number))
          6))
       :to-be
       :loom-test-indentation)
      (%with-selected-buffer-state (buffer "value")
        (buffer-set-major-mode buffer :loom-test-indentation)
        (expect (major-mode-indentation-column buffer 0) :to-equal 6))))

  (it
    "indents a new Shell line after then"
    (%with-minibuffer-state
        (minibuffer "if ready; then" (buffer (%selected-test-buffer)))
      (buffer-set-major-mode buffer :shell)
      (buffer-set-point buffer 0 (length (buffer-line buffer 0)))
      (let ((keymap-state
              (loom/core/command:make-keymap-state
               (loom/core/editor-session:editor-state-keymap *editor-state*))))
        (loom::%dispatch-key-event
         (cl-tty-kit:make-key-event :type :special :code :enter)
         keymap-state))
      (expect (buffer-line buffer 1) :to-equal "  ")))
  (it
    "records RET with its command route and key"
    (host-kit:with-temporary-directory (directory)
      (let ((trace-path (namestring (merge-pathnames "commands.jsonl" directory))))
        (%with-minibuffer-state
            (minibuffer "root" (buffer (%selected-test-buffer)))
          (let ((keymap-state
                  (loom/core/command:make-keymap-state
                   (loom/core/editor-session:editor-state-keymap *editor-state*))))
            (buffer-set-major-mode buffer :python)
            (buffer-set-point buffer 0 4)
            (with-replaced-function
                (uiop:getenv
                 (lambda (name)
                   (when (string= name "LOOM_TRACE_COMMANDS") trace-path)))
              (loom::%dispatch-key-event
               (cl-tty-kit:make-key-event :type :special :code :enter)
               keymap-state))
            (with-open-file (stream trace-path)
              (let* ((event (json-kit:parse (read-line stream nil)))
                     (entry (gethash "entry" event)))
                (expect (gethash "command" event)
                        :to-equal
                        "mode/newline-and-indent")
                (expect (gethash "route" event) :to-equal "key")
                (expect (search "global" entry) :to-be-truthy)
                (expect (search "enter" entry) :to-be-truthy)
                (expect (read-line stream nil) :to-be nil))))))))

  (it
    "reindents the active region with C-M-backslash"
    (%with-minibuffer-state
        (minibuffer "root
    child
  next" (buffer (%selected-test-buffer)))
      (buffer-set-major-mode buffer :python)
      (loom/core/buffer:buffer-set-mark buffer 1 0)
      (buffer-set-point buffer 2 6)
      (let ((keymap-state
              (loom/core/command:make-keymap-state
               (loom/core/editor-session:editor-state-keymap *editor-state*))))
        (progn
          (expect
           (loom/core/buffer:buffer-active-region-span buffer)
           :to-be-truthy)
          (expect
           (loom/core/command:key-event->descriptor
            (cl-tty-kit:make-key-event
             :type :character
             :code #\\
             :modifiers (quote (:control :alt))))
           :to-equal
           (cons (quote (:alt :control)) #\\))
          (expect
           (loom/core/command:keymap-lookup
            (loom/feature/mode:major-mode-keymap
             :python
             (loom/core/editor-session:editor-state-keymap *editor-state*))
            (loom/core/command:defkeys-key-sequence
             (quote (:control :alt #\\))))
           :to-equal
           (loom/core/command:command-id-for-function
            (quote loom/feature/mode:indent-for-tab-command)))
          (loom::%dispatch-key-event
           (cl-tty-kit:make-key-event
            :type :character
            :code #\\
            :modifiers (quote (:control :alt)))
           keymap-state)
          (expect (loom:minibuffer-message-string minibuffer) :to-be nil)))
      (expect (buffer-line buffer 1) :to-equal "child")
      (expect (buffer-line buffer 2) :to-equal "next")
      (expect (buffer-point-line buffer) :to-equal 2)
      (expect (buffer-point-column buffer) :to-equal 4)
      (expect (multiple-value-list (loom/core/buffer:buffer-mark buffer))
              :to-equal
              (quote (1 0)))
      (expect (loom/core/buffer:buffer-mark-active-p buffer) :to-be t))))

(describe
  "major-mode pair completion protocol"
  (it
    "retains distinct pairs, replaces duplicate openers, and rejects symmetric pairs"
    (%with-registered-major-modes (:loom-test-pair-insertion)
      (register-major-mode :loom-test-pair-insertion)
      (expect
       (loom/feature/mode:register-major-mode-pair-completion
        :loom-test-pair-insertion #\( #\))
       :to-be
       :loom-test-pair-insertion)
      (loom/feature/mode:register-major-mode-pair-completion
       :loom-test-pair-insertion #\[ #\])
      (loom/feature/mode:register-major-mode-pair-completion
       :loom-test-pair-insertion #\[ #\})
      (signals error
        (loom/feature/mode:register-major-mode-pair-completion
         :loom-test-pair-insertion #\x #\x))
      (%with-minibuffer-state
          (minibuffer "" (buffer (%selected-test-buffer)))
        (buffer-set-major-mode buffer :loom-test-pair-insertion)
        (let ((keymap-state
                (loom/core/command:make-keymap-state
                 (loom/core/editor-session:editor-state-keymap
                  *editor-state*))))
          (loom::%dispatch-key-event
           (cl-tty-kit:make-key-event
            :type :character :code #\( :modifiers nil)
           keymap-state)
          (expect (buffer-text buffer) :to-equal "()")
          (expect (buffer-point-line buffer) :to-equal 0)
          (expect (buffer-point-column buffer) :to-equal 1)
          (loom::%dispatch-key-event
           (cl-tty-kit:make-key-event
            :type :character :code #\[ :modifiers nil)
           keymap-state)
          (expect (buffer-text buffer) :to-equal "([})")
          (expect (buffer-point-line buffer) :to-equal 0)
          (expect (buffer-point-column buffer) :to-equal 2)))))
  (it
    "skips an existing Lisp closer when the mode enables closer skipping"
    (%with-minibuffer-state
        (minibuffer "()" (buffer (%selected-test-buffer)))
      (buffer-set-major-mode buffer :common-lisp)
      (buffer-set-point buffer 0 1)
      (let ((keymap-state
              (loom/core/command:make-keymap-state
               (loom/core/editor-session:editor-state-keymap
                *editor-state*))))
        (loom::%dispatch-key-event
         (cl-tty-kit:make-key-event
          :type :character :code #\) :modifiers nil)
         keymap-state))
      (expect (buffer-text buffer) :to-equal "()")
      (expect (buffer-point-line buffer) :to-equal 0)
      (expect (buffer-point-column buffer) :to-equal 2)))
  (it
    "inserts a closer when its mode does not enable closer skipping"
    (%with-registered-major-modes (:loom-test-pair-no-skip)
      (register-major-mode :loom-test-pair-no-skip)
      (loom/feature/mode:register-major-mode-pair-completion
       :loom-test-pair-no-skip #\( #\))
      (%with-minibuffer-state
          (minibuffer ")" (buffer (%selected-test-buffer)))
        (buffer-set-major-mode buffer :loom-test-pair-no-skip)
        (buffer-set-point buffer 0 0)
        (let ((keymap-state
                (loom/core/command:make-keymap-state
                 (loom/core/editor-session:editor-state-keymap
                  *editor-state*))))
          (loom::%dispatch-key-event
           (cl-tty-kit:make-key-event
            :type :character :code #\) :modifiers nil)
           keymap-state))
        (expect (buffer-text buffer) :to-equal "))")
        (expect (buffer-point-line buffer) :to-equal 0)
        (expect (buffer-point-column buffer) :to-equal 1)))))
(describe
  "major-mode newline continuation protocol"
  (it
    "combines indentation and a mode-provided continuation prefix"
    (%with-registered-major-modes (:loom-test-newline-continuation)
      (register-major-mode :loom-test-newline-continuation)
      (signals error
        (loom/feature/mode:register-major-mode-newline-continuation
         :loom-unknown-mode (function identity)))
      (let ((received-line nil))
        (expect
         (loom/feature/mode:register-major-mode-newline-continuation
          :loom-test-newline-continuation
          (lambda (buffer line-number)
            (declare (ignore buffer))
            (setf received-line line-number)
            "- "))
         :to-be
         :loom-test-newline-continuation)
        (loom/feature/mode:register-major-mode-indentation-rule
         :loom-test-newline-continuation
         (lambda (buffer line-number)
           (declare (ignore buffer))
           (if (= line-number 1) 2 0)))
        (%with-minibuffer-state
            (minibuffer "- item" (buffer (%selected-test-buffer)))
          (buffer-set-major-mode buffer :loom-test-newline-continuation)
          (buffer-set-point buffer 0 6)
          (loom/feature/mode:newline-and-indent)
          (expect (buffer-text buffer) :to-equal (format nil "- item~%  - ")))
        (expect received-line :to-equal 0))))
  (it
    "removes a mode-selected range when an empty item ends"
    (%with-registered-major-modes (:loom-test-empty-item)
      (register-major-mode :loom-test-empty-item)
      (loom/feature/mode:register-major-mode-newline-continuation
       :loom-test-empty-item
       (lambda (buffer line-number)
         (when (and (zerop line-number)
                    (string= (buffer-line buffer line-number) "- "))
           (values nil 0 2))))
      (%with-minibuffer-state
          (minibuffer "- " (buffer (%selected-test-buffer)))
        (buffer-set-major-mode buffer :loom-test-empty-item)
        (buffer-set-point buffer 0 2)
        (loom/feature/mode:newline-and-indent)
        (expect (buffer-line buffer 0) :to-equal "")
        (expect (buffer-line buffer 1) :to-equal "")
        (expect (buffer-point-line buffer) :to-equal 1)
        (expect (buffer-point-column buffer) :to-equal 0))))
  (it
    "rejects an invalid deletion range before changing the buffer"
    (%with-registered-major-modes (:loom-test-invalid-newline-range)
      (register-major-mode :loom-test-invalid-newline-range)
      (loom/feature/mode:register-major-mode-newline-continuation
       :loom-test-invalid-newline-range
       (lambda (buffer line-number)
         (declare (ignore buffer line-number))
         (values nil 0 2)))
      (%with-minibuffer-state
          (minibuffer "x" (buffer (%selected-test-buffer)))
        (buffer-set-major-mode buffer :loom-test-invalid-newline-range)
        (buffer-set-point buffer 0 1)
        (signals error
          (loom/feature/mode:newline-and-indent))
        (expect (buffer-text buffer) :to-equal "x"))))
  (it
    "preserves indentation and continuation on RET"
    (%with-registered-major-modes (:loom-test-ret-continuation)
      (register-major-mode :loom-test-ret-continuation)
      (loom/feature/mode:register-major-mode-indentation-rule
       :loom-test-ret-continuation
       (lambda (buffer line-number)
         (declare (ignore buffer))
         (if (= line-number 1) 2 0)))
      (loom/feature/mode:register-major-mode-newline-continuation
       :loom-test-ret-continuation
       (lambda (buffer line-number)
         (declare (ignore buffer))
         (when (zerop line-number) "- ")))
      (%with-minibuffer-state
          (minibuffer "- item" (buffer (%selected-test-buffer)))
        (buffer-set-major-mode buffer :loom-test-ret-continuation)
        (buffer-set-point buffer 0 6)
        (let ((keymap-state
                (loom/core/command:make-keymap-state
                 (loom/core/editor-session:editor-state-keymap *editor-state*))))
          (loom::%dispatch-key-event
           (cl-tty-kit:make-key-event :type :special :code :enter)
           keymap-state))
        (expect (buffer-text buffer) :to-equal (format nil "- item~%  - "))
        (expect (buffer-point-line buffer) :to-equal 1)
        (expect (buffer-point-column buffer) :to-equal 4)))))
