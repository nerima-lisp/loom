;;;; t/integration/session-test.lisp
;;;;
;;;; Session persistence tests cover the pure snapshot/store boundary and the
;;;; application round-trip that rebuilds buffers and window layout.
(in-package #:loom/test)

(defun %session-test-workspace (&key (name "main")
                                      (layout '(:leaf 0 0))
                                      (selected-window-index 0))
  (make-session-workspace-snapshot
   :name name
   :layout layout
   :selected-window-index selected-window-index))

(defun %session-test-snapshot ()
  "Return a small snapshot with every persisted buffer field populated."
  (make-session-snapshot
   :buffers (list
             (make-session-buffer-snapshot
              :name "*scratch*"
              :path nil
              :text (format nil "one~%two")
              :point-line 1
              :point-column 2
              :mark-line 0
              :mark-column 1
              :modified-p t))
   :recent-files (list "one.lisp" "two.lisp")
   :bookmarks (list
               (make-session-bookmark-snapshot
                :name "spot"
                :path "one.lisp"
                :buffer-name "*scratch*"
                :line 1
                :column 2))
   :command-history (list "M-x find-file" "M-x")
   :workspaces (list (%session-test-workspace :layout '(:leaf 0 4)))
   :current-workspace-index 0))

(describe
  "session-store"
  (it
    "round-trips a validated snapshot through a versioned file"
    (host-kit:with-temporary-directory (directory)
      (let ((path (merge-pathnames "session.sexp" directory))
            (snapshot (%session-test-snapshot)))
        (expect (session-store-write path snapshot) :to-be snapshot)
        (expect (host-kit:path-exists-p path) :to-be-truthy)
        (let ((restored (session-store-read path)))
          (let ((workspace (first (session-snapshot-workspaces restored))))
            (expect (session-workspace-snapshot-layout workspace)
                    :to-equal '(:leaf 0 4))
            (expect (session-workspace-snapshot-selected-window-index workspace)
                    :to-equal 0)
            (expect (session-workspace-snapshot-name workspace)
                    :to-equal "main"))
          (expect (session-snapshot-current-workspace-index restored) :to-equal 0)
          (expect (session-snapshot-recent-files restored)
                  :to-equal '("one.lisp" "two.lisp"))
          (expect (session-snapshot-command-history restored)
                  :to-equal '("M-x find-file" "M-x"))
          (let ((bookmark (first (session-snapshot-bookmarks restored))))
            (expect (session-bookmark-snapshot-name bookmark)
                    :to-equal "spot")
            (expect (session-bookmark-snapshot-path bookmark)
                    :to-equal "one.lisp")
            (expect (session-bookmark-snapshot-line bookmark) :to-equal 1)
            (expect (session-bookmark-snapshot-column bookmark) :to-equal 2))
          (let ((buffer (first (session-snapshot-buffers restored))))
            (expect (session-buffer-snapshot-name buffer)
                    :to-equal "*scratch*")
            (expect (session-buffer-snapshot-text buffer)
                    :to-equal (format nil "one~%two"))
            (expect (session-buffer-snapshot-point-line buffer) :to-equal 1)
            (expect (session-buffer-snapshot-point-column buffer) :to-equal 2)
            (expect (session-buffer-snapshot-mark-line buffer) :to-equal 0)
            (expect (session-buffer-snapshot-mark-column buffer) :to-equal 1)
            (expect (session-buffer-snapshot-modified-p buffer)
                    :to-be-truthy)))))))

  (it
    "round-trips multiple named workspaces and their active view"
    (host-kit:with-temporary-directory (directory)
      (let* ((path (merge-pathnames "workspace-v5.sexp" directory))
             (buffer
               (make-session-buffer-snapshot
                :name "*workspace*"
                :path nil
                :text "text"
                :point-line 0
                :point-column 0
                :mark-line nil
                :mark-column nil
                :modified-p nil))
             (main
               (make-session-workspace-snapshot
                :name "main"
                :layout '(:leaf 0 2)
                :selected-window-index 0))
             (notes
               (make-session-workspace-snapshot
                :name "Notes"
                :layout '(:split :vertical (:leaf 0 1) (:leaf 0 3))
                :selected-window-index 1))
             (snapshot
               (make-session-snapshot
                :buffers (list buffer)
                :recent-files nil
                :bookmarks nil
                :command-history nil
                :workspaces (list main notes)
                :current-workspace-index 1)))
        (session-store-write path snapshot)
        (expect (search ":LOOM-SESSION 5"
                        (string-upcase (host-kit:read-file-string path)))
                :to-be-truthy)
        (let ((restored (session-store-read path)))
          (expect (mapcar #'session-workspace-snapshot-name
                          (session-snapshot-workspaces restored))
                  :to-equal '("main" "Notes"))
          (expect (session-snapshot-current-workspace-index restored) :to-equal 1)
          (let ((restored-notes (second (session-snapshot-workspaces restored))))
            (expect (session-workspace-snapshot-layout restored-notes)
                    :to-equal '(:split :vertical (:leaf 0 1) (:leaf 0 3)))
            (expect (session-workspace-snapshot-selected-window-index restored-notes)
                    :to-equal 1))))))

  (it
    "rejects reader evaluation and malformed session input"
    (host-kit:with-temporary-directory (directory)
      (let ((path (merge-pathnames "unsafe.sexp" directory)))
        (host-kit:write-file-string
         "(:loom-session 5 :buffers () :recent-files () :bookmarks () :command-history () :workspaces ((:name \"main\" :layout (:leaf 0 0) :selected-window-index 0)) :current-workspace-index 0 #.(list))"
         path)
        (signals error (session-store-read path)))))

  (it
    "removes the temporary file when atomic replacement fails"
    (host-kit:with-temporary-directory (directory)
      (let* ((path (merge-pathnames "session.sexp" directory))
             (temporary (merge-pathnames "session.sexp.tmp" directory))
             (snapshot (%session-test-snapshot)))
        (host-kit:write-file-string "previous session" path)
        (with-replaced-function
            (loom/feature/session::%session-temporary-path
             (lambda (target)
               (declare (ignore target))
               temporary))
          (with-replaced-function
              (loom/feature/session::%session-rename
               (lambda (old-path new-path)
                 (declare (ignore old-path new-path))
                 (error "replacement failed")))
            (signals error (session-store-write path snapshot))))
        (expect (probe-file temporary) :to-be nil)
        (expect (host-kit:read-file-string path) :to-equal "previous session"))))

  (it
    "accepts unmodified buffers without a mark"
    (let* ((buffer (make-session-buffer-snapshot
                    :name "*unmodified*"
                    :path "unmodified.txt"
                    :text ""
                    :point-line 0
                    :point-column 0
                    :mark-line nil
                    :mark-column nil
                    :modified-p nil))
           (snapshot (make-session-snapshot
                      :buffers (list buffer)
                      :recent-files nil
                      :bookmarks nil
                      :command-history nil
                      :workspaces (list (%session-test-workspace))
                      :current-workspace-index 0)))
      (expect (validate-session-snapshot snapshot) :to-be snapshot)))

  (it
    "rejects malformed snapshot envelopes and buffer values"
    (flet ((buffer (&key (name "*buffer*")
                         (path nil)
                         (text "text")
                         (point-line 0)
                         (point-column 0)
                         (mark-line nil)
                         (mark-column nil)
                         (modified-p nil))
             (make-session-buffer-snapshot
              :name name
              :path path
              :text text
              :point-line point-line
              :point-column point-column
              :mark-line mark-line
              :mark-column mark-column
              :modified-p modified-p)))
      (flet ((snapshot (value &key (recent-files nil)
                                      (bookmarks nil)
                                      (command-history nil)
                                      (layout '(:leaf 0 0))
                                      (selected-index 0))
               (make-session-snapshot
                :buffers (list value)
                :recent-files recent-files
                :bookmarks bookmarks
                :command-history command-history
                :workspaces (list (%session-test-workspace
                                   :layout layout
                                   :selected-window-index selected-index))
                :current-workspace-index 0)))
        (signals error (validate-session-snapshot nil))
        (signals error
                 (validate-session-snapshot
                  (make-session-snapshot
                   :buffers nil
                   :recent-files nil
                   :bookmarks nil
                   :command-history nil
                   :workspaces (list (%session-test-workspace))
                   :current-workspace-index 0)))
        (signals error
                 (validate-session-snapshot
                  (snapshot "not a buffer")))
        (signals error (validate-session-snapshot
                        (snapshot (buffer :name nil))))
        (signals error (validate-session-snapshot
                        (snapshot (buffer :path 42))))
        (signals error (validate-session-snapshot
                        (snapshot (buffer :text nil))))
        (signals error (validate-session-snapshot
                        (snapshot (buffer :point-line -1))))
        (signals error (validate-session-snapshot
                        (snapshot (buffer :point-column -1))))
        (signals error (validate-session-snapshot
                        (snapshot (buffer :mark-line 0))))
        (signals error (validate-session-snapshot
                        (snapshot (buffer :mark-line -1 :mark-column 0))))
        (signals error (validate-session-snapshot
                        (snapshot (buffer :modified-p :maybe))))
        (signals error
                 (validate-session-snapshot
                  (snapshot (buffer) :recent-files (list 42))))
        (signals error
                 (validate-session-snapshot
                  (snapshot
                   (buffer)
                   :bookmarks
                   (list (make-session-bookmark-snapshot
                          :name ""
                          :path nil
                          :buffer-name nil
                          :line 0
                          :column 0)))))
        (signals error
                 (validate-session-snapshot
                  (snapshot (buffer) :command-history (list "ok" 42)))))))

  (it
    "rejects malformed layouts and selected window indexes"
    (let ((buffer (make-session-buffer-snapshot
                   :name "*layout*"
                   :path nil
                   :text ""
                   :point-line 0
                   :point-column 0
                   :mark-line nil
                   :mark-column nil
                   :modified-p nil)))
      (flet ((snapshot (layout &optional (selected-index 0))
               (make-session-snapshot
                :buffers (list buffer)
                :recent-files nil
                :bookmarks nil
                :command-history nil
                :workspaces (list (%session-test-workspace
                                   :layout layout
                                   :selected-window-index selected-index))
                :current-workspace-index 0)))
        (signals error (validate-session-snapshot
                        (snapshot "not a list")))
        (signals error (validate-session-snapshot
                        (snapshot nil)))
        (signals error (validate-session-snapshot
                        (snapshot '(:leaf 0))))
        (signals error (validate-session-snapshot
                        (snapshot '(:leaf 1 0))))
        (signals error (validate-session-snapshot
                        (snapshot '(:leaf 0 -1))))
        (signals error (validate-session-snapshot
                        (snapshot '(:split :diagonal
                                    (:leaf 0 0)
                                    (:leaf 0 0)))))
        (signals error (validate-session-snapshot
                        (snapshot '(:split :horizontal (:leaf 0 0)))))
        (signals error (validate-session-snapshot
                        (snapshot '(:split :horizontal
                                    (:leaf 0 0)
                                    (:unknown)))))
        (signals error (validate-session-snapshot
                        (snapshot '(:split :horizontal
                                    42
                                    (:leaf 0 0)))))
        (signals error (validate-session-snapshot
                        (snapshot '(:leaf 0 0) -1)))
        (signals error (validate-session-snapshot
                        (snapshot '(:leaf 0 0) 1)))
        (signals error
                 (validate-session-snapshot
                  (make-session-snapshot
                   :buffers (list buffer)
                   :recent-files nil
                   :bookmarks nil
                   :command-history nil
                   :workspaces (list (%session-test-workspace
                                      :layout '(:split :horizontal
                                                (:leaf 0 0)
                                                (:leaf 0 0))
                                      :selected-window-index 2))
                   :current-workspace-index 0))))))

  (it
    "accepts only the canonical v5 envelope and rejects invalid plist shapes"
    (host-kit:with-temporary-directory (directory)
      (let* ((valid-buffer-form
               "(:name \"*x*\" :path nil :text \"\" :point-line 0 :point-column 0 :mark-line nil :mark-column nil :modified-p nil)")
             (valid-workspace-form
               "(:name \"main\" :layout (:leaf 0 0) :selected-window-index 0)")
             (valid-form
               (format nil
                       "(:loom-session 5 :buffers (~A) :recent-files () :bookmarks () :command-history () :workspaces (~A) :current-workspace-index 0)"
                       valid-buffer-form
                       valid-workspace-form)))
        (flet ((reject (name contents)
                 (let ((path (merge-pathnames name directory)))
                   (host-kit:write-file-string contents path)
                   (signals error (session-store-read path)))))
          (reject "empty.sexp" "")
          (dolist (version '(1 2 3 4 6))
            (reject (format nil "unsupported-version-~D.sexp" version)
                    (format nil
                            "(:loom-session ~D :buffers (~A) :recent-files () :bookmarks () :command-history () :workspaces (~A) :current-workspace-index 0)"
                            version
                            valid-buffer-form
                            valid-workspace-form)))
          (reject "bad-command-history.sexp"
                  (format nil
                          "(:loom-session 5 :buffers (~A) :recent-files () :bookmarks () :command-history (42) :workspaces (~A) :current-workspace-index 0)"
                          valid-buffer-form
                          valid-workspace-form))
          (reject "trailing.sexp"
                  (format nil "~A~%~A" valid-form valid-form))
          (reject "duplicate-field.sexp"
                  (format nil
                          "(:loom-session 5 :buffers (~A) :recent-files () :bookmarks () :command-history () :workspaces (~A) :current-workspace-index 0 :current-workspace-index 0)"
                          valid-buffer-form
                          valid-workspace-form))
          (reject "missing-field.sexp"
                  (format nil
                          "(:loom-session 5 :buffers (~A) :recent-files () :bookmarks () :command-history () :workspaces (~A)"
                          valid-buffer-form
                          valid-workspace-form))
          (reject "extra-field.sexp"
                  (format nil
                          "(:loom-session 5 :buffers (~A) :recent-files () :bookmarks () :command-history () :workspaces (~A) :current-workspace-index 0 :unexpected t)"
                          valid-buffer-form
                          valid-workspace-form))
          (reject "bad-buffers.sexp"
                  (format nil
                          "(:loom-session 5 :buffers \"not a list\" :recent-files () :bookmarks () :command-history () :workspaces (~A) :current-workspace-index 0)"
                          valid-workspace-form))
          (reject "bad-buffer-value.sexp"
                  (format nil
                          "(:loom-session 5 :buffers (42) :recent-files () :bookmarks () :command-history () :workspaces (~A) :current-workspace-index 0)"
                          valid-workspace-form))
          (reject "odd-buffer-plist.sexp"
                  (format nil
                          "(:loom-session 5 :buffers ((:name)) :recent-files () :bookmarks () :command-history () :workspaces (~A) :current-workspace-index 0)"
                          valid-workspace-form))
          (reject "non-keyword-buffer-plist.sexp"
                  (format nil
                          "(:loom-session 5 :buffers ((name \"*x*\")) :recent-files () :bookmarks () :command-history () :workspaces (~A) :current-workspace-index 0)"
                          valid-workspace-form))
          (reject "bad-buffer-fields.sexp"
                  (format nil
                          "(:loom-session 5 :buffers ((:name \"*x*\" :path nil :text \"\" :point-line 0 :point-column 0 :mark-line nil :mark-column nil :modified-p nil :modified-p nil)) :recent-files () :bookmarks () :command-history () :workspaces (~A) :current-workspace-index 0)"
                          valid-workspace-form))
          (reject "bad-workspace-value.sexp"
                  "(:loom-session 5 :buffers ((:name \"*x*\" :path nil :text \"\" :point-line 0 :point-column 0 :mark-line nil :mark-column nil :modified-p nil)) :recent-files () :bookmarks () :command-history () :workspaces (42) :current-workspace-index 0)")
          (reject "empty-buffers.sexp"
                  (format nil
                          "(:loom-session 5 :buffers () :recent-files () :bookmarks () :command-history () :workspaces (~A) :current-workspace-index 0)"
                          valid-workspace-form))))))

(describe
  "session application round-trip"
  (it
    "restores registered buffers, point, mark, modified state, scroll, and selection"
    (let* ((one (make-buffer :name "*one*" :initial-content "one"))
           (two (make-buffer
                 :name "*two*"
                 :path (pathname "two.txt")
                 :initial-content (format nil "two~%line")))
           (tree (make-window-tree one 20 8))
           (other (window-split tree
                                (window-tree-selected-window tree)
                                :vertical))
           (bookmarks (make-hash-table :test #'equal))
           (state (make-editor-state
                   :window-tree tree
                   :minibuffer (make-minibuffer
                                :history (history-kit:make-history))
                   :keymap (make-keymap)
                   :file-tree (make-file-tree "/root/")
                   :buffers (list one two)
                   :kill-ring nil
                   :recent-files (list "two.txt")
                   :bookmarks bookmarks)))
      (window-set-buffer other two)
      (setf (window-scroll-line other) 1)
      (buffer-set-point two 1 2)
      (buffer-set-mark two 0 1)
      (buffer-insert-string one "x")
      (setf (gethash "spot" bookmarks)
            (make-editor-bookmark
             :name "spot"
             :buffer two
             :path (buffer-path two)
             :buffer-name (buffer-name two)
             :line 1
             :column 2))
      (minibuffer-set-history-entries
       (editor-state-minibuffer state)
       '("find-file" "M-x"))
      (let ((*editor-state* state))
        (let ((snapshot (loom/feature/session::%session-snapshot-from-state)))
          (loom/feature/session::%restore-session-snapshot snapshot)
          (let* ((restored-buffers (editor-state-buffers *editor-state*))
                 (restored-one (find "*one*" restored-buffers
                                     :key #'buffer-name :test #'string=))
                 (restored-two (find "*two*" restored-buffers
                                     :key #'buffer-name :test #'string=))
                 (restored-tree (editor-state-window-tree *editor-state*))
                 (windows (window-tree-windows restored-tree)))
            (expect (length restored-buffers) :to-equal 2)
            (expect (length windows) :to-equal 2)
            (expect (window-tree-selected-index restored-tree) :to-equal 1)
            (expect (editor-state-recent-files *editor-state*)
                    :to-equal '("two.txt"))
            (expect (minibuffer-history-entries
                     (editor-state-minibuffer *editor-state*))
                    :to-equal '("find-file" "M-x"))
            (let ((bookmark (gethash "spot"
                                     (editor-state-bookmarks *editor-state*))))
              (expect bookmark :to-be-truthy)
              (expect (buffer-name (editor-bookmark-buffer bookmark))
                      :to-equal "*two*")
              (expect (editor-bookmark-line bookmark) :to-equal 1)
              (expect (editor-bookmark-column bookmark) :to-equal 2))
            (expect (buffer-text restored-one) :to-equal "xone")
            (expect (buffer-modified-p restored-one) :to-be-truthy)
            (expect (buffer-text restored-two)
                    :to-equal (format nil "two~%line"))
            (expect (buffer-path restored-two) :to-equal (pathname "two.txt"))
            (expect (buffer-point-line restored-two) :to-equal 1)
            (expect (buffer-point-column restored-two) :to-equal 2)
            (multiple-value-bind (mark-line mark-column)
                (buffer-mark restored-two)
              (expect mark-line :to-equal 0)
              (expect mark-column :to-equal 1))
            (expect (window-scroll-line (second windows)) :to-equal 1)))))))

  (it
    "restores every named workspace with its independent layout and active workspace"
    (let* ((main-buffer (make-buffer :name "*main-buffer*" :initial-content "main"))
           (notes-buffer (make-buffer :name "*notes-buffer*" :initial-content "notes"))
           (main-tree (make-window-tree main-buffer 20 8))
           (notes-tree (make-window-tree notes-buffer 20 8))
           (notes-second
             (window-split notes-tree
                           (window-tree-selected-window notes-tree)
                           :vertical))
           (manager
             (make-workspace-manager-from-workspaces
              (list (make-workspace :name "main" :window-tree main-tree)
                    (make-workspace :name "notes" :window-tree notes-tree))
              :current-index 1))
           (state
             (make-editor-state
              :window-tree notes-tree
              :workspaces manager
              :minibuffer (make-minibuffer)
              :keymap (make-keymap)
              :file-tree (make-file-tree "/root/")
              :buffers (list main-buffer notes-buffer)
              :kill-ring nil
              :recent-files nil
              :bookmarks nil)))
      (setf (window-scroll-line (first (window-tree-windows main-tree))) 2
            (window-scroll-line (first (window-tree-windows notes-tree))) 3
            (window-scroll-line notes-second) 4)
      (window-tree-select-index notes-tree 1)
      (let ((*editor-state* state))
        (let ((snapshot (loom/feature/session::%session-snapshot-from-state)))
          (expect (session-snapshot-current-workspace-index snapshot) :to-equal 1)
          (expect (mapcar #'session-workspace-snapshot-name
                          (session-snapshot-workspaces snapshot))
                  :to-equal '("main" "notes"))
          (loom/feature/session::%restore-session-snapshot snapshot)
          (let* ((restored-manager (editor-state-workspaces *editor-state*))
                 (restored-workspaces
                   (workspace-manager-workspaces restored-manager))
                 (restored-main (first restored-workspaces))
                 (restored-notes (second restored-workspaces))
                 (restored-main-tree (workspace-window-tree restored-main))
                 (restored-notes-tree (workspace-window-tree restored-notes))
                 (restored-notes-windows
                   (window-tree-windows restored-notes-tree)))
            (expect (length restored-workspaces) :to-equal 2)
            (expect (workspace-manager-current-index restored-manager) :to-equal 1)
            (expect (workspace-manager-current-name restored-manager) :to-equal "notes")
            (expect (editor-state-window-tree *editor-state*)
                    :to-be restored-notes-tree)
            (expect (length (window-tree-windows restored-main-tree)) :to-equal 1)
            (expect (length restored-notes-windows) :to-equal 2)
            (expect (buffer-name
                     (window-buffer (first (window-tree-windows restored-main-tree))))
                    :to-equal "*main-buffer*")
            (expect (buffer-name (window-buffer (first restored-notes-windows)))
                    :to-equal "*notes-buffer*")
            (expect (window-scroll-line
                     (first (window-tree-windows restored-main-tree)))
                    :to-equal 2)
            (expect (window-scroll-line (first restored-notes-windows)) :to-equal 3)
            (expect (window-scroll-line (second restored-notes-windows)) :to-equal 4)
            (expect (window-tree-selected-index restored-notes-tree) :to-equal 1))))))

  (it
    "rejects unknown application layout nodes and unregistered buffers"
    (let ((registered (make-buffer :name "*registered*"))
          (unregistered (make-buffer :name "*unregistered*")))
      (signals error
        (loom/feature/session::%session-indexed-layout
         (list :leaf unregistered 0)
         (list registered)))
      (signals error
        (loom/feature/session::%session-indexed-layout
         '(:unknown)
         (list registered)))
      (signals error
        (loom/feature/session::%restore-session-layout
         '(:unknown)
         (list registered)))))

(describe
  "session commands"
  (it
    "reject empty save and load paths through the minibuffer"
    (%with-minibuffer-state (minibuffer "")
      (save-session)
      (expect (minibuffer-prompt-string minibuffer)
              :to-equal "Save session to: ")
      (funcall (loom::%minibuffer-on-confirm minibuffer) "  ")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Session path cannot be empty")
      (load-session)
      (expect (minibuffer-prompt-string minibuffer)
              :to-equal "Load session: ")
      (funcall (loom::%minibuffer-on-confirm minibuffer) " ")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Session path cannot be empty")))

  (it
    "saves and loads a session through the public commands"
    (host-kit:with-temporary-directory (directory)
      (let ((path (namestring (merge-pathnames "session.sexp" directory))))
        (%with-minibuffer-state (minibuffer "")
          (save-session)
          (funcall (loom::%minibuffer-on-confirm minibuffer) path)
          (expect (loom:minibuffer-message-string minibuffer)
                  :to-equal (format nil "Session saved: ~A" path))
          (expect (host-kit:path-exists-p path) :to-be-truthy)
          (load-session)
          (funcall (loom::%minibuffer-on-confirm minibuffer) path)
          (expect (loom:minibuffer-message-string minibuffer)
                  :to-equal (format nil "Session loaded: ~A" path)))))

  (it
    "reports save and load failures without replacing editor state"
    (host-kit:with-temporary-directory (directory)
      (let ((path (namestring
                   (merge-pathnames "missing/session.sexp" directory))))
        (%with-minibuffer-state (minibuffer "")
          (let ((original (buffer-text (%selected-test-buffer))))
            (save-session)
            (funcall (loom::%minibuffer-on-confirm minibuffer) path)
            (expect (loom:minibuffer-message-string minibuffer)
                    :to-contain "Could not save session:")
            (load-session)
            (funcall (loom::%minibuffer-on-confirm minibuffer) path)
            (expect (loom:minibuffer-message-string minibuffer)
                    :to-contain "Could not load session:")
            (expect (buffer-text (%selected-test-buffer)) :to-equal original))))))))

  (describe
    "session command cancellation"
    (it
      "cancels save and load prompts through a real C-g event"
      (%with-minibuffer-state (minibuffer "")
        (save-session)
        (minibuffer-handle-key minibuffer (%special-key :control-g))
        (expect (loom:minibuffer-message-string minibuffer) :to-equal "Quit")
        (load-session)
        (minibuffer-handle-key minibuffer (%special-key :control-g))
        (expect (loom:minibuffer-message-string minibuffer) :to-equal "Quit"))))
