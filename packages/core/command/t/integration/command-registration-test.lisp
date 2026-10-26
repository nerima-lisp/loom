(in-package #:loom/test)

(describe "command registration"
  (it "requires all five classification metadata keys at registration"
    (let ((loom/core/command::*registered-command-specs* nil)
          (metadata '(:keys nil
                      :keymap :global
                      :group nil
                      :mutates nil
                      :prompts nil
                      :needs-region nil
                      :external nil
                      :modes (:all))))
      (dolist (missing '(:mutates :prompts :needs-region :external :modes))
        (signals error
          (apply #'loom/core/command:register-command-spec
                 :test
                 "test/missing-metadata"
                 nil
                 #'identity
                 (loop for (key value) on metadata by #'cddr
                       unless (eq key missing)
                         append (list key value)))))))

  (it "keeps stable IDs unique and makes identical owner registrations idempotent"
    (let ((loom/core/command::*registered-command-specs* nil))
      (let ((spec (loom/core/command:register-command-spec
                   :test "test/stable-id" "stable-name" #'identity
                   :keys nil :keymap :global :group nil
                   :mutates nil :prompts nil :needs-region nil
                   :external nil :modes '(:all))))
        (expect (loom/core/command:register-command-spec
                 :test "test/stable-id" "stable-name" #'identity
                 :keys nil :keymap :global :group nil
                 :mutates nil :prompts nil :needs-region nil
                 :external nil :modes '(:all))
                :to-be spec)
        (expect (length (loom/core/command:command-specs)) :to-equal 1)
        (signals error
          (loom/core/command:register-command-spec
           :another-owner "test/stable-id" "other-name" #'identity
           :keys nil :keymap :global :group nil
           :mutates nil :prompts nil :needs-region nil
           :external nil :modes '(:all)))
        (signals error
          (loom/core/command:register-command-spec
           :test "test/stable-id" "changed-name" #'identity
           :keys nil :keymap :global :group nil
           :mutates nil :prompts nil :needs-region nil
           :external nil :modes '(:all))))))
  (it "refreshes the callable for a repeated owner ID during system reload"
    (let ((loom/core/command::*registered-command-specs* nil)
          (old-command (lambda () :old))
          (new-command (lambda () :new)))
      (loom/core/command:register-command-spec
       :test "test/reload" "reload" old-command
       :keys nil :keymap :global :group nil
       :mutates nil :prompts nil :needs-region nil
       :external nil :modes (list :all))
      (let ((spec (loom/core/command:register-command-spec
                   :test "test/reload" "reload" new-command
                   :keys nil :keymap :global :group nil
                   :mutates nil :prompts nil :needs-region nil
                   :external nil :modes (list :all))))
        (expect (loom/core/command:find-command-spec "test/reload")
                :to-be spec)
        (expect (loom/core/command:invoke-command "test/reload" :mx)
                :to-equal :new)
        (expect (length (loom/core/command:command-specs)) :to-equal 1))))

  (it "rejects case-insensitive command name collisions across IDs"
    (let ((loom/core/command::*registered-command-specs* nil))
      (loom/core/command:register-command-spec
       :test "test/first" "same-name" #'identity
       :keys nil :keymap :global :group nil
       :mutates nil :prompts nil :needs-region nil
       :external nil :modes '(:all))
      (signals error
        (loom/core/command:register-command-spec
         :other "test/second" "SAME-NAME" #'identity
         :keys nil :keymap :global :group nil
         :mutates nil :prompts nil :needs-region nil
         :external nil :modes '(:all)))))

  (it "rejects exact and prefix key conflicts only within the same keymap"
    (let ((loom/core/command::*registered-command-specs* nil))
      (loom/core/command:register-command-spec
       :test "test/key-one" "key-one" #'identity
       :keys '((:control #\x)) :keymap :global :group nil
       :mutates nil :prompts nil :needs-region nil
       :external nil :modes '(:all))
      (signals error
        (loom/core/command:register-command-spec
         :test "test/key-exact" "key-exact" #'identity
         :keys '((:control #\x)) :keymap :global :group nil
         :mutates nil :prompts nil :needs-region nil
         :external nil :modes '(:all)))
      (signals error
        (loom/core/command:register-command-spec
         :test "test/key-prefix" "key-prefix" #'identity
         :keys '((( :control #\x) (:control #\s))) :keymap :global :group nil
         :mutates nil :prompts nil :needs-region nil
         :external nil :modes '(:all)))
      (loom/core/command:register-command-spec
       :test "test/other-map" "other-map" #'identity
       :keys '((:control #\x)) :keymap :local :group nil
       :mutates nil :prompts nil :needs-region nil
       :external nil :modes '(:all)))
    (let ((loom/core/command::*registered-command-specs* nil))
      (loom/core/command:register-command-spec
       :test "test/prefix-a" "prefix-a" #'identity
       :keys '((( :control #\x) (:control #\s))) :keymap :local :group nil
       :mutates nil :prompts nil :needs-region nil
       :external nil :modes '(:all))
      (loom/core/command:register-command-spec
       :test "test/prefix-b" "prefix-b" #'identity
       :keys '((( :control #\x) (:control #\c))) :keymap :local :group nil
       :mutates nil :prompts nil :needs-region nil
       :external nil :modes '(:all))
      (expect (length (loom/core/command:command-specs)) :to-equal 2)))

  (it
  "exposes the full catalog by ID and preserves the legacy name fallback"
  (let* ((catalog
           (json-kit:parse (loom/core/command:command-catalog-json)
                           :array-type :list
                           :object-type :hash-table))
         (required-fields
           '("id" "owner" "name" "mx-eligible" "group" "keymap" "keys"
             "mutates" "prompts" "needs-region" "external" "modes"))
         (ids (mapcar (lambda (entry) (gethash "id" entry)) catalog))
         (extended
           (loom/core/command:find-command-spec "execute-extended-command")))
    (expect (length catalog) :to-equal 131)
    (expect (length (remove-duplicates ids :test #'equal)) :to-equal 131)
    (expect (loop for entry in catalog
                  always (loop for field in required-fields
                               always (nth-value 1 (gethash field entry))))
            :to-be t)
    (expect (loom/core/command:command-spec-name extended) :to-be nil)
    (expect (loom/core/command:find-extended-command-spec
             "execute-extended-command")
            :to-be nil)
    (expect (some
             (lambda (entry)
               (and (equal (gethash "id" entry) "execute-extended-command")
                    (equal (gethash "name" entry) "execute-extended-command")
                    (json-kit:json-false-p (gethash "mx-eligible" entry))))
             catalog)
            :to-be t)
    (expect (member "execute-extended-command"
                    (loom/core/command:command-completion-names ""))
            :to-be nil)))

  (it
  "serializes owner, keymap, key sequence, and classification metadata"
  (let* ((loom/core/command::*registered-command-specs* nil)
         (spec (loom/core/command:register-command-spec
                :test "test/catalog-entry" nil #'identity
                :keys '((:control #\f)) :keymap :sample
                :group "movement" :help nil :help-order nil
                :mutates t :prompts '(:free-string :completion)
                :needs-region nil :external '("rg")
                :modes '(:common-lisp)))
         (entry (json-kit:parse
                 (json-kit:stringify
                  (loom/core/command::%command-spec-json spec))
                 :array-type :list
                 :object-type :hash-table))
         (binding (first (gethash "keys" entry)))
         (chord (first (gethash "sequence" binding))))
    (expect (gethash "id" entry) :to-equal "test/catalog-entry")
    (expect (gethash "owner" entry) :to-equal "test")
    (expect (eq (gethash "name" entry) json-kit:+json-null+) :to-be t)
    (expect (gethash "keymap" entry) :to-equal "sample")
    (expect (gethash "keymap" binding) :to-equal "sample")
    (expect (gethash "group" entry) :to-equal "movement")
    (expect (gethash "modifiers" chord) :to-equal '("control"))
    (expect (gethash "key" chord) :to-equal "f")
    (expect (gethash "mutates" entry) :to-be t)
    (expect (gethash "prompts" entry)
            :to-equal '("free-string" "completion"))
    (expect (json-kit:json-false-p (gethash "needs-region" entry))
            :to-be t)
    (expect (gethash "external" entry) :to-equal '("rg"))
    (expect (gethash "modes" entry) :to-equal '("common-lisp"))))

  (it "forwards gateway arguments and records routes, key context, and prefix snapshots"
    (host-kit:with-temporary-directory (directory)
      (let* ((loom/core/command::*registered-command-specs* nil)
             (loom/core/command::*command-trace-sequence* 0)
             (trace-path (namestring (merge-pathnames "commands.jsonl" directory)))
             (arguments nil)
             (command (lambda (&rest values) (setf arguments values)))
             (spec (loom/core/command:register-command-spec
                    :test "test/gateway" "gateway" command
                    :keys nil :keymap :global :group nil
                    :mutates nil :prompts nil :needs-region nil
                    :external nil :modes '(:all)))
             (prefix (loom/core/command:make-prefix-argument))
             (*editor-state* (%fresh-editor-state "")))
        (declare (ignore spec))
        (setf (editor-state-prefix-argument *editor-state*) prefix)
        (loom/core/command:prefix-argument-universal prefix)
        (with-replaced-function
            (uiop:getenv
             (lambda (name)
               (when (string= name "LOOM_TRACE_COMMANDS") trace-path)))
          (expect (loom/core/command:invoke-command "test/gateway" :mx "visible-argument" 7)
                  :to-equal '("visible-argument" 7))
          (expect arguments :to-equal '("visible-argument" 7))
          (loom/core/command:prefix-argument-digit prefix 3)
          (expect (loom/core/command:invoke-key-command
                   "test/gateway" :key (list *ctrl-x*) "global"
                   "sensitive-argument" 9)
                  :to-equal '("sensitive-argument" 9))
          (expect arguments :to-equal '("sensitive-argument" 9)))
        (with-open-file (stream trace-path)
          (let* ((mx-line (read-line stream nil))
                 (key-line (read-line stream nil))
                 (mx-event (json-kit:parse mx-line))
                 (key-event (json-kit:parse key-line))
                 (entry (gethash "entry" key-event)))
            (expect (gethash "command" mx-event) :to-equal "test/gateway")
            (expect (gethash "route" mx-event) :to-equal "mx")
            (expect (gethash "seq" mx-event) :to-equal 1)
            (expect (gethash "prefix" mx-event) :to-equal 4)
            (expect (json-kit:json-false-p (gethash "prefix-explicit" mx-event))
                    :to-be t)
            (expect (gethash "command" key-event) :to-equal "test/gateway")
            (expect (gethash "route" key-event) :to-equal "key")
            (expect (gethash "seq" key-event) :to-equal 2)
            (expect (gethash "prefix" key-event) :to-equal 3)
            (expect (gethash "prefix-explicit" key-event) :to-be t)
            (expect (search "global" entry) :to-be-truthy)
            (expect (search "control" entry) :to-be-truthy)
            (expect (search "x" entry) :to-be-truthy)
            (expect (search "visible-argument" mx-line) :to-be nil)
            (expect (search "sensitive-argument" key-line) :to-be nil)
            (expect (read-line stream nil) :to-be nil))))))
  (it "accepts paste and mouse routes and rejects unsupported routes"
    (host-kit:with-temporary-directory (directory)
      (let* ((loom/core/command::*registered-command-specs* nil)
             (loom/core/command::*command-trace-sequence* 0)
             (trace-path (namestring (merge-pathnames "commands.jsonl" directory)))
             (calls nil)
             (paste-payload "paste-payload")
             (mouse-payload '(:button :left :x 4 :y 2 :marker "mouse-payload"))
             (command (lambda (&rest arguments)
                        (setf calls (append calls (list arguments)))
                        (first arguments))))
        (loom/core/command:register-command-spec
         :test "test/input-event-routes" "input-event-routes" command
         :keys nil :keymap :global :group nil
         :mutates nil :prompts nil :needs-region nil
         :external nil :modes '(:all))
        (with-replaced-function
            (uiop:getenv
             (lambda (name)
               (when (string= name "LOOM_TRACE_COMMANDS") trace-path)))
          (expect (loom/core/command:invoke-command
                   "test/input-event-routes" :paste paste-payload)
                  :to-equal paste-payload)
          (expect (loom/core/command:invoke-command
                   "test/input-event-routes" :mouse mouse-payload)
                  :to-equal mouse-payload))
        (expect calls :to-equal (list (list paste-payload) (list mouse-payload)))
        (with-open-file (stream trace-path)
          (let* ((paste-line (read-line stream nil))
                 (mouse-line (read-line stream nil))
                 (paste-event (json-kit:parse paste-line))
                 (mouse-event (json-kit:parse mouse-line)))
            (expect (gethash "command" paste-event)
                    :to-equal "test/input-event-routes")
            (expect (gethash "route" paste-event) :to-equal "paste")
            (expect (gethash "seq" paste-event) :to-equal 1)
            (expect (gethash "command" mouse-event)
                    :to-equal "test/input-event-routes")
            (expect (gethash "route" mouse-event) :to-equal "mouse")
            (expect (gethash "seq" mouse-event) :to-equal 2)
            (expect (search "paste-payload" paste-line) :to-be nil)
            (expect (search "mouse-payload" mouse-line) :to-be nil)
            (expect (read-line stream nil) :to-be nil)))
        (signals error
          (loom/core/command:invoke-command "test/input-event-routes" :unsupported))
        (expect calls :to-equal (list (list paste-payload) (list mouse-payload))))))

  (it "continues key and M-x commands when trace writes fail"
    (host-kit:with-temporary-directory (directory)
      (let ((trace-path
              (namestring (merge-pathnames "missing/commands.jsonl" directory)))
            (loom/core/command::*command-trace-sequence* 0))
        (with-replaced-function
            (uiop:getenv
             (lambda (name)
               (when (string= name "LOOM_TRACE_COMMANDS") trace-path)))
          (let* ((state (%fresh-editor-state "hi" :with-minibuffer t))
                 (*editor-state* state)
                 (minibuffer (editor-state-minibuffer state))
                 (keymap (loom/core/command:install-default-keybindings (make-keymap)))
                 (keymap-state (make-keymap-state keymap))
                 (buffer (%selected-test-buffer)))
            (setf (editor-state-keymap state) keymap)
            (loom::%dispatch-key-event
             (cl-tty-kit:make-key-event :type :character :code #\f
                                        :modifiers '(:control))
             keymap-state)
            (expect (buffer-point-column buffer) :to-equal 1)
            (expect (loom:minibuffer-message-string minibuffer)
                    :to-contain "Could not append LOOM_TRACE_COMMANDS")
            (loom::execute-extended-command)
            (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer)
                     "backward-char")
            (expect (buffer-point-column buffer) :to-equal 0)
            (expect (loom:minibuffer-message-string minibuffer)
                    :to-contain "Could not append LOOM_TRACE_COMMANDS")
            (expect loom/core/command::*command-trace-sequence* :to-equal 0)))))))

(describe "execute-extended-command"
  (it "resolves a registered command through the command-spec registry"
    (%with-minibuffer-state (minibuffer "hi")
      (loom::execute-extended-command)
      (%expect-minibuffer-prompt minibuffer (%m-x-prompt-string))
      (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "  FORWARD-CHAR  ")
      (expect (buffer-point-column (%selected-test-buffer)) :to-equal 1)))
  (it "completes a registered command with Tab"
    (%with-minibuffer-state (minibuffer "hi")
      (loom::execute-extended-command)
      (%type-string minibuffer "forward-c")
      (minibuffer-handle-key minibuffer (%special-key :tab))
      (expect (minibuffer-input-string minibuffer) :to-equal "forward-char")
      (minibuffer-handle-key minibuffer (%special-key :enter))
      (expect (buffer-point-column (%selected-test-buffer)) :to-equal 1)))
  (it "reports an unregistered command without evaluating it"
    (%with-minibuffer-state (minibuffer "hi")
      (loom::execute-extended-command)
      (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "not-a-command")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Unknown command: not-a-command")))
  (it "binds M-x to the stable command ID"
    (let ((keymap (make-keymap)))
      (loom/core/command:install-default-keybindings keymap)
      (expect (keymap-lookup keymap (list (cons '(:alt) #\x)))
              :to-equal "execute-extended-command"))))
