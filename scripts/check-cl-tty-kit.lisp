(require :asdf)

(load (merge-pathnames #P"scripts/bootstrap.lisp" (uiop:getcwd)))

(cl-tty-kit/bootstrap:with-script-timeout ("test suite" 120)
  (cl-tty-kit/bootstrap:load-test-system)
  (unless (uiop:symbol-call :cl-weave :run-all
                          :reporter :spec :pass-with-no-tests nil)
    (error "The test suite reported a failing case or selected no tests.")))

(uiop:quit 0)
