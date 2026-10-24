(in-package #:loom/test)

(describe
  "keymap-state-dispatch"
  (it
    "passes the normalized completed sequence and owning keymap to its invoker"
    (let* ((invoked nil)
           (command (lambda () (setf invoked t) :saved))
           (dispatched nil)
           (input-first (cons '(:meta :control) #\x))
           (normalized-first (cons '(:control :meta) #\x))
           (sequence (list normalized-first *ctrl-s*))
           (keymap (make-keymap :name "test"))
           (invoker
             (lambda (bound-command dispatched-sequence keymap-name)
               (setf dispatched
                     (list bound-command dispatched-sequence keymap-name))
               (loom/core/command:invoke-key-command bound-command :key dispatched-sequence keymap-name))))
      (progn (%register-test-command command) (keymap-define-key keymap sequence command))
      (let ((state (make-keymap-state keymap)))
        (expect (keymap-state-dispatch state input-first invoker)
                :to-equal :pending)
        (expect (keymap-state-dispatch state *ctrl-s* invoker)
                :to-equal :saved)
        (expect invoked :to-be-truthy)
        (expect (first dispatched) :to-equal (loom/core/command:command-id-for-function command))
        (expect (second dispatched) :to-equal sequence)
        (expect (third dispatched) :to-equal "test")
        (expect (keymap-state-sequence state) :to-equal nil))))

  (it
    "resets accumulated sequence to empty on an unbound key"
    (let* ((keymap (make-keymap))
           (state (make-keymap-state keymap))
           (invoker (lambda (command sequence keymap-name) (declare (ignore command sequence keymap-name)) :ok)))
      (expect (keymap-state-dispatch state (cons nil #\q) invoker)
              :to-be-falsy)
      (expect (keymap-state-sequence state) :to-equal nil)
      (keymap-define-key keymap (list (cons nil #\q)) "forward-char")
      (expect (keymap-state-dispatch state (cons nil #\q) invoker)
              :to-equal :ok))))
