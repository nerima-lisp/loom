(in-package #:loom/test)

(describe
  "install-default-keybindings"
  (it-each
      (("C-x C-s" (((:control) . #\x) ((:control) . #\s)) loom/feature/files:save-buffer)
       ("C-x C-u" (((:control) . #\x) ((:control) . #\u)) nil)
       ("C-x C-y" (((:control) . #\x) ((:control) . #\y)) nil)
       ("C-x C-q" (((:control) . #\x) ((:control) . #\q)) loom::toggle-read-only)
       ("C-x C-w" (((:control) . #\x) ((:control) . #\w)) loom/feature/files:write-file)
       ("C-x k" (((:control) . #\x) (nil . #\k)) loom/feature/buffers:kill-buffer)
       ("C-x 0" (((:control) . #\x) (nil . #\0)) loom/feature/window:delete-window)
       ("C-x 1" (((:control) . #\x) (nil . #\1)) loom/feature/window:delete-other-windows)
       ("C-r" (((:control) . #\r)) loom/feature/search::isearch-backward)
       ("M-f" (((:alt) . #\f)) loom::forward-word)
       ("M-w" (((:alt) . #\w)) loom/feature/kill-ring:kill-ring-save)
       ("M-y" (((:alt) . #\y)) loom/feature/kill-ring:yank-pop)
       ("Enter" ((nil . :enter)) loom::newline-command)
       ("C-x 2" (((:control) . #\x) (nil . #\2)) loom/feature/window:split-window-below)
       ("C-g" (((:control) . #\g)) loom::keyboard-quit))
      "maps ~A to its expected command" (label key-sequence command)
    (declare (ignore label))
    (let ((keymap (make-keymap)))
      (loom/application:install-default-keybindings keymap)
      (expect
 (keymap-lookup keymap key-sequence)
 :to-equal
 (if command (loom/core/command:command-id-for-function command) nil))))

  (it
    "opens an empty buffer for an uncreated path and saves it"
    (host-kit:with-temporary-directory (dir)
      (%with-minibuffer-state (minibuffer ""
                               (path (merge-pathnames "created-by-find-file.txt" dir)))
        (loom/feature/file-tree:find-file)
        (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) path)
        (let ((buffer (%selected-test-buffer)))
          (expect (buffer-name buffer) :to-equal "created-by-find-file.txt")
          (expect (buffer-path buffer) :to-equal path)
          (expect (buffer-text buffer) :to-equal "")
          (expect (host-kit:path-exists-p path) :to-be-falsy)
          (buffer-insert-string buffer "created")
          (loom/feature/file-tree:save-buffer)
          (expect (host-kit:read-file-string path) :to-equal "created"))))))

