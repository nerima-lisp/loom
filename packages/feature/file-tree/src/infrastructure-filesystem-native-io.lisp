;;;; packages/feature/file-tree/src/infrastructure-filesystem-native-io.lisp
;;;;
;;;; Native SBCL file I/O helpers for file-tree and buffer persistence.
(in-package #:loom/feature/file-tree)

#+sbcl
(defmacro %with-native-file-descriptor ((fd path flags &optional mode) &body body)
  `(let ((,fd (sb-posix:open (%native-namestring ,path) ,flags ,@(when mode `(,mode)))))
     (unwind-protect
          (progn
            ,@body)
       (when ,fd
         (ignore-errors (sb-posix:close ,fd))))))

#+sbcl
(defun %native-read-file (path)
  (%with-native-file-descriptor (fd path sb-posix:o-rdonly)
    (let ((stream (sb-sys:make-fd-stream fd
                                         :input t
                                         :element-type 'character
                                         :external-format :utf-8)))
      (setf fd nil)
      (unwind-protect
           (let ((chunk (make-string 4096))
                 (output (make-string-output-stream)))
             (loop for count = (read-sequence chunk stream)
                   while (plusp count)
                   do (write-string chunk output :end count))
             (get-output-stream-string output))
        (close stream)))))

#+sbcl
(defun %native-write-file (path content)
  (%with-native-file-descriptor
      (fd path (logior sb-posix:o-wronly
                       sb-posix:o-creat
                       sb-posix:o-trunc) #o666)
    (let ((stream (sb-sys:make-fd-stream fd
                                         :output t
                                         :element-type 'character
                                         :external-format :utf-8)))
      (setf fd nil)
      (unwind-protect
           (progn
             (write-string content stream)
             (finish-output stream))
        (close stream)))))
