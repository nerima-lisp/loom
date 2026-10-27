(in-package #:loom/test)

(describe "clipboard paste"
          (it
           "enables bracketed paste and inserts paste input literally as one undo"
           (let* ((*editor-state* (%fresh-editor-state ""))
                  (session (editor-state-session *editor-state*))
                  (buffer (%selected-test-buffer))
                  (text (format nil "before~%line1~%~Cline2" #\Tab)))
             (buffer-insert-string buffer "before")
             (setf (loom/core/editor-session:editor-state-last-command-self-insert-p
                    *editor-state*) t)
             (expect
              (some
               (lambda (modes)
                 (member :bracketed-paste modes))
               (loom/core/editor-session:run-session-hooks :terminal-modes
                                                           session))
              :to-be-truthy)
             (expect
              (loom/core/editor-session:run-session-hooks :input-event
                                                          session
                                                          :paste
                                                          (format nil "~%line1~%~Cline2" #\Tab))
              :to-equal
              :handled)
             (expect (buffer-text buffer) :to-equal text)
             (buffer-undo buffer)
             (expect (buffer-text buffer) :to-equal "before"))))
