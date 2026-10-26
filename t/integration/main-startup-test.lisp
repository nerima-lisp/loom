(in-package #:loom/test)

(describe "%main-exit-code"
          (it
           "passes the argument vector to the CLI application and returns its exit code"
           (let ((received-argv nil)
                 (argv (list "loom" "--version")))
             (with-replaced-function
              (cl-cli:run-app
               (lambda (app &key argv)
                 (expect app :to-equal loom::*loom-app*)
                 (setf received-argv argv)
                 7))
              (expect (loom::%main-exit-code argv) :to-equal 7))
             (expect received-argv :to-equal argv))))

(it "uses UIOP's raw command-line arguments when no argument vector is supplied"
    (let ((argv (list "loom" "--version"))
          (received-argv nil))
      (with-replaced-function
       (cl-cli:run-app
        (lambda (app &key argv)
          (expect app :to-equal loom::*loom-app*)
          (setf received-argv argv)
          0))
       (with-replaced-function
        (uiop:raw-command-line-arguments
         (lambda ()
           argv))
        (expect (loom::%main-exit-code) :to-equal 0)))
      (expect received-argv :to-equal argv)))

(it
 "passes the default raw arguments to the application and quits with its code"
 (let ((argv (list "loom" "--version"))
       (received-argv nil)
       (quit-code nil))
   (with-replaced-function
    (cl-cli:run-app
     (lambda (app &key argv)
       (declare (ignore app))
       (setf received-argv argv)
       7))
    (with-replaced-function
     (uiop:raw-command-line-arguments
      (lambda ()
        argv))
     (with-replaced-function
      (uiop:quit
       (lambda (code)
         (setf quit-code code)))
      (loom::main))))
   (expect received-argv :to-equal argv)
   (expect quit-code :to-equal 7)))

(describe "%startup-file-and-root"
          (it
           "returns the resolved file and its containing directory as file-tree root for an existing file"
           (host-kit:with-temporary-directory (dir)
                                              (let ((path
                                                     (merge-pathnames "note.txt"
                                                                      dir)))
                                                (host-kit:write-file-string "hi"
                                                                            path)
                                                (multiple-value-bind (file root)
                                                    (loom::%startup-file-and-root
                                                     (namestring path))
                                                  (expect file
                                                          :to-equal
                                                          (probe-file path))
                                                  (expect root
                                                          :to-equal
                                                          (make-pathname :name
                                                                         nil
                                                                         :type
                                                                         nil
                                                                         :defaults
                                                                         (probe-file
                                                                          path)))))))
          (it
           "returns no file and the argument itself as root for a directory argument"
           (host-kit:with-temporary-directory (dir)
                                              (multiple-value-bind (file root)
                                                  (loom::%startup-file-and-root
                                                   (namestring dir))
                                                (expect file :to-be nil)
                                                (expect root
                                                        :to-equal
                                                        (namestring dir)))))
          (it "rejects a missing path as a CLI positional error"
              (host-kit:with-temporary-directory (dir)
                                                 (let ((path
                                                        (merge-pathnames
                                                         "missing.txt"
                                                         dir)))
                                                   (handler-case (progn
                                                                   (loom::%startup-file-and-root
                                                                    (namestring
                                                                     path))
                                                                   (error
                                                                    "Expected a missing path to be rejected"))
                                                     (cl-cli:cli-invalid-positional-value (condition)
                                                       (expect
                                                        (cl-cli:cli-invalid-positional-value-name
                                                         condition)
                                                        :to-equal
                                                        "PATH")
                                                       (expect
                                                        (cl-cli:cli-invalid-positional-value-value
                                                         condition)
                                                        :to-equal
                                                        (namestring path))
                                                       (expect
                                                        (cl-cli:cli-invalid-positional-value-cause
                                                         condition)
                                                        :to-be
                                                        nil))))))
          (it "defaults to \".\" as root when given no argument"
              (multiple-value-bind (file root)
                  (loom::%startup-file-and-root nil)
                (expect file :to-be nil)
                (expect root :to-equal "."))))

(describe "%call-with-started-editor-state"
          (it
           "initializes state, starts services, runs the body, and always shuts services down"
           (let ((events nil)
                 (body-state nil))
             (with-replaced-function
              (loom::%initialize-editor-state
               (lambda (path &optional additional-file-paths)
                 (declare (ignore additional-file-paths))
                 (push (list :initialize path) events)
                 (setf loom::*editor-state* (make-editor-state :session
                                                               (%make-test-editor-session)))))
              (with-replaced-function
               (loom::%enable-concurrent-file-tree
                (lambda (state)
                  (push (list :start state) events)
                  :runtime))
               (with-replaced-function
                (loom::%shutdown-editor-services
                 (lambda (state)
                   (push (list :stop state) events)))
                (loom::%call-with-started-editor-state "path.txt"
                                                       (lambda (state)
                                                         (setf body-state state)
                                                         (push
                                                          (list :body state)
                                                          events)
                                                         :ok)))))
             (expect body-state :to-equal loom::*editor-state*)
             (expect (nreverse (mapcar #'first events))
                     :to-equal
                     (list :initialize :start :body :stop))))
          (it "shuts services down on a non-local exit from the body"
              (let ((stopped nil))
                (with-replaced-function
                 (loom::%initialize-editor-state
                  (lambda (path &optional additional-file-paths)
                    (declare (ignore path additional-file-paths))
                    (setf loom::*editor-state* (make-editor-state :session
                                                                  (%make-test-editor-session)))))
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
                   (handler-case (loom::%call-with-started-editor-state nil
                                                                        (lambda
                                                                            (state)
                                                                          (declare (ignore
                                                                                    state))
                                                                          (error
                                                                           "boom")))
                     (error (condition)
                       (expect (princ-to-string condition) :to-contain "boom"))))))
                (expect stopped :to-be t)))
          (it
           "applies the first startup file request position to the selected buffer"
           (host-kit:with-temporary-directory (directory)
                                              (let* ((path
                                                      (merge-pathnames
                                                       "note.txt"
                                                       directory))
                                                     (request
                                                      (loom/core/editor-session:make-startup-file-request
                                                       (namestring path)
                                                       :line
                                                       2
                                                       :column
                                                       3))
                                                     (*editor-state* nil)
                                                     (selected-position nil))
                                                (host-kit:write-file-string
                                                 (format nil "first~%second")
                                                 path)
                                                (with-replaced-function
                                                 (loom::%enable-concurrent-file-tree
                                                  (lambda (state)
                                                    (declare (ignore state))))
                                                 (with-replaced-function
                                                  (loom::%shutdown-editor-services
                                                   (lambda (state)
                                                     (declare (ignore state))))
                                                  (loom::%call-with-started-editor-state
                                                   (namestring path)
                                                   (lambda (state)
                                                     (declare (ignore state))
                                                     (let ((buffer
                                                            (%selected-test-buffer)))
                                                       (setf selected-position (cons
                                                                                (buffer-point-line
                                                                                 buffer)
                                                                                (buffer-point-column
                                                                                 buffer)))))
                                                   request)))
                                                (expect selected-position
                                                        :to-equal
                                                        (cons 1 2))))))

(describe "%run-loom"
          (it
           "dispatches lifecycle hooks before cleanup and exit status after cleanup"
           (let* ((events nil)
                  (session (%make-test-editor-session))
                  (state (make-editor-state :session session))
                  (startup-context
                   (loom/core/editor-session:make-startup-context nil
                                                                  (make-hash-table
                                                                   :test
                                                                   #'equal)
                                                                  nil))
                  (loom/core/editor-session::*session-hooks*
                   (make-hash-table :test #'eq))
                  (*editor-state* nil))
             (loom/core/editor-session:register-session-hook :startup
                                                             :feature/lifecycle
                                                             (lambda
                                                                 (received-session
                                                                  context
                                                                  terminal-session)
                                                               (declare (ignore
                                                                         received-session
                                                                         terminal-session))
                                                               (expect context
                                                                       :to-be
                                                                       startup-context)
                                                               (push :startup
                                                                     events)))
             (loom/core/editor-session:register-session-hook :shutdown
                                                             :feature/lifecycle
                                                             (lambda
                                                                 (received-session
                                                                  reason)
                                                               (declare (ignore
                                                                         received-session))
                                                               (expect reason
                                                                       :to-be
                                                                       :normal)
                                                               (push :shutdown
                                                                     events)))
             (loom/core/editor-session:register-session-hook :exit-status
                                                             :feature/lifecycle
                                                             (lambda
                                                                 (received-session
                                                                  reason)
                                                               (declare (ignore
                                                                         received-session))
                                                               (expect reason
                                                                       :to-be
                                                                       :normal)
                                                               (push
                                                                :exit-status
                                                                events)
                                                               23))
             (with-replaced-function
              (loom::%call-with-started-editor-state
               (lambda
                   (path thunk
                         &optional
                         startup-request
                         additional-file-requests)
                 (declare (ignore path startup-request additional-file-requests))
                 (setf *editor-state* state)
                 (unwind-protect (funcall thunk state)
                   (push :services-shutdown events))))
              (with-replaced-function
               (loom::%run-loom-session
                (lambda (context fd render-frame-function)
                  (declare (ignore fd render-frame-function))
                  (loom/core/editor-session:run-session-hooks :startup
                                                              session
                                                              context
                                                              :terminal-session)
                  (loom/core/editor-session:run-session-hooks :shutdown
                                                              session
                                                              :normal)
                  (values :normal 0)))
               (expect (loom::%run-loom startup-context :fd 7) :to-equal 23)))
             (expect (reverse events)
                     :to-equal
                     '(:startup :shutdown :services-shutdown :exit-status)))))
