(in-package #:loom/test)

(describe
  "search result list API"
  (it "exports the result item type, constructor, and accessors"
    (multiple-value-bind (symbol status)
        (find-symbol "RESULT-ITEM" "LOOM/FEATURE/SEARCH")
      (expect symbol :to-be-truthy)
      (expect status :to-equal :external))
    (dolist (name
             (list "RESULT-ITEM-P"
                   "MAKE-RESULT-ITEM"
                   "RESULT-ITEM-FILE-PATH"
                   "RESULT-ITEM-LINE"
                   "RESULT-ITEM-COLUMN"
                   "RESULT-ITEM-DISPLAY-TEXT"))
      (multiple-value-bind (symbol status)
          (find-symbol name "LOOM/FEATURE/SEARCH")
        (expect status :to-equal :external)
        (expect (and symbol (fboundp symbol)) :to-be-truthy))))
  (it "publishes formatted rows into result buffers owned by each session"
    (let* ((session-a
             (loom/core/editor-session:make-editor-session
              (list :feature/buffers :feature/search)))
           (session-b
             (loom/core/editor-session:make-editor-session
              (list :feature/buffers :feature/search)))
           (first-item
             (loom/feature/search::make-result-item
              "source.lisp" 0 4 "alpha"))
           (second-item
             (loom/feature/search::make-result-item
              "source.lisp" 2 1 "omega"))
           (other-item
             (loom/feature/search::make-result-item
              "other.lisp" 1 0 "beta"))
           (first-list
             (loom/feature/search::publish-result-list
              session-a "*Search Results*" (list first-item second-item)))
           (second-list
             (loom/feature/search::publish-result-list
              session-b "*Search Results*" (list other-item))))
      (expect (loom/feature/search::result-item-file-path first-item)
              :to-equal "source.lisp")
      (expect (loom/feature/search::result-item-line second-item)
              :to-equal 2)
      (expect (loom/feature/search::result-item-column second-item)
              :to-equal 1)
      (expect (loom/feature/search::result-item-display-text second-item)
              :to-equal "omega")
      (expect (buffer-text first-list)
              :to-equal
              (format nil "source.lisp:1:5: alpha~%source.lisp:3:2: omega"))
      (expect (buffer-text second-list) :to-equal "other.lisp:2:1: beta")
      (expect (eq first-list second-list) :to-be nil)
      (expect (loom/feature/buffers:find-buffer-by-name
               session-a "*Search Results*")
              :to-be
              first-list)))
  ;; GNU Emacs Manual, "Compilation Mode", documents M-g n/p navigation from any buffer:
  ;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Compilation-Mode.html
  (it "navigates from result and source buffers and reuses file buffers by path"
    (host-kit:with-temporary-directory (directory)
      (let* ((path (merge-pathnames "source.lisp" directory))
             (contents (format nil "zero~%one~%two"))
             (source (make-buffer :name "origin"))
             (tree (make-window-tree source 80 24))
             (session
               (loom/core/editor-session:make-editor-session
                (list :core/window-tree :feature/buffers :feature/search :feature/workspace :feature/keyboard-macro)
                :initial-slices (list (cons :core/window-tree tree))))
             (*editor-state*
               (make-editor-state
                :session session
                :window-tree tree
                :minibuffer (make-minibuffer)
                :keymap (make-keymap)
                :file-tree nil
                :renderer nil
                :kill-ring nil))
             (loom/core/editor-session:*editor-session* session)
             (window
               (loom/core/window-tree:window-tree-selected-window tree)))
        (host-kit:write-file-string contents path)
        (let ((result-buffer
                (loom/feature/search::publish-result-list
                 session
                 "*Search Results*"
                 (list
                  (loom/feature/search::make-result-item path 0 2 "zero")
                  (loom/feature/search::make-result-item path 1 3 "one")
                  (loom/feature/search::make-result-item path 2 1 "two")))))
          (loom/core/window-tree:window-set-buffer window result-buffer)
          (loom/feature/search::next-error)
          (let ((source-buffer
                  (loom/core/window-tree:window-buffer window)))
            (expect (loom/core/buffer:buffer-path source-buffer) :to-equal path)
            (expect source-buffer :to-have-point (cons 0 2))
            (loom/feature/search::next-error)
            (expect source-buffer :to-have-point (cons 1 3))
            (loom/feature/search::previous-error)
            (expect source-buffer :to-have-point (cons 0 2))
            (loom/core/window-tree:window-set-buffer window result-buffer)
            (buffer-set-point result-buffer 2 0)
            (loom/feature/search::search-result-visit)
            (expect (loom/core/window-tree:window-buffer window)
                    :to-be
                    source-buffer)
            (expect source-buffer :to-have-point (cons 2 1)))))))
  (it "binds next-error commands globally and RET in the result mode"
    (let* ((global-keymap
             (loom/application:install-default-keybindings
              (loom/core/command:make-keymap)))
           (result-keymap
             (loom/feature/mode:major-mode-keymap
              :loom-search-results global-keymap)))
      (multiple-value-bind (command-id owner)
          (loom/core/command:keymap-lookup
           global-keymap
           (loom/core/command:defkeys-key-sequence
            (list (list :alt #\g) #\n)))
        (declare (ignore owner))
        (expect command-id :to-equal "search-next-error"))
      (multiple-value-bind (command-id owner)
          (loom/core/command:keymap-lookup
           global-keymap
           (loom/core/command:defkeys-key-sequence
            (list (list :alt #\g) #\p)))
        (declare (ignore owner))
        (expect command-id :to-equal "search-previous-error"))
      (multiple-value-bind (command-id owner)
          (loom/core/command:keymap-lookup
           result-keymap
           (loom/core/command:defkeys-key-sequence :enter))
        (expect command-id :to-equal "search-result-visit")
        (expect owner :to-be result-keymap)))))
