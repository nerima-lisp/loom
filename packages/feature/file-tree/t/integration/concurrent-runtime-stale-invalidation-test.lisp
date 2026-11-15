(in-package #:loom/test)

(describe "loom concurrent runtime"
  (it "discards a stale in-flight result after invalidation"
    (let* ((path "/root/stale/")
           (started (cl-concurrent-kit:make-channel :buffer-size 1))
           (release (cl-concurrent-kit:make-channel :buffer-size 1))
           (runtime
             (loom/feature/file-tree:make-loom-concurrent-runtime
              :directory-lister
              (lambda (requested-path)
                (cl-concurrent-kit:send started requested-path)
                (cl-concurrent-kit:recv release)
                (list (cons "/root/stale/old-file" :file))))))
      (unwind-protect
           (multiple-value-bind (promises accepted)
               (loom/feature/file-tree:loom-concurrent-runtime-prefetch runtime (list path))
             (declare (ignore accepted))
             (let ((promise (first promises)))
               (multiple-value-bind (started-path received-p)
                   (cl-concurrent-kit:recv
                    started
                    :timeout (%concurrent-runtime-test-timeout))
                 (expect started-path :to-equal path)
                 (expect received-p :to-be t))
               (multiple-value-bind (value received-p closed-p)
                   (cl-concurrent-kit:try-recv started)
                 (expect value :to-be nil)
                 (expect received-p :to-be nil)
                 (expect closed-p :to-be nil))
               (loom/feature/file-tree:loom-concurrent-runtime-invalidate-directory
                runtime path)
               (expect
                (loom/feature/file-tree:loom-concurrent-runtime-directory-entries runtime path)
                :to-be nil)
               (expect (cl-concurrent-kit:try-send release :release)
                       :to-be-truthy)
               (cl-concurrent-kit:await
                promise
                :timeout (%concurrent-runtime-test-timeout))
               (loom/feature/file-tree:loom-concurrent-runtime-drain runtime)
               (expect
                (loom/feature/file-tree:loom-concurrent-runtime-directory-entries runtime path)
                :to-be nil)
               (multiple-value-bind (fresh-promises fresh-accepted)
                   (loom/feature/file-tree:loom-concurrent-runtime-prefetch runtime (list path))
                 (expect fresh-accepted :to-be 1)
                 (let ((fresh-promise (first fresh-promises)))
                   (multiple-value-bind (fresh-started-path fresh-received-p)
                       (cl-concurrent-kit:recv
                        started
                        :timeout (%concurrent-runtime-test-timeout))
                     (expect fresh-started-path :to-equal path)
                     (expect fresh-received-p :to-be t))
                   (expect (cl-concurrent-kit:try-send release :release)
                           :to-be-truthy)
                   (cl-concurrent-kit:await
                    fresh-promise
                    :timeout (%concurrent-runtime-test-timeout))
                   (loom/feature/file-tree:loom-concurrent-runtime-drain runtime)
                   (expect
                    (loom/feature/file-tree:loom-concurrent-runtime-directory-entries runtime path)
                    :to-equal
                    (list (cons "/root/stale/old-file" :file)))))))
        (ignore-errors
          (cl-concurrent-kit:try-send release :cleanup))
        (ignore-errors
          (cl-concurrent-kit:close-channel started))
        (ignore-errors
          (cl-concurrent-kit:close-channel release))
        (ignore-errors
          (loom/feature/file-tree:loom-concurrent-runtime-shutdown runtime))))))
(describe "file-tree unavailable runtime viewport"
  (it "preserves every viewport field until invalidated children arrive"
    (let* ((*editor-state* (%fresh-editor-state ""))
           (tree (make-file-tree "/root/"))
           (children (loop for index below 200
                           collect (cons (format nil "/root/file~3,'0D" index) :file)))
           (started (cl-concurrent-kit:make-channel :buffer-size 1))
           (release (cl-concurrent-kit:make-channel :buffer-size 1))
           (async-p nil))
      (setf (editor-state-file-tree *editor-state*) tree)
      (loom/feature/file-tree:file-tree-install-child-lister
       tree (lambda (path)
              (when async-p
                (cl-concurrent-kit:send started path)
                (cl-concurrent-kit:recv release))
              children))
      (let ((runtime (loom/feature/file-tree:enable-file-tree-runtime *editor-state*)))
        (unwind-protect
             (progn
               (loom/feature/file-tree:file-tree-prepare-viewport tree 24 5)
               (setf (loom/feature/file-tree:file-tree-scroll-top tree) 150)
               (loom/feature/file-tree:file-tree-prepare-viewport tree 24 5)
               (let ((before (copy-structure tree)))
                 (loom/feature/file-tree:loom-concurrent-runtime-invalidate-directory runtime "/root/")
                 (multiple-value-bind (entries present-p)
                     (loom/feature/file-tree:file-tree-prepare-viewport tree 20 10)
                   (expect entries :to-be nil)
                   (expect present-p :to-be nil)
                   (expect (equalp before tree) :to-be t))
                 (setf async-p t)
                 (multiple-value-bind (promises accepted)
                     (loom/feature/file-tree:loom-concurrent-runtime-prefetch runtime '("/root/"))
                   (expect accepted :to-equal 1)
                   (multiple-value-bind (path received-p)
                       (cl-concurrent-kit:recv started :timeout (%concurrent-runtime-test-timeout))
                     (expect path :to-equal "/root/")
                     (expect received-p :to-be t))
                   (loom/feature/file-tree:file-tree-prepare-viewport tree 20 10)
                   (expect (equalp before tree) :to-be t)
                   (setf children (subseq children 0 100))
                   (cl-concurrent-kit:send release :ready)
                   (cl-concurrent-kit:await (first promises) :timeout (%concurrent-runtime-test-timeout))
                   (loom/feature/file-tree:loom-concurrent-runtime-drain runtime)
                   (multiple-value-bind (entries present-p)
                       (loom/feature/file-tree:file-tree-prepare-viewport tree 20 10)
                     (expect present-p :to-be t)
                     (expect (length entries) :to-equal 100)
                     (expect (loom/feature/file-tree:file-tree-scroll-top tree) :to-equal 90)
                     (expect (loom/feature/file-tree:file-tree-viewport-height tree) :to-equal 10)))
               (loom/feature/file-tree:loom-concurrent-runtime-prime-directory runtime "/root/" nil)
               (multiple-value-bind (entries present-p)
                   (loom/feature/file-tree:file-tree-prepare-viewport tree 20 10)
                 (expect entries :to-be nil)
                 (expect present-p :to-be t)
                 (expect (loom/feature/file-tree:file-tree-scroll-top tree) :to-equal 0))))
          (cl-concurrent-kit:try-send release :cleanup)
          (cl-concurrent-kit:close-channel release)
          (cl-concurrent-kit:close-channel started)
          (loom/feature/file-tree:shutdown-file-tree-runtime *editor-state*))))))
(describe "file-tree runtime recorded errors"
  (it "keeps wheel and real file clicks available after an expanded listing fails"
    (host-kit:with-temporary-directory (directory)
      (let* ((*editor-state* (%fresh-editor-state "" :with-minibuffer t))
             (loom/core/editor-session:*editor-session*
               (loom/core/editor-session:editor-state-session *editor-state*))
             (tree (make-file-tree "/root/"))
             (target (namestring (merge-pathnames "target.txt" directory)))
             (roots (cons '("/root/bad/" . :directory)
                          (loop for i from 1 below 200 collect
                                (cons (if (= i 4) target (format nil "/root/file~3,'0D" i)) :file)))))
        (with-open-file (out target :direction :output :if-exists :supersede
                                    :if-does-not-exist :create)
          (write-string "runtime-click-ok" out))
        (setf (editor-state-file-tree *editor-state*) tree)
        (loom/feature/file-tree:file-tree-install-child-lister
         tree (lambda (path)
                (if (equal path "/root/") roots (error "listing failed"))))
        (file-tree-toggle tree)
        (let ((runtime (loom/feature/file-tree:enable-file-tree-runtime *editor-state*)))
          (unwind-protect
               (progn
                 (loom/feature/file-tree:file-tree-prepare-viewport tree 24 5)
                 (file-tree-toggle-expand tree "/root/bad/")
                 (let ((before (copy-structure tree)))
                   (loom/feature/file-tree:file-tree-prepare-viewport tree 24 5)
                   (expect (equalp tree before) :to-be t))
                 (multiple-value-bind (promises accepted)
                     (loom/feature/file-tree:loom-concurrent-runtime-prefetch runtime '("/root/bad/"))
                   (expect accepted :to-equal 1)
                   (signals error
                     (cl-concurrent-kit:await (first promises)
                                              :timeout (%concurrent-runtime-test-timeout))))
                 (expect (loom/feature/file-tree:loom-concurrent-runtime-drain runtime) :to-equal 1)
                 (multiple-value-bind (entries present-p)
                     (loom/feature/file-tree:loom-concurrent-runtime-directory-entries runtime "/root/bad/")
                   (expect entries :to-be nil)
                   (expect present-p :to-be t))
                 (expect (typep (loom/feature/file-tree:loom-concurrent-runtime-directory-error
                                 runtime "/root/bad/") 'error) :to-be t)
                 (loom/feature/mouse::%mouse-scroll-file-tree :wheel-down)
                 (expect (loom/feature/file-tree:file-tree-scroll-top tree) :to-equal 3)
                 (let ((hit (loom/feature/mouse::%mouse-file-tree-hit-test
                             (loom/core/editor-session:editor-state-session *editor-state*) 0 1)))
                   (expect hit :to-be-truthy)
                   (expect (loom/core/editor-session:hit-test-result-target hit) :to-equal target)
                   (loom/feature/mouse::%mouse-open-file-tree-target
                    (loom/core/editor-session:hit-test-result-target hit)))
                 (expect (file-tree-selected-path tree) :to-equal target)
                 (expect (buffer-text
                          (loom/core/window-tree:window-buffer
                           (loom/core/window-tree:window-tree-selected-window
                            (editor-state-window-tree *editor-state*))))
                         :to-equal "runtime-click-ok"))
            (loom/feature/file-tree:shutdown-file-tree-runtime *editor-state*)))))))


