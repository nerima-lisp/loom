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
              :to-equal "scroll-up-command")))
  (it "matches the effective global bindings in the Emacs keymap reference"
      (load (asdf:system-relative-pathname
             "loom-core-command" "t/emacs-keymap-reference.lisp"))
      (let* ((reference
              (symbol-value (find-symbol "*EMACS-KEYMAP-REFERENCE*" "LOOM/TEST")))
             (ids (mapcar (lambda (row) (getf row :id)) reference))
             (expected-ids
              (list
               "undo-control-slash" "undo-control-underscore" "undo-control-x-u"
               "redo-control-meta-underscore" "backward-char-left" "forward-char-right"
               "previous-line-up" "next-line-down" "beginning-of-line-home" "end-of-line-end"
               "scroll-down-page-up" "scroll-up-page-down" "delete-char-delete"
               "undo-legacy-control-x-control-u" "redo-legacy-control-x-control-y"
               "recenter-control-l" "transpose-control-t" "upcase-word-meta-u"
               "downcase-word-meta-l" "capitalize-word-meta-c" "fill-paragraph-meta-q"
               "indent-region-control-meta-backslash" "delete-indentation-meta-caret"
               "goto-line-meta-g-meta-g"
               "goto-line-meta-g-plain-g" "list-buffers-control-x-control-b"
               "save-some-buffers-control-x-s" "eval-last-sexp-control-x-control-e"
               "eval-buffer-m-x" "file-tree-legacy-control-x-control-t" "file-tree-control-x-d"
               "list-bookmarks-control-x-r-l" "load-session-m-x" "file-tree-next-local"
               "file-tree-previous-local" "file-tree-open-local" "file-tree-create-file-local"
               "file-tree-create-directory-local" "paredit-forward-slurp-local"
               "paredit-forward-barf-local" "paredit-backward-slurp-local"
               "paredit-backward-barf-local" "paredit-wrap-meta-open" "paredit-splice-meta-s"
               "paredit-raise-meta-r" "suspend-frame-control-z")))
        (expect (sort (copy-list ids) (lambda (a b) (string< a b)))
                :to-equal
                (sort (copy-list expected-ids) (lambda (a b) (string< a b))))
        (let ((keymap (make-keymap)))
          (loom/core/command:install-default-keybindings keymap)
          (dolist (row reference)
            (let* ((effective (getf row :effective))
                   (status (getf row :status))
                   (owner (getf row :owner))
                   (target (getf row :target))
                   (target-map (getf row :target-map))
                   (sequence (or (getf row :target-keys)
                                 (getf row :keys))))
              (expect target :to-be-truthy)
              (expect target-map :to-be-truthy)
              (cond
                ((equal target-map :mode-provider)
                 (expect (equal owner :w3-7a) :to-be-truthy)
                 (expect (equal status :implemented) :to-be-truthy)
                 (expect (equal target "indent-for-tab-command")
                         :to-be-truthy)
                 (expect (equal effective "indent-for-tab-command")
                         :to-be-truthy))
                ((equal effective :not-asserted)
                 (progn
                   (expect (equal status :pending) :to-be-truthy)
                   (expect owner :to-be-truthy)
                   (expect (or sequence (equal target-map :extended-command))
                           :to-be-truthy)))
                (t
                 (progn
                   (expect (equal owner :w3-1) :to-be-truthy)
                   (expect (equal target-map :global) :to-be-truthy)
                   (expect (or (equal status :implemented)
                               (equal status :removed))
                           :to-be-truthy)
                   (expect (if (equal target :unbound) nil target)
                           :to-equal effective)
                   (expect (keymap-lookup keymap sequence)
                           :to-equal effective))))))))))
