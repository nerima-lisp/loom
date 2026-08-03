;;;; t/commands-test.lisp
;;;;
;;;; Application layer: the command protocol (src/application/commands-*.lisp).
;;;; A representative sample, not one test per command: movement clamping at
;;;; buffer boundaries, a kill-line/yank round trip, UNDO-COMMAND actually
;;;; undoing, and INSTALL-DEFAULT-KEYBINDINGS's C-x C-s binding. Each test
;;;; binds a fresh *EDITOR-STATE* around real domain objects (MAKE-BUFFER,
;;;; MAKE-WINDOW-TREE, MAKE-KEYMAP); MINIBUFFER/FILE-TREE/RENDERER are left
;;;; NIL since none of the commands exercised here touch them. Commands are
;;;; not exported from the LOOM package (see commands-internal.lisp's header
;;;; comment), so tests reach them via LOOM:: qualification, the same
;;;; precedent t/file-tree-test.lisp already set for
;;;; LOOM::FILE-TREE-CHILD-LISTER.
(in-package #:loom/test)

(defun %fresh-editor-state (initial-content)
  "Build a minimal *EDITOR-STATE* around a single window over a buffer
containing INITIAL-CONTENT -- enough for movement, editing, and undo
commands, which never touch the minibuffer/file-tree/renderer slots."
  (let* ((buffer (make-buffer :initial-content initial-content))
         (tree (make-window-tree buffer 80 24)))
    (make-editor-state :window-tree tree
                        :minibuffer nil
                        :keymap (make-keymap)
                        :file-tree nil
                        :renderer nil
                        :kill-ring nil)))

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
    (let* ((state (%fresh-editor-state "hello"))
           (minibuffer (make-minibuffer))
           (*editor-state* state))
      (setf (editor-state-minibuffer state) minibuffer)
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
    (let* ((state (%fresh-editor-state ""))
           (minibuffer (make-minibuffer))
           (path (merge-pathnames "created-by-find-file.txt" dir))
           (*editor-state* state))
      (setf (editor-state-minibuffer state) minibuffer)
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
      (let* ((state (%fresh-editor-state ""))
             (minibuffer (make-minibuffer))
             (path (merge-pathnames "existing.txt" dir))
             (*editor-state* state))
        (host-kit:write-file-string "already here" path)
        (setf (editor-state-minibuffer state) minibuffer)
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
      (let* ((buffer (make-buffer :initial-content "hello world"))
             (tree (make-window-tree buffer 80 24))
             (minibuffer (make-minibuffer))
             (*editor-state* (make-editor-state :window-tree tree
                                                 :minibuffer minibuffer
                                                 :keymap (make-keymap)
                                                 :file-tree nil
                                                 :renderer nil
                                                 :kill-ring nil)))
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
        (let* ((buffer (make-buffer :initial-content "hello"))
               (tree (make-window-tree buffer 80 24))
               (minibuffer (make-minibuffer))
               (*editor-state* (make-editor-state :window-tree tree
                                                   :minibuffer minibuffer
                                                   :keymap (make-keymap)
                                                   :file-tree nil
                                                   :renderer nil
                                                   :kill-ring nil)))
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
    (let* ((state (%fresh-editor-state "alpha ALPHA alpha"))
           (minibuffer (make-minibuffer))
           (*editor-state* state))
      (setf (editor-state-minibuffer state) minibuffer)
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 6)
        (loom::search-forward)
        (expect (minibuffer-prompt-string minibuffer) :to-equal "Search: ")
        (funcall (loom::%minibuffer-on-confirm minibuffer) "alpha")
        (expect (buffer-point-column buffer) :to-equal 12)
        (expect (loom::%minibuffer-message minibuffer) :to-equal "Found")
        (buffer-set-point buffer 0 17)
        (loom::search-forward)
        (funcall (loom::%minibuffer-on-confirm minibuffer) "alpha")
        (expect (buffer-point-column buffer) :to-equal 0))))
  (it
    "reports not found when the searched text does not occur anywhere"
    (let* ((state (%fresh-editor-state "alpha"))
           (minibuffer (make-minibuffer))
           (*editor-state* state))
      (setf (editor-state-minibuffer state) minibuffer)
      (loom::search-forward)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "nonexistent")
      (expect (loom::%minibuffer-message minibuffer) :to-equal "Not found")))
  (it
    "reports not found for an empty search string without moving point"
    (let* ((state (%fresh-editor-state "alpha"))
           (minibuffer (make-minibuffer))
           (*editor-state* state))
      (setf (editor-state-minibuffer state) minibuffer)
      (buffer-set-point (%selected-test-buffer) 0 2)
      (loom::search-forward)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "")
      (expect (loom::%minibuffer-message minibuffer) :to-equal "Not found")
      (expect (%selected-test-buffer) :to-have-point (cons 0 2))))
  (it
    "finds an occurrence on a later line of a multi-line buffer, searching from a later starting line"
    (let* ((state (%fresh-editor-state (format nil "one~%two~%three~%four")))
           (minibuffer (make-minibuffer))
           (*editor-state* state))
      (setf (editor-state-minibuffer state) minibuffer)
      ;; Point starts on line 1 (not the default line 0), so converting it to
      ;; a flat offset must walk past at least one earlier line's length.
      (buffer-set-point (%selected-test-buffer) 1 0)
      (loom::search-forward)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "four")
      (expect (%selected-test-buffer) :to-have-point (cons 3 0))))
  (it
    "replaces every case-sensitive occurrence from point and wraps once"
    (let* ((state (%fresh-editor-state "red RED red"))
           (minibuffer (make-minibuffer))
           (*editor-state* state))
      (setf (editor-state-minibuffer state) minibuffer)
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 4)
        (loom::replace-string)
        (expect (minibuffer-prompt-string minibuffer) :to-equal "Replace: ")
        (funcall (loom::%minibuffer-on-confirm minibuffer) "red")
        (expect (minibuffer-prompt-string minibuffer) :to-equal "With: ")
        (funcall (loom::%minibuffer-on-confirm minibuffer) "redred")
        (expect (buffer-text buffer) :to-equal "redred RED redred")
        (expect (buffer-point-column buffer) :to-equal 6)
        (expect (loom::%minibuffer-message minibuffer)
                :to-equal "Replaced 2 occurrence(s)"))))
  (it
    "reports not found when the text to replace does not occur anywhere"
    (let* ((state (%fresh-editor-state "alpha"))
           (minibuffer (make-minibuffer))
           (*editor-state* state))
      (setf (editor-state-minibuffer state) minibuffer)
      (loom::replace-string)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "nonexistent")
      (funcall (loom::%minibuffer-on-confirm minibuffer) "replacement")
      (expect (loom::%minibuffer-message minibuffer) :to-equal "Not found")))
  (it
    "reports not found for an empty replacement target without searching"
    (let* ((state (%fresh-editor-state "alpha"))
           (minibuffer (make-minibuffer))
           (*editor-state* state))
      (setf (editor-state-minibuffer state) minibuffer)
      (loom::replace-string)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "")
      (funcall (loom::%minibuffer-on-confirm minibuffer) "replacement")
      (expect (loom::%minibuffer-message minibuffer) :to-equal "Not found")
      (expect (buffer-text (%selected-test-buffer)) :to-equal "alpha")))
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
    (let* ((state (%fresh-editor-state (format nil "one~%two~%three")))
           (minibuffer (make-minibuffer))
           (*editor-state* state))
      (setf (editor-state-minibuffer state) minibuffer)
      (loom::goto-line)
      (expect (minibuffer-prompt-string minibuffer) :to-equal "Go to line: ")
      (funcall (loom::%minibuffer-on-confirm minibuffer) "3")
      (expect (buffer-point-line (%selected-test-buffer)) :to-equal 2)))
  (it
    "reports a non-positive line number without moving point"
    (let* ((state (%fresh-editor-state (format nil "one~%two")))
           (minibuffer (make-minibuffer))
           (*editor-state* state))
      (setf (editor-state-minibuffer state) minibuffer)
      (loom::goto-line)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "0")
      (expect (loom::%minibuffer-message minibuffer) :to-equal "Line number must be positive")
      (expect (buffer-point-line (%selected-test-buffer)) :to-equal 0)))
  (it
    "reports unparseable input without moving point"
    (let* ((state (%fresh-editor-state (format nil "one~%two")))
           (minibuffer (make-minibuffer))
           (*editor-state* state))
      (setf (editor-state-minibuffer state) minibuffer)
      (loom::goto-line)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "not-a-number")
      (expect (loom::%minibuffer-message minibuffer) :to-equal "Enter a line number")
      (expect (buffer-point-line (%selected-test-buffer)) :to-equal 0)))
  (progn
  (it
   "asks about a modified file buffer shown in a nonselected split"
   (host-kit:with-temporary-directory (dir)
     (let* ((state (%fresh-editor-state "selected"))
            (minibuffer (make-minibuffer))
            (*editor-state* state)
            (tree (editor-state-window-tree state))
            (other (make-buffer :name "other.txt"
                                :path (merge-pathnames "other.txt" dir)
                                :initial-content "other"))
            (quit nil))
       (setf (editor-state-minibuffer state) minibuffer)
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
     (let* ((state (%fresh-editor-state "selected"))
            (minibuffer (make-minibuffer))
            (*editor-state* state)
            (tree (editor-state-window-tree state))
            (first (make-buffer :name "first.txt"
                                :path (merge-pathnames "first.txt" dir)
                                :initial-content "first"))
            (second (make-buffer :name "second.txt"
                                 :path (merge-pathnames "second.txt" dir)
                                 :initial-content "second"))
            (quit nil))
       (setf (editor-state-minibuffer state) minibuffer)
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
   (let* ((state (%fresh-editor-state "draft"))
          (minibuffer (make-minibuffer))
          (*editor-state* state)
          (quit nil))
     (setf (editor-state-minibuffer state) minibuffer)
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
   (let* ((state (%fresh-editor-state "draft"))
          (minibuffer (make-minibuffer))
          (*editor-state* state)
          (quit nil))
     (setf (editor-state-minibuffer state) minibuffer)
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
  "keyboard-quit"
  (it "reports a Quit message"
    (let* ((state (%fresh-editor-state ""))
           (minibuffer (make-minibuffer))
           (*editor-state* state))
      (setf (editor-state-minibuffer state) minibuffer)
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
      (let* ((state (%fresh-editor-state ""))
             (minibuffer (make-minibuffer))
             (*editor-state* state))
        (setf (editor-state-minibuffer state) minibuffer)
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
      (let* ((state (%fresh-editor-state "hi"))
             (minibuffer (make-minibuffer))
             (*editor-state* state))
        (setf (editor-state-minibuffer state) minibuffer)
        (loom::execute-extended-command)
        (expect (minibuffer-prompt-string minibuffer) :to-equal "M-x ")
        (funcall (loom::%minibuffer-on-confirm minibuffer) "  FORWARD-CHAR  ")
        (expect (buffer-point-column (%selected-test-buffer)) :to-equal 1)))
    (it "reports an unregistered command without evaluating it"
      (let* ((state (%fresh-editor-state "hi"))
             (minibuffer (make-minibuffer))
             (*editor-state* state))
        (setf (editor-state-minibuffer state) minibuffer)
        (loom::execute-extended-command)
        (funcall (loom::%minibuffer-on-confirm minibuffer) "not-a-command")
        (expect (loom::%minibuffer-message minibuffer)
                :to-equal "Unknown command: not-a-command")))
    (it "binds M-x to execute-extended-command"
      (let ((keymap (make-keymap)))
        (loom::install-default-keybindings keymap)
        (expect (keymap-lookup keymap (list (cons (quote (:alt)) #\x)))
                :to-be (quote loom::execute-extended-command))))))

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
    (let* ((state (%fresh-editor-state "selected"))
           (minibuffer (make-minibuffer))
           (*editor-state* state)
           (tree (editor-state-window-tree state))
           (other (make-buffer :name "other.txt" :initial-content "other")))
      (setf (editor-state-minibuffer state) minibuffer)
      (window-set-buffer (window-split tree (window-tree-selected-window tree) :horizontal) other)
      (window-select-next tree)
      (loom::switch-to-buffer)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "other.txt")
      (expect (buffer-name (window-buffer (window-tree-selected-window tree)))
              :to-equal "other.txt")))

  (it
    "switch-to-buffer reports an unknown buffer name"
    (let* ((state (%fresh-editor-state "selected"))
           (minibuffer (make-minibuffer))
           (*editor-state* state))
      (setf (editor-state-minibuffer state) minibuffer)
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
      (let* ((state (%fresh-editor-state ""))
             (minibuffer (make-minibuffer))
             (*editor-state* state)
             (path (merge-pathnames "created.txt" dir)))
        (setf (editor-state-file-tree state) (%fresh-file-tree dir))
        (setf (editor-state-minibuffer state) minibuffer)
        (loom::file-tree-create-file-command)
        (funcall (loom::%minibuffer-on-confirm minibuffer) path)
        (expect (host-kit:path-exists-p path) :to-be-truthy))))

  (it
    "file-tree-create-directory-command creates a directory at the prompted path"
    (host-kit:with-temporary-directory (dir)
      (let* ((state (%fresh-editor-state ""))
             (minibuffer (make-minibuffer))
             (*editor-state* state)
             (path (merge-pathnames "created-dir/" dir)))
        (setf (editor-state-file-tree state) (%fresh-file-tree dir))
        (setf (editor-state-minibuffer state) minibuffer)
        (loom::file-tree-create-directory-command)
        (funcall (loom::%minibuffer-on-confirm minibuffer) path)
        (expect (host-kit:path-exists-p path) :to-be-truthy))))

  (it
    "file-tree-rename-command renames the selected entry"
    (host-kit:with-temporary-directory (dir)
      (let ((old-path (merge-pathnames "old.txt" dir))
            (new-path (merge-pathnames "new.txt" dir)))
        (host-kit:write-file-string "content" old-path)
        (let* ((state (%fresh-editor-state ""))
               (minibuffer (make-minibuffer))
               (*editor-state* state))
          (setf (editor-state-file-tree state) (%fresh-file-tree dir))
          (setf (editor-state-minibuffer state) minibuffer)
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
      (expect expansion :to-equal '(let ((m (foo))) (progn (use-nothing)))))))
