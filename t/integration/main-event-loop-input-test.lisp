;;;; t/integration/main-event-loop-input-test.lisp
(in-package #:loom/test)

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
              (loom::%run-event-loop (make-string-output-stream))))
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
              (loom::%run-event-loop (make-string-output-stream))))
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
              (loom::%run-event-loop (make-string-output-stream)))))))))
