(in-package #:loom/test)

(progn
  (defun %keymap-bound-command-ids (keymap)
    (let ((ids '()))
      (labels ((walk (table)
                 (maphash (lambda (descriptor value)
                            (declare (ignore descriptor))
                            (if (hash-table-p value)
                                (walk value)
                                (pushnew value ids :test #'equal)))
                          table)))
        (walk (loom/core/command::keymap-table keymap)))
      ids)))

(describe
  "keybinding / M-x registry consistency"
  (it "resolves every keybound ID to a registered command and M-x name"
    (let* ((keymap (make-keymap))
           (ids (progn
                  (loom/core/command:install-default-keybindings keymap)
                  (%keymap-bound-command-ids keymap)))
           (names (loom/core/command:command-completion-names "")))
      (expect (remove-if #'loom/core/command:find-command-spec ids)
              :to-equal nil)
      (expect (remove-if
               (lambda (id)
                 (let ((spec (loom/core/command:find-command-spec id)))
                   (or (null (loom/core/command:command-spec-name spec))
                       (member (loom/core/command:command-spec-name spec)
                               names
                               :test #'string-equal))))
               ids)
              :to-equal nil)))
  (it "keeps execute-extended-command registered by ID but out of M-x names"
    (let* ((keymap (make-keymap))
           (spec (loom/core/command:find-command-spec
                  "execute-extended-command")))
      (loom/core/command:install-default-keybindings keymap)
      (expect (loom/core/command:command-spec-id spec)
              :to-equal "execute-extended-command")
      (expect (loom/core/command:command-spec-name spec) :to-be nil)
      (expect (loom/core/command:find-extended-command-spec
               "execute-extended-command")
              :to-be nil)
      (expect (member "execute-extended-command"
                      (loom/core/command:command-completion-names ""))
              :to-be nil)
      (expect (%keymap-bound-command-ids keymap)
              :to-contain "execute-extended-command")))
  (it "binds page keys to the Emacs scroll directions"
    (let ((keymap (make-keymap)))
      (loom/core/command:install-default-keybindings keymap)
      (expect (keymap-lookup keymap (list :page-up))
              :to-equal "scroll-down-command")
      (expect (keymap-lookup keymap (list :page-down))
              :to-equal "scroll-up-command"))))
