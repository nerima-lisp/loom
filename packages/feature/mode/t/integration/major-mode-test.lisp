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
