;;;; t/integration/session-test.lisp
;;;;
;;;; Session persistence tests cover the pure snapshot/store boundary and the
;;;; application round-trip that rebuilds buffers and window layout.
(in-package #:loom/test)

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
   :layout '(:leaf 0 4)
   :selected-window-index 0))

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
          (expect (session-snapshot-layout restored) :to-equal '(:leaf 0 4))
          (expect (session-snapshot-selected-window-index restored)
                  :to-equal 0)
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
    "rejects reader evaluation and malformed session input"
    (host-kit:with-temporary-directory (directory)
      (let ((path (merge-pathnames "unsafe.sexp" directory)))
        (host-kit:write-file-string
         "(:loom-session 1 :buffers #.(list) :layout (:leaf 0 0) :selected-window-index 0)"
         path)
        (signals error (session-store-read path)))))

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
           (state (make-editor-state
                   :window-tree tree
                   :minibuffer (make-minibuffer)
                   :keymap (make-keymap)
                   :file-tree (make-file-tree "/root/")
                   :buffers (list one two)
                   :kill-ring nil)))
      (window-set-buffer other two)
      (setf (window-scroll-line other) 1)
      (buffer-set-point two 1 2)
      (buffer-set-mark two 0 1)
      (buffer-insert-string one "x")
      (let ((*editor-state* state))
        (let ((snapshot (loom::%session-snapshot-from-state)))
          (loom::%restore-session-snapshot snapshot)
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
