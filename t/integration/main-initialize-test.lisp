;;;; t/integration/main-initialize-test.lisp
(in-package #:loom/test)

(describe
  "%initialize-editor-state"
  (it
    "loads an existing file into the initial buffer and names it after the file"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "note.txt" dir))
            (*editor-state* nil))
        (host-kit:write-file-string "hello" path)
        (loom::%initialize-editor-state (namestring path))
        (expect (buffer-name (%selected-test-buffer)) :to-equal "note.txt")
        (expect (buffer-text (%selected-test-buffer)) :to-equal "hello"))))

  (it
    "opens an empty *scratch* buffer when given no path argument"
    (let ((*editor-state* nil))
      (loom::%initialize-editor-state nil)
      (expect (buffer-name (%selected-test-buffer)) :to-equal "*scratch*"))))

(describe
  "%loom-version"
  (it
    "returns the loom ASDF system's version string"
    (expect (loom::%loom-version) :to-equal (asdf:component-version (asdf:find-system "loom")))))
