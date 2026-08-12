;;;; t/integration/main-startup-test.lisp
(in-package #:loom/test)

(describe
  "%startup-file-and-root"
  (it
    "returns the resolved file and its containing directory as file-tree root for an existing file"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "note.txt" dir)))
        (host-kit:write-file-string "hi" path)
        (multiple-value-bind (file root) (loom::%startup-file-and-root (namestring path))
          (expect file :to-equal (probe-file path))
          (expect root :to-equal (make-pathname :name nil :type nil :defaults (probe-file path)))))))

  (it
    "returns no file and the argument itself as root for a directory argument"
    (host-kit:with-temporary-directory (dir)
      (multiple-value-bind (file root) (loom::%startup-file-and-root (namestring dir))
        (expect file :to-be nil)
        (expect root :to-equal (namestring dir)))))

  (it
    "rejects a missing path as a CLI positional error"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "missing.txt" dir)))
        (handler-case
            (progn
              (loom::%startup-file-and-root (namestring path))
              (error "Expected a missing path to be rejected"))
          (cl-cli:cli-invalid-positional-value (condition)
            (expect (cl-cli:cli-invalid-positional-value-name condition)
                    :to-equal "PATH")
            (expect (cl-cli:cli-invalid-positional-value-value condition)
                    :to-equal (namestring path))
            (expect (cl-cli:cli-invalid-positional-value-cause condition)
                    :to-be nil))))))

  (it
    "defaults to \".\" as root when given no argument"
    (multiple-value-bind (file root) (loom::%startup-file-and-root nil)
      (expect file :to-be nil)
      (expect root :to-equal "."))))

(describe
  "%call-with-started-editor-state"
  (it
    "initializes state, starts services, runs the body, and always shuts services down"
    (let ((events nil)
          (body-state nil))
      (with-replaced-function
          (loom::%initialize-editor-state
           (lambda (path)
             (push (list :initialize path) events)
             (setf loom::*editor-state* (make-editor-state))))
        (with-replaced-function
            (loom::%enable-concurrent-file-tree
             (lambda (state)
               (push (list :start state) events)
               :runtime))
          (with-replaced-function
              (loom::%shutdown-editor-services
               (lambda (state)
                 (push (list :stop state) events)))
            (loom::%call-with-started-editor-state
             "path.txt"
             (lambda (state)
               (setf body-state state)
               (push (list :body state) events)
               :ok)))))
      (expect body-state :to-equal loom::*editor-state*)
      (expect (nreverse (mapcar #'first events))
              :to-equal (list :initialize :start :body :stop))))

  (it
    "shuts services down on a non-local exit from the body"
    (let ((stopped nil))
      (with-replaced-function
          (loom::%initialize-editor-state
           (lambda (path)
             (declare (ignore path))
             (setf loom::*editor-state* (make-editor-state))))
        (with-replaced-function
            (loom::%enable-concurrent-file-tree
             (lambda (state)
               (declare (ignore state))
               :runtime))
          (with-replaced-function
              (loom::%shutdown-editor-services
               (lambda (state)
                 (declare (ignore state))
                 (setf stopped t)))
            (handler-case
                (loom::%call-with-started-editor-state
                 nil
                 (lambda (state)
                   (declare (ignore state))
                   (error "boom")))
              (error (condition)
                (expect (princ-to-string condition) :to-contain "boom"))))))
      (expect stopped :to-be t))))
