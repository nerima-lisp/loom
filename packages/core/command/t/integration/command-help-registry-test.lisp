(in-package #:loom/test)

(describe
  "command completion"
  (it "filters named command IDs by a case-insensitive prefix"
    (expect
     (loom/core/command:command-completion-names "  FORWARD-C  ")
     :to-equal
     (list "forward-char")))
  (it
  "returns only registered names and excludes key-only commands"
  (let ((loom/core/command::*registered-command-specs* nil))
    (loom/core/command:register-command-spec
     :test "test/alpha" "alpha" #'identity
     :mutates nil :prompts nil :needs-region nil :external nil :modes '(:all))
    (loom/core/command:register-command-spec
     :test "test/key-only" nil #'identity
     :mutates nil :prompts nil :needs-region nil :external nil :modes '(:all))
    (loom/core/command:register-command-spec
     :test "test/beta" "Beta" #'identity
     :mutates nil :prompts nil :needs-region nil :external nil :modes '(:all))
    (expect (loom/core/command:command-completion-names "")
            :to-equal (list "alpha" "beta"))
    (expect (mapcar #'loom/core/command:command-spec-id
                    (loom/core/command:command-completion-candidates ""))
            :to-equal '("test/alpha" "test/beta"))))
  (it "finds a named command spec without exposing key-only entries"
    (let ((loom/core/command::*registered-command-specs* nil))
      (loom/core/command:register-command-spec
       :test "test/key-only" nil #'identity
       :mutates nil :prompts nil :needs-region nil :external nil :modes '(:all))
      (loom/core/command:register-command-spec
       :test "test/alpha" "Alpha" #'identity
       :mutates nil :prompts nil :needs-region nil :external nil :modes '(:all))
      (expect (loom/core/command:command-spec-id
               (loom/core/command:find-extended-command-spec "  alpha "))
              :to-equal "test/alpha")
      (expect (loom/core/command:find-extended-command-spec
               "key-only")
              :to-be nil)))
  (it "treats a missing command input as empty"
    (expect (loom/core/command:find-extended-command-spec nil)
            :to-be nil))
  (it "returns no candidates for an unknown prefix"
    (expect (loom/core/command:command-completion-names "does-not-exist")
            :to-equal nil)))

(describe
  "help summary message"
  (it "does not reorder registered command specs while sorting help entries"
    (let ((loom/core/command::*registered-command-specs* nil))
      (loom/core/command:register-command-spec
       :test "test/second" "second" #'identity
       :help "Second" :help-order 10
       :mutates nil :prompts nil :needs-region nil :external nil :modes '(:all))
      (loom/core/command:register-command-spec
       :test "test/first" "first" #'identity
       :help "First" :help-order 20
       :mutates nil :prompts nil :needs-region nil :external nil :modes '(:all))
      (let ((before (mapcar #'loom/core/command:command-spec-id
                            (loom/core/command:command-specs))))
        (expect (loom/core/command:help-summary-message)
                :to-equal "Help: Second  First")
        (expect (mapcar #'loom/core/command:command-spec-id
                        (loom/core/command:command-specs))
                :to-equal before))))
  (it "builds production help text from manifest-listed command specs"
  (let* ((root (asdf:system-source-directory (asdf:find-system "loom")))
         (manifest-paths
           (directory
            (merge-pathnames "packages/*/*/t/command-ids.lisp" root)))
         (actual (loom/core/command:help-summary-message)))
    (labels
        ((read-manifest (path)
           (with-open-file (stream path)
             (let* ((*read-eval* nil)
                    (eof (list :eof))
                    (ids (read stream nil eof)))
               (unless (and (listp ids)
                            (every #'stringp ids)
                            (eq (read stream nil eof) eof))
                 (error "Invalid command ID manifest: ~A" path))
               ids))))
      (let* ((ids (loop for path in manifest-paths
                        append (read-manifest path)))
             (specs (mapcar #'loom/core/command:find-command-spec ids))
             (help-specs
               (remove-if-not
                (lambda (spec)
                  (and
                   (member (loom/core/command:command-spec-id spec) ids :test #'equal)
                   (loom/core/command::%command-spec-help spec)))
                (loom/core/command:command-specs)))
             (expected
               (format nil
                       "Help: ~{~A~^  ~}"
                       (mapcar
                        #'loom/core/command::%command-spec-help
                        (stable-sort (copy-list help-specs)
                                     #'loom/core/command::%help-spec<)))))
        (expect (plusp (length manifest-paths)) :to-be t)
        (expect (every #'identity specs) :to-be t)
        (expect actual :to-equal expected)))))
  (it "preserves registry order for equally ordered help entries"
    (let ((loom/core/command::*registered-command-specs* nil))
      (loom/core/command:register-command-spec
       :test "test/second" "second" #'identity
       :help "Second" :help-order 10
       :mutates nil :prompts nil :needs-region nil :external nil :modes '(:all))
      (loom/core/command:register-command-spec
       :test "test/first" "first" #'identity
       :help "First" :help-order 10
       :mutates nil :prompts nil :needs-region nil :external nil :modes '(:all))
      (expect (loom/core/command:help-summary-message)
              :to-equal "Help: First  Second"))))
