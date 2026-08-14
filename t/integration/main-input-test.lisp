;;;; t/integration/main-input-test.lisp
(in-package #:loom/test)

(describe
  "%read-input-octets"
  (it
    "reads all currently-available octets into buffer and returns the count"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "input.bin" dir)))
        (with-open-file (out path :direction :output :element-type '(unsigned-byte 8))
          (write-byte 1 out)
          (write-byte 2 out)
          (write-byte 3 out))
        (with-open-file (*standard-input* path :direction :input
                                          :element-type '(unsigned-byte 8))
          (let ((buf (make-array 10 :element-type '(unsigned-byte 8))))
            (expect (loom::%read-input-octets buf *standard-input*) :to-equal 3)
            (expect (aref buf 0) :to-equal 1)
            (expect (aref buf 1) :to-equal 2)
            (expect (aref buf 2) :to-equal 3))))))

  (it
    "returns nil at end-of-file"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "empty.bin" dir)))
        (with-open-file (out path :direction :output :element-type '(unsigned-byte 8)))
        (with-open-file (*standard-input* path :direction :input
                                          :element-type '(unsigned-byte 8))
          (let ((buf (make-array 10 :element-type '(unsigned-byte 8))))
            (expect (loom::%read-input-octets buf *standard-input*) :to-be nil))))))

  (it
    "stops draining when a readable stream reaches EOF"
    (let ((*standard-input* (make-instance '%eof-after-listen-stream))
          (buf (make-array 1 :element-type '(unsigned-byte 8))))
      (expect (loom::%drain-buffered-octets buf 0 *standard-input*) :to-equal 0)))

  (it
    "stops filling the buffer at its capacity even if more input is available"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "input.bin" dir)))
        (with-open-file (out path :direction :output :element-type '(unsigned-byte 8))
          (write-byte 1 out)
          (write-byte 2 out)
          (write-byte 3 out))
        (with-open-file (*standard-input* path :direction :input
                                          :element-type '(unsigned-byte 8))
          (let ((buf (make-array 2 :element-type '(unsigned-byte 8))))
            (expect (loom::%read-input-octets buf *standard-input*) :to-equal 2)))))))

(describe
  "%enable-concurrent-file-tree"
  (it
    "serves the primed root and reports cache misses as NIL"
    (let* ((state (%fresh-full-editor-state "content"))
           (tree (editor-state-file-tree state))
           (root "/root/")
           (entries '(("/root/file.txt" . :file)))
           (calls 0)
           (runtime nil))
      (loom/feature/file-tree:file-tree-install-child-lister
       tree
       (lambda (path)
         (incf calls)
         (when (equal path root)
           entries)))
      (setf runtime (loom::%enable-concurrent-file-tree state))
      (unwind-protect
           (progn
             (expect calls :to-equal 1)
             (expect (funcall (loom/feature/file-tree:file-tree-child-lister tree) root)
                     :to-equal entries)
             (expect (funcall (loom/feature/file-tree:file-tree-child-lister tree) "/uncached/")
                     :to-be nil))
        (loom/feature/file-tree:loom-concurrent-runtime-shutdown runtime)))))
