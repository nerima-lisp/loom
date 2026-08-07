;;;; t/commands-test.lisp
;;;;
;;;; Application layer: the command protocol (src/application/commands-*.lisp).
;;;; A representative sample, not one test per command: movement clamping at
;;;; buffer boundaries, a kill-line/yank round trip, UNDO-COMMAND actually
;;;; undoing, and INSTALL-DEFAULT-KEYBINDINGS's C-x C-s binding. Each test
;;;; binds a fresh *EDITOR-STATE* around real domain objects (MAKE-BUFFER,
;;;; MAKE-WINDOW-TREE, MAKE-KEYMAP) via %FRESH-EDITOR-STATE, or via
;;;; %WITH-MINIBUFFER-STATE where the command under test prompts; FILE-TREE
;;;; and RENDERER stay NIL unless a test installs one. Commands are
;;;; not exported from the LOOM package (see commands-internal.lisp's header
;;;; comment), so tests reach them via LOOM:: qualification, the same
;;;; precedent t/file-tree-test.lisp already set for
;;;; LOOM::FILE-TREE-CHILD-LISTER.
(in-package #:loom/test)

(defun %fresh-editor-state (initial-content &key with-minibuffer)
  "Build a minimal *EDITOR-STATE* around a single window over a buffer
containing INITIAL-CONTENT -- enough for movement, editing, and undo
commands, which never touch the minibuffer/file-tree/renderer slots.
WITH-MINIBUFFER installs a live MAKE-MINIBUFFER for the prompting commands,
which do; see %WITH-MINIBUFFER-STATE."
  (let* ((buffer (make-buffer :initial-content initial-content))
         (tree (make-window-tree buffer 80 24)))
    (make-editor-state :window-tree tree
                        :minibuffer (and with-minibuffer (make-minibuffer))
                        :keymap (make-keymap)
                        :file-tree nil
                        :renderer nil
                        :kill-ring nil)))

(defmacro %with-minibuffer-state ((minibuffer initial-content &rest extra-bindings)
                                  &body body)
  "Run BODY with *EDITOR-STATE* dynamically bound to a fresh state over
INITIAL-CONTENT carrying a live minibuffer, and MINIBUFFER bound to that
minibuffer. EXTRA-BINDINGS are appended to the same LET*, so they may refer
to *EDITOR-STATE* and to MINIBUFFER."
  `(let* ((*editor-state* (%fresh-editor-state ,initial-content :with-minibuffer t))
          (,minibuffer (editor-state-minibuffer *editor-state*))
          ,@extra-bindings)
     ,@body))

(defun %selected-test-buffer ()
  "Return the buffer displayed in the fresh editor state's sole window."
  (window-buffer (window-tree-selected-window (editor-state-window-tree *editor-state*))))

(defun %fresh-file-tree (root)
  "Build a FILE-TREE rooted at ROOT with a real, disk-backed child-lister
\(LOOM-FS-LIST-DIRECTORY, the same one MAIN wires up in
%INITIALIZE-EDITOR-STATE\), for exercising the file-tree application
commands \(commands-window.lisp\) against a real temporary directory."
  (let ((tree (make-file-tree root)))
    (setf (loom::file-tree-child-lister tree) (function loom-fs-list-directory))
    tree))

(describe
  "movement commands"
  (it
    "clamps forward-char at the end of the buffer"
    (let ((*editor-state* (%fresh-editor-state "hi")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 2)
        (loom::forward-char)
        (expect (buffer-point-line buffer) :to-equal 0)
        (expect (buffer-point-column buffer) :to-equal 2))))

  (it
    "forward-char crosses onto the next line at end-of-line"
    (let ((*editor-state* (%fresh-editor-state (format nil "hi~%there"))))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 2)
        (loom::forward-char)
        (expect (buffer-point-line buffer) :to-equal 1)
        (expect (buffer-point-column buffer) :to-equal 0))))

  (it
    "clamps backward-char at the start of the buffer"
    (let ((*editor-state* (%fresh-editor-state "hi")))
      (let ((buffer (%selected-test-buffer)))
        (loom::backward-char)
        (expect (buffer-point-line buffer) :to-equal 0)
        (expect (buffer-point-column buffer) :to-equal 0))))

  (it
    "backward-char moves back one column within a line"
    (let ((*editor-state* (%fresh-editor-state "hi")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 2)
        (loom::backward-char)
        (expect buffer :to-have-point (cons 0 1)))))

  (it
    "backward-char wraps onto the end of the previous line at column 0"
    (let ((*editor-state* (%fresh-editor-state (format nil "hi~%there"))))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 1 0)
        (loom::backward-char)
        (expect buffer :to-have-point (cons 0 2)))))

  (it
    "next-line moves point down one line, clamping column to its length"
    (let ((*editor-state* (%fresh-editor-state (format nil "hello~%hi"))))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 4)
        (loom::next-line)
        (expect buffer :to-have-point (cons 1 2)))))

  (it
    "previous-line moves point up one line, clamping column to its length"
    (let ((*editor-state* (%fresh-editor-state (format nil "hi~%hello"))))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 1 4)
        (loom::previous-line)
        (expect buffer :to-have-point (cons 0 2)))))

  (it
    "move-end-of-line then move-beginning-of-line round-trips point"
    (let ((*editor-state* (%fresh-editor-state "hello")))
      (let ((buffer (%selected-test-buffer)))
        (loom::move-end-of-line)
        (expect (buffer-point-column buffer) :to-equal 5)
        (loom::move-beginning-of-line)
        (expect (buffer-point-column buffer) :to-equal 0))))

  (it
    "inserts a newline and advances point"
    (let ((*editor-state* (%fresh-editor-state "hello")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 2)
        (loom::newline-command)
        (expect (buffer-text buffer) :to-equal (format nil "he~%llo"))
        (expect (buffer-point-line buffer) :to-equal 1)
        (expect (buffer-point-column buffer) :to-equal 0))))

  (it
    "opens a line without moving point"
    (let ((*editor-state* (%fresh-editor-state "hello")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 2)
        (loom::open-line)
        (expect (buffer-text buffer) :to-equal (format nil "he~%llo"))
        (expect (buffer-point-line buffer) :to-equal 0)
        (expect (buffer-point-column buffer) :to-equal 2)))))

(describe
  "editing commands"
  (it
    "self-insert-command inserts the typed character at point"
    (let ((*editor-state* (%fresh-editor-state "hllo")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 1)
        (loom::self-insert-command #\e)
        (expect (buffer-line buffer 0) :to-equal "hello"))))

  (it
    "delete-char deletes the character at point"
    (let ((*editor-state* (%fresh-editor-state "hello")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 0)
        (loom::delete-char)
        (expect (buffer-line buffer 0) :to-equal "ello"))))

  (it
    "delete-backward-char deletes the character before point"
    (let ((*editor-state* (%fresh-editor-state "hello")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 5)
        (loom::delete-backward-char)
        (expect (buffer-line buffer 0) :to-equal "hell"))))

  (it
    "set-mark-command sets mark to point's current position"
    (let ((*editor-state* (%fresh-editor-state "hello")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 3)
        (loom::set-mark-command)
        (multiple-value-bind (mark-line mark-column) (buffer-mark buffer)
          (expect mark-line :to-equal 0)
          (expect mark-column :to-equal 3)))))

  (it
    "kill-line at end of a non-last line kills through the newline"
    (let ((*editor-state* (%fresh-editor-state (format nil "one~%two"))))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 3)
        (loom::kill-line)
        (expect (buffer-text buffer) :to-equal "onetwo")
        (expect (first (editor-state-kill-ring *editor-state*))
                :to-equal (format nil "~%")))))

  (it
    "kill-line is a no-op at the very end of the buffer"
    (let ((*editor-state* (%fresh-editor-state "hi")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 2)
        (loom::kill-line)
        (expect (buffer-text buffer) :to-equal "hi")
        (expect (editor-state-kill-ring *editor-state*) :to-be nil))))

  (it
    "kill-region reports no active region when the mark is unset"
    (%with-minibuffer-state (minibuffer "hello")
      (loom::kill-region)
      (expect (loom::%minibuffer-message minibuffer)
              :to-equal "The mark is not set now, so no region is active")))

  (it
    "kill-region kills forward from point to mark"
    (let ((*editor-state* (%fresh-editor-state "hello world")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 0)
        (buffer-set-mark buffer 0 5)
        (loom::kill-region)
        (expect (buffer-line buffer 0) :to-equal " world")
        (expect (first (editor-state-kill-ring *editor-state*)) :to-equal "hello"))))

  (it
    "kill-region kills backward from mark to point"
    (let ((*editor-state* (%fresh-editor-state "hello world")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-mark buffer 0 0)
        (buffer-set-point buffer 0 5)
        (loom::kill-region)
        (expect (buffer-line buffer 0) :to-equal " world")
        (expect (first (editor-state-kill-ring *editor-state*)) :to-equal "hello"))))

  (it
    "kill-region spans multiple lines when point and mark are on different lines"
    (let ((*editor-state* (%fresh-editor-state (format nil "one~%two~%three"))))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 0)
        (buffer-set-mark buffer 2 0)
        (loom::kill-region)
        (expect (buffer-text buffer) :to-equal "three"))))

  (it
    "kill-region spans multiple lines when point is on a LATER line than mark"
    (let ((*editor-state* (%fresh-editor-state (format nil "one~%two~%three"))))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-mark buffer 0 0)
        (buffer-set-point buffer 2 0)
        (loom::kill-region)
        (expect (buffer-text buffer) :to-equal "three")))))

(describe
  "kill-line and yank"
  (it
    "kills from point to end of line and yanks it back at a new position"
    (let ((*editor-state* (%fresh-editor-state "hello world")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 5)
        (loom::kill-line)
        (expect (buffer-line buffer 0) :to-equal "hello")
        (expect (first (editor-state-kill-ring *editor-state*)) :to-equal " world")
        (buffer-set-point buffer 0 0)
        (loom::yank)
        (expect (buffer-line buffer 0) :to-equal " worldhello")))))

(describe
  "undo-command"
  (it
    "undoes the most recent edit in the selected buffer"
    (let ((*editor-state* (%fresh-editor-state "hello")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 5)
        (buffer-insert-string buffer "!")
        (expect (buffer-line buffer 0) :to-equal "hello!")
        (loom::undo-command)
        (expect (buffer-line buffer 0) :to-equal "hello")))))

(describe
  "install-default-keybindings"
  (it-each
      (("C-x C-s" (((:control) . #\x) ((:control) . #\s)) loom::save-buffer)
       ("Enter" ((nil . :enter)) loom::newline-command)
       ("C-x 2" (((:control) . #\x) (nil . #\2)) loom::split-window-below)
       ("C-g" (((:control) . #\g)) loom::keyboard-quit))
      "binds ~A to its default command" (label key-sequence command)
    (declare (ignore label))
    (let ((keymap (make-keymap)))
      (loom::install-default-keybindings keymap)
      (expect (keymap-lookup keymap key-sequence) :to-be command)))
  (it
  "opens an empty buffer for an uncreated path and saves it"
  (host-kit:with-temporary-directory (dir)
    (%with-minibuffer-state (minibuffer ""
                             (path (merge-pathnames "created-by-find-file.txt" dir)))
      (loom::find-file)
      (funcall (loom::%minibuffer-on-confirm minibuffer) path)
      (let ((buffer (%selected-test-buffer)))
        (expect (buffer-name buffer) :to-equal "created-by-find-file.txt")
        (expect (buffer-path buffer) :to-equal path)
        (expect (buffer-text buffer) :to-equal "")
        (expect (host-kit:path-exists-p path) :to-be-falsy)
        (buffer-insert-string buffer "created")
        (loom::save-buffer)
        (expect (host-kit:read-file-string path) :to-equal "created")))))
  (it
    "loads an existing file's contents into the selected window"
    (host-kit:with-temporary-directory (dir)
      (%with-minibuffer-state (minibuffer ""
                               (path (merge-pathnames "existing.txt" dir)))
        (host-kit:write-file-string "already here" path)
        (loom::find-file)
        (funcall (loom::%minibuffer-on-confirm minibuffer) path)
        (let ((buffer (%selected-test-buffer)))
          (expect (buffer-name buffer) :to-equal "existing.txt")
          (expect (buffer-text buffer) :to-equal "already here"))))))

(describe
  "save-buffer path-less first save"
  (it
    "carries the old buffer's point onto the newly-swapped-in buffer"
    (host-kit:with-temporary-directory (dir)
      (%with-minibuffer-state (minibuffer "hello world"
                               (tree (editor-state-window-tree *editor-state*))
                               (buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 5)
        (buffer-set-mark buffer 0 2)
        (loom::save-buffer)
        ;; SAVE-BUFFER's path-less branch activated MINIBUFFER above rather
        ;; than saving directly; drive its stored ON-CONFIRM callback
        ;; ourselves with a path under a fresh temp directory, exactly as
        ;; MINIBUFFER-HANDLE-KEY would on RET.
        (funcall (loom::%minibuffer-on-confirm minibuffer)
                 (merge-pathnames "new-save.txt" dir))
        (let ((new-buffer (window-buffer (window-tree-selected-window tree))))
          (expect new-buffer :to-have-point (cons 0 5))
          (multiple-value-bind (mark-line mark-column) (buffer-mark new-buffer)
            (expect mark-line :to-equal 0)
            (expect mark-column :to-equal 2))))))
  (it
    "warns instead of overwriting when the typed path already names an existing file"
    (host-kit:with-temporary-directory (dir)
      (let* ((existing-path (merge-pathnames "already-here.txt" dir)))
        (host-kit:write-file-string "old content" existing-path)
        (%with-minibuffer-state (minibuffer "hello")
          (loom::save-buffer)
          (funcall (loom::%minibuffer-on-confirm minibuffer) existing-path)
          (expect (loom::%minibuffer-message minibuffer)
                  :to-equal
                  (format nil "File exists: ~A (press C-x C-s again to overwrite)" existing-path))
          (expect (host-kit:read-file-string existing-path) :to-equal "old content"))))))

(describe
  "kill-ring cap"
  (it
    "trims the kill ring to +kill-ring-max+ entries, dropping the oldest"
    (let ((*editor-state* (%fresh-editor-state "")))
      (dotimes (i (+ loom::+kill-ring-max+ 10))
        (loom::%kill-ring-push (format nil "entry-~D" i)))
      (expect (length (editor-state-kill-ring *editor-state*))
              :to-equal loom::+kill-ring-max+)
      (expect (first (editor-state-kill-ring *editor-state*))
              :to-equal (format nil "entry-~D" (1- (+ loom::+kill-ring-max+ 10)))))))
(describe
  "search and replace commands"
  (it
    "searches case-sensitively from point and wraps once"
    (%with-minibuffer-state (minibuffer "alpha ALPHA alpha")
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 6)
        (loom::search-forward)
        (expect (minibuffer-prompt-string minibuffer) :to-equal "Search (regex): ")
        (funcall (loom::%minibuffer-on-confirm minibuffer) "alpha")
        (expect (buffer-point-column buffer) :to-equal 12)
        (expect (loom::%minibuffer-message minibuffer) :to-equal "Found")
        (buffer-set-point buffer 0 17)
        (loom::search-forward)
        (funcall (loom::%minibuffer-on-confirm minibuffer) "alpha")
        (expect (buffer-point-column buffer) :to-equal 0))))
  (it
    "reports not found when the searched text does not occur anywhere"
    (%with-minibuffer-state (minibuffer "alpha")
      (loom::search-forward)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "nonexistent")
      (expect (loom::%minibuffer-message minibuffer) :to-equal "Not found")))
  (it
    "reports not found for an empty search string without moving point"
    (%with-minibuffer-state (minibuffer "alpha")
      (buffer-set-point (%selected-test-buffer) 0 2)
      (loom::search-forward)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "")
      (expect (loom::%minibuffer-message minibuffer) :to-equal "Not found")
      (expect (%selected-test-buffer) :to-have-point (cons 0 2))))
  (it
    "finds an occurrence on a later line of a multi-line buffer, searching from a later starting line"
    (%with-minibuffer-state (minibuffer (format nil "one~%two~%three~%four"))
      ;; Point starts on line 1 (not the default line 0), so converting it to
      ;; a flat offset must walk past at least one earlier line's length.
      (buffer-set-point (%selected-test-buffer) 1 0)
      (loom::search-forward)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "four")
      (expect (%selected-test-buffer) :to-have-point (cons 3 0))))
  (it
    "replaces every case-sensitive occurrence from point and wraps once"
    (%with-minibuffer-state (minibuffer "red RED red")
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 4)
        (loom::replace-string)
        (expect (minibuffer-prompt-string minibuffer) :to-equal "Replace (regex): ")
        (funcall (loom::%minibuffer-on-confirm minibuffer) "red")
        (expect (minibuffer-prompt-string minibuffer) :to-equal "With: ")
        (funcall (loom::%minibuffer-on-confirm minibuffer) "redred")
        (expect (buffer-text buffer) :to-equal "redred RED redred")
        (expect (buffer-point-column buffer) :to-equal 6)
        (expect (loom::%minibuffer-message minibuffer)
                :to-equal "Replaced 2 occurrence(s)"))))
  (it
    "reports not found when the text to replace does not occur anywhere"
    (%with-minibuffer-state (minibuffer "alpha")
      (loom::replace-string)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "nonexistent")
      (funcall (loom::%minibuffer-on-confirm minibuffer) "replacement")
      (expect (loom::%minibuffer-message minibuffer) :to-equal "Not found")))
  (it
    "reports not found for an empty replacement target without searching"
    (%with-minibuffer-state (minibuffer "alpha")
      (loom::replace-string)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "")
      (funcall (loom::%minibuffer-on-confirm minibuffer) "replacement")
      (expect (loom::%minibuffer-message minibuffer) :to-equal "Not found")
      (expect (buffer-text (%selected-test-buffer)) :to-equal "alpha")))
  (it
    "moves point to a match only a regular expression describes"
    ;; \d+ is not a literal substring of the buffer anywhere, so this passes
    ;; only because the search side is compiled as a regular expression rather
    ;; than looked up with CL:SEARCH.
    (%with-minibuffer-state (minibuffer "abc 1234 def")
      (loom::search-forward)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "\\d+")
      (expect (loom::%minibuffer-message minibuffer) :to-equal "Found")
      (expect (%selected-test-buffer) :to-have-point (cons 0 4))))
  (it
    "replaces variable-length matches rather than a fixed-length literal"
    ;; The two \s+ runs are different lengths, so each occurrence's end has to
    ;; come from the match itself; computing it as start plus (LENGTH OLD)
    ;; would delete the wrong span here.
    (%with-minibuffer-state (minibuffer "a    b  c")
      (loom::replace-string)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "\\s+")
      (funcall (loom::%minibuffer-on-confirm minibuffer) " ")
      (expect (buffer-text (%selected-test-buffer)) :to-equal "a b c")
      (expect (loom::%minibuffer-message minibuffer)
              :to-equal "Replaced 2 occurrence(s)")))
  (it
    "reports a malformed search pattern in the minibuffer instead of crashing"
    ;; CL-REGEX-KIT signals REGEX-SYNTAX-ERROR from inside SEARCH-FORWARD's
    ;; :ON-CONFIRM. Confirming through %DISPATCH-KEY-EVENT rather than calling
    ;; the callback directly is what runs it under the HANDLER-CASE that
    ;; already reports FIND-FILE/SAVE-BUFFER errors, so accepting regular
    ;; expressions needs no error handling of its own.
    (%with-minibuffer-state (minibuffer "abc"
                             (keymap-state (make-keymap-state (make-keymap))))
      (loom::search-forward)
      (%type-string minibuffer "(")
      (loom::%dispatch-key-event (%special-key :enter) keymap-state)
      (expect (loom::%minibuffer-message minibuffer)
              :to-contain "Invalid regular expression")
      (expect (%selected-test-buffer) :to-have-point (cons 0 0))))
  (it
    "hands its deadline to the regex engine on both the search and replace paths"
    ;; Forcing a real REGEX-TIMEOUT would need a pattern that makes the engine
    ;; backtrack, which is precisely what a Thompson NFA never does -- so the
    ;; deadline is proved to reach CL-REGEX-KIT by binding it to a value
    ;; CL-REGEX-KIT itself rejects, and watching both call sites refuse it.
    (let ((buffer (make-buffer :initial-content "abc 123"))
          (loom::+regex-search-timeout-seconds+ -1))
      (signals type-error (loom::%find-next-occurrence buffer "\\d+"))
      (signals type-error
        (loom::%replacement-match-spans (buffer-text buffer) "\\d+" 0))))
  (it-each
      (("C-s" (((:control) . #\s)) loom::search-forward)
       ("M-%" (((:alt) . #\%)) loom::replace-string)
       ("C-w" (((:control) . #\w)) loom::kill-region)
       ("C-o" (((:control) . #\o)) loom::open-line)
       ("M-g g" (((:alt) . #\g) (nil . #\g)) loom::goto-line))
      "binds ~A to its default command" (label key-sequence command)
    (declare (ignore label))
    (let ((keymap (make-keymap)))
      (loom::install-default-keybindings keymap)
      (expect (keymap-lookup keymap key-sequence) :to-be command)))
  (it
    "moves to a one-based line entered in the minibuffer"
    (%with-minibuffer-state (minibuffer (format nil "one~%two~%three"))
      (loom::goto-line)
      (expect (minibuffer-prompt-string minibuffer) :to-equal "Go to line: ")
      (funcall (loom::%minibuffer-on-confirm minibuffer) "3")
      (expect (buffer-point-line (%selected-test-buffer)) :to-equal 2)))
  (it
    "reports a non-positive line number without moving point"
    (%with-minibuffer-state (minibuffer (format nil "one~%two"))
      (loom::goto-line)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "0")
      (expect (loom::%minibuffer-message minibuffer) :to-equal "Line number must be positive")
      (expect (buffer-point-line (%selected-test-buffer)) :to-equal 0)))
  (it
    "reports unparseable input without moving point"
    (%with-minibuffer-state (minibuffer (format nil "one~%two"))
      (loom::goto-line)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "not-a-number")
      (expect (loom::%minibuffer-message minibuffer) :to-equal "Enter a line number")
      (expect (buffer-point-line (%selected-test-buffer)) :to-equal 0)))
  (progn
  (it
   "asks about a modified file buffer shown in a nonselected split"
   (host-kit:with-temporary-directory (dir)
     (%with-minibuffer-state (minibuffer "selected"
                             (tree (editor-state-window-tree *editor-state*))
                             (other (make-buffer :name "other.txt"
                                                 :path (merge-pathnames "other.txt" dir)
                                                 :initial-content "other"))
                             (quit nil))
       (let ((other-window (window-split tree
                                         (window-tree-selected-window tree)
                                         :horizontal)))
         (window-set-buffer other-window other))
       (window-select-next tree)
       (buffer-insert-string other "!")
       (loom::save-buffers-kill-terminal)
       (expect (minibuffer-prompt-string minibuffer)
               :to-equal "Save other.txt? (s/d/c): ")
       (handler-bind ((loom::loom-quit
                        (lambda (condition)
                          (declare (ignore condition))
                          (setf quit t))))
         (funcall (loom::%minibuffer-on-confirm minibuffer) "d"))
       (expect quit :to-be t))))

  (it
   "saves one modified split buffer before prompting for the next"
   (host-kit:with-temporary-directory (dir)
     (%with-minibuffer-state (minibuffer "selected"
                             (tree (editor-state-window-tree *editor-state*))
                             (first (make-buffer :name "first.txt"
                                                 :path (merge-pathnames "first.txt" dir)
                                                 :initial-content "first"))
                             (second (make-buffer :name "second.txt"
                                                  :path (merge-pathnames "second.txt" dir)
                                                  :initial-content "second"))
                             (quit nil))
       (window-set-buffer (window-tree-selected-window tree) first)
       (let ((second-window (window-split tree
                                          (window-tree-selected-window tree)
                                          :horizontal)))
         (window-set-buffer second-window second))
       (buffer-insert-string first "!")
       (buffer-insert-string second "!")
       (loom::save-buffers-kill-terminal)
       (expect (minibuffer-prompt-string minibuffer)
               :to-equal "Save first.txt? (s/d/c): ")
       (funcall (loom::%minibuffer-on-confirm minibuffer) "s")
       (expect (buffer-modified-p first) :to-be nil)
       (expect (minibuffer-prompt-string minibuffer)
               :to-equal "Save second.txt? (s/d/c): ")
       (handler-bind ((loom::loom-quit
                        (lambda (condition)
                          (declare (ignore condition))
                          (setf quit t))))
         (funcall (loom::%minibuffer-on-confirm minibuffer) "d"))
       (expect quit :to-be t))))

  (it
   "cancels quit without discarding a modified scratch buffer"
   (%with-minibuffer-state (minibuffer "draft" (quit nil))
     (let ((buffer (%selected-test-buffer)))
       (buffer-insert-string buffer "!")
       (loom::save-buffers-kill-terminal)
       (expect (minibuffer-prompt-string minibuffer)
               :to-equal (format nil "Discard changes to ~A? (d/c): "
                                 (buffer-name buffer)))
       (handler-bind ((loom::loom-quit
                        (lambda (condition)
                          (declare (ignore condition))
                          (setf quit t))))
         (funcall (loom::%minibuffer-on-confirm minibuffer) "c"))
       (expect quit :to-be nil)
       (expect (buffer-modified-p buffer) :to-be t))))

  (it
   "re-prompts on an unrecognized answer instead of quitting or discarding"
   (%with-minibuffer-state (minibuffer "draft" (quit nil))
     (let ((buffer (%selected-test-buffer)))
       (buffer-insert-string buffer "!")
       (loom::save-buffers-kill-terminal)
       (handler-bind ((loom::loom-quit
                        (lambda (condition)
                          (declare (ignore condition))
                          (setf quit t))))
         (funcall (loom::%minibuffer-on-confirm minibuffer) "not-a-valid-answer"))
       (expect quit :to-be nil)
       (expect (buffer-modified-p buffer) :to-be t)
       (expect (minibuffer-prompt-string minibuffer)
               :to-equal (format nil "Discard changes to ~A? (d/c): "
                                 (buffer-name buffer))))))))

(describe
  "%quit-answer-action"
  (it "resolves \"s\" to :save-and-continue when the buffer has a path"
    (expect (loom::%quit-answer-action "s" t) :to-be :save-and-continue))
  (it "resolves \"s\" to :retry when the buffer has no path"
    (expect (loom::%quit-answer-action "s" nil) :to-be :retry))
  (it "resolves \"d\" to :discard-and-continue regardless of path"
    (expect (loom::%quit-answer-action "d" t) :to-be :discard-and-continue)
    (expect (loom::%quit-answer-action "d" nil) :to-be :discard-and-continue))
  (it "resolves \"c\" to :cancel regardless of path"
    (expect (loom::%quit-answer-action "c" t) :to-be :cancel)
    (expect (loom::%quit-answer-action "c" nil) :to-be :cancel))
  (it "resolves an unrecognized answer to :retry"
    (expect (loom::%quit-answer-action "x" t) :to-be :retry)))

(describe
  "keyboard-quit"
  (it "reports a Quit message"
    (%with-minibuffer-state (minibuffer "")
      (loom::keyboard-quit)
      (expect (loom::%minibuffer-message minibuffer) :to-equal "Quit"))))

(describe
  "define-extended-commands macroexpansion"
  (it "expands each (name command) pair into its own cl-prolog rulebase clause"
    (let ((expansion (macroexpand-1
                      '(loom::define-extended-commands
                        ("forward-char" forward-char)
                        ("kill-line" kill-line)))))
      (expect (first expansion) :to-equal 'cl-prolog:define-rulebase)
      (expect (second expansion) :to-equal 'loom::*extended-command-rulebase*)
      (expect (third expansion) :to-equal '((loom::extended-command "forward-char" forward-char)))
      (expect (fourth expansion) :to-equal '((loom::extended-command "kill-line" kill-line))))))

(progn
  (describe "help command"
    (it "shows the primary command reference in the minibuffer"
      (%with-minibuffer-state (minibuffer "")
        (loom::help-command)
        (expect (loom::%minibuffer-message minibuffer)
                :to-equal
                "Help: M-x Command  C-x C-s Save  C-x C-f Open  C-s Find  C-k Cut  C-y Paste  C-x C-c Exit")))
    (it-each
        (("C-h" (((:control) . #\h)) loom::help-command)
         ("F1" ((nil . :f1)) loom::help-command))
        "binds ~A to help-command" (label key-sequence command)
      (declare (ignore label))
      (let ((keymap (make-keymap)))
        (loom::install-default-keybindings keymap)
        (expect (keymap-lookup keymap key-sequence) :to-be command))))

  (describe "execute-extended-command"
    (it "resolves a registered command through the command rulebase"
      (%with-minibuffer-state (minibuffer "hi")
        (loom::execute-extended-command)
        (expect (minibuffer-prompt-string minibuffer) :to-equal "M-x ")
        (funcall (loom::%minibuffer-on-confirm minibuffer) "  FORWARD-CHAR  ")
        (expect (buffer-point-column (%selected-test-buffer)) :to-equal 1)))
    (it "reports an unregistered command without evaluating it"
      (%with-minibuffer-state (minibuffer "hi")
        (loom::execute-extended-command)
        (funcall (loom::%minibuffer-on-confirm minibuffer) "not-a-command")
        (expect (loom::%minibuffer-message minibuffer)
                :to-equal "Unknown command: not-a-command")))
    (it "binds M-x to execute-extended-command"
      (let ((keymap (make-keymap)))
        (loom::install-default-keybindings keymap)
        (expect (keymap-lookup keymap (list (cons (quote (:alt)) #\x)))
                :to-be (quote loom::execute-extended-command))))))

(progn
  (defparameter +m-x-exempt-commands+ (list (quote loom::execute-extended-command))
    "The keybound commands DEFINE-EXTENDED-COMMANDS deliberately does not
register for M-x. EXECUTE-EXTENDED-COMMAND is the only member: it *is* the
M-x prompt, so an \"M-x execute-extended-command\" would do nothing but
reopen the prompt the user is already answering. Anything else missing from
the registry is an oversight, which is what the spec below fails on.")

  (defun %keymap-bound-commands (keymap)
    "Return every command symbol bound anywhere in KEYMAP, once each,
descending through prefix keys. Reads the keymap's own trie (see
domain/keymap.lisp: a table maps one normalized descriptor to either a bound
command or a nested table for a prefix), since KEYMAP-LOOKUP can only answer
about a key sequence already known to the caller and this spec's whole point
is to not maintain a second hand-written list of them."
    (let ((commands (list)))
      (labels ((walk (table)
                 (maphash (lambda (descriptor value)
                            (declare (ignore descriptor))
                            (if (hash-table-p value)
                                (walk value)
                                (pushnew value commands)))
                          table)))
        (walk (loom::keymap-table keymap)))
      commands))

  (defun %extended-command-names (command)
    "Return the M-x names COMMAND may be registered under. Two spellings are
in real use in DEFINE-EXTENDED-COMMANDS's table: a command whose Lisp name is
free to be the user-facing one registers under it verbatim
\(\"forward-char\"\), while a command that had to take a -COMMAND suffix in
Lisp to avoid clashing with a same-named generic registers under the bare
name \(NEWLINE-COMMAND as \"newline\", FILE-TREE-RENAME-COMMAND as
\"file-tree-rename\"\). Accepting both keeps this spec a check on
reachability rather than on which of the two spellings was chosen."
    (let* ((full (string-downcase (symbol-name command)))
           (suffix "-command")
           (cut (- (length full) (length suffix))))
      (if (and (plusp cut) (string= suffix full :start2 cut))
          (list full (subseq full 0 cut))
          (list full))))

  (describe
    "keybinding / M-x registry consistency"
    (it
      "resolves every keybound command through %find-extended-command"
      (let ((keymap (make-keymap)))
        (loom::install-default-keybindings keymap)
        (expect (remove-if
                 (lambda (command)
                   (or (member command +m-x-exempt-commands+)
                       (some (lambda (name)
                               (eq (loom::%find-extended-command name) command))
                             (%extended-command-names command))))
                 (%keymap-bound-commands keymap))
                :to-equal (list))))
    (it
      "exempts execute-extended-command, which is itself the M-x prompt"
      (let ((keymap (make-keymap)))
        (loom::install-default-keybindings keymap)
        (expect (%keymap-bound-commands keymap)
                :to-contain (quote loom::execute-extended-command)))
      (expect (loom::%find-extended-command "execute-extended-command") :to-be nil)
      (expect (loom::%find-extended-command "execute-extended") :to-be nil))))

(describe
  "window commands"
  (it
    "split-window-below adds a second window stacked below the first"
    (let ((*editor-state* (%fresh-editor-state "hi")))
      (let ((tree (editor-state-window-tree *editor-state*)))
        (expect (length (window-tree-windows tree)) :to-equal 1)
        (loom::split-window-below)
        (expect (length (window-tree-windows tree)) :to-equal 2))))

  (it
    "split-window-right adds a second window beside the first"
    (let ((*editor-state* (%fresh-editor-state "hi")))
      (let ((tree (editor-state-window-tree *editor-state*)))
        (loom::split-window-right)
        (expect (length (window-tree-windows tree)) :to-equal 2))))

  (it
    "other-window cycles back to the original window after a split"
    (let ((*editor-state* (%fresh-editor-state "hi")))
      (let* ((tree (editor-state-window-tree *editor-state*))
             (original (window-tree-selected-window tree)))
        (loom::split-window-below)
        (expect (eq (window-tree-selected-window tree) original) :to-be nil)
        (loom::other-window)
        (expect (window-tree-selected-window tree) :to-be original))))

  (it
    "switch-to-buffer displays a buffer already shown in another window"
    (%with-minibuffer-state (minibuffer "selected"
                             (tree (editor-state-window-tree *editor-state*))
                             (other (make-buffer :name "other.txt" :initial-content "other")))
      (window-set-buffer (window-split tree (window-tree-selected-window tree) :horizontal) other)
      (window-select-next tree)
      (loom::switch-to-buffer)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "other.txt")
      (expect (buffer-name (window-buffer (window-tree-selected-window tree)))
              :to-equal "other.txt")))

  (it
    "switch-to-buffer reports an unknown buffer name"
    (%with-minibuffer-state (minibuffer "selected")
      (loom::switch-to-buffer)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "nope.txt")
      (expect (loom::%minibuffer-message minibuffer) :to-equal "No such buffer: nope.txt"))))

(describe
  "file-tree commands"
  (it
    "toggle-file-tree flips the sidebar's visibility"
    (let ((*editor-state* (%fresh-editor-state "")))
      (setf (editor-state-file-tree *editor-state*) (make-file-tree "/root/"))
      (expect (file-tree-visible-p (editor-state-file-tree *editor-state*)) :to-be-falsy)
      (loom::toggle-file-tree)
      (expect (file-tree-visible-p (editor-state-file-tree *editor-state*)) :to-be-truthy)))

  (it
    "file-tree-select-next and file-tree-select-previous move the selection"
    (host-kit:with-temporary-directory (dir)
      (host-kit:write-file-string "a" (merge-pathnames "a.txt" dir))
      (host-kit:write-file-string "b" (merge-pathnames "b.txt" dir))
      (let ((*editor-state* (%fresh-editor-state "")))
        (setf (editor-state-file-tree *editor-state*) (%fresh-file-tree dir))
        (let ((tree (editor-state-file-tree *editor-state*)))
          (loom::file-tree-select-next)
          (let ((first (file-tree-selected-path tree)))
            (loom::file-tree-select-next)
            (expect (equal (file-tree-selected-path tree) first) :to-be nil)
            (loom::file-tree-select-previous)
            (expect (file-tree-selected-path tree) :to-equal first))))))

  (it
    "file-tree-open-selected opens a file entry as a buffer in the selected window"
    (host-kit:with-temporary-directory (dir)
      (host-kit:write-file-string "hello" (merge-pathnames "note.txt" dir))
      (let ((*editor-state* (%fresh-editor-state "")))
        (setf (editor-state-file-tree *editor-state*) (%fresh-file-tree dir))
        (loom::file-tree-select-next)
        (loom::file-tree-open-selected)
        (expect (buffer-name (%selected-test-buffer)) :to-equal "note.txt"))))

  (it
    "file-tree-open-selected expands a directory entry instead of opening it"
    (host-kit:with-temporary-directory (dir)
      (ensure-directories-exist (merge-pathnames "sub/" dir))
      (let ((*editor-state* (%fresh-editor-state "")))
        (setf (editor-state-file-tree *editor-state*) (%fresh-file-tree dir))
        (let ((tree (editor-state-file-tree *editor-state*)))
          (loom::file-tree-select-next)
          (loom::file-tree-open-selected)
          (expect (gethash (file-tree-selected-path tree) (loom::file-tree-expanded tree))
                  :to-be-truthy)))))

  (it
    "file-tree-create-file-command creates an empty file at the prompted path"
    (host-kit:with-temporary-directory (dir)
      (%with-minibuffer-state (minibuffer ""
                               (path (merge-pathnames "created.txt" dir)))
        (setf (editor-state-file-tree *editor-state*) (%fresh-file-tree dir))
        (loom::file-tree-create-file-command)
        (funcall (loom::%minibuffer-on-confirm minibuffer) path)
        (expect (host-kit:path-exists-p path) :to-be-truthy))))

  (it
    "file-tree-create-directory-command creates a directory at the prompted path"
    (host-kit:with-temporary-directory (dir)
      (%with-minibuffer-state (minibuffer ""
                               (path (merge-pathnames "created-dir/" dir)))
        (setf (editor-state-file-tree *editor-state*) (%fresh-file-tree dir))
        (loom::file-tree-create-directory-command)
        (funcall (loom::%minibuffer-on-confirm minibuffer) path)
        (expect (host-kit:path-exists-p path) :to-be-truthy))))

  (it
    "file-tree-rename-command renames the selected entry"
    (host-kit:with-temporary-directory (dir)
      (let ((old-path (merge-pathnames "old.txt" dir))
            (new-path (merge-pathnames "new.txt" dir)))
        (host-kit:write-file-string "content" old-path)
        (%with-minibuffer-state (minibuffer "")
          (setf (editor-state-file-tree *editor-state*) (%fresh-file-tree dir))
          (loom::file-tree-select-next)
          (loom::file-tree-rename-command)
          (funcall (loom::%minibuffer-on-confirm minibuffer) new-path)
          (expect (host-kit:path-exists-p old-path) :to-be-falsy)
          (expect (host-kit:path-exists-p new-path) :to-be-truthy)))))

  (it
    "file-tree-delete-command deletes the selected entry immediately"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "doomed.txt" dir)))
        (host-kit:write-file-string "content" path)
        (let ((*editor-state* (%fresh-editor-state "")))
          (setf (editor-state-file-tree *editor-state*) (%fresh-file-tree dir))
          (loom::file-tree-select-next)
          (loom::file-tree-delete-command)
          (expect (host-kit:path-exists-p path) :to-be-falsy))))))

(describe
  "%defkeys-single-chord-p"
  (it "is true for a bare keyword (an unmodified special key)"
    (expect (loom::%defkeys-single-chord-p :backspace) :to-be-truthy))
  (it "is true for a (:control code) chord"
    (expect (loom::%defkeys-single-chord-p '(:control #\f)) :to-be-truthy))
  (it "is true for a (:alt code) chord"
    (expect (loom::%defkeys-single-chord-p '(:alt #\x)) :to-be-truthy))
  (it "is false for a multi-chord sequence"
    (expect (loom::%defkeys-single-chord-p '((:control #\x) (:control #\f))) :to-be-falsy)))

(describe
  "%defkeys-chord-form"
  (it "builds a plain (cons nil code) form for a bare atom"
    (expect (loom::%defkeys-chord-form :enter) :to-equal '(cons nil :enter)))
  (it "builds a (cons (modifier) code) form for a modified chord"
    (expect (loom::%defkeys-chord-form '(:control #\f))
            :to-equal '(cons (quote (:control)) #\f))))

(describe
  "%defkeys-chord-forms"
  (it "normalizes a single chord into a one-element list of chord-forms"
    (expect (loom::%defkeys-chord-forms '(:control #\f))
            :to-equal '((cons (quote (:control)) #\f))))
  (it "normalizes a multi-chord sequence into a list of chord-forms"
    (expect (loom::%defkeys-chord-forms '((:control #\x) (:control #\f)))
            :to-equal '((cons (quote (:control)) #\x) (cons (quote (:control)) #\f)))))

(describe
  "defkeys macroexpansion"
  (it "expands each (key command) binding into its own keymap-define-key call"
    (let ((expansion (macroexpand-1 '(loom::defkeys km ((:control #\f) forward-char)))))
      (expect (first expansion) :to-equal 'progn)
      (expect (length (rest expansion)) :to-equal 1)
      (let ((call (second expansion)))
        (expect (first call) :to-equal 'keymap-define-key)
        (expect (second call) :to-equal 'km)
        (expect (fourth call) :to-equal '(quote forward-char))))))

(describe
  "with-prompts macroexpansion"
  (it "expands into a LET binding the minibuffer once, then nested prompts"
    (let ((expansion (macroexpand-1
                       '(loom::with-prompts (m (foo))
                            ((old "Replace: ") (new "With: "))
                          (use old new)))))
      (expect (first expansion) :to-equal 'let)
      (expect (second expansion) :to-equal '((m (foo))))
      (let ((outer-activate (third expansion)))
        (expect (first outer-activate) :to-equal 'minibuffer-activate)
        (expect (second outer-activate) :to-equal 'm)
        (expect (third outer-activate) :to-equal "Replace: ")
        (expect (fourth outer-activate) :to-equal :on-confirm)
        (let ((outer-lambda (fifth outer-activate)))
          (expect (first outer-lambda) :to-equal 'lambda)
          (expect (second outer-lambda) :to-equal '(old))
          (let ((inner-activate (third outer-lambda)))
            (expect (first inner-activate) :to-equal 'minibuffer-activate)
            (expect (third inner-activate) :to-equal "With: ")
            (let ((inner-lambda (fifth inner-activate)))
              (expect (second inner-lambda) :to-equal '(new))
              (expect (third inner-lambda) :to-equal '(progn (use old new)))))))))
  (it "expands to just the body, wrapped in a LET, when BINDINGS is empty"
    (let ((expansion (macroexpand-1 '(loom::with-prompts (m (foo)) () (use-nothing)))))
      (expect expansion :to-equal '(let ((m (foo))) (progn (use-nothing))))))
  (it "omits the :on-cancel keyword entirely when ON-CANCEL is not supplied"
    (let ((expansion (macroexpand-1
                       '(loom::with-prompts (m (foo)) ((old "Replace: ")) (use old)))))
      (expect (length (third expansion)) :to-equal 5)))
  (it "threads :on-cancel into every activation in the chain, after :on-confirm"
    (let* ((expansion (macroexpand-1
                        '(loom::with-prompts (m (foo) :on-cancel (bail m))
                             ((old "Replace: ") (new "With: "))
                           (use old new))))
           (outer-activate (third expansion))
           (inner-activate (third (fifth outer-activate))))
      (expect (fourth outer-activate) :to-equal :on-confirm)
      (expect (sixth outer-activate) :to-equal :on-cancel)
      (expect (seventh outer-activate) :to-equal '(lambda () (bail m)))
      (expect (sixth inner-activate) :to-equal :on-cancel)
      (expect (seventh inner-activate) :to-equal '(lambda () (bail m))))))

(describe
  "prompt cancellation"
  ;; Every prompting command passes WITH-PROMPTS an :ON-CANCEL that reports
  ;; "Quit", the same message KEYBOARD-QUIT gives for a top-level C-g, so
  ;; abandoning a prompt is acknowledged rather than silent. Driven through
  ;; MINIBUFFER-HANDLE-KEY with a real C-g key event (the sibling tests drive
  ;; %MINIBUFFER-ON-CONFIRM directly, which cannot exercise the cancel path).
  (it-each
      (("find-file" loom::find-file)
       ("save-buffer on a path-less buffer" loom::save-buffer)
       ("search-forward" loom::search-forward)
       ("replace-string" loom::replace-string)
       ("goto-line" loom::goto-line)
       ("switch-to-buffer" loom::switch-to-buffer)
       ("execute-extended-command" loom::execute-extended-command))
      "~A reports Quit on C-g" (label command)
    (declare (ignore label))
    (%with-minibuffer-state (minibuffer "hi")
      (funcall command)
      (expect (minibuffer-active-p minibuffer) :to-be-truthy)
      (minibuffer-handle-key minibuffer (%special-key :control-g))
      (expect (minibuffer-active-p minibuffer) :to-be-falsy)
      (expect (loom::%minibuffer-message minibuffer) :to-equal "Quit")))

  (it
    "cancelling replace-string's second prompt quits without replacing"
    ;; WITH-PROMPTS threads :ON-CANCEL into every activation in the chain,
    ;; not only the first, so a C-g after the first answer is confirmed still
    ;; reports Quit -- and the buffer is left untouched, proving the body
    ;; (and so %PERFORM-REPLACEMENT) never ran.
    (%with-minibuffer-state (minibuffer "alpha alpha")
      (loom::replace-string)
      (%type-string minibuffer "alpha")
      (minibuffer-handle-key minibuffer (%special-key :enter))
      (expect (minibuffer-prompt-string minibuffer) :to-equal "With: ")
      (minibuffer-handle-key minibuffer (%special-key :control-g))
      (expect (loom::%minibuffer-message minibuffer) :to-equal "Quit")
      (expect (buffer-text (%selected-test-buffer)) :to-equal "alpha alpha")))

  (it
    "cancelling file-tree-create-file-command creates nothing"
    (host-kit:with-temporary-directory (dir)
      (%with-minibuffer-state (minibuffer "")
        (setf (editor-state-file-tree *editor-state*) (%fresh-file-tree dir))
        (loom::file-tree-create-file-command)
        (%type-string minibuffer (namestring (merge-pathnames "unwanted.txt" dir)))
        (minibuffer-handle-key minibuffer (%special-key :control-g))
        (expect (loom::%minibuffer-message minibuffer) :to-equal "Quit")
        (expect (host-kit:path-exists-p (merge-pathnames "unwanted.txt" dir))
                :to-be-falsy))))

  (it
    "cancelling save-buffers-kill-terminal's quit prompt reports Quit"
    (%with-minibuffer-state (minibuffer "")
      (buffer-insert-string (%selected-test-buffer) "unsaved")
      (loom::save-buffers-kill-terminal)
      (expect (minibuffer-active-p minibuffer) :to-be-truthy)
      (minibuffer-handle-key minibuffer (%special-key :control-g))
      (expect (loom::%minibuffer-message minibuffer) :to-equal "Quit"))))
