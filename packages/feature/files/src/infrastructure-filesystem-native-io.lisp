(in-package #:loom/feature/files)

#+sbcl
(defmacro %with-native-file-descriptor ((fd path flags &optional mode) &body body)
  `(let ((,fd (sb-posix:open (%native-namestring ,path) ,flags ,@(when mode `(,mode)))))
     (unwind-protect
          (progn
            ,@body)
       (when ,fd
         (ignore-errors (sb-posix:close ,fd))))))

#+sbcl (progn
  (defun %native-read-file-octets (path)
    (%with-native-file-descriptor (fd path sb-posix:o-rdonly)
      (let ((stream (sb-sys:make-fd-stream
                     fd
                     :input t
                     :element-type (quote (unsigned-byte 8)))))
        (setf fd nil)
        (unwind-protect
             (let ((chunk (make-array 8192
                                      :element-type (quote (unsigned-byte 8))))
                   (output (make-array 0
                                       :element-type (quote (unsigned-byte 8))
                                       :adjustable t
                                       :fill-pointer 0)))
               (loop for count = (read-sequence chunk stream)
                     while (plusp count)
                     do (loop for index below count
                              do (vector-push-extend (aref chunk index) output)))
               output)
          (close stream)))))

  (defun %native-read-file (path)
    (nth-value 0 (%decode-file-octets (%native-read-file-octets path)))))

#+sbcl (progn
  (defun %native-write-file-octets (path octets)
    (%with-native-file-descriptor
        (fd path (logior sb-posix:o-wronly
                         sb-posix:o-creat
                         sb-posix:o-trunc) #o666)
      (let ((stream (sb-sys:make-fd-stream
                     fd
                     :output t
                     :element-type (quote (unsigned-byte 8)))))
        (setf fd nil)
        (unwind-protect
             (progn
               (write-sequence octets stream)
               (finish-output stream))
          (close stream)))))

  (defun %native-write-file (path content)
    (%native-write-file-octets
     path
     (%encode-file-text
      content
      (%make-file-format :encoding :utf-8 :newline :lf :bom-p nil)))))
