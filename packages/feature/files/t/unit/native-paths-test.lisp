(in-package #:loom/test)

(describe "files native paths"
  (it "converts literal and legacy wildcard pathnames to the same native filename"
    (cl-weave:expect-assertions 4)
    (let* ((raw "literal [bracket].txt")
           (literal (sb-ext:parse-native-namestring raw))
           (legacy (pathname raw)))
      (expect (wild-pathname-p literal) :to-be nil)
      (expect (wild-pathname-p legacy) :to-be t)
      (expect (loom/feature/files::%native-namestring literal) :to-equal raw)
      (expect (loom/feature/files::%native-namestring legacy) :to-equal raw)))

  (it "writes and reads the literal file named by a non-wild pathname with [ * ? \\"
    (cl-weave:expect-assertions 5)
    (host-kit:with-temporary-directory (directory)
      (let* ((name "draft [1] *?\\x.txt")
             (path (merge-pathnames (sb-ext:parse-native-namestring name)
                                    directory))
             (native-path (concatenate 'string
                                       (sb-ext:native-namestring directory)
                                       name))
             (octets (coerce #(108 111 111 109 10) '(vector (unsigned-byte 8)))))
        (expect (wild-pathname-p path) :to-be nil)
        (loom/feature/files::%native-write-file-octets path octets)
        (expect (sb-posix:stat-size (sb-posix:stat native-path)) :to-equal 5)
        (expect (let ((names '()))
                  (host-kit:call-with-directory-entries
                   (lambda (child-path metadata)
                     (declare (ignore metadata))
                     (push (sb-ext:native-namestring child-path) names))
                   directory)
                  names)
                :to-equal (list native-path))
        (expect (loom/feature/files::%native-path-exists-p path) :to-be t)
        (expect (loom/feature/files::%native-read-file-octets path)
                :to-equalp octets)))))
