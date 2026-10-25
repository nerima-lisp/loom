(in-package #:loom/test)

(describe "CLI argument parsing"
          (it "recognizes --help without dispatching the editor"
              (let ((invocation
                     (cl-cli:parse-argv loom::*loom-app* '("loom" "--help"))))
                (expect (cl-cli:invocation-action invocation) :to-be :help)))
          (it "recognizes --version without dispatching the editor"
              (let ((invocation
                     (cl-cli:parse-argv loom::*loom-app* '("loom" "--version"))))
                (expect (cl-cli:invocation-action invocation) :to-be :version)))
          (it "recognizes the documented short help and version aliases"
              (expect
               (cl-cli:invocation-action
                (cl-cli:parse-argv loom::*loom-app* '("loom" "-h")))
               :to-be
               :help)
              (expect
               (cl-cli:invocation-action
                (cl-cli:parse-argv loom::*loom-app* '("loom" "-V")))
               :to-be
               :version))
          (it
           "returns usage status for unknown options and positions without files"
           (dolist (argv (list (list "loom" "--definitely-invalid")
                               (list "loom" "+2")))
             (expect (loom::%main-exit-code argv) :to-equal 64)))
          (it "returns usage status for a missing path"
              (host-kit:with-temporary-directory (dir)
                                                 (let* ((path
                                                         (merge-pathnames
                                                          "missing.txt"
                                                          dir))
                                                        (*error-output*
                                                         (make-string-output-stream)))
                                                   (expect
                                                    (loom::%main-exit-code
                                                     (list "loom"
                                                           (namestring path)))
                                                    :to-equal
                                                    64)
                                                   (expect
                                                    (get-output-stream-string
                                                     *error-output*)
                                                    :to-contain
                                                    "PATH does not exist"))))
          (it "adapts a cl-cli invocation into a startup context"
              (let ((received-context nil))
                (with-replaced-function
                 (loom::%run-loom
                  (lambda (startup-context &key fd)
                    (expect fd :to-equal 0)
                    (setf received-context startup-context)
                    23))
                 (expect
                  (cl-cli:run-app (loom::%make-loom-app)
                                  :argv
                                  '("loom" "notes.txt"))
                  :to-equal
                  23))
                (expect
                 (loom/core/editor-session:startup-context-p received-context)
                 :to-be-truthy)
                (expect
                 (loom/core/editor-session:startup-file-request-path
                  (first
                   (loom/core/editor-session:startup-context-file-requests
                    received-context)))
                 :to-equal
                 "notes.txt")))
          (it
           "dispatches registered options and file requests through startup context"
           (let* ((loom/core/editor-session::*cli-options*
                   (make-hash-table :test (function equal)))
                  (received-context nil)
                  (call-count 0)
                  (argv
                   (list "loom"
                         "--resume"
                         "--session-file"
                         "--help"
                         "+7:3"
                         "notes.txt"
                         "other.txt")))
             (loom/core/editor-session:register-cli-option :feature/lifecycle
                                                           "--resume"
                                                           :switch)
             (loom/core/editor-session:register-cli-option :feature/lifecycle
                                                           "--session-file"
                                                           :value)
             (with-replaced-function
              (loom::%run-loom
               (lambda (context &key fd)
                 (incf call-count)
                 (setf received-context context)
                 (expect fd :to-be nil)
                 23))
              (expect (loom::%main-exit-code argv) :to-equal 23))
             (expect call-count :to-equal 1)
             (expect
              (loom/core/editor-session:startup-context-p received-context)
              :to-be
              t)
             (let ((options
                    (loom/core/editor-session:startup-context-options
                     received-context))
                   (requests
                    (loom/core/editor-session:startup-context-file-requests
                     received-context)))
               (expect (gethash "--resume" options) :to-be t)
               (expect (gethash "--session-file" options) :to-equal "--help")
               (expect (length requests) :to-equal 2)
               (expect
                (loom/core/editor-session:startup-file-request-path
                 (first requests))
                :to-equal
                "notes.txt")
               (expect
                (loom/core/editor-session:startup-file-request-line
                 (first requests))
                :to-equal
                7)
               (expect
                (loom/core/editor-session:startup-file-request-column
                 (first requests))
                :to-equal
                3)
               (expect
                (loom/core/editor-session:startup-file-request-path
                 (second requests))
                :to-equal
                "other.txt")
               (expect
                (loom/core/editor-session:startup-file-request-line
                 (second requests))
                :to-equal
                1)
               (expect
                (loom/core/editor-session:startup-file-request-column
                 (second requests))
                :to-equal
                1))
             (with-replaced-function
              (loom::%run-loom
               (lambda (context &key fd)
                 (declare (ignore fd))
                 (setf received-context context)
                 29))
              (expect (loom::%main-exit-code (list "loom" "--" "--help"))
                      :to-equal
                      29))
             (expect
              (loom/core/editor-session:startup-file-request-path
               (first
                (loom/core/editor-session:startup-context-file-requests
                 received-context)))
              :to-equal
              "--help")
             (with-replaced-function
              (loom::%run-loom
               (lambda (context &key fd)
                 (declare (ignore fd))
                 (setf received-context context)
                 31))
              (expect
               (loom::%main-exit-code
                (list "loom" "--session-file" "--dump-catalog" "notes.txt"))
               :to-equal
               31))
             (expect
              (gethash "--session-file"
                       (loom/core/editor-session:startup-context-options
                        received-context))
              :to-equal
              "--dump-catalog")))
          (it "routes standalone help and version flags through cl-cli"
              (let ((received-argv nil)
                    (flags (list "--help" "-h" "--version" "-V")))
                (with-replaced-function
                 (cl-cli:run-app
                  (lambda (app &key argv)
                    (declare (ignore app))
                    (setf received-argv argv)
                    17))
                 (dolist (flag flags)
                   (let ((argv (list "loom" flag)))
                     (expect (loom::%main-exit-code argv) :to-equal 17)
                     (expect received-argv :to-equal argv))))))
          (it "prints the command catalog without dispatching the CLI app"
              (let ((output-stream (make-string-output-stream))
                    (exit-code nil))
                (with-replaced-function
                 (cl-cli:run-app
                  (lambda (&rest arguments)
                    (declare (ignore arguments))
                    (error "--dump-catalog should bypass CL-CLI dispatch")))
                 (let ((*standard-output* output-stream))
                   (setf exit-code (loom::%main-exit-code
                                    '("loom-alias" "--dump-catalog")))))
                (expect exit-code :to-equal 0)
                (let* ((catalog
                        (json-kit:parse (get-output-stream-string output-stream)
                                        :array-type
                                        :list
                                        :object-type
                                        :hash-table))
                       (required-fields
                        '("id" "owner"
                               "name"
                               "mx-eligible"
                               "group"
                               "keymap"
                               "keys"
                               "mutates"
                               "prompts"
                               "needs-region"
                               "external"
                               "modes"))
                       (ids
                        (mapcar
                         (lambda (entry)
                           (gethash "id" entry))
                         catalog)))
                  (expect (length catalog) :to-equal 120)
                  (expect (length (remove-duplicates ids :test #'equal))
                          :to-equal
                          120)
                  (expect
                   (loop for entry in catalog
                         always (loop for field in required-fields
                                      always (nth-value 1 (gethash field entry))))
                   :to-be
                   t)
                  (expect
                   (some
                    (lambda (entry)
                      (and
                       (equal (gethash "id" entry) "execute-extended-command")
                       (equal (gethash "name" entry) "execute-extended-command")
                       (json-kit:json-false-p (gethash "mx-eligible" entry))))
                    catalog)
                   :to-be
                   t))))
          (it
           "does not treat --dump-catalog with additional arguments as the dump request"
           (let ((received-argv nil))
             (with-replaced-function
              (cl-cli:run-app
               (lambda (app &key argv)
                 (declare (ignore app))
                 (setf received-argv argv)
                 7))
              (expect
               (loom::%main-exit-code '("loom" "--dump-catalog" "notes.txt"))
               :to-equal
               7))
             (expect received-argv
                     :to-equal
                     '("loom" "--dump-catalog" "notes.txt"))))
          (it
           "rejects unknown, repeated, malformed, and incomplete startup arguments"
           (let ((loom/core/editor-session::*cli-options*
                  (make-hash-table :test (function equal))))
             (loom/core/editor-session:register-cli-option :feature/lifecycle
                                                           "--resume"
                                                           :switch)
             (loom/core/editor-session:register-cli-option :feature/lifecycle
                                                           "--session-file"
                                                           :value)
             (signals error (loom::%parse-startup-context (list "--unknown")))
             (signals error
                      (loom::%parse-startup-context (list "--session-file")))
             (signals error
                      (loom::%parse-startup-context
                       (list "--session-file" "--" "notes.txt")))
             (signals error
                      (loom::%parse-startup-context
                       (list "--resume=1" "notes.txt")))
             (signals error
                      (loom::%parse-startup-context
                       (list "--resume" "--resume" "notes.txt")))
             (signals error
                      (loom::%parse-startup-context (list "+0" "notes.txt")))
             (signals error
                      (loom::%parse-startup-context (list "+4:bad" "notes.txt")))
             (signals error (loom::%parse-startup-context (list "+2"))))))
