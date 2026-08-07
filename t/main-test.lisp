;;;; t/main-test.lisp
;;;;
;;;; The :TOPLEVEL entry point's supporting logic (src/main.lisp) that does
;;;; NOT itself require a real controlling terminal: raw octet reading
;;;; (%READ-INPUT-OCTETS, against a real binary file stream bound to
;;;; *STANDARD-INPUT* -- READ-BYTE/LISTEN work identically on a file and a
;;;; terminal fd-stream), key-event routing (%KEY-EVENT->DESCRIPTOR,
;;;; %DISPATCH-KEY-EVENT), undo-boundary bookkeeping
;;;; (%RECORD-UNDO-BOUNDARY-FOR-COMMAND), terminal-size polling
;;;; (%INITIAL-TERMINAL-SIZE, %POLL-TERMINAL-RESIZE, with
;;;; CL-TTY-KIT:TERMINAL-SIZE stubbed via CL-WEAVE:WITH-REPLACED-FUNCTION so
;;;; these are deterministic under any test environment, tty or not), the
;;;; CLI-argument-to-startup-file/file-tree-root resolution
;;;; (%STARTUP-FILE-AND-ROOT, %INITIALIZE-EDITOR-STATE), and %LOOM-VERSION.
;;;;
;;;; %RUN-EVENT-LOOP itself needs no real terminal either -- it only reads
;;;; *STANDARD-INPUT* (a binary file stream works identically to a tty
;;;; fd-stream) and writes to an explicit STREAM parameter (any character
;;;; output stream), with CL-TTY-KIT:TERMINAL-SIZE stubbed the same way as
;;;; above. Only %RUN-LOOM and MAIN themselves -- which wrap it in a real
;;;; CL-TTY-KIT:WITH-TERMINAL-SESSION (raw mode, alternate screen) -- need an
;;;; actual controlling terminal, out of scope for this suite.
(in-package #:loom/test)

(defun %fresh-full-editor-state (initial-content)
  "Build a complete *EDITOR-STATE*, unlike %FRESH-EDITOR-STATE in
commands-test.lisp: a real minibuffer, file-tree, renderer, and the default
keybindings, for exercising %RUN-EVENT-LOOP end to end."
  (let* ((buffer (make-buffer :initial-content initial-content))
         (window-tree (make-window-tree buffer 80 24)))
    (make-editor-state :window-tree window-tree
                       :minibuffer (make-minibuffer)
                       :keymap (loom::install-default-keybindings (make-keymap))
                       :file-tree (make-file-tree "/root/")
                       :renderer (make-loom-renderer 80 24)
                       :kill-ring nil)))

(describe
  "%read-input-octets"
  (it
    "reads all currently-available octets into buffer and returns the count"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "input.bin" dir)))
        (with-open-file (out path :direction :output :element-type '(unsigned-byte 8))
          (write-byte 1 out)
          (write-byte 2 out)
          (write-byte 3 out))
        (with-open-file (*standard-input* path :direction :input
                                          :element-type '(unsigned-byte 8))
          (let ((buf (make-array 10 :element-type '(unsigned-byte 8))))
            (expect (loom::%read-input-octets buf) :to-equal 3)
            (expect (aref buf 0) :to-equal 1)
            (expect (aref buf 1) :to-equal 2)
            (expect (aref buf 2) :to-equal 3))))))

  (it
    "returns nil at end-of-file"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "empty.bin" dir)))
        (with-open-file (out path :direction :output :element-type '(unsigned-byte 8)))
        (with-open-file (*standard-input* path :direction :input
                                          :element-type '(unsigned-byte 8))
          (let ((buf (make-array 10 :element-type '(unsigned-byte 8))))
            (expect (loom::%read-input-octets buf) :to-be nil))))))

  (it
    "stops filling the buffer at its capacity even if more input is available"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "input.bin" dir)))
        (with-open-file (out path :direction :output :element-type '(unsigned-byte 8))
          (write-byte 1 out)
          (write-byte 2 out)
          (write-byte 3 out))
        (with-open-file (*standard-input* path :direction :input
                                          :element-type '(unsigned-byte 8))
          (let ((buf (make-array 2 :element-type '(unsigned-byte 8))))
            (expect (loom::%read-input-octets buf) :to-equal 2)))))))

(describe
  "%key-event->descriptor"
  (it
    "rewrites a :special :control-<letter> event into ((:control) . <letter>)"
    (let ((event (cl-tty-kit:make-key-event :type :special :code :control-x)))
      (expect (loom::%key-event->descriptor event) :to-equal (cons '(:control) #\x))))

  (it
    "passes a plain character event through unchanged, wrapped as (modifiers . code)"
    (let ((event (cl-tty-kit:make-key-event :type :character :code #\a)))
      (expect (loom::%key-event->descriptor event) :to-equal (cons nil #\a))))

  (it
    "passes a character event with an explicit :control modifier through unchanged"
    (let ((event (cl-tty-kit:make-key-event :type :character :code #\f :modifiers '(:control))))
      (expect (loom::%key-event->descriptor event) :to-equal (cons '(:control) #\f))))

  (it
    "passes a non-control :special event (e.g. an arrow key) through unchanged"
    (let ((event (cl-tty-kit:make-key-event :type :special :code :up)))
      (expect (loom::%key-event->descriptor event) :to-equal (cons nil :up)))))

(describe
  "%record-undo-boundary-for-command"
  (it
    "records a boundary when the command kind differs from the last one"
    (let ((*editor-state* (%fresh-editor-state "ab")))
      (setf (loom::editor-state-last-command-self-insert-p *editor-state*) nil)
      (let ((buffer (%selected-test-buffer)))
        (buffer-insert-string buffer "x")
        (loom::%record-undo-boundary-for-command t)
        (buffer-insert-string buffer "y")
        (loom::undo-command)
        (expect (buffer-line buffer 0) :to-equal "xab"))))

  (it
    "does not record a boundary between consecutive same-kind commands"
    (let ((*editor-state* (%fresh-editor-state "")))
      (setf (loom::editor-state-last-command-self-insert-p *editor-state*) t)
      (let ((buffer (%selected-test-buffer)))
        (buffer-insert-string buffer "x")
        (loom::%record-undo-boundary-for-command t)
        (buffer-insert-string buffer "y")
        (loom::undo-command)
        (expect (buffer-line buffer 0) :to-equal ""))))

  (it
    "updates last-command-self-insert-p for the next call"
    (let ((*editor-state* (%fresh-editor-state "")))
      (loom::%record-undo-boundary-for-command t)
      (expect (loom::editor-state-last-command-self-insert-p *editor-state*) :to-be t))))

(describe
  "%dispatch-key-event"
  (it
    "routes to minibuffer-handle-key while the minibuffer is active"
    (let* ((state (%fresh-editor-state "hi"))
           (minibuffer (make-minibuffer))
           (*editor-state* state)
           (keymap-state (make-keymap-state (make-keymap)))
           (confirmed nil))
      (setf (editor-state-minibuffer state) minibuffer)
      (minibuffer-activate minibuffer "Prompt: "
                           :on-confirm (lambda (input) (setf confirmed input)))
      (loom::%dispatch-key-event (cl-tty-kit:make-key-event :type :character :code #\a) keymap-state)
      (loom::%dispatch-key-event (cl-tty-kit:make-key-event :type :special :code :enter) keymap-state)
      (expect confirmed :to-equal "a")))

  (it
    "self-inserts a plain unmodified character when no prefix key is pending"
    (let ((*editor-state* (%fresh-editor-state "hllo")))
      (setf (editor-state-minibuffer *editor-state*) (make-minibuffer))
      (let ((keymap-state (make-keymap-state (make-keymap))))
        (buffer-set-point (%selected-test-buffer) 0 1)
        (loom::%dispatch-key-event (cl-tty-kit:make-key-event :type :character :code #\e) keymap-state)
        (expect (buffer-line (%selected-test-buffer) 0) :to-equal "hello"))))

  (it
    "dispatches a bound key through the keymap instead of self-inserting"
    (let* ((*editor-state* (%fresh-editor-state "hi"))
           (keymap (loom::install-default-keybindings (make-keymap)))
           (keymap-state (make-keymap-state keymap)))
      (setf (editor-state-minibuffer *editor-state*) (make-minibuffer))
      (setf (editor-state-keymap *editor-state*) keymap)
      (buffer-set-point (%selected-test-buffer) 0 0)
      (loom::%dispatch-key-event
       (cl-tty-kit:make-key-event :type :character :code #\f :modifiers '(:control))
       keymap-state)
      (expect (buffer-point-column (%selected-test-buffer)) :to-equal 1)))

  (it
    "does not self-insert a plain character while a prefix sequence is pending"
    (let* ((*editor-state* (%fresh-editor-state "hi"))
           (keymap (loom::install-default-keybindings (make-keymap)))
           (keymap-state (make-keymap-state keymap)))
      (setf (editor-state-minibuffer *editor-state*) (make-minibuffer))
      (setf (editor-state-keymap *editor-state*) keymap)
      (buffer-set-point (%selected-test-buffer) 0 0)
      ;; C-x begins the two-chord C-x C-s binding, leaving a pending prefix.
      (loom::%dispatch-key-event
       (cl-tty-kit:make-key-event :type :character :code #\x :modifiers '(:control))
       keymap-state)
      ;; a plain, unmodified "q" does not continue any bound sequence, and
      ;; must not fall through to self-insertion while the prefix is pending.
      (loom::%dispatch-key-event (cl-tty-kit:make-key-event :type :character :code #\q) keymap-state)
      (expect (buffer-line (%selected-test-buffer) 0) :to-equal "hi")))

  (it
    "reports a dispatched command's error in the minibuffer instead of propagating it"
    (let* ((state (%fresh-editor-state "hi"))
           (minibuffer (make-minibuffer))
           (*editor-state* state)
           (keymap (make-keymap))
           (keymap-state (make-keymap-state keymap)))
      (setf (editor-state-minibuffer state) minibuffer)
      (keymap-define-key keymap (list (cons '(:control) #\z))
                         (lambda () (error "boom")))
      (loom::%dispatch-key-event
       (cl-tty-kit:make-key-event :type :character :code #\z :modifiers '(:control))
       keymap-state)
      (expect (loom::%minibuffer-message minibuffer) :to-equal "boom"))))

(describe
  "%initial-terminal-size"
  (it
    "returns cl-tty-kit's reported terminal size when available"
    (with-replaced-function (cl-tty-kit:terminal-size (lambda () (values 100 40)))
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
      (with-replaced-function (cl-tty-kit:terminal-size (lambda () (values 100 40)))
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
      (with-replaced-function (cl-tty-kit:terminal-size (lambda () (values 80 24)))
        (expect (multiple-value-list (loom::%poll-terminal-resize renderer 80 24))
                :to-equal (list 80 24))))))

(describe
  "%run-event-loop"
  (it
    "self-inserts decoded input and exits cleanly at end-of-file"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "input.bin" dir)))
        (with-open-file (out path :direction :output :element-type '(unsigned-byte 8))
          (write-byte (char-code #\a) out))
        (let ((*editor-state* (%fresh-full-editor-state "")))
          (with-replaced-function (cl-tty-kit:terminal-size (lambda () (values 80 24)))
            (with-open-file (*standard-input* path :direction :input
                                              :element-type '(unsigned-byte 8))
              (loom::%run-event-loop (make-string-output-stream))))
          (expect (buffer-line (window-buffer (window-tree-selected-window
                                               (editor-state-window-tree *editor-state*)))
                                0)
                  :to-equal "a")))))

  (it
    "decodes a full 4096-byte read as-is, without slicing a partial chunk"
    ;; %READ-INPUT-OCTETS' BUF is exactly 4096 octets; writing that many
    ;; available bytes fills it completely in one read (COUNT = (LENGTH BUF)),
    ;; the one case the 1-byte test above never reaches.
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "input.bin" dir)))
        (with-open-file (out path :direction :output :element-type '(unsigned-byte 8))
          (dotimes (i 4096) (write-byte (char-code #\a) out)))
        (let ((*editor-state* (%fresh-full-editor-state "")))
          (with-replaced-function (cl-tty-kit:terminal-size (lambda () (values 80 24)))
            (with-open-file (*standard-input* path :direction :input
                                              :element-type '(unsigned-byte 8))
              (loom::%run-event-loop (make-string-output-stream))))
          (expect (length (buffer-line (window-buffer (window-tree-selected-window
                                                       (editor-state-window-tree *editor-state*)))
                                        0))
                  :to-equal 4096)))))

  (it
    "exits via LOOM-QUIT when a dispatched command signals it"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "input.bin" dir)))
        ;; C-x C-c is bound to SAVE-BUFFERS-KILL-TERMINAL, which SIGNALs
        ;; LOOM-QUIT once every displayed buffer is unmodified (true here:
        ;; the scratch buffer was never edited).
        (with-open-file (out path :direction :output :element-type '(unsigned-byte 8))
          (write-byte 24 out) ; C-x
          (write-byte 3 out)) ; C-c
        (let ((*editor-state* (%fresh-full-editor-state "")))
          (with-replaced-function (cl-tty-kit:terminal-size (lambda () (values 80 24)))
            (with-open-file (*standard-input* path :direction :input
                                              :element-type '(unsigned-byte 8))
              ;; A clean, non-local exit via LOOM-QUIT (not an unhandled
              ;; condition) proves %RUN-EVENT-LOOP's own HANDLER-CASE caught
              ;; it -- this call finishing at all, rather than the test
              ;; erroring out, is the assertion.
              (loom::%run-event-loop (make-string-output-stream))))))))

  (it
    "enables and restores raw mode against a real terminal descriptor, then returns 0"
    ;; CL-TTY-KIT:MAKE-PTY (the same real-pty helper cl-tty-kit's own test
    ;; suite uses for its raw-mode/session tests) spawns a real child
    ;; attached to a real pty, giving a genuine tty file descriptor --
    ;; %RUN-LOOM's :FD keyword lets this test hand that descriptor to
    ;; CL-TTY-KIT:WITH-TERMINAL-SESSION instead of the production default of
    ;; 0 (stdin), so ENABLE-RAW-MODE's TCSETATTR succeeds instead of failing
    ;; the way it does against a plain file or pipe.
    (let ((pty (cl-tty-kit:make-pty :program "/bin/sh")))
      (unwind-protect
          (let ((fd (sb-sys:fd-stream-fd (cl-tty-kit:pty-stream pty)))
                (invocation (cl-cli:parse-argv loom::*loom-app* '("loom"))))
            (with-open-file (*standard-input* "/dev/null"
                                              :direction :input
                                              :element-type '(unsigned-byte 8))
              ;; *STANDARD-INPUT* is unrelated to FD (which only backs the
              ;; raw-mode ioctls); reading immediate EOF from /dev/null makes
              ;; %RUN-EVENT-LOOP return after just its initial render.
              (expect (loom::%run-loom invocation :fd fd) :to-equal 0)))
        (cl-tty-kit:close-pty pty)))))

(describe
  "%startup-file-and-root"
  (it
    "returns the resolved file and its containing directory as file-tree root for an existing file"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "note.txt" dir)))
        (host-kit:write-file-string "hi" path)
        (multiple-value-bind (file root) (loom::%startup-file-and-root (namestring path))
          (expect file :to-equal (probe-file path))
          (expect root :to-equal (make-pathname :name nil :type nil :defaults (probe-file path)))))))

  (it
    "returns no file and the argument itself as root for a directory argument"
    (host-kit:with-temporary-directory (dir)
      (multiple-value-bind (file root) (loom::%startup-file-and-root (namestring dir))
        (expect file :to-be nil)
        (expect root :to-equal (namestring dir)))))

  (it
    "defaults to \".\" as root when given no argument"
    (multiple-value-bind (file root) (loom::%startup-file-and-root nil)
      (expect file :to-be nil)
      (expect root :to-equal "."))))

(describe
  "%initialize-editor-state"
  (it
    "loads an existing file into the initial buffer and names it after the file"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "note.txt" dir))
            (*editor-state* nil))
        (host-kit:write-file-string "hello" path)
        (loom::%initialize-editor-state (namestring path))
        (expect (buffer-name (%selected-test-buffer)) :to-equal "note.txt")
        (expect (buffer-text (%selected-test-buffer)) :to-equal "hello"))))

  (it
    "opens an empty *scratch* buffer when given no path argument"
    (let ((*editor-state* nil))
      (loom::%initialize-editor-state nil)
      (expect (buffer-name (%selected-test-buffer)) :to-equal "*scratch*"))))

(describe
  "%loom-version"
  (it
    "returns the loom ASDF system's version string"
    (expect (loom::%loom-version) :to-equal (asdf:component-version (asdf:find-system "loom")))))
