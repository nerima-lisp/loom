(in-package #:loom/test)
(describe
  "editing commands"
  (it
    "self-insert-command inserts the typed character at point"
    (let ((*editor-state* (%fresh-editor-state "hllo")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 1)
        (loom:self-insert-command #\e)
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
    "kill-word removes the next word and adds it to the kill ring"
    (let ((*editor-state* (%fresh-editor-state "one two")))
      (let ((buffer (%selected-test-buffer)))
        (loom::kill-word)
        (expect (buffer-text buffer) :to-equal " two")
        (expect (first (editor-state-kill-ring *editor-state*))
                :to-equal "one"))))

  (it
    "backward-kill-word removes the previous word"
    (let ((*editor-state* (%fresh-editor-state "one two")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 7)
        (loom::backward-kill-word)
        (expect (buffer-text buffer) :to-equal "one ")
        (expect (first (editor-state-kill-ring *editor-state*))
                :to-equal "two"))))

  (it
    "kill-word with a negative prefix removes the previous word"
    (let ((*editor-state* (%fresh-editor-state "one two"))
          (loom:*current-prefix-argument* -1))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 7)
        (loom::kill-word)
        (expect (buffer-text buffer) :to-equal "one ")
        (expect (first (editor-state-kill-ring *editor-state*))
                :to-equal "two"))))

  (it
    "backward-kill-word with a negative prefix removes the next word"
    (let ((*editor-state* (%fresh-editor-state "one two"))
          (loom:*current-prefix-argument* -1))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 0)
        (loom::backward-kill-word)
        (expect (buffer-text buffer) :to-equal " two")
        (expect (first (editor-state-kill-ring *editor-state*))
                :to-equal "one"))))

  (it
    "kill-word is a no-op at the end of the buffer"
    (let ((*editor-state* (%fresh-editor-state "one")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 3)
        (loom::kill-word)
        (expect (buffer-text buffer) :to-equal "one")
        (expect (editor-state-kill-ring *editor-state*) :to-be nil))))

  (it
    "backward-kill-word is a no-op at the beginning of the buffer"
    (let ((*editor-state* (%fresh-editor-state "one")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 0)
        (loom::backward-kill-word)
        (expect (buffer-text buffer) :to-equal "one")
        (expect (editor-state-kill-ring *editor-state*) :to-be nil))))

  (it
    "exchanges point and mark and marks the whole buffer"
    (let ((*editor-state* (%fresh-editor-state "hello")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 2)
        (buffer-set-mark buffer 0 4)
        (loom::exchange-point-and-mark)
        (expect buffer :to-have-point (cons 0 4))
        (multiple-value-bind (mark-line mark-column) (buffer-mark buffer)
          (expect mark-line :to-equal 0)
          (expect mark-column :to-equal 2))
        (loom::mark-whole-buffer)
        (expect buffer :to-have-point (cons 0 0))
        (multiple-value-bind (mark-line mark-column) (buffer-mark buffer)
          (expect mark-line :to-equal 0)
          (expect mark-column :to-equal 5)))))

  (it
    "reports when exchanging point and mark before setting the mark"
    (%with-minibuffer-state (minibuffer "hello")
      (loom::exchange-point-and-mark)
      (expect (loom::%minibuffer-message minibuffer)
              :to-equal "The mark is not set")))

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
      (("C-x C-s" (((:control) . #\x) ((:control) . #\s)) loom/feature/file-tree:save-buffer)
       ("C-x C-w" (((:control) . #\x) ((:control) . #\w)) loom/feature/file-tree:write-file)
       ("C-x k" (((:control) . #\x) (nil . #\k)) loom/feature/window:kill-buffer)
       ("C-x 0" (((:control) . #\x) (nil . #\0)) loom/feature/window:delete-window)
       ("C-x 1" (((:control) . #\x) (nil . #\1)) loom/feature/window:delete-other-windows)
       ("C-r" (((:control) . #\r)) loom/feature/search::search-backward)
       ("M-f" (((:alt) . #\f)) loom::forward-word)
       ("Enter" ((nil . :enter)) loom::newline-command)
       ("C-x 2" (((:control) . #\x) (nil . #\2)) loom/feature/window:split-window-below)
       ("C-g" (((:control) . #\g)) loom::keyboard-quit))
      "binds ~A to its default command" (label key-sequence command)
    (declare (ignore label))
    (let ((keymap (make-keymap)))
      (loom/application:install-default-keybindings keymap)
      (expect (keymap-lookup keymap key-sequence) :to-be command)))
  (it
  "opens an empty buffer for an uncreated path and saves it"
  (host-kit:with-temporary-directory (dir)
    (%with-minibuffer-state (minibuffer ""
                             (path (merge-pathnames "created-by-find-file.txt" dir)))
      (loom/feature/file-tree:find-file)
      (funcall (loom::%minibuffer-on-confirm minibuffer) path)
      (let ((buffer (%selected-test-buffer)))
        (expect (buffer-name buffer) :to-equal "created-by-find-file.txt")
        (expect (buffer-path buffer) :to-equal path)
        (expect (buffer-text buffer) :to-equal "")
        (expect (host-kit:path-exists-p path) :to-be-falsy)
        (buffer-insert-string buffer "created")
        (loom/feature/file-tree:save-buffer)
        (expect (host-kit:read-file-string path) :to-equal "created")))))
  (it
    "loads an existing file's contents into the selected window"
    (host-kit:with-temporary-directory (dir)
      (%with-minibuffer-state (minibuffer ""
                               (path (merge-pathnames "existing.txt" dir)))
        (host-kit:write-file-string "already here" path)
        (loom/feature/file-tree:find-file)
        (funcall (loom::%minibuffer-on-confirm minibuffer) path)
        (let ((buffer (%selected-test-buffer)))
          (expect (buffer-name buffer) :to-equal "existing.txt")
          (expect (buffer-text buffer) :to-equal "already here"))))))
(it
    "writes the selected buffer to a new path and registers the new buffer"
    (host-kit:with-temporary-directory (dir)
      (%with-minibuffer-state (minibuffer "hello world"
                               (original (%selected-test-buffer))
                               (path (merge-pathnames "alias.txt" dir)))
        (buffer-set-point original 0 5)
        (buffer-set-mark original 0 2)
        (loom/feature/file-tree:write-file)
        (funcall (loom::%minibuffer-on-confirm minibuffer) path)
        (let ((new-buffer (%selected-test-buffer)))
          (expect (buffer-name new-buffer) :to-equal "alias.txt")
          (expect (buffer-path new-buffer) :to-equal path)
          (expect (buffer-text new-buffer) :to-equal "hello world")
          (expect new-buffer :to-have-point (cons 0 5))
          (multiple-value-bind (mark-line mark-column) (buffer-mark new-buffer)
            (expect mark-line :to-equal 0)
            (expect mark-column :to-equal 2))
          (expect (host-kit:read-file-string path) :to-equal "hello world")
          (expect (member original (editor-state-buffers *editor-state*))
                  :to-be-truthy)
          (expect (member new-buffer (editor-state-buffers *editor-state*))
                  :to-be-truthy)))))
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
        (loom/feature/file-tree:save-buffer)
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
          (loom/feature/file-tree:save-buffer)
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
        (loom/feature/search::search-forward)
        (expect (minibuffer-prompt-string minibuffer) :to-equal "Search (regex): ")
        (funcall (loom::%minibuffer-on-confirm minibuffer) "alpha")
        (expect (buffer-point-column buffer) :to-equal 12)
        (expect (loom::%minibuffer-message minibuffer) :to-equal "Found")
        (buffer-set-point buffer 0 17)
        (loom/feature/search::search-forward)
        (funcall (loom::%minibuffer-on-confirm minibuffer) "alpha")
        (expect (buffer-point-column buffer) :to-equal 0))))
  (it
    "searches backward to the previous match"
    (%with-minibuffer-state (minibuffer "one two one")
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 11)
        (loom/feature/search::search-backward)
        (funcall (loom::%minibuffer-on-confirm minibuffer) "one")
        (expect buffer :to-have-point (cons 0 8))
        (expect (loom::%minibuffer-message minibuffer) :to-equal "Found"))))
  (it
    "reports not found when backward search does not find the pattern"
    (%with-minibuffer-state (minibuffer "alpha")
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 2)
        (loom/feature/search::search-backward)
        (funcall (loom::%minibuffer-on-confirm minibuffer) "nonexistent")
        (expect (loom::%minibuffer-message minibuffer) :to-equal "Not found")
        (expect buffer :to-have-point (cons 0 2)))))
  (it
    "wraps backward search to the last match when point is before every match"
    (let ((buffer (make-buffer :initial-content "one two one")))
      (buffer-set-point buffer 0 0)
      (let ((span (buffer-search-backward buffer "one")))
        (expect span :to-be-truthy)
        (expect (buffer-span-start span) :to-equal 8))))
  (it
    "reports not found when the searched text does not occur anywhere"
    (%with-minibuffer-state (minibuffer "alpha")
      (loom/feature/search::search-forward)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "nonexistent")
      (expect (loom::%minibuffer-message minibuffer) :to-equal "Not found")))
  (it
    "reports not found for an empty search string without moving point"
    (%with-minibuffer-state (minibuffer "alpha")
      (buffer-set-point (%selected-test-buffer) 0 2)
      (loom/feature/search::search-forward)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "")
      (expect (loom::%minibuffer-message minibuffer) :to-equal "Not found")
      (expect (%selected-test-buffer) :to-have-point (cons 0 2))))
  (it
    "returns no spans for an empty search pattern at the domain boundary"
    (let ((buffer (make-buffer :initial-content "alpha")))
      (expect (buffer-search-forward buffer "") :to-be nil)
      (expect (buffer-search-backward buffer "") :to-be nil)
      (expect (buffer-search-spans buffer "" 0) :to-be nil)))
  (it
    "finds an occurrence on a later line of a multi-line buffer, searching from a later starting line"
    (%with-minibuffer-state (minibuffer (format nil "one~%two~%three~%four"))
      ;; Point starts on line 1 (not the default line 0), so converting it to
      ;; a flat offset must walk past at least one earlier line's length.
      (buffer-set-point (%selected-test-buffer) 1 0)
      (loom/feature/search::search-forward)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "four")
      (expect (%selected-test-buffer) :to-have-point (cons 3 0))))
  (it
    "replaces every case-sensitive occurrence from point and wraps once"
    (%with-minibuffer-state (minibuffer "red RED red")
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 4)
        (loom/feature/search::replace-string)
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
      (loom/feature/search::replace-string)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "nonexistent")
      (funcall (loom::%minibuffer-on-confirm minibuffer) "replacement")
      (expect (loom::%minibuffer-message minibuffer) :to-equal "Not found")))
  (it
    "reports not found for an empty replacement target without searching"
    (%with-minibuffer-state (minibuffer "alpha")
      (loom/feature/search::replace-string)
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
      (loom/feature/search::search-forward)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "\\d+")
      (expect (loom::%minibuffer-message minibuffer) :to-equal "Found")
      (expect (%selected-test-buffer) :to-have-point (cons 0 4))))
  (it
    "replaces variable-length matches rather than a fixed-length literal"
    ;; The two \s+ runs are different lengths, so each occurrence's end has to
    ;; come from the match itself; computing it as start plus (LENGTH OLD)
    ;; would delete the wrong span here.
    (%with-minibuffer-state (minibuffer "a    b  c")
      (loom/feature/search::replace-string)
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
      (loom/feature/search::search-forward)
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
          (loom/feature/search::+regex-search-timeout-seconds+ -1))
      (signals type-error (buffer-search-forward buffer "\\d+"))
      (signals type-error
        (buffer-search-spans buffer "\\d+" 0))))
  (it-each
      (("C-s" (((:control) . #\s)) loom/feature/search::search-forward)
       ("M-%" (((:alt) . #\%)) loom/feature/search::replace-string)
       ("C-w" (((:control) . #\w)) loom::kill-region)
       ("C-o" (((:control) . #\o)) loom::open-line)
       ("M-g g" (((:alt) . #\g) (nil . #\g)) loom::goto-line))
      "binds ~A to its default command" (label key-sequence command)
    (declare (ignore label))
    (let ((keymap (make-keymap)))
      (loom/application:install-default-keybindings keymap)
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
  "quit buffer registry"
  (it
    "prompts for a modified registered buffer that is not displayed"
    (host-kit:with-temporary-directory (directory)
      (let ((path (merge-pathnames "hidden.txt" directory)))
        (host-kit:write-file-string "hidden" path)
        (%with-minibuffer-state
            (minibuffer "selected"
                        (hidden (buffer-load path))
                        (quit nil))
          (setf (editor-state-buffers *editor-state*)
                (cons hidden (editor-state-buffers *editor-state*)))
          (buffer-insert-string hidden "!")
          (loom::save-buffers-kill-terminal)
          (expect (minibuffer-prompt-string minibuffer)
                  :to-equal "Save hidden.txt? (s/d/c): ")
          (handler-bind ((loom::loom-quit
                           (lambda (condition)
                             (declare (ignore condition))
                             (setf quit t))))
            (funcall (loom::%minibuffer-on-confirm minibuffer) "d"))
          (expect quit :to-be t))))))
