(in-package #:loom/test)

(defun %buffer-menu-register (buffers)
  "Make BUFFERS the registry and show the first one.
Buffers not yet registered are added in list order; already registered ones
keep their registration, so file buffers keep their disk snapshots."
  (let ((session (loom/core/editor-session:editor-state-session *editor-state*)))
    (dolist (buffer (loom/feature/buffers:registered-buffers session))
      (unless (member buffer buffers)
        (loom/feature/buffers:unregister-buffer session buffer)))
    (dolist (buffer buffers)
      (loom/feature/buffers:register-buffer session buffer))
    (window-set-buffer (window-tree-selected-window
                        (editor-state-window-tree *editor-state*))
                       (first buffers))
    (loom/core/command:install-default-keybindings
     (loom/core/editor-session:editor-state-keymap *editor-state*))))

(defun %buffer-menu-list-buffer ()
  (loom/feature/buffers:find-buffer-by-name
   (loom/core/editor-session:editor-state-session *editor-state*)
   "*Buffer List*"))

(defun %buffer-menu-lines ()
  (let ((buffer (%buffer-menu-list-buffer)))
    (loop for line below (loom/core/buffer:buffer-line-count buffer)
          collect (loom/core/buffer:buffer-line buffer line))))

(defun %buffer-menu-select-list-window ()
  (let ((tree (editor-state-window-tree *editor-state*)))
    (loom/core/window-tree:window-tree-select-index
     tree
     (position (%buffer-menu-list-buffer) (window-tree-windows tree)
               :key #'window-buffer))))

(defun %buffer-menu-point-line ()
  (loom/core/buffer:buffer-point-line (%buffer-menu-list-buffer)))

(defun %buffer-menu-live-p (buffer)
  (not (null (member buffer (%test-registered-buffers *editor-state*)))))

(describe
  "list-buffers display"
  (it
    "splits one window, keeps the origin window and point, and lists every buffer in registration order"
    (%with-minibuffer-state (minibuffer "")
      (let ((tree (editor-state-window-tree *editor-state*))
            (a (make-buffer :name "a.txt" :path "/nonexistent-wp4a/a.txt"
                            :initial-content "alpha"))
            (b (make-buffer :name "b.txt" :initial-content "bravo"))
            (c (make-buffer :name "c.txt" :initial-content "c")))
        (%buffer-menu-register (list a b c))
        (buffer-set-point a 0 3)
        (buffer-insert-string b "!")
        (loom/core/buffer:buffer-set-read-only c t)
        (loom/feature/buffer-menu:list-buffers)
        (let ((windows (window-tree-windows tree))
              (list-buffer (%buffer-menu-list-buffer)))
          (expect (length windows) :to-equal 2)
          (expect (window-tree-selected-window tree) :to-be (first windows))
          (expect (window-buffer (first windows)) :to-be a)
          (expect a :to-have-point (cons 0 3))
          (expect (window-buffer (second windows)) :to-be list-buffer)
          (expect (loom/core/buffer:buffer-read-only-p list-buffer) :to-be t)
          (expect (loom/core/buffer:buffer-modified-p list-buffer) :to-be nil)
          (expect (loom/core/buffer:buffer-major-mode list-buffer)
                  :to-equal :buffer-menu)
          (expect (%buffer-menu-lines)
                  :to-equal
                  (list "  .   a.txt         5 Fundamental /nonexistent-wp4a/a.txt"
                        "    * b.txt         6 Fundamental"
                        "   %  c.txt         1 Fundamental"
                        "      *Buffer List* 0 Buffer Menu"))
          (expect (%buffer-menu-point-line) :to-equal 0)))))

  (it
    "shows a narrowed buffer's visible size without widening it"
    (%with-minibuffer-state (minibuffer "")
      (let ((a (make-buffer :name "a.txt" :initial-content "hello world")))
        (%buffer-menu-register (list a))
        (loom/core/buffer:buffer-narrow-to-region a 0 0 0 5)
        (loom/feature/buffer-menu:list-buffers)
        (expect (first (%buffer-menu-lines))
                :to-equal "  .   a.txt         5 Fundamental")
        (expect (loom/core/buffer:buffer-narrowed-p a) :to-be-truthy))))

  (it
    "q deletes the window list-buffers created and reselects the origin"
    (%with-minibuffer-state (minibuffer "")
      (let ((tree (editor-state-window-tree *editor-state*))
            (a (make-buffer :name "a.txt" :initial-content "alpha")))
        (%buffer-menu-register (list a))
        (buffer-set-point a 0 2)
        (let ((origin (window-tree-selected-window tree)))
          (loom/feature/buffer-menu:list-buffers)
          (%buffer-menu-select-list-window)
          (loom/feature/buffer-menu:buffer-menu-quit)
          (expect (window-tree-windows tree) :to-equal (list origin))
          (expect (window-tree-selected-window tree) :to-be origin)
          (expect (window-buffer origin) :to-be a)
          (expect a :to-have-point (cons 0 2))))))

  (it
    "reuses the next window when two exist and q restores its previous buffer"
    (%with-minibuffer-state (minibuffer "")
      (let ((tree (editor-state-window-tree *editor-state*))
            (a (make-buffer :name "a.txt" :initial-content "alpha"))
            (b (make-buffer :name "b.txt" :initial-content "bravo")))
        (%buffer-menu-register (list a b))
        (let* ((upper (window-tree-selected-window tree))
               (lower (window-split tree upper :horizontal)))
          (window-set-buffer lower b)
          (loom/core/window-tree:window-tree-select-index tree 0)
          (loom/feature/buffer-menu:list-buffers)
          (expect (window-tree-windows tree) :to-equal (list upper lower))
          (expect (window-tree-selected-window tree) :to-be upper)
          (expect (window-buffer lower) :to-be (%buffer-menu-list-buffer))
          (loom/feature/buffer-menu:list-buffers)
          (expect (window-buffer lower) :to-be (%buffer-menu-list-buffer))
          (expect (window-buffer upper) :to-be a)
          (loom/core/window-tree:window-tree-select-index tree 1)
          (loom/feature/buffer-menu:buffer-menu-quit)
          (expect (window-tree-windows tree) :to-equal (list upper lower))
          (expect (window-buffer lower) :to-be b)))))

  (it
    "q shows the origin buffer when the created window is the only one left"
    (%with-minibuffer-state (minibuffer "")
      (let ((tree (editor-state-window-tree *editor-state*))
            (a (make-buffer :name "a.txt" :initial-content "alpha")))
        (%buffer-menu-register (list a))
        (loom/feature/buffer-menu:list-buffers)
        (%buffer-menu-select-list-window)
        (loom/core/window-tree:window-delete-other-windows
         tree (window-tree-selected-window tree))
        (loom/feature/buffer-menu:buffer-menu-quit)
        (expect (length (window-tree-windows tree)) :to-equal 1)
        (expect (window-buffer (window-tree-selected-window tree)) :to-be a)))))

(describe
  "buffer menu marks and motion"
  (it
    "moves within the listed lines and replaces a line's mark with the later one"
    (%with-minibuffer-state (minibuffer "")
      (let ((a (make-buffer :name "a.txt" :initial-content "alpha"))
            (b (make-buffer :name "b.txt" :initial-content "bravo")))
        (%buffer-menu-register (list a b))
        (loom/feature/buffer-menu:list-buffers)
        (%buffer-menu-select-list-window)
        (loom/feature/buffer-menu:buffer-menu-previous-line)
        (expect (%buffer-menu-point-line) :to-equal 0)
        (loom/feature/buffer-menu:buffer-menu-delete)
        (expect (char (first (%buffer-menu-lines)) 0) :to-equal #\D)
        (expect (%buffer-menu-point-line) :to-equal 1)
        (loom/feature/buffer-menu:buffer-menu-previous-line)
        (loom/feature/buffer-menu:buffer-menu-save)
        (expect (first (%buffer-menu-lines))
                :to-equal "S .   a.txt         5 Fundamental")
        (expect (char (second (%buffer-menu-lines)) 0) :to-equal #\Space)
        (expect (%buffer-menu-point-line) :to-equal 1)
        (loom/feature/buffer-menu:buffer-menu-previous-line)
        (loom/feature/buffer-menu:buffer-menu-unmark)
        (expect (char (first (%buffer-menu-lines)) 0) :to-equal #\Space)
        (loom/feature/buffer-menu:buffer-menu-next-line)
        (loom/feature/buffer-menu:buffer-menu-next-line)
        (expect (%buffer-menu-point-line) :to-equal 2)
        (expect (loom/core/buffer:buffer-modified-p (%buffer-menu-list-buffer))
                :to-be nil))))

  (it
    "g rebuilds the list, keeping surviving marks and point on the same buffer"
    (%with-minibuffer-state (minibuffer "")
      (let ((a (make-buffer :name "a.txt" :initial-content "alpha"))
            (b (make-buffer :name "b.txt" :initial-content "bravo"))
            (c (make-buffer :name "c.txt" :initial-content "charlie")))
        (%buffer-menu-register (list a b c))
        (loom/feature/buffer-menu:list-buffers)
        (%buffer-menu-select-list-window)
        (loom/feature/buffer-menu:buffer-menu-next-line)
        (loom/feature/buffer-menu:buffer-menu-delete)
        (loom/feature/buffer-menu:buffer-menu-save)
        (loom/feature/buffers:kill-buffer-with-confirmation a)
        (loom/feature/buffer-menu:buffer-menu-revert)
        (expect (mapcar (lambda (line) (subseq line 0 11)) (%buffer-menu-lines))
                :to-equal (list "D     b.txt" "S     c.txt" "   %  *Buff"))
        (expect (%buffer-menu-point-line) :to-equal 2)))))

(describe
  "buffer menu display commands"
  (it
    "RET shows the line's buffer in the selected window"
    (%with-minibuffer-state (minibuffer "")
      (let ((tree (editor-state-window-tree *editor-state*))
            (a (make-buffer :name "a.txt" :initial-content "alpha"))
            (b (make-buffer :name "b.txt" :initial-content "bravo")))
        (%buffer-menu-register (list a b))
        (loom/feature/buffer-menu:list-buffers)
        (%buffer-menu-select-list-window)
        (let ((list-window (window-tree-selected-window tree)))
          (loom/feature/buffer-menu:buffer-menu-next-line)
          (loom/feature/buffer-menu:buffer-menu-this-window)
          (expect (window-tree-selected-window tree) :to-be list-window)
          (expect (window-buffer list-window) :to-be b)))))

  (it
    "o shows the line's buffer in another window, splitting a sole window, and selects it"
    (%with-minibuffer-state (minibuffer "")
      (let ((tree (editor-state-window-tree *editor-state*))
            (a (make-buffer :name "a.txt" :initial-content "alpha"))
            (b (make-buffer :name "b.txt" :initial-content "bravo")))
        (%buffer-menu-register (list a b))
        (loom/feature/buffer-menu:list-buffers)
        (%buffer-menu-select-list-window)
        (loom/feature/buffer-menu:buffer-menu-next-line)
        (loom/feature/buffer-menu:buffer-menu-other-window)
        (expect (window-buffer (window-tree-selected-window tree)) :to-be b)
        (expect (length (window-tree-windows tree)) :to-equal 2)
        (%buffer-menu-select-list-window)
        (loom/core/window-tree:window-delete-other-windows
         tree (window-tree-selected-window tree))
        (loom/feature/buffer-menu:buffer-menu-other-window)
        (expect (length (window-tree-windows tree)) :to-equal 2)
        (expect (window-buffer (window-tree-selected-window tree)) :to-be b)
        (expect (window-buffer (first (window-tree-windows tree)))
                :to-be (%buffer-menu-list-buffer))))))

(describe
  "buffer menu x"
  (it
    "saves S lines, kills D lines, clears their marks, and rebuilds the list"
    (host-kit:with-temporary-directory (dir)
      (let ((save-path (merge-pathnames "save.txt" dir))
            (kill-path (merge-pathnames "kill.txt" dir)))
        (host-kit:write-file-string "save" save-path)
        (host-kit:write-file-string "kill" kill-path)
        (%with-minibuffer-state (minibuffer "")
          (let ((save (loom/feature/files:visit-file save-path))
                (kill (loom/feature/files:visit-file kill-path))
                (loom/feature/files::*loom-backup-directory*
                  (merge-pathnames "backups/" dir)))
            (%buffer-menu-register (list save kill))
            (buffer-insert-string save "!")
            (loom/feature/buffer-menu:list-buffers)
            (%buffer-menu-select-list-window)
            (loom/feature/buffer-menu:buffer-menu-save)
            (loom/feature/buffer-menu:buffer-menu-delete)
            (loom/feature/buffer-menu:buffer-menu-execute)
            (expect (host-kit:read-file-string save-path) :to-equal "!save")
            (expect (%buffer-menu-live-p kill) :to-be nil)
            (expect (loom:minibuffer-message-string minibuffer)
                    :to-equal "Killed kill.txt")
            (expect (mapcar (lambda (line) (subseq line 0 14)) (%buffer-menu-lines))
                    :to-equal (list "  .   save.txt" "   %  *Buffer ")))))))

  (it
    "stops at a cancelled save, killing nothing and keeping every mark"
    (host-kit:with-temporary-directory (dir)
      (let ((save-path (merge-pathnames "save.txt" dir))
            (kill-path (merge-pathnames "kill.txt" dir)))
        (host-kit:write-file-string "save" save-path)
        (host-kit:write-file-string "kill" kill-path)
        (%with-minibuffer-state (minibuffer "")
          (let ((save (loom/feature/files:visit-file save-path))
                (kill (loom/feature/files:visit-file kill-path)))
            (%buffer-menu-register (list save kill))
            (buffer-insert-string save "!")
            (host-kit:write-file-string "external" save-path)
            (loom/feature/buffer-menu:list-buffers)
            (%buffer-menu-select-list-window)
            (loom/feature/buffer-menu:buffer-menu-save)
            (loom/feature/buffer-menu:buffer-menu-delete)
            (loom/feature/buffer-menu:buffer-menu-execute)
            (expect (minibuffer-prompt-string minibuffer)
                    :to-equal
                    (format nil "File changed on disk. Overwrite? (y/n): ~A"
                            (loom/core/buffer:buffer-path save)))
            (minibuffer-handle-key minibuffer (%special-key :control-g))
            (expect (loom:minibuffer-message-string minibuffer) :to-equal "Quit")
            (expect (%buffer-menu-live-p kill) :to-be-truthy)
            (expect (host-kit:read-file-string save-path) :to-equal "external")
            (expect (mapcar (lambda (line) (char line 0)) (%buffer-menu-lines))
                    :to-equal (list #\S #\D #\Space)))))))

  (it
    "keeps the S mark after n and continues to the D lines"
    (host-kit:with-temporary-directory (dir)
      (let ((save-path (merge-pathnames "save.txt" dir))
            (kill-path (merge-pathnames "kill.txt" dir)))
        (host-kit:write-file-string "save" save-path)
        (host-kit:write-file-string "kill" kill-path)
        (%with-minibuffer-state (minibuffer "")
          (let ((save (loom/feature/files:visit-file save-path))
                (kill (loom/feature/files:visit-file kill-path)))
            (%buffer-menu-register (list save kill))
            (buffer-insert-string save "!")
            (host-kit:write-file-string "external" save-path)
            (loom/feature/buffer-menu:list-buffers)
            (%buffer-menu-select-list-window)
            (loom/feature/buffer-menu:buffer-menu-save)
            (loom/feature/buffer-menu:buffer-menu-delete)
            (loom/feature/buffer-menu:buffer-menu-execute)
            (%confirm-minibuffer minibuffer "n")
            (expect (%buffer-menu-live-p kill) :to-be nil)
            (expect (host-kit:read-file-string save-path) :to-equal "external")
            (expect (mapcar (lambda (line) (char line 0)) (%buffer-menu-lines))
                    :to-equal (list #\S #\Space)))))))

  (it
    "stops when a modified D buffer's kill is cancelled"
    (%with-minibuffer-state (minibuffer "")
      (let ((a (make-buffer :name "a.txt" :initial-content "alpha"))
            (b (make-buffer :name "b.txt" :initial-content "bravo")))
        (%buffer-menu-register (list a b))
        (buffer-insert-string a "!")
        (loom/feature/buffer-menu:list-buffers)
        (%buffer-menu-select-list-window)
        (loom/feature/buffer-menu:buffer-menu-delete)
        (loom/feature/buffer-menu:buffer-menu-delete)
        (loom/feature/buffer-menu:buffer-menu-execute)
        (%expect-minibuffer-prompt minibuffer (%discard-buffer-prompt-string a))
        (%confirm-minibuffer minibuffer "c")
        (expect (%buffer-menu-live-p a) :to-be-truthy)
        (expect (%buffer-menu-live-p b) :to-be-truthy)
        (expect (mapcar (lambda (line) (char line 0)) (%buffer-menu-lines))
                :to-equal (list #\D #\D #\Space)))))

  (it
    "skips a D mark on the buffer list itself"
    (%with-minibuffer-state (minibuffer "")
      (let ((a (make-buffer :name "a.txt" :initial-content "alpha")))
        (%buffer-menu-register (list a))
        (loom/feature/buffer-menu:list-buffers)
        (%buffer-menu-select-list-window)
        (loom/feature/buffer-menu:buffer-menu-next-line)
        (loom/feature/buffer-menu:buffer-menu-delete)
        (loom/feature/buffer-menu:buffer-menu-execute)
        (expect (%buffer-menu-live-p (%buffer-menu-list-buffer)) :to-be-truthy)
        (expect (%buffer-menu-live-p a) :to-be-truthy)))))

(describe
  "buffer menu key-input hook"
  (it
    "runs plain letters bound in the list but leaves prefix continuations to the keymap"
    (%with-minibuffer-state (minibuffer "")
      (let* ((a (make-buffer :name "a.txt" :initial-content "alpha"))
             (b (make-buffer :name "b.txt" :initial-content "bravo"))
             (session (loom/core/editor-session:editor-state-session *editor-state*))
             (control-x (cl-tty-kit:make-key-event
                         :type :character :code #\x :modifiers '(:control))))
        (%buffer-menu-register (list a b))
        (flet ((hook (event)
                 (loom/feature/buffer-menu::%buffer-menu-key-input-hook
                  session event :key)))
          (expect (hook (%char-key #\n)) :to-equal :pass)
          (loom/feature/buffer-menu:list-buffers)
          (%buffer-menu-select-list-window)
          (expect (hook (%char-key #\n)) :to-equal :handled)
          (expect (%buffer-menu-point-line) :to-equal 1)
          (expect (hook (%char-key #\z)) :to-equal :pass)
          (expect (hook control-x) :to-equal :pass)
          (expect (hook (%char-key #\o)) :to-equal :pass)
          (expect (%buffer-menu-point-line) :to-equal 1)
          (expect (hook (%char-key #\p)) :to-equal :handled)
          (expect (%buffer-menu-point-line) :to-equal 0)
          (loom/feature/files:find-file)
          (expect (hook (%char-key #\n)) :to-equal :pass)
          (expect (%buffer-menu-point-line) :to-equal 0))))))
