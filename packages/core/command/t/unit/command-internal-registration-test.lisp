(in-package #:loom/test)
(describe "internal command registration"
  (it "keeps registered internal commands out of the public catalog and trace"
    (host-kit:with-temporary-directory (directory)
      (let* ((loom/core/command::*registered-command-specs* nil)
             (loom/core/command::*command-trace-sequence* 0)
             (trace-path
               (namestring (merge-pathnames "commands.jsonl" directory)))
             (spec (loom/core/command:register-internal-command
                    :test "test/internal-command"
                    (lambda () :called)
                    :mutates nil :prompts nil :needs-region nil
                    :external nil :modes '(:all))))
        (expect (loom/core/command:find-command-spec "test/internal-command")
                :to-be spec)
        (expect (loom/core/command:command-spec-id spec)
                :to-equal "test/internal-command")
        (with-replaced-function
            (uiop:getenv
             (lambda (name)
               (when (string= name "LOOM_TRACE_COMMANDS") trace-path)))
          (expect (loom/core/command:invoke-command "test/internal-command" :mx)
                  :to-equal :called))
        (expect (search "test/internal-command"
                        (loom/core/command:command-catalog-json))
                :to-be nil)
        (expect (probe-file trace-path) :to-be nil)
        (expect loom/core/command::*command-trace-sequence* :to-equal 0)))))
