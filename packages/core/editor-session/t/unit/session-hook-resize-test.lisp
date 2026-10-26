(in-package #:loom/test)

(describe "session resize hooks"
  (it "dispatches width and height to registered hooks"
    (let* ((loom/core/editor-session::*session-hooks*
             (make-hash-table :test #'eq))
           (session (%make-test-editor-session))
           (received nil))
      (loom/core/editor-session:register-session-hook
       :resize
       :feature/terminal
       (lambda (hook-session columns rows)
         (setf received (list hook-session columns rows))
         (list columns rows)))
      (expect
       (loom/core/editor-session:run-session-hooks :resize session 100 40)
       :to-equal
       (list (list 100 40)))
      (expect received :to-equal (list session 100 40)))))
