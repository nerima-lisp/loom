(in-package #:loom/feature/git)

(defparameter *git-command-timeout-seconds* 30
  "Maximum seconds allowed for one Git command invocation.")

(defmacro define-git-operation (name lambda-list documentation subcommand arguments)
  "Define a captured Git operation from declarative command metadata.

ARGUMENTS is evaluated in the lexical environment established by LAMBDA-LIST;
the generated function owns the process boundary while callers only provide
domain arguments."
  `(defun ,name ,lambda-list
     ,documentation
     (vcs-kit:run-git nil ,subcommand ,arguments
                      :directory directory
                      :timeout *git-command-timeout-seconds*)))

(define-git-operation run-git-status (&key directory)
  "Run Git status in DIRECTORY and return its captured process result."
  "status"
  '("--short" "--branch"))

(define-git-operation run-git-diff (&key directory staged)
  "Run Git diff in DIRECTORY and return its captured process result."
  "diff"
  (and staged '("--cached")))

(define-git-operation run-git-stage (path &key directory)
  "Stage PATH in DIRECTORY and return its captured process result."
  "add"
  (list "--" path))

(define-git-operation run-git-unstage (path &key directory)
  "Remove PATH from the index in DIRECTORY and return its captured process
result."
  "restore"
  (list "--staged" "--" path))
