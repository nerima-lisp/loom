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
          (it "opens startup files below missing directories as empty registered buffers"
              (host-kit:with-temporary-directory (directory)
                (let* ((first-path (merge-pathnames "missing/deep/first.txt" directory))
                       (second-path (merge-pathnames "second.txt" directory))
                       (*editor-state* nil))
                  (with-replaced-function
                   (loom::%initial-terminal-size
                    (lambda ()
                      (values 80 24)))
                   (loom::%initialize-editor-state
                    (namestring first-path)
                    (list (namestring second-path))))
                  (let* ((state *editor-state*)
                         (session (editor-state-session state))
                         (buffers (loom/feature/buffers:registered-buffers session))
                         (file-tree-root
                          (first
                           (loom/feature/file-tree:file-tree-prefetch-paths
                            (editor-state-file-tree state)))))
                    (expect (length buffers) :to-equal 2)
                    (expect (mapcar (function loom/core/buffer:buffer-text) buffers)
                            :to-equal
                            (list "" ""))
                    (expect (mapcar (function loom/core/buffer:buffer-name)
                                    (reverse buffers))
                            :to-equal
                            (list "first.txt" "second.txt"))
                    (expect (mapcar (function file-namestring)
                                    (mapcar (function loom/core/buffer:buffer-path)
                                            buffers))
                            :to-equal
                            (list "second.txt" "first.txt"))
                    (expect (probe-file first-path) :to-be nil)
                    (expect (probe-file second-path) :to-be nil)
                    (expect (probe-file
                             (host-kit:pathname-directory-pathname first-path))
                            :to-be
                            nil)
                    (expect (host-kit:directory-exists-p file-tree-root) :to-be t)
                    (expect file-tree-root :to-equal (probe-file directory))))))
          (it
           "saves a missing startup file directly without an external-change prompt"
           (host-kit:with-temporary-directory (directory)
                                              (let* ((path (merge-pathnames "created.txt" directory))
                                                     (*editor-state* nil))
                                                (expect (probe-file path) :to-be nil)
                                                (with-replaced-function
                                                 (loom::%initial-terminal-size
                                                  (lambda ()
                                                    (values 80 24)))
                                                 (loom::%initialize-editor-state (namestring path)))
                                                (let* ((state *editor-state*)
                                                       (session (editor-state-session state))
                                                       (buffer
                                                        (loom/core/window-tree:window-buffer
                                                         (loom/core/window-tree:window-tree-selected-window
                                                          (editor-state-window-tree state))))
                                                       (loom/core/editor-session:*editor-session* session))
                                                  (loom/core/buffer:buffer-insert-string buffer "created")
                                                  (loom/feature/files:save-buffer)
                                                  (expect (host-kit:read-file-string path) :to-equal "created")
                                                  (expect
                                                   (loom:minibuffer-prompt-string (editor-state-minibuffer state))
                                                   :to-be
                                                   nil)
                                                  (expect (loom/core/buffer:buffer-modified-p buffer) :to-be nil)))))
          (it "defaults to \".\" as root when given no argument"
              (multiple-value-bind (file root)
                  (loom::%startup-file-and-root nil)
                (expect file :to-be nil)
                (expect root :to-equal ".")))
          (it
           "includes search and project states in the normal startup session"
           (host-kit:with-temporary-directory (directory)
             (let* ((state
                      (loom::%make-startup-editor-state
                       nil (namestring directory) 80 24))
                    (session (editor-state-session state))
                    (slice-names
                      (loom/core/editor-session:editor-session-slice-names
                       session)))
               (expect (not (null (member :feature/search slice-names)))
                       :to-be
                       t)
               (expect (not (null (member :feature/project slice-names)))
                       :to-be
                       t)))))

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
