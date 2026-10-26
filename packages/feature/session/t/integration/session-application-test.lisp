(in-package #:loom/test)

(describe
  "session application round-trip"
  (it "rejects an editor state without its required workspace manager"
    (let ((*editor-state* (%fresh-editor-state "one")))
      (setf (editor-state-workspaces *editor-state*) nil)
      (signals error
        (loom/feature/session::%session-workspace-manager))))

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
                   :workspaces (make-workspace-manager tree :name "main")
                   :minibuffer (make-minibuffer
                                :history (history-kit:make-history))
                   :keymap (make-keymap)
                   :file-tree (make-file-tree "/root/")
                   :session (%make-test-editor-session (list one two) :window-tree tree)
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
      (let ((*editor-state* state)
            (loom/core/editor-session:*editor-session*
             (loom/core/editor-session:editor-state-session state)))
        (setf (editor-state-minibuffer *editor-state*) nil)
        (let ((snapshot (loom/feature/session::%session-snapshot-from-state)))
          (expect (session-snapshot-command-history snapshot) :to-be nil))
        (setf (editor-state-minibuffer *editor-state*)
              (make-minibuffer :history (history-kit:make-history)))
        (minibuffer-set-history-entries
         (editor-state-minibuffer *editor-state*)
         '("find-file" "M-x"))
        (let ((snapshot (loom/feature/session::%session-snapshot-from-state)))
          (loom/feature/session::%restore-session-snapshot snapshot)
          (let* ((restored-buffers (%test-registered-buffers *editor-state*))
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
            (expect (window-scroll-line (second windows)) :to-equal 1))))))

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

  (it
    "restores an unmatched bookmark while preserving its saved location"
    (let* ((snapshot
             (make-session-bookmark-snapshot
              :name "orphan"
              :path "/tmp/orphan.txt"
              :buffer-name "orphan.txt"
              :line 4
              :column 7))
           (bookmarks
             (loom/feature/session::%restore-session-bookmarks
              (list snapshot) nil))
           (bookmark (gethash "orphan" bookmarks)))
      (expect bookmark :to-be-truthy)
      (expect (editor-bookmark-buffer bookmark) :to-be nil)
      (expect (editor-bookmark-path bookmark) :to-equal #P"/tmp/orphan.txt")
      (expect (editor-bookmark-buffer-name bookmark) :to-equal "orphan.txt")
      (expect (editor-bookmark-line bookmark) :to-equal 4)
      (expect (editor-bookmark-column bookmark) :to-equal 7)))

  (it
    "reconnects a bookmark by buffer name when its path is absent"
    (let* ((buffer (make-buffer :name "notes.txt"))
           (snapshot
             (make-session-bookmark-snapshot
              :name "spot"
              :buffer-name "notes.txt"
              :line 1
              :column 3))
           (bookmarks
             (loom/feature/session::%restore-session-bookmarks
              (list snapshot) (list buffer)))
           (bookmark (gethash "spot" bookmarks)))
      (expect (editor-bookmark-buffer bookmark) :to-be buffer)
      (expect (editor-bookmark-buffer-name bookmark) :to-equal "notes.txt")))

  (it
    "derives a bookmark buffer name when its explicit name is absent"
    (let* ((buffer (make-buffer :name "notes.txt"))
           (*editor-state* (%fresh-editor-state "content"))
           (bookmarks (make-hash-table :test #'equal)))
      (setf (gethash "spot" bookmarks)
            (make-editor-bookmark :name "spot" :buffer buffer)
            (editor-state-bookmarks *editor-state*) bookmarks)
      (expect (session-bookmark-snapshot-buffer-name
               (first (loom/feature/session::%session-bookmark-snapshots)))
              :to-equal "notes.txt")))

  (it
    "derives a restored bookmark buffer name from its connected buffer"
    (let* ((buffer (make-buffer :name "notes.txt"
                                :path #P"/tmp/notes.txt"))
           (snapshot (make-session-bookmark-snapshot
                      :name "spot"
                      :path "/tmp/notes.txt"))
           (bookmarks
             (loom/feature/session::%restore-session-bookmarks
              (list snapshot) (list buffer)))
           (bookmark (gethash "spot" bookmarks)))
      (expect (editor-bookmark-buffer bookmark) :to-be buffer)
      (expect (editor-bookmark-buffer-name bookmark) :to-equal "notes.txt")))

  (it
    "rejects non-hash-table bookmark state during snapshotting"
    (let ((*editor-state* (%fresh-editor-state "content")))
      (setf (editor-state-bookmarks *editor-state*) 'invalid)
      (signals error
        (loom/feature/session::%session-bookmark-snapshots))))

  (it
    "orders bookmark snapshots deterministically when names differ by case"
    (let* ((bookmarks (make-hash-table :test #'equal))
           (*editor-state* (%fresh-editor-state "content")))
      (setf (gethash "zebra" bookmarks)
            (make-editor-bookmark :name "zebra" :line 1 :column 0)
            (gethash "Alpha" bookmarks)
            (make-editor-bookmark :name "Alpha" :line 2 :column 0)
            (gethash "alpha" bookmarks)
            (make-editor-bookmark :name "alpha" :line 3 :column 0)
            (editor-state-bookmarks *editor-state*) bookmarks)
      (expect (mapcar #'session-bookmark-snapshot-name
                      (loom/feature/session::%session-bookmark-snapshots))
              :to-equal '("Alpha" "alpha" "zebra"))))
  (it
    "restores session state when the saved file-tree root is stale"
    (host-kit:with-temporary-directory (directory)
      (let* ((stale-root (merge-pathnames "missing/" directory))
             (stale-root-string (namestring stale-root))
             (old-file-tree (loom/feature/file-tree:make-file-tree directory))
             (state (%fresh-editor-state "before" :with-minibuffer t))
             (*editor-state* state)
             (loom/core/editor-session:*editor-session*
               (editor-state-session state))
             (snapshot (%session-test-snapshot))
             (original-lister
               (symbol-function
                (find-symbol "LOOM-FS-LIST-DIRECTORY"
                             "LOOM/FEATURE/FILE-TREE")))
             (stale-root-list-calls 0))
        (setf (editor-state-file-tree state) old-file-tree
              (editor-state-recent-files state) (list "before.txt")
              (editor-state-bookmarks state)
              (make-hash-table :test (function equal)))
        (progn
          (setf (editor-state-minibuffer state)
                (make-minibuffer :history (history-kit:make-history)))
          (minibuffer-set-history-entries
           (editor-state-minibuffer state)
           (list "before")))
        (setf (session-snapshot-file-tree snapshot)
              (make-session-file-tree-snapshot
               :root-path stale-root-string
               :visible-p t
               :expanded-paths
               (list (namestring (merge-pathnames "src/" stale-root)))
               :selected-path
               (namestring (merge-pathnames "src/main.lisp" stale-root))))
        (expect (host-kit:directory-exists-p stale-root) :to-be-falsy)
        (with-replaced-function
            (loom/feature/file-tree:loom-fs-list-directory
             (lambda (path)
               (if (string= (namestring (pathname path)) stale-root-string)
                   (progn
                     (incf stale-root-list-calls)
                     (error "stale file-tree root cannot be listed"))
                   (funcall original-lister path))))
          (multiple-value-bind (restored-tree warning)
              (loom/feature/session::%restore-session-snapshot snapshot)
            (declare (ignore restored-tree))
            (expect warning :to-be-truthy)
            (expect warning :to-contain "File-tree root not found")
            (expect stale-root-list-calls :to-equal 0)
            (expect (editor-state-file-tree *editor-state*)
                    :to-be old-file-tree)
            (expect (length (%test-registered-buffers *editor-state*))
                    :to-equal 1)
            (expect (buffer-text
                     (first (%test-registered-buffers *editor-state*)))
                    :to-equal (format nil "one~%two"))
            (expect (editor-state-recent-files *editor-state*)
                    :to-equal (list "one.lisp" "two.lisp"))
            (expect (minibuffer-history-entries
                     (editor-state-minibuffer *editor-state*))
                    :to-equal (list "M-x find-file" "M-x"))
            (expect
             (loom/feature/workspace:workspace-name
              (loom/feature/workspace:workspace-manager-current
               (editor-state-workspaces *editor-state*)))
             :to-equal "main")
            (expect (gethash "spot" (editor-state-bookmarks *editor-state*))
                    :to-be-truthy))))))
  (it
    "leaves the current editor state installed when file-tree refresh fails"
    (host-kit:with-temporary-directory (directory)
      (let* ((state (%fresh-editor-state "before" :with-minibuffer t))
             (*editor-state* state)
             (loom/core/editor-session:*editor-session*
               (editor-state-session state))
             (old-window-tree (editor-state-window-tree state))
             (old-file-tree
               (loom/feature/file-tree:make-file-tree "/old-root/"))
             (old-buffer (first (%test-registered-buffers state)))
             (old-bookmarks (make-hash-table :test (function equal)))
             (snapshot (%session-test-snapshot))
             (refresh-candidate nil))
        (setf (editor-state-file-tree state) old-file-tree
              (editor-state-recent-files state) (list "before.txt")
              (editor-state-bookmarks state) old-bookmarks)
        (progn
          (setf (editor-state-minibuffer state)
                (make-minibuffer :history (history-kit:make-history)))
          (minibuffer-set-history-entries
           (editor-state-minibuffer state)
           (list "before")))
        (setf (session-snapshot-file-tree snapshot)
              (make-session-file-tree-snapshot
               :root-path (namestring directory)
               :visible-p t
               :expanded-paths nil
               :selected-path nil))
        (with-replaced-function
            (loom/feature/file-tree:refresh-file-tree-runtime
             (lambda (candidate)
               (setf refresh-candidate candidate)
               (error "injected file-tree refresh failure")))
          (signals error
            (loom/feature/session::%restore-session-snapshot snapshot)))
        (expect refresh-candidate :to-be-truthy)
        (expect (eq (editor-state-window-tree refresh-candidate)
                    old-window-tree)
                :to-be t)
        (expect (eq (editor-state-window-tree *editor-state*)
                    old-window-tree)
                :to-be t)
        (expect (eq (editor-state-file-tree *editor-state*)
                    old-file-tree)
                :to-be t)
        (expect (first (%test-registered-buffers *editor-state*))
                :to-be old-buffer)
        (expect (editor-state-recent-files *editor-state*)
                :to-equal (list "before.txt"))
        (expect (minibuffer-history-entries
                 (editor-state-minibuffer *editor-state*))
                :to-equal (list "before"))
        (expect (eq (editor-state-bookmarks *editor-state*)
                    old-bookmarks)
                :to-be t))))
  (it
    "rejects persisted file-tree paths outside the saved root before listing"
    (host-kit:with-temporary-directory (directory)
      (let* ((state (%fresh-editor-state "before"))
             (*editor-state* state)
             (loom/core/editor-session:*editor-session*
               (editor-state-session state))
             (old-buffer (first (%test-registered-buffers state)))
             (old-file-tree (loom/feature/file-tree:make-file-tree directory))
             (snapshot (%session-test-snapshot))
             (outside-directory (merge-pathnames "../outside/" directory))
             (original-lister
               (symbol-function
                (find-symbol "LOOM-FS-LIST-DIRECTORY"
                             "LOOM/FEATURE/FILE-TREE")))
             (listing-calls 0))
        (setf (editor-state-file-tree state) old-file-tree
              (editor-state-recent-files state) (list "before.txt")
              (session-snapshot-file-tree snapshot)
              (make-session-file-tree-snapshot
               :root-path (namestring directory)
               :visible-p t
               :expanded-paths (list (namestring outside-directory))
               :selected-path
               (namestring (merge-pathnames "secret.txt" outside-directory))))
        (with-replaced-function
            (loom/feature/file-tree:loom-fs-list-directory
             (lambda (path)
               (incf listing-calls)
               (funcall original-lister path)))
          (signals error
            (loom/feature/session::%restore-session-snapshot snapshot)))
        (expect listing-calls :to-equal 0)
        (expect (eq (editor-state-file-tree *editor-state*) old-file-tree)
                :to-be t)
        (expect (first (%test-registered-buffers *editor-state*))
                :to-be old-buffer)
        (expect (editor-state-recent-files *editor-state*)
                :to-equal (list "before.txt"))))))
(describe
  "session file-tree path normalization"
  (it
    "restores an existing root and saved paths reached through parent segments"
    (host-kit:with-temporary-directory (directory)
      (let* ((canonical-root (truename directory))
             (*default-pathname-defaults*
               (progn
                 (ensure-directories-exist
                  (merge-pathnames "nested/selected.txt" canonical-root))
                 (truename (merge-pathnames "nested/" canonical-root))))
             (relative-root "../")
             (relative-expanded
               "../nested/")
             (relative-selected "../nested")
             (nested-directory (merge-pathnames "nested/" canonical-root))
             (selected-file
               (merge-pathnames "nested/selected.txt" canonical-root))
             (state (%fresh-editor-state "before" :with-minibuffer t))
             (*editor-state* state)
             (loom/core/editor-session:*editor-session*
               (editor-state-session state))
             (snapshot (%session-test-snapshot)))
        (ensure-directories-exist selected-file)
        (with-open-file
            (stream selected-file
                    :direction :output
                    :if-exists :supersede
                    :if-does-not-exist :create)
          (write-line "selected" stream))
        (setf (editor-state-file-tree state)
              (loom/feature/file-tree:make-file-tree canonical-root)
              (session-snapshot-file-tree snapshot)
              (make-session-file-tree-snapshot
               :root-path relative-root
               :visible-p t
               :expanded-paths (list (namestring relative-expanded))
               :selected-path relative-selected))
        (expect (search ".." relative-root) :to-be-truthy)
        (expect (search ".." (namestring relative-expanded)) :to-be-truthy)
        (expect (search ".." relative-selected) :to-be-truthy)
        (loom/feature/session::%restore-session-snapshot snapshot)
        (let* ((restored-tree (editor-state-file-tree *editor-state*))
               (restored-paths
                 (loom/feature/file-tree:file-tree-prefetch-paths
                  restored-tree))
               (expected-root (namestring (truename canonical-root)))
               (expected-expanded (namestring (truename nested-directory)))
               (expected-selected
 (namestring
  (host-kit:ensure-directory-pathname
   (truename nested-directory)))))
          (expect (namestring (first restored-paths)) :to-equal expected-root)
          (expect
           (find expected-expanded (rest restored-paths)
                 :test (function string=) :key (function namestring))
           :to-be-truthy)
          (expect
           (namestring
 (host-kit:ensure-directory-pathname
  (loom/feature/file-tree:file-tree-selected-path restored-tree)))
           :to-equal expected-selected)
          (expect
           (loom/feature/file-tree:file-tree-visible-p restored-tree)
           :to-be t))))))
