(in-package #:loom/test)
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
  "define-command-specs macroexpansion"
  (it "emits only the explicit command registry"
    (let ((expansion
            (macroexpand-1
             (quote
               (loom::define-command-specs
                 (loom::command-spec "forward-char" forward-char)
                 (loom::command-spec "kill-line" kill-line))))))
      (expect (first expansion) :to-equal (quote progn))
      (expect (first (second expansion)) :to-equal (quote defparameter))
      (expect (second (second expansion))
              :to-equal
              (quote loom::*command-specs*))
      (expect (third (second expansion))
              :to-equal
              (quote
                (list
                  (list :name "forward-char"
                        :command (quote forward-char)
                        :keys (quote nil))
                  (list :name "kill-line"
                        :command (quote kill-line)
                        :keys (quote nil)))))
      (expect (third expansion) :to-be nil))))
(describe
  "command-spec validation"
  (it "accepts a valid command-spec command"
    (let ((expansion
            (macroexpand-1
             '(loom::command-spec "forward-char" forward-char))))
      (expect (first expansion) :to-be 'list)
      (expect (getf (rest expansion) :name) :to-equal "forward-char")
      (expect (getf (rest expansion) :command)
              :to-equal
              (quote (quote forward-char)))))
  (it "rejects a non-string command-spec name"
    (signals error
      (macroexpand-1 '(loom::command-spec 42 forward-char))))
  (it "rejects a non-symbol command-spec command"
    (signals error
      (macroexpand-1 '(loom::command-spec "forward-char" 42))))
  (it "rejects a non-command-spec registry entry"
    (signals error
      (macroexpand-1 '(loom::define-command-specs (not-a-command-spec)))))
  (it "rejects an atom registry entry"
    (signals error
      (macroexpand-1 '(loom::define-command-specs 42))))
  (it "rejects a non-string registry name"
    (signals error
      (macroexpand-1
       '(loom::define-command-specs
          (loom::command-spec 42 forward-char)))))
  (it "rejects a non-symbol registry command"
    (signals error
      (macroexpand-1
       '(loom::define-command-specs
          (loom::command-spec "forward-char" 42)))))
  (it "rejects duplicate registry names case-insensitively"
    (signals error
      (macroexpand-1
       '(loom::define-command-specs
          (loom::command-spec "forward-char" forward-char)
          (loom::command-spec "FORWARD-CHAR" backward-char))))))
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
    (it "resolves a registered command through the command-spec registry"
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
    "The keybound command EXECUTE-EXTENDED-COMMAND deliberately does not
register in the COMMAND-SPEC table for M-x. It *is* the M-x prompt, so an
\"M-x execute-extended-command\" would do nothing but reopen the prompt the
user is already answering. Anything else missing from the registry is an
oversight, which is what the spec below fails on.")

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
in real use in the COMMAND-SPEC table: a command whose Lisp name is free to
be the user-facing one registers under it verbatim
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
  "file-tree commands"
  (it
    "toggle-file-tree flips the sidebar's visibility"
    (let ((*editor-state* (%fresh-editor-state "")))
      (setf (editor-state-file-tree *editor-state*) (make-file-tree "/root/"))
      (expect (file-tree-visible-p (editor-state-file-tree *editor-state*)) :to-be-falsy)
      (loom::toggle-file-tree)
      (expect (file-tree-visible-p (editor-state-file-tree *editor-state*)) :to-be-truthy)))

  (it
    "invalidates the file-tree runtime cache after a path mutation"
    (let ((runtime
            (loom::make-loom-concurrent-runtime
             :directory-lister
             (lambda (path)
               (declare (ignore path))
               nil))))
      (unwind-protect
           (let* ((*editor-state* (%fresh-editor-state ""))
                  (path "/root/child/file.txt")
                  (parent "/root/child/")
                  (entries '(("/root/child/file.txt" . :file))))
             (setf (editor-state-concurrent-runtime *editor-state*) runtime)
             (loom::loom-concurrent-runtime-prime-directory runtime parent entries)
             (loom::loom-concurrent-runtime-prime-directory runtime path entries)
             (loom::%invalidate-file-tree-path path)
             (multiple-value-bind (cached present-p)
                 (loom::loom-concurrent-runtime-directory-entries runtime parent)
               (declare (ignore cached))
               (expect present-p :to-be nil))
             (multiple-value-bind (cached present-p)
                 (loom::loom-concurrent-runtime-directory-entries runtime path)
               (declare (ignore cached))
               (expect present-p :to-be nil)))
        (ignore-errors
          (loom::loom-concurrent-runtime-shutdown runtime)))))

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
        (expect (buffer-name (%selected-test-buffer)) :to-equal "note.txt")
        (expect (member (%selected-test-buffer)
                        (editor-state-buffers *editor-state*))
                :to-be-truthy))))

  (it
    "file-tree-open-selected does nothing when no entry is selected"
    (let ((*editor-state* (%fresh-editor-state "")))
      (setf (editor-state-file-tree *editor-state*) (make-file-tree "/root/"))
      (expect (loom::file-tree-open-selected) :to-be nil)))

  (it
    "file-tree-open-selected reports an entry that disappeared"
    (let ((*editor-state* (%fresh-editor-state ""))
          (tree (make-file-tree "/root/")))
      (setf (editor-state-file-tree *editor-state*) tree
            (loom::file-tree-selection tree) "/root/vanished.txt")
      (with-replaced-function
          (file-tree-entry-kind
           (lambda (tree path)
             (declare (ignore tree path))
             nil))
        (signals error (loom::file-tree-open-selected)))))

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
