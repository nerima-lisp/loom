(require :asdf)

(load (merge-pathnames #P"scripts/bootstrap.lisp" (uiop:getcwd)))

(cl-tty-kit/bootstrap:with-script-timeout ("test suite" 120)
  (format *standard-output* "~&[cl-tty-kit] Loading test system.~%")
  (finish-output *standard-output*)
  (let ((*compile-verbose* t))
    (cl-tty-kit/bootstrap:load-test-system))
  (format *standard-output* "~&[cl-tty-kit] Test system loaded.~%")
  (finish-output *standard-output*)
  (format *standard-output* "~&[cl-tty-kit] Starting full test suite.~%")
  (finish-output *standard-output*)
  (unless (uiop:symbol-call :cl-weave :run-all
                          :reporter :spec :pass-with-no-tests nil)
    (error "The test suite reported a failing case or selected no tests.")))

(uiop:quit 0)
