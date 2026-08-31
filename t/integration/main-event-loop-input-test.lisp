;;;; t/integration/main-event-loop-input-test.lisp
(in-package #:loom/test)

(describe
  "%render-event-loop-frame"
  (it
    "runs optional refresh work before composing and presenting a frame"
    (let* ((buffer (make-buffer :path "/tmp/main.lisp" :initial-content "x"))
           (*editor-state* (%fresh-full-editor-state ""))
           (runtime-drained nil)
           (prefetched-paths nil)
           (lsp-refreshed nil)
           (composed nil)
           (presented nil))
      (window-set-buffer
       (window-tree-selected-window (editor-state-window-tree *editor-state*))
       buffer)
      (setf (editor-state-concurrent-runtime *editor-state*) :runtime
            (editor-state-lsp-session *editor-state*) :session)
      (with-replaced-function
          (loom/feature/terminal:poll-terminal-sessions
           (lambda (state) (declare (ignore state))))
        (with-replaced-function
            (loom/feature/file-tree:loom-concurrent-runtime-drain
             (lambda (runtime)
               (expect runtime :to-be :runtime)
               (setf runtime-drained t)))
          (with-replaced-function
              (loom/feature/file-tree:file-tree-prefetch-paths
               (lambda (tree)
                 (declare (ignore tree))
                 '(:prefetch-path)))
            (with-replaced-function
                (loom/feature/file-tree:loom-concurrent-runtime-prefetch
                 (lambda (runtime paths)
                   (expect runtime :to-be :runtime)
                   (setf prefetched-paths paths)))
              (with-replaced-function
                  (loom/feature/lsp:lsp-session-refresh
                   (lambda (session selected-buffer)
                     (expect session :to-be :session)
                     (expect selected-buffer :to-be buffer)
                     (setf lsp-refreshed t)))
                (with-replaced-function
                    (loom::compose-frame
                     (lambda (state)
                       (expect state :to-be *editor-state*)
                       (setf composed t)))
                  (with-replaced-function
                      (loom:loom-renderer-present
                       (lambda (renderer &key stream cursor)
                         (declare (ignore stream cursor))
                         (expect renderer :to-be
                                 (editor-state-renderer *editor-state*))
                         (setf presented t)))
                    (loom::%render-event-loop-frame
                     (make-string-output-stream))))))))
      (expect runtime-drained :to-be-truthy)
      (expect prefetched-paths :to-equal '(:prefetch-path))
      (expect lsp-refreshed :to-be-truthy)
      (expect composed :to-be-truthy)
      (expect presented :to-be-truthy)))))

(describe
  "%run-event-loop input"
  (it
    "self-inserts decoded input and exits cleanly at end-of-file"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "input.bin" dir)))
        (with-open-file (out path :direction :output :element-type '(unsigned-byte 8))
          (write-byte (char-code #\a) out))
        (let ((*editor-state* (%fresh-full-editor-state "")))
          (%with-stubbed-terminal-size (80 24)
            (with-open-file (*standard-input* path :direction :input
                                              :element-type '(unsigned-byte 8))
              (loom::%run-event-loop (make-string-output-stream)
                                     *standard-input*)))
          (expect (buffer-line (window-buffer (window-tree-selected-window
                                               (editor-state-window-tree *editor-state*)))
                               0)
                  :to-equal "a")))))

  (it
    "decodes a full 4096-byte read as-is, without slicing a partial chunk"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "input.bin" dir)))
        (with-open-file (out path :direction :output :element-type '(unsigned-byte 8))
          (dotimes (i 4096) (write-byte (char-code #\a) out)))
        (let ((*editor-state* (%fresh-full-editor-state "")))
          (%with-stubbed-terminal-size (80 24)
            (with-open-file (*standard-input* path :direction :input
                                              :element-type '(unsigned-byte 8))
              (loom::%run-event-loop (make-string-output-stream)
                                     *standard-input*)))
          (expect (length (buffer-line (window-buffer (window-tree-selected-window
                                                       (editor-state-window-tree *editor-state*)))
                                       0))
                  :to-equal 4096)))))

  (it
    "exits via LOOM-QUIT when a dispatched command signals it"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "input.bin" dir)))
        (with-open-file (out path :direction :output :element-type '(unsigned-byte 8))
          (write-byte 24 out)
          (write-byte 3 out))
        (let ((*editor-state* (%fresh-full-editor-state "")))
          (%with-stubbed-terminal-size (80 24)
            (with-open-file (*standard-input* path :direction :input
                                              :element-type '(unsigned-byte 8))
              (loom::%run-event-loop (make-string-output-stream)
                                     *standard-input*))))))))
