(in-package #:loom/test)

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
          (list full)))))

(describe
  "keybinding / M-x registry consistency"
  (it
    "resolves every keybound command through %find-extended-command"
    (let ((keymap (make-keymap)))
      (loom/application:install-default-keybindings keymap)
      (expect (remove-if
               (lambda (command)
                 (or (member command +m-x-exempt-commands+)
                     (some (lambda (name)
                             (eq (loom/application:find-extended-command name) command))
                           (%extended-command-names command))))
               (%keymap-bound-commands keymap))
              :to-equal (list))))
  (it
    "exempts execute-extended-command, which is itself the M-x prompt"
    (let ((keymap (make-keymap)))
      (loom/application:install-default-keybindings keymap)
      (expect (%keymap-bound-commands keymap)
              :to-contain (quote loom::execute-extended-command)))
    (expect (loom/application:find-extended-command "execute-extended-command") :to-be nil)
    (expect (loom/application:find-extended-command "execute-extended") :to-be nil)))
