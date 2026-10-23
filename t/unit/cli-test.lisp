(in-package #:loom/test)

(describe
  "CLI argument parsing"
  (it
    "recognizes --help without dispatching the editor"
    (let ((invocation (cl-cli:parse-argv loom::*loom-app* '("loom" "--help"))))
      (expect (cl-cli:invocation-action invocation) :to-be :help)))

  (it
    "recognizes --version without dispatching the editor"
    (let ((invocation (cl-cli:parse-argv loom::*loom-app* '("loom" "--version"))))
      (expect (cl-cli:invocation-action invocation) :to-be :version)))

  (it
    "recognizes the documented short help and version aliases"
    (expect (cl-cli:invocation-action
             (cl-cli:parse-argv loom::*loom-app* '("loom" "-h")))
            :to-be :help)
    (expect (cl-cli:invocation-action
             (cl-cli:parse-argv loom::*loom-app* '("loom" "-V")))
            :to-be :version))

  (it
    "stores an optional file path as the :path positional"
    (let ((invocation (cl-cli:parse-argv loom::*loom-app* '("loom" "notes.txt"))))
      (expect (cl-cli:invocation-action invocation) :to-be :dispatch)
      (expect (cl-cli:positional-value invocation :path) :to-equal "notes.txt")))

  (it
    "leaves the path absent when no positional argument is given"
    (let ((invocation (cl-cli:parse-argv loom::*loom-app* '("loom"))))
      (expect (cl-cli:invocation-action invocation) :to-be :dispatch)
      (expect (cl-cli:positional-value invocation :path) :to-be nil)))

  (it
    "prints the command catalog without dispatching the CLI app"
    (let ((output-stream (make-string-output-stream))
          (exit-code nil))
      (with-replaced-function
          (cl-cli:run-app
           (lambda (&rest arguments)
             (declare (ignore arguments))
             (error "--dump-catalog should bypass CL-CLI dispatch")))
        (let ((*standard-output* output-stream))
          (setf exit-code
                (loom::%main-exit-code '("loom-alias" "--dump-catalog")))))
      (expect exit-code :to-equal 0)
      (let* ((catalog
               (json-kit:parse (get-output-stream-string output-stream)
                               :array-type :list
                               :object-type :hash-table))
             (required-fields
               '("name" "mx-eligible" "group" "keys" "mutates" "prompts" "needs-region" "external" "modes")))
        (expect (length catalog) :to-equal 120)
        (expect (loop for entry in catalog
                      always (loop for field in required-fields
                                    always (nth-value 1 (gethash field entry))))
                :to-be t))))

  (it
    "does not treat --dump-catalog with additional arguments as the dump request"
    (let ((received-argv nil))
      (with-replaced-function
          (cl-cli:run-app
           (lambda (app &key argv)
             (declare (ignore app))
             (setf received-argv argv)
             7))
        (expect (loom::%main-exit-code
                 '("loom" "--dump-catalog" "notes.txt"))
                :to-equal 7))
      (expect received-argv :to-equal '("loom" "--dump-catalog" "notes.txt")))))
