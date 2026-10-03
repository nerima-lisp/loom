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
   #:expect-has-assertions
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
   #:list-tests
   #:clear-tests
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

(before-each
  (expect-has-assertions))

(defun %run-test-suite (&key name-filter)
  "Run the selected specs after proving collection was non-empty."
  (let ((selected-tests
          (list-tests :reporter :sexp
                      :stream (make-broadcast-stream)
                      :name-filter name-filter)))
    (unless selected-tests
      (error "loom test suite collected no tests"))
    (unless (run-all :reporter :spec
                     :timeout-ms 40000
                     :name-filter name-filter
                     :pass-with-no-tests nil)
      (error "loom test suite failed")))
  t)

(defun run-tests ()
  "Run every registered spec, signalling on collection or assertion failure."
  (%run-test-suite)
  (format t "~&loom/test: successful completion with 0 failures~%")
  t)
