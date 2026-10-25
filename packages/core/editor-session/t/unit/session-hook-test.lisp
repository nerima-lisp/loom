(in-package #:loom/test)

(progn
  (describe "session hook registry" (it
             "orders hooks by owner, deduplicates registrations, and snapshots dispatch"
             (let* ((loom/core/editor-session::*session-hooks*
                     (make-hash-table :test #'eq))
                    (session (%make-test-editor-session))
                    (events nil)
                    (deferred-registration-p nil)
                    (deferred
                     (lambda (session argument)
                       (declare (ignore session))
                       (push (list :deferred argument) events)
                       (list :deferred argument)))
                    (early
                     (lambda (session argument)
                       (declare (ignore session))
                       (push (list :early argument) events)
                       (unless deferred-registration-p
                         (setf deferred-registration-p t)
                         (loom/core/editor-session:register-session-hook :tick
                                                                         :feature/user-init
                                                                         deferred))
                       (list :early argument)))
                    (later
                     (lambda (session argument)
                       (declare (ignore session))
                       (push (list :later argument) events)
                       (list :later argument)))
                    (later-in-same-owner
                     (lambda (session argument)
                       (declare (ignore session))
                       (push (list :same-owner-later argument) events)
                       (list :same-owner-later argument))))
               (loom/core/editor-session:register-session-hook :tick
                                                               :feature/auto-save
                                                               later)
               (loom/core/editor-session:register-session-hook :tick
                                                               :feature/buffers
                                                               later)
               (loom/core/editor-session:register-session-hook :tick
                                                               :feature/auto-save
                                                               later)
               (loom/core/editor-session:register-session-hook :tick
                                                               :feature/auto-save
                                                               later-in-same-owner)
               (loom/core/editor-session:register-session-hook :tick
                                                               :feature/format
                                                               early)
               (expect
                (loom/core/editor-session:run-session-hooks :tick
                                                            session
                                                            "first")
                :to-equal
                (list (list :later "first")
                      (list :early "first")
                      (list :later "first")
                      (list :same-owner-later "first")))
               (expect (nreverse events)
                       :to-equal
                       (list (list :later "first")
                             (list :early "first")
                             (list :later "first")
                             (list :same-owner-later "first")))
               (setf events nil)
               (expect
                (loom/core/editor-session:run-session-hooks :tick
                                                            session
                                                            "second")
                :to-equal
                (list (list :later "second")
                      (list :early "second")
                      (list :later "second")
                      (list :same-owner-later "second")
                      (list :deferred "second")))
               (expect (nreverse events)
                       :to-equal
                       (list (list :later "second")
                             (list :early "second")
                             (list :later "second")
                             (list :same-owner-later "second")
                             (list :deferred "second")))))
            (it
             "stops key input at handled and returns pass when input events pass"
             (let* ((loom/core/editor-session::*session-hooks*
                     (make-hash-table :test #'eq))
                    (session (%make-test-editor-session))
                    (events nil)
                    (key-event (gensym "KEY-EVENT-"))
                    (event-payload (gensym "EVENT-PAYLOAD-"))
                    (later
                     (lambda (session event route)
                       (declare (ignore session))
                       (push (list :later event route) events)
                       :pass))
                    (handled
                     (lambda (session event route)
                       (declare (ignore session))
                       (push (list :handled event route) events)
                       :handled))
                    (early
                     (lambda (session event route)
                       (declare (ignore session))
                       (push (list :early event route) events)
                       :pass)))
               (loom/core/editor-session:register-session-hook :key-input
                                                               :feature/buffers
                                                               early)
               (loom/core/editor-session:register-session-hook :key-input
                                                               :feature/format
                                                               handled)
               (loom/core/editor-session:register-session-hook :key-input
                                                               :feature/auto-save
                                                               later)
               (expect
                (loom/core/editor-session:run-session-hooks :key-input
                                                            session
                                                            key-event
                                                            :key)
                :to-equal
                :handled)
               (expect (nreverse events)
                       :to-equal
                       (list (list :early key-event :key)
                             (list :handled key-event :key)))
               (setf events nil)
               (expect
                (loom/core/editor-session:run-session-hooks :key-input
                                                            session
                                                            key-event
                                                            :macro)
                :to-equal
                :handled)
               (expect (nreverse events)
                       :to-equal
                       (list (list :early key-event :macro)
                             (list :handled key-event :macro)))
               (setf events nil)
               (clrhash loom/core/editor-session::*session-hooks*)
               (loom/core/editor-session:register-session-hook :input-event
                                                               :feature/auto-save
                                                               later)
               (loom/core/editor-session:register-session-hook :input-event
                                                               :feature/format
                                                               early)
               (expect
                (loom/core/editor-session:run-session-hooks :input-event
                                                            session
                                                            :paste
                                                            event-payload)
                :to-equal
                :pass)
               (expect (nreverse events)
                       :to-equal
                       (list (list :early :paste event-payload)
                             (list :later :paste event-payload)))))
            (it
             "returns tick, render, terminal-mode, before-save, and after-save results"
             (let* ((loom/core/editor-session::*session-hooks*
                     (make-hash-table :test #'eq))
                    (session (%make-test-editor-session))
                    (frame
                     (loom/core/editor-session:make-frame-snapshot 1
                                                                   1
                                                                   (vector
                                                                    (list "x"
                                                                          nil))))
                    (buffer (gensym "BUFFER-"))
                    (render-frame-seen-p nil)
                    (operation
                     (loom/core/editor-session:make-render-operation :text
                                                                     0
                                                                     0
                                                                     "x")))
               (loom/core/editor-session:register-session-hook :tick
                                                               :core/command
                                                               (lambda
                                                                   (session
                                                                    value)
                                                                 (declare (ignore
                                                                           session))
                                                                 (list :tick
                                                                       value)))
               (loom/core/editor-session:register-session-hook :render
                                                               :feature/window
                                                               (lambda
                                                                   (session
                                                                    received-frame)
                                                                 (declare (ignore
                                                                           session))
                                                                 (setf render-frame-seen-p (eq
                                                                                            received-frame
                                                                                            frame))
                                                                 (list
                                                                  operation)))
               (loom/core/editor-session:register-session-hook :terminal-modes
                                                               :feature/clipboard
                                                               (lambda (session)
                                                                 (declare (ignore
                                                                           session))
                                                                 (list
                                                                  :bracketed-paste)))
               (loom/core/editor-session:register-session-hook :terminal-modes
                                                               :feature/mouse
                                                               (lambda (session)
                                                                 (declare (ignore
                                                                           session))
                                                                 (list
                                                                  :mouse-sgr
                                                                  :mouse-button-event)))
               (loom/core/editor-session:register-session-hook :before-save
                                                               :feature/format
                                                               (lambda
                                                                   (session
                                                                    received-buffer)
                                                                 (declare (ignore
                                                                           session))
                                                                 (list :before
                                                                       received-buffer)))
               (loom/core/editor-session:register-session-hook :after-save
                                                               :feature/auto-save
                                                               (lambda
                                                                   (session
                                                                    received-buffer)
                                                                 (declare (ignore
                                                                           session))
                                                                 (list :after
                                                                       received-buffer)))
               (expect
                (loom/core/editor-session:run-session-hooks :tick session 17)
                :to-equal
                (list (list :tick 17)))
               (expect
                (loom/core/editor-session:run-session-hooks :render
                                                            session
                                                            frame)
                :to-equal
                (list (list operation)))
               (expect render-frame-seen-p :to-be t)
               (expect
                (loom/core/editor-session:run-session-hooks :terminal-modes
                                                            session)
                :to-equal
                (list (list :bracketed-paste)
                      (list :mouse-sgr :mouse-button-event)))
               (expect
                (loom/core/editor-session:run-session-hooks :before-save
                                                            session
                                                            buffer)
                :to-equal
                (list (list :before buffer)))
               (expect
                (loom/core/editor-session:run-session-hooks :after-save
                                                            session
                                                            buffer)
                :to-equal
                (list (list :after buffer)))))
            (it
             "rejects invalid kinds, owners, callback values, and hook results"
             (let ((loom/core/editor-session::*session-hooks*
                    (make-hash-table :test #'eq)))
               (signals error
                        (loom/core/editor-session:register-session-hook :unknown
                                                                        :core/command
                                                                        #'identity))
               (signals error
                        (loom/core/editor-session:register-session-hook :tick
                                                                        "core/command"
                                                                        #'identity))
               (progn
                 (signals type-error
                          (loom/core/editor-session:register-session-hook
                           :tick
                           :core/command
                           42))
                 (signals error
                          (loom/core/editor-session:register-session-hook
                           :tick
                           :feature/unknown
                           (function identity))))
               (loom/core/editor-session:register-session-hook :tick
                                                               :feature/lifecycle
                                                               (lambda
                                                                   (session
                                                                    monotonic-time)
                                                                 (declare (ignore
                                                                           session
                                                                           monotonic-time))
                                                                 :lifecycle))
               (expect
                (loom/core/editor-session:run-session-hooks :tick
                                                            (%make-test-editor-session)
                                                            0)
                :to-equal
                (list :lifecycle)))
             (let ((loom/core/editor-session::*session-hooks*
                    (make-hash-table :test #'eq)))
               (loom/core/editor-session:register-session-hook :key-input
                                                               :core/command
                                                               (lambda
                                                                   (session
                                                                    key-event
                                                                    route)
                                                                 (declare (ignore
                                                                           session
                                                                           key-event
                                                                           route))
                                                                 :consume))
               (signals error
                        (loom/core/editor-session:run-session-hooks :key-input
                                                                    (%make-test-editor-session)
                                                                    (gensym
                                                                     "KEY-EVENT-")
                                                                    :key)))
             (let ((loom/core/editor-session::*session-hooks*
                    (make-hash-table :test #'eq)))
               (loom/core/editor-session:register-session-hook :render
                                                               :core/command
                                                               (lambda
                                                                   (session
                                                                    frame)
                                                                 (declare (ignore
                                                                           session
                                                                           frame))
                                                                 :not-an-operation-list))
               (signals error
                        (loom/core/editor-session:run-session-hooks :render
                                                                    (%make-test-editor-session)
                                                                    (loom/core/editor-session:make-frame-snapshot
                                                                     1
                                                                     1
                                                                     (vector
                                                                      (list "x"
                                                                            nil))))))
             (let ((loom/core/editor-session::*session-hooks*
                    (make-hash-table :test #'eq)))
               (loom/core/editor-session:register-session-hook :terminal-modes
                                                               :core/command
                                                               (lambda (session)
                                                                 (declare (ignore
                                                                           session))
                                                                 (list
                                                                  :unknown-mode)))
               (signals error
                        (loom/core/editor-session:run-session-hooks
                         :terminal-modes
                         (%make-test-editor-session)))))
            (it
             "dispatches lifecycle and buffer-close hooks under their declared owners"
             (let* ((loom/core/editor-session::*session-hooks*
                     (make-hash-table :test #'eq))
                    (session (%make-test-editor-session))
                    (startup-context (gensym "STARTUP-CONTEXT-"))
                    (terminal-session (gensym "TERMINAL-SESSION-"))
                    (buffer (gensym "BUFFER-"))
                    (events nil))
               (loom/core/editor-session:register-session-hook :startup
                                                               :feature/lifecycle
                                                               (lambda
                                                                   (received-session
                                                                    context
                                                                    terminal)
                                                                 (declare (ignore
                                                                           received-session))
                                                                 (push
                                                                  (list :startup
                                                                        context
                                                                        terminal)
                                                                  events)
                                                                 :started))
               (loom/core/editor-session:register-session-hook :signal
                                                               :feature/lifecycle
                                                               (lambda
                                                                   (received-session
                                                                    signal-name)
                                                                 (declare (ignore
                                                                           received-session))
                                                                 (push
                                                                  (list :signal
                                                                        signal-name)
                                                                  events)
                                                                 (if (member
                                                                      signal-name
                                                                      (list
                                                                       :term
                                                                       :hup)
                                                                      :test
                                                                      #'eq)
                                                                     :terminate
                                                                     :continue)))
               (loom/core/editor-session:register-session-hook :suspend
                                                               :feature/lifecycle
                                                               (lambda
                                                                   (received-session)
                                                                 (declare (ignore
                                                                           received-session))
                                                                 (push
                                                                  (list
                                                                   :suspend)
                                                                  events)
                                                                 :suspended))
               (loom/core/editor-session:register-session-hook :resume
                                                               :feature/lifecycle
                                                               (lambda
                                                                   (received-session
                                                                    terminal)
                                                                 (declare (ignore
                                                                           received-session))
                                                                 (push
                                                                  (list :resume
                                                                        terminal)
                                                                  events)
                                                                 :resumed))
               (loom/core/editor-session:register-session-hook :shutdown
                                                               :feature/lifecycle
                                                               (lambda
                                                                   (received-session
                                                                    reason)
                                                                 (declare (ignore
                                                                           received-session))
                                                                 (push
                                                                  (list
                                                                   :shutdown
                                                                   reason)
                                                                  events)
                                                                 :shutdown))
               (loom/core/editor-session:register-session-hook :exit-status
                                                               :feature/lifecycle
                                                               (lambda
                                                                   (received-session
                                                                    reason)
                                                                 (declare (ignore
                                                                           received-session))
                                                                 (push
                                                                  (list
                                                                   :exit-status
                                                                   reason)
                                                                  events)
                                                                 (cond
                                                                   ((eq reason
                                                                        :sigterm)
                                                                    143)
                                                                   ((eq reason
                                                                        :sighup)
                                                                    129)
                                                                   (t 0))))
               (loom/core/editor-session:register-session-hook :buffer-close
                                                               :feature/lsp
                                                               (lambda
                                                                   (received-session
                                                                    closed-buffer
                                                                    reason)
                                                                 (declare (ignore
                                                                           received-session))
                                                                 (push
                                                                  (list
                                                                   :buffer-close
                                                                   closed-buffer
                                                                   reason)
                                                                  events)
                                                                 nil))
               (expect
                (loom/core/editor-session:run-session-hooks :startup
                                                            session
                                                            startup-context
                                                            terminal-session)
                :to-equal
                (list :started))
               (expect
                (loom/core/editor-session:run-session-hooks :signal
                                                            session
                                                            :term)
                :to-equal
                (list :terminate))
               (expect
                (loom/core/editor-session:run-session-hooks :signal
                                                            session
                                                            :hup)
                :to-equal
                (list :terminate))
               (expect
                (loom/core/editor-session:run-session-hooks :signal
                                                            session
                                                            :tstp)
                :to-equal
                (list :continue))
               (expect
                (loom/core/editor-session:run-session-hooks :signal
                                                            session
                                                            :cont)
                :to-equal
                (list :continue))
               (expect
                (loom/core/editor-session:run-session-hooks :suspend session)
                :to-equal
                (list :suspended))
               (expect
                (loom/core/editor-session:run-session-hooks :resume
                                                            session
                                                            terminal-session)
                :to-equal
                (list :resumed))
               (expect
                (loom/core/editor-session:run-session-hooks :shutdown
                                                            session
                                                            :normal)
                :to-equal
                (list :shutdown))
               (expect
                (loom/core/editor-session:run-session-hooks :exit-status
                                                            session
                                                            :sigterm)
                :to-equal
                (list 143))
               (expect
                (loom/core/editor-session:run-session-hooks :exit-status
                                                            session
                                                            :sighup)
                :to-equal
                (list 129))
               (expect
                (loom/core/editor-session:run-session-hooks :buffer-close
                                                            session
                                                            buffer
                                                            :session-restore)
                :to-equal
                (list nil))
               (expect (nreverse events)
                       :to-equal
                       (list (list :startup startup-context terminal-session)
                             (list :signal :term)
                             (list :signal :hup)
                             (list :signal :tstp)
                             (list :signal :cont)
                             (list :suspend)
                             (list :resume terminal-session)
                             (list :shutdown :normal)
                             (list :exit-status :sigterm)
                             (list :exit-status :sighup)
                             (list :buffer-close buffer :session-restore)))
               (dolist
                   (kind
                    '(:startup :signal :suspend :resume :shutdown :exit-status))
                 (signals error
                          (loom/core/editor-session:register-session-hook kind
                                                                          :feature/files
                                                                          #'identity)))
               (signals error
                        (loom/core/editor-session:register-session-hook
                         :exit-status
                         :core/command
                         #'identity))))
            (it "validates signal and exit-status hook results"
                (let ((loom/core/editor-session::*session-hooks*
                       (make-hash-table :test #'eq)))
                  (loom/core/editor-session:register-session-hook :signal
                                                                  :feature/lifecycle
                                                                  (lambda
                                                                      (session
                                                                       signal-name)
                                                                    (declare (ignore
                                                                              session
                                                                              signal-name))
                                                                    :keep-running))
                  (signals error
                           (loom/core/editor-session:run-session-hooks :signal
                                                                       (%make-test-editor-session)
                                                                       :term)))
                (let ((loom/core/editor-session::*session-hooks*
                       (make-hash-table :test #'eq)))
                  (loom/core/editor-session:register-session-hook :exit-status
                                                                  :feature/lifecycle
                                                                  (lambda
                                                                      (session
                                                                       reason)
                                                                    (declare (ignore
                                                                              session
                                                                              reason))
                                                                    256))
                  (signals error
                           (loom/core/editor-session:run-session-hooks
                            :exit-status
                            (%make-test-editor-session)
                            :normal)))
                (let ((loom/core/editor-session::*session-hooks*
                       (make-hash-table :test #'eq)))
                  (loom/core/editor-session:register-session-hook :exit-status
                                                                  :feature/lifecycle
                                                                  (lambda
                                                                      (session
                                                                       reason)
                                                                    (declare (ignore
                                                                              session
                                                                              reason))
                                                                    -1))
                  (signals error
                           (loom/core/editor-session:run-session-hooks
                            :exit-status
                            (%make-test-editor-session)
                            :normal)))
                (let ((loom/core/editor-session::*session-hooks*
                       (make-hash-table :test #'eq)))
                  (loom/core/editor-session:register-session-hook :exit-status
                                                                  :feature/lifecycle
                                                                  (lambda
                                                                      (session
                                                                       reason)
                                                                    (declare (ignore
                                                                              session
                                                                              reason))
                                                                    0))
                  (expect
                   (loom/core/editor-session:run-session-hooks :exit-status
                                                               (%make-test-editor-session)
                                                               :normal)
                   :to-equal
                   (list 0)))
                (let ((loom/core/editor-session::*session-hooks*
                       (make-hash-table :test #'eq)))
                  (loom/core/editor-session:register-session-hook :exit-status
                                                                  :feature/lifecycle
                                                                  (lambda
                                                                      (session
                                                                       reason)
                                                                    (declare (ignore
                                                                              session
                                                                              reason))
                                                                    255))
                  (expect
                   (loom/core/editor-session:run-session-hooks :exit-status
                                                               (%make-test-editor-session)
                                                               :normal)
                   :to-equal
                   (list 255))))
            (it "coalesces pending terminal-suspend requests"
                (let ((session (%make-test-editor-session))
                      (other-session (%make-test-editor-session)))
                  (expect (loom/core/editor-session:request-terminal-suspend session) :to-equal :queued)
                  (expect (loom/core/editor-session:request-terminal-suspend session)
                          :to-equal
                          :coalesced)
                  (expect (loom/core/editor-session:request-terminal-suspend other-session)
                          :to-equal
                          :queued)))
            (it "wakes the root once for a new terminal-suspend request"
                (let* ((loom/core/editor-session::*terminal-suspend-requests*
                        (make-hash-table :test #'eq))
                       (loom/core/editor-session::*session-wake-functions*
                        (make-hash-table :test #'eq))
                       (session (%make-test-editor-session))
                       (wake-count 0))
                  (loom/core/editor-session:set-session-wake-function session
                                                                      (lambda
                                                                          (received-session)
                                                                        (declare (ignore
                                                                                  received-session))
                                                                        (incf
                                                                         wake-count)))
                  (expect (loom/core/editor-session:request-terminal-suspend session) :to-equal :queued)
                  (expect (loom/core/editor-session:request-terminal-suspend session)
                          :to-equal
                          :coalesced)
                  (expect wake-count :to-equal 1)))
            (it
             "registers unique CLI option names and rejects conflicting registrations"
             (let* ((loom/core/editor-session::*cli-options*
                     (make-hash-table :test #'equal))
                    (switch-name "--resume")
                    (value-name "--session-file"))
               (loom/core/editor-session:register-cli-option :feature/lifecycle
                                                             switch-name
                                                             :switch)
               (loom/core/editor-session:register-cli-option :feature/lifecycle
                                                             value-name
                                                             :value)
               (signals error
                        (loom/core/editor-session:register-cli-option
                         :feature/lifecycle
                         switch-name
                         :switch))
               (signals error
                        (loom/core/editor-session:register-cli-option
                         :feature/files
                         "--foreign-owner"
                         :switch))
               (signals error
                        (loom/core/editor-session:register-cli-option
                         :feature/lifecycle
                         "-resume"
                         :switch))
               (signals error
                        (loom/core/editor-session:register-cli-option
                         :feature/lifecycle
                         (concatenate 'string
                                      "--"
                                      (symbol-name (gensym "W2A-BAD-")))
                         :invalid-value-kind))))
            (it
             "coalesces ready tokens, polls each once in FIFO order, and removes done work"
             (let* ((session (%make-test-editor-session))
                    (polled nil)
                    (token-a
                     (loom/core/editor-session:register-background-work session
                                               :feature/search
                                               (lambda (received-session token)
                                                 (declare (ignore
                                                           received-session))
                                                 (push token polled)
                                                 (values t t))
                                               (lambda (&rest arguments)
                                                 (declare (ignore arguments)))))
                    (token-b
                     (loom/core/editor-session:register-background-work session
                                               :feature/project
                                               (lambda (received-session token)
                                                 (declare (ignore
                                                           received-session))
                                                 (push token polled)
                                                 (values nil t))
                                               (lambda (&rest arguments)
                                                 (declare (ignore arguments))))))
               (expect (loom/core/editor-session:notify-background-work-ready session token-a)
                       :to-equal
                       :queued)
               (expect (loom/core/editor-session:notify-background-work-ready session token-b)
                       :to-equal
                       :queued)
               (expect (loom/core/editor-session:notify-background-work-ready session token-a)
                       :to-equal
                       :coalesced)
               (multiple-value-bind (frame-dirty-p more-ready-p)
                   (loom/core/editor-session:poll-ready-background-work session)
                 (expect frame-dirty-p :to-be t)
                 (expect more-ready-p :to-be nil))
               (expect (nreverse polled) :to-equal (list token-a token-b))
               (expect (loom/core/editor-session:notify-background-work-ready session token-a)
                       :to-equal
                       :ignored)
               (expect (loom/core/editor-session:notify-background-work-ready session token-b)
                       :to-equal
                       :ignored)))
            (it "wakes once when background work first becomes ready"
                (let* ((loom/core/editor-session::*background-work-states*
                        (make-hash-table :test #'eq))
                       (loom/core/editor-session::*session-wake-functions*
                        (make-hash-table :test #'eq))
                       (session (%make-test-editor-session))
                       (wake-count 0)
                       (poller
                        (lambda (received-session token)
                          (declare (ignore received-session token))
                          (values nil nil)))
                       (cancel-function
                        (lambda (received-session token)
                          (declare (ignore received-session token))))
                       (token-a
                        (loom/core/editor-session:register-background-work session
                                                  :feature/search
                                                  poller
                                                  cancel-function))
                       (token-b
                        (loom/core/editor-session:register-background-work session
                                                  :feature/project
                                                  poller
                                                  cancel-function)))
                  (loom/core/editor-session:set-session-wake-function session
                                                                      (lambda
                                                                          (received-session)
                                                                        (declare (ignore
                                                                                  received-session))
                                                                        (incf
                                                                         wake-count)))
                  (expect (loom/core/editor-session:notify-background-work-ready session token-a)
                          :to-equal
                          :queued)
                  (expect (loom/core/editor-session:notify-background-work-ready session token-b)
                          :to-equal
                          :queued)
                  (expect (loom/core/editor-session:notify-background-work-ready session token-a)
                          :to-equal
                          :coalesced)
                  (expect wake-count :to-equal 1)
                  (multiple-value-bind (frame-dirty-p more-ready-p)
                      (loom/core/editor-session:poll-ready-background-work session)
                    (expect frame-dirty-p :to-be nil)
                    (expect more-ready-p :to-be nil))
                  (expect (loom/core/editor-session:notify-background-work-ready session token-b)
                          :to-equal
                          :queued)
                  (expect wake-count :to-equal 2)))
            (it
             "queues a notification during polling for the next event-loop turn"
             (let* ((session (%make-test-editor-session))
                    (poll-count 0)
                    (renotify-result nil)
                    (token nil))
               (setf token (loom/core/editor-session:register-background-work session
                                                     :feature/search
                                                     (lambda
                                                         (received-session
                                                          received-token)
                                                       (declare (ignore
                                                                 received-session))
                                                       (incf poll-count)
                                                       (if (= poll-count 1)
                                                           (progn
                                                             (setf renotify-result (loom/core/editor-session:notify-background-work-ready session received-token))
                                                             (values t nil))
                                                           (values nil t)))
                                                     (lambda (&rest arguments)
                                                       (declare (ignore
                                                                 arguments)))))
               (expect (loom/core/editor-session:notify-background-work-ready session token)
                       :to-equal
                       :queued)
               (multiple-value-bind (frame-dirty-p more-ready-p)
                   (loom/core/editor-session:poll-ready-background-work session)
                 (expect frame-dirty-p :to-be t)
                 (expect more-ready-p :to-be t))
               (expect renotify-result :to-equal :queued)
               (expect poll-count :to-equal 1)
               (multiple-value-bind (frame-dirty-p more-ready-p)
                   (loom/core/editor-session:poll-ready-background-work session)
                 (expect frame-dirty-p :to-be nil)
                 (expect more-ready-p :to-be nil))
               (expect poll-count :to-equal 2)
               (expect (loom/core/editor-session:notify-background-work-ready session token)
                       :to-equal
                       :ignored)))
            (it
             "cancels work once, suppresses cancelled dirty results, and propagates poll errors"
             (let* ((session (%make-test-editor-session))
                    (cancel-count 0)
                    (cancelled-token
                     (loom/core/editor-session:register-background-work session
                                               :feature/search
                                               (lambda (received-session token)
                                                 (declare (ignore
                                                           received-session
                                                           token))
                                                 (values t t))
                                               (lambda (&rest arguments)
                                                 (declare (ignore arguments))
                                                 (incf cancel-count)))))
               (loom/core/editor-session:cancel-background-work session cancelled-token)
               (loom/core/editor-session:cancel-background-work session cancelled-token)
               (expect cancel-count :to-equal 1)
               (expect (loom/core/editor-session:notify-background-work-ready session cancelled-token)
                       :to-equal
                       :queued)
               (multiple-value-bind (frame-dirty-p more-ready-p)
                   (loom/core/editor-session:poll-ready-background-work session)
                 (expect frame-dirty-p :to-be nil)
                 (expect more-ready-p :to-be nil))
               (expect (loom/core/editor-session:notify-background-work-ready session cancelled-token)
                       :to-equal
                       :ignored))
             (let* ((session (%make-test-editor-session))
                    (token
                     (loom/core/editor-session:register-background-work session
                                               :feature/search
                                               (lambda
                                                   (received-session
                                                    received-token)
                                                 (declare (ignore
                                                           received-session
                                                           received-token))
                                                 (error "poller failed"))
                                               (lambda (&rest arguments)
                                                 (declare (ignore arguments))))))
               (loom/core/editor-session:notify-background-work-ready session token)
               (signals error (loom/core/editor-session:poll-ready-background-work session))))
            (it "parses registered CLI options and copies startup file requests"
                (let* ((loom/core/editor-session::*cli-options*
                        (make-hash-table :test #'equal))
                       (argv
                        (list "--resume"
                              "--session-file"
                              "state file"
                              "+7:3"
                              "file one"
                              "notes.txt"))
                       (context nil))
                  (loom/core/editor-session:register-cli-option
                   :feature/lifecycle
                   "--resume"
                   :switch)
                  (loom/core/editor-session:register-cli-option
                   :feature/lifecycle
                   "--session-file"
                   :value)
                  (setf context (loom::%parse-startup-context argv))
                  (expect (loom/core/editor-session:startup-context-argv context) :to-equal argv)
                  (let ((options (loom/core/editor-session:startup-context-options context)))
                    (expect (gethash "--resume" options) :to-be t)
                    (expect (gethash "--session-file" options)
                            :to-equal
                            "state file")
                    (setf (gethash "--session-file" options) "changed")
                    (expect
                     (gethash "--session-file"
                              (loom/core/editor-session:startup-context-options context))
                     :to-equal
                     "state file"))
                  (let ((argv-copy (loom/core/editor-session:startup-context-argv context)))
                    (setf (char (first argv-copy) 2) #\X)
                    (expect (loom/core/editor-session:startup-context-argv context) :to-equal argv))
                  (let* ((requests (loom/core/editor-session:startup-context-file-requests context))
                         (first-request (first requests))
                         (second-request (second requests))
                         (returned-path
                          (loom/core/editor-session:startup-file-request-path first-request)))
                    (expect (length requests) :to-equal 2)
                    (expect (loom/core/editor-session:startup-file-request-p first-request) :to-be t)
                    (expect returned-path :to-equal "file one")
                    (expect (loom/core/editor-session:startup-file-request-line first-request)
                            :to-equal
                            7)
                    (expect (loom/core/editor-session:startup-file-request-column first-request)
                            :to-equal
                            3)
                    (expect (loom/core/editor-session:startup-file-request-path second-request)
                            :to-equal
                            "notes.txt")
                    (expect (loom/core/editor-session:startup-file-request-line second-request)
                            :to-equal
                            1)
                    (expect (loom/core/editor-session:startup-file-request-column second-request)
                            :to-equal
                            1)
                    (setf (char returned-path 0) #\X)
                    (expect (loom/core/editor-session:startup-file-request-path first-request)
                            :to-equal
                            "file one")
                    (setf (first requests) nil)
                    (expect (length (loom/core/editor-session:startup-context-file-requests context))
                            :to-equal
                            2))
                  (let* ((line-only-context
                          (loom::%parse-startup-context
                           (list "+8" "line-only.txt")))
                         (request
                          (first
                           (loom/core/editor-session:startup-context-file-requests line-only-context))))
                    (expect (loom/core/editor-session:startup-file-request-line request) :to-equal 8)
                    (expect (loom/core/editor-session:startup-file-request-column request) :to-equal 1))
                  (signals error
                           (loom::%parse-startup-context
                            (list "--unregistered")))))
            (it "propagates hook errors and skips later hooks"
                (let* ((loom/core/editor-session::*session-hooks*
                        (make-hash-table :test (function eq)))
                       (session (%make-test-editor-session))
                       (events nil))
                  (loom/core/editor-session:register-session-hook
                   :tick
                   :core/command
                   (lambda (&rest arguments)
                     (declare (ignore arguments))
                     (push :before events)))
                  (loom/core/editor-session:register-session-hook
                   :tick
                   :core/minibuffer
                   (lambda (&rest arguments)
                     (declare (ignore arguments))
                     (push :failing events)
                     (error "hook failed")))
                  (loom/core/editor-session:register-session-hook
                   :tick
                   :feature/lifecycle
                   (lambda (&rest arguments)
                     (declare (ignore arguments))
                     (push :after events)))
                  (signals simple-error
                           (loom/core/editor-session:run-session-hooks :tick session))
                  (expect (nreverse events)
                          :to-equal
                          (quote (:before :failing)))))))

(progn
  (describe "public session extension APIs"
            (it
             "looks up registered CLI option kinds and returns NIL for unknown names"
             (let ((loom/core/editor-session::*cli-options*
                    (make-hash-table :test (function equal))))
               (loom/core/editor-session:register-cli-option :feature/lifecycle
                                                             "--resume"
                                                             :switch)
               (loom/core/editor-session:register-cli-option :feature/lifecycle
                                                             "--session-file"
                                                             :value)
               (expect
                (loom/core/editor-session:cli-option-value-kind "--resume")
                :to-be
                :switch)
               (expect
                (loom/core/editor-session:cli-option-value-kind
                 "--session-file")
                :to-be
                :value)
               (expect
                (loom/core/editor-session:cli-option-value-kind "--unknown")
                :to-be
                nil)))
            (it "consumes each queued terminal-suspend request once"
                (let* ((loom/core/editor-session::*terminal-suspend-requests*
                        (make-hash-table :test (function eq)))
                       (session (%make-test-editor-session)))
                  (expect (loom/core/editor-session:request-terminal-suspend session) :to-equal :queued)
                  (expect
                   (loom/core/editor-session:consume-terminal-suspend-request
                    session)
                   :to-be
                   t)
                  (expect
                   (loom/core/editor-session:consume-terminal-suspend-request
                    session)
                   :to-be
                   nil)
                  (expect (loom/core/editor-session:request-terminal-suspend session) :to-equal :queued)))
            (it "clears the root wake callback when given NIL"
                (let* ((loom/core/editor-session::*terminal-suspend-requests*
                        (make-hash-table :test (function eq)))
                       (loom/core/editor-session::*session-wake-functions*
                        (make-hash-table :test (function eq)))
                       (session (%make-test-editor-session))
                       (wake-count 0))
                  (loom/core/editor-session:set-session-wake-function session
                                                                      (lambda
                                                                          (received-session)
                                                                        (declare (ignore
                                                                                  received-session))
                                                                        (incf
                                                                         wake-count)))
                  (expect (loom/core/editor-session:request-terminal-suspend session) :to-equal :queued)
                  (loom/core/editor-session:consume-terminal-suspend-request
                   session)
                  (loom/core/editor-session:set-session-wake-function session
                                                                      nil)
                  (expect (loom/core/editor-session:request-terminal-suspend session) :to-equal :queued)
                  (loom/core/editor-session:consume-terminal-suspend-request
                   session)
                  (expect wake-count :to-equal 1)
                  (signals error
                           (loom/core/editor-session:set-session-wake-function
                            session
                            :invalid))))
            (it "cancels every registered background item only once"
                (let* ((loom/core/editor-session::*background-work-states*
                        (make-hash-table :test (function eq)))
                       (session (%make-test-editor-session))
                       (cancel-count-a 0)
                       (cancel-count-b 0))
                  (loom/core/editor-session:register-background-work session
                                                                     :feature/search
                                                                     (lambda
                                                                         (received-session
                                                                          token)
                                                                       (declare (ignore
                                                                                 received-session
                                                                                 token))
                                                                       (values
                                                                        nil
                                                                        nil))
                                                                     (lambda
                                                                         (received-session
                                                                          token)
                                                                       (declare (ignore
                                                                                 received-session
                                                                                 token))
                                                                       (incf
                                                                        cancel-count-a)))
                  (loom/core/editor-session:register-background-work session
                                                                     :feature/project
                                                                     (lambda
                                                                         (received-session
                                                                          token)
                                                                       (declare (ignore
                                                                                 received-session
                                                                                 token))
                                                                       (values
                                                                        nil
                                                                        nil))
                                                                     (lambda
                                                                         (received-session
                                                                          token)
                                                                       (declare (ignore
                                                                                 received-session
                                                                                 token))
                                                                       (incf
                                                                        cancel-count-b)))
                  (loom/core/editor-session:cancel-session-background-work
                   session)
                  (loom/core/editor-session:cancel-session-background-work
                   session)
                  (expect cancel-count-a :to-equal 1)
                  (expect cancel-count-b :to-equal 1)))))
