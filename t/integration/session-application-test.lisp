;;;; t/integration/session-application-test.lisp
;;;;
;;;; Session persistence tests cover the application round-trip that rebuilds
;;;; buffers and window layout.
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
    "rejects non-hash-table bookmark state during snapshotting"
    (let ((*editor-state* (%fresh-editor-state "content")))
      (setf (editor-state-bookmarks *editor-state*) 'invalid)
      (signals error
        (loom/feature/session::%session-bookmark-snapshots)))))
