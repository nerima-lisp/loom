;;;; t/unit/cli-test.lisp
;;;;
;;;; The CLI contract is independent from the terminal event loop: argument
;;;; parsing must select the right action and preserve an optional file path.
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
      (expect (cl-cli:positional-value invocation :path) :to-be nil))))
