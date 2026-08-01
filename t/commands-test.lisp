;;;; t/commands-test.lisp
;;;;
;;;; Application layer: the command protocol (src/application/commands.lisp).
;;;; A representative sample, not one test per command: movement clamping at
;;;; buffer boundaries, a kill-line/yank round trip, UNDO-COMMAND actually
;;;; undoing, and INSTALL-DEFAULT-KEYBINDINGS's C-x C-s binding. Each test
;;;; binds a fresh *EDITOR-STATE* around real domain objects (MAKE-BUFFER,
;;;; MAKE-WINDOW-TREE, MAKE-KEYMAP); MINIBUFFER/FILE-TREE/RENDERER are left
;;;; NIL since none of the commands exercised here touch them. Commands are
;;;; not exported from the LOOM package (see commands.lisp's header comment),
;;;; so tests reach them via LOOM:: qualification, the same precedent
;;;; t/file-tree-test.lisp already set for LOOM::FILE-TREE-CHILD-LISTER.
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
    "move-end-of-line then move-beginning-of-line round-trips point"
    (let ((*editor-state* (%fresh-editor-state "hello")))
      (let ((buffer (%selected-test-buffer)))
        (loom::move-end-of-line)
        (expect (buffer-point-column buffer) :to-equal 5)
        (loom::move-beginning-of-line)
        (expect (buffer-point-column buffer) :to-equal 0)))))

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
  (it
    "binds C-x C-s to save-buffer"
    (let ((keymap (make-keymap)))
      (loom::install-default-keybindings keymap)
      (expect (keymap-lookup keymap (list (cons '(:control) #\x) (cons '(:control) #\s)))
              :to-be 'loom::save-buffer)))

  (it
    "binds C-x 2 to split-window-below and C-g to keyboard-quit"
    (let ((keymap (make-keymap)))
      (loom::install-default-keybindings keymap)
      (expect (keymap-lookup keymap (list (cons '(:control) #\x) (cons nil #\2)))
              :to-be 'loom::split-window-below)
      (expect (keymap-lookup keymap (list (cons '(:control) #\g)))
              :to-be 'loom::keyboard-quit))))

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
        (loom::save-buffer)
        ;; SAVE-BUFFER's path-less branch activated MINIBUFFER above rather
        ;; than saving directly; drive its stored ON-CONFIRM callback
        ;; ourselves with a path under a fresh temp directory, exactly as
        ;; MINIBUFFER-HANDLE-KEY would on RET.
        (funcall (loom::%minibuffer-on-confirm minibuffer)
                 (merge-pathnames "new-save.txt" dir))
        (let ((new-buffer (window-buffer (window-tree-selected-window tree))))
          (expect (buffer-point-line new-buffer) :to-equal 0)
          (expect (buffer-point-column new-buffer) :to-equal 5))))))

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
