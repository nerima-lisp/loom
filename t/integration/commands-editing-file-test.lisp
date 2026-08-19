;;;; t/integration/commands-editing-file-test.lisp
;;;;
;;;; File-oriented editing command integration tests.
(in-package #:loom/test)

(describe
  "install-default-keybindings"
  (it-each
      (("C-x C-s" (((:control) . #\x) ((:control) . #\s)) loom/feature/file-tree:save-buffer)
       ("C-x C-u" (((:control) . #\x) ((:control) . #\u)) loom::undo-command)
       ("C-x C-y" (((:control) . #\x) ((:control) . #\y)) loom::redo-command)
       ("C-x C-q" (((:control) . #\x) ((:control) . #\q)) loom::toggle-read-only)
       ("C-x C-w" (((:control) . #\x) ((:control) . #\w)) loom/feature/file-tree:write-file)
       ("C-x k" (((:control) . #\x) (nil . #\k)) loom/feature/window:kill-buffer)
       ("C-x 0" (((:control) . #\x) (nil . #\0)) loom/feature/window:delete-window)
       ("C-x 1" (((:control) . #\x) (nil . #\1)) loom/feature/window:delete-other-windows)
       ("C-r" (((:control) . #\r)) loom/feature/search::search-backward)
       ("M-f" (((:alt) . #\f)) loom::forward-word)
       ("M-w" (((:alt) . #\w)) loom::kill-ring-save)
       ("M-y" (((:alt) . #\y)) loom::yank-pop)
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
      (let ((existing-path (merge-pathnames "already-here.txt" dir)))
        (host-kit:write-file-string "old content" existing-path)
        (%with-minibuffer-state (minibuffer "hello")
          (loom/feature/file-tree:save-buffer)
          (funcall (loom::%minibuffer-on-confirm minibuffer) existing-path)
          (expect (loom:minibuffer-message-string minibuffer)
                  :to-equal
                  (format nil "File exists: ~A (press C-x C-s again to overwrite)" existing-path))
          (expect (host-kit:read-file-string existing-path) :to-equal "old content"))))))
