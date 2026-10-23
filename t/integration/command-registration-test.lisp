(in-package #:loom/test)

(describe "command registration"
  (it "keeps the command catalogue unique and symbol-based"
    (let ((specs loom/core/command:*command-specs*))
      (expect specs :to-be-truthy)
      (expect (loop for spec in specs
                    for command = (getf spec :command)
                    always (and (or (null (getf spec :name))
                                    (stringp (getf spec :name)))
                                (symbolp command)))
              :to-be t)
      (let ((names (remove nil (mapcar (lambda (spec)
                                         (getf spec :name))
                                       specs))))
        (expect (count nil specs :key (lambda (spec) (getf spec :name)))
                :to-equal 1)
        (expect (length (remove-duplicates names :test #'string-equal))
                :to-equal (length names)))))

  (it "serializes the catalog schema and key metadata as JSON"
    (let* ((catalog
             (json-kit:parse (loom/application:command-catalog-json)
                             :array-type :list
                             :object-type :hash-table))
           (required-fields
             '("name" "mx-eligible" "group" "keys" "mutates" "prompts" "needs-region" "external" "modes")))
      (expect (length catalog) :to-equal 120)
      (expect (loop for entry in catalog
                    always (loop for field in required-fields
                                  always (nth-value 1 (gethash field entry))))
              :to-be t)
      (expect (some (lambda (entry) (and (equal (gethash "name" entry) "execute-extended-command") (json-kit:json-false-p (gethash "mx-eligible" entry)))) catalog)
              :to-be t)))

  (it "serializes a fixed command spec with the declared JSON shape"
    (let* ((json
             (json-kit:stringify
              (loom/core/command::%command-spec-json
               '(:name nil
                 :group "movement"
                 :command forward-char
                 :keys ((:control #\f))
                 :mutates t
                 :prompts (:free-string :completion)
                 :needs-region nil
                 :external ("rg")
                 :modes (:common-lisp)))))
           (entry (json-kit:parse json
                                  :array-type :list
                                  :object-type :hash-table))
           (binding (first (gethash "keys" entry)))
           (chord (first (gethash "sequence" binding))))
      (expect (and (equal (gethash "name" entry) "forward-char") (json-kit:json-false-p (gethash "mx-eligible" entry))) :to-be t)
      (expect (gethash "group" entry) :to-equal "movement")
      (expect (gethash "keymap" binding) :to-equal "global")
      (expect (gethash "modifiers" chord) :to-equal '("control"))
      (expect (gethash "key" chord) :to-equal "f")
      (expect (gethash "mutates" entry) :to-be t)
      (expect (gethash "prompts" entry)
              :to-equal '("free-string" "completion"))
      (expect (json-kit:json-false-p (gethash "needs-region" entry))
              :to-be t)
      (expect (gethash "external" entry) :to-equal '("rg"))
      (expect (gethash "modes" entry) :to-equal '("common-lisp"))))

  (it "appends trace events with extensible routes and process identifiers"
  (host-kit:with-temporary-directory (directory)
    (let ((trace-path
            (namestring (merge-pathnames "commands.jsonl" directory)))
          (loom/core/command::*command-trace-sequence* 0))
      (with-replaced-function
          (uiop:getenv
           (lambda (name)
             (when (string= name "LOOM_TRACE_COMMANDS") trace-path)))
        (loom/core/command:record-command-trace
         (loom/application:find-extended-command "forward-char") :key)
        (loom/core/command:record-command-trace
         (loom/application:find-extended-command "backward-char") :mx)
        (loom/core/command:record-command-trace
         (loom/application:find-extended-command "next-line") :mouse))
      (with-open-file (stream trace-path)
        (let ((key-event (json-kit:parse (read-line stream)))
              (m-x-event (json-kit:parse (read-line stream)))
              (mouse-event (json-kit:parse (read-line stream))))
          (expect (gethash "command" key-event) :to-equal "forward-char")
          (expect (gethash "route" key-event) :to-equal "key")
          (expect (gethash "seq" key-event) :to-equal 1)
          (expect (gethash "command" m-x-event) :to-equal "backward-char")
          (expect (gethash "route" m-x-event) :to-equal "mx")
          (expect (gethash "seq" m-x-event) :to-equal 2)
          (expect (gethash "command" mouse-event) :to-equal "next-line")
          (expect (gethash "route" mouse-event) :to-equal "mouse")
          (expect (gethash "seq" mouse-event) :to-equal 3)
          (expect (gethash "pid" key-event) :to-equal (sb-posix:getpid))
          (expect (gethash "pid" m-x-event) :to-equal (sb-posix:getpid))
          (expect (gethash "pid" mouse-event) :to-equal (sb-posix:getpid))
          (expect (read-line stream nil) :to-be nil))))))

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
                 (keymap (loom/application:install-default-keybindings (make-keymap)))
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
            (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "backward-char")
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
  (it "binds M-x to execute-extended-command"
    (let ((keymap (make-keymap)))
      (loom/application:install-default-keybindings keymap)
      (expect (keymap-lookup keymap (list (cons (quote (:alt)) #\x)))
              :to-be (quote loom::execute-extended-command)))))
