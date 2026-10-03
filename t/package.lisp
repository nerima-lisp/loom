(defpackage #:loom/test
  (:use #:cl #:loom #:loom/application
        #:loom/feature/mode
        #:loom/feature/syntax-highlighting
        #:loom/feature/project
        #:loom/feature/search
        #:loom/feature/file-tree
        #:loom/feature/window
        #:loom/feature/workspace
        #:loom/feature/evaluation
        #:loom/feature/shell
        #:loom/feature/format
        #:loom/feature/auto-save
        #:loom/feature/terminal
        #:loom/feature/git
        #:loom/feature/keyboard-macro
        #:loom/feature/register
        #:loom/feature/session
        #:loom/feature/user-init
        #:loom/feature/lsp)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-weave
   #:after-all
   #:after-each
   #:around-each
   #:before-all
   #:before-each
   #:describe-each
   #:it
   #:it-each
   #:it-fuzz
   #:it-isolated
   #:it-property
   #:it-skip-if
   #:expect
   #:expect-poll
   #:expect-rejects
   #:expect-resolves
   #:signals
   #:skip
   #:gen-boolean
   #:gen-character
   #:gen-integer
   #:gen-keyword
   #:gen-list
   #:gen-map
   #:gen-member
   #:gen-one-of
   #:gen-recursive
   #:gen-form
   #:gen-sexp
   #:gen-state-machine
   #:gen-string
   #:gen-such-that
   #:gen-symbol
   #:gen-tuple
   #:gen-vector
   #:with-continuation-result
   #:with-continuation-values
   #:with-cleared-hash-table
   #:with-mocked-functions
   #:with-restored-binding
   #:with-restored-bindings
   #:with-restored-hash-table
   #:with-snapshot-updates
   #:run-all
   #:run-isolated
   #:isolated-result-status
   #:isolated-result-stdout
   #:isolated-result-stderr
   #:isolated-result-exit-code
   #:isolated-result-timed-out-p
   #:make-mock-function
   #:mock-calls
   #:mock-results
   #:mock-return-value
   #:mock-return-values
   #:mock-restore
   #:spy-on
   #:dispose-mock
   #:defmatcher
   #:with-soft-assertions
   #:with-replaced-function)
  (:export #:run-tests))

(in-package #:loom/test)

(defun run-tests ()
  "Run every registered spec, signalling on any failure so ASDF's TEST-OP fails."
  (unless (run-all :reporter :spec :timeout-ms 40000
                   :pass-with-no-tests nil)
    (error "loom test suite failed"))
  (format t "~&loom/test: successful completion with 0 failures~%")
  t)
