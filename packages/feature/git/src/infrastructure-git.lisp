(in-package #:loom/feature/git)

(defparameter *git-command-timeout-seconds* 30
  "Maximum seconds allowed for one Git command invocation.")

(defmacro define-git-operation (name lambda-list subcommand arguments documentation)
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
  "status"
  '("--short" "--branch")
  "Run Git status in DIRECTORY and return its captured process result.")

(define-git-operation run-git-diff (&key directory staged)
  "diff"
  (if staged '("--cached") nil)
  "Run Git diff in DIRECTORY and return its captured process result.")

(define-git-operation run-git-stage (path &key directory)
  "add"
  (list "--" path)
  "Stage PATH in DIRECTORY and return its captured process result.")

(define-git-operation run-git-unstage (path &key directory)
  "restore"
  (list "--staged" "--" path)
  "Remove PATH from the index in DIRECTORY and return its captured process
result.")
