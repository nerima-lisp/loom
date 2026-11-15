(in-package #:loom/test)

(describe "native path names"
  (it "names a non-wild file pathname holding [ * ? and \\ literally"
    (cl-weave:expect-assertions 3)
    (let* ((native "/tmp/draft [1] *?\\x.txt")
           (pathname (sb-ext:parse-native-namestring native)))
      (expect (wild-pathname-p pathname) :to-be nil)
      (expect (loom/core/editor-session:native-path-namestring pathname)
              :to-equal native)
      (expect (loom/core/editor-session:native-path-basename pathname)
              :to-equal "draft [1] *?\\x.txt")))

  (it "names a non-wild directory pathname by its last directory"
    (cl-weave:expect-assertions 3)
    (let* ((native "/tmp/dir [2] *?\\/")
           (pathname (sb-ext:parse-native-namestring native)))
      (expect (wild-pathname-p pathname) :to-be nil)
      (expect (loom/core/editor-session:native-path-namestring pathname)
              :to-equal native)
      (expect (loom/core/editor-session:native-path-basename pathname)
              :to-equal "dir [2] *?\\")))

  (it "reads a wild pathname through its namestring text"
    (cl-weave:expect-assertions 3)
    (let ((pathname (pathname "/tmp/draft [1]*?.txt")))
      (expect (wild-pathname-p pathname) :to-be t)
      (expect (loom/core/editor-session:native-path-namestring pathname)
              :to-equal "/tmp/draft [1]*?.txt")
      (expect (loom/core/editor-session:native-path-basename pathname)
              :to-equal "draft [1]*?.txt")))

  (it "returns a string path as is and takes its basename after PATHNAME"
    (cl-weave:expect-assertions 2)
    (expect (loom/core/editor-session:native-path-namestring "/tmp/a\\b [1].txt")
            :to-equal "/tmp/a\\b [1].txt")
    (expect (loom/core/editor-session:native-path-basename "/tmp/sub/a [1].txt")
            :to-equal "a [1].txt")))
