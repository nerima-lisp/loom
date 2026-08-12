;;;; t/integration/input-routing-test.lisp
;;;;
;;;; Key-event routing and undo-boundary bookkeeping from
;;;; src/application/input-routing-*.lisp. These tests need the editor-state
;;;; helpers from commands-test.lisp but not the event-loop/startup harness.
(in-package #:loom/test)

(describe
  "%key-event->descriptor"
  (it
    "rewrites a :special :control-<letter> event into ((:control) . <letter>)"
    (let ((event (cl-tty-kit:make-key-event :type :special :code :control-x)))
      (expect (loom::%key-event->descriptor event) :to-equal (cons '(:control) #\x))))

  (it
    "passes a plain character event through unchanged, wrapped as (modifiers . code)"
    (let ((event (cl-tty-kit:make-key-event :type :character :code #\a)))
      (expect (loom::%key-event->descriptor event) :to-equal (cons nil #\a))))

  (it
    "passes a character event with an explicit :control modifier through unchanged"
    (let ((event (cl-tty-kit:make-key-event :type :character :code #\f :modifiers '(:control))))
      (expect (loom::%key-event->descriptor event) :to-equal (cons '(:control) #\f))))

  (it
    "passes a non-control :special event (e.g. an arrow key) through unchanged"
    (let ((event (cl-tty-kit:make-key-event :type :special :code :up)))
      (expect (loom::%key-event->descriptor event) :to-equal (cons nil :up)))))

(describe
  "%record-undo-boundary-for-command"
  (it
    "records a boundary when the command kind differs from the last one"
    (let ((*editor-state* (%fresh-editor-state "ab")))
      (setf (loom::editor-state-last-command-self-insert-p *editor-state*) nil)
      (let ((buffer (%selected-test-buffer)))
        (buffer-insert-string buffer "x")
        (loom:record-undo-boundary-for-command t)
        (buffer-insert-string buffer "y")
        (loom::undo-command)
        (expect (buffer-line buffer 0) :to-equal "xab"))))

  (it
    "does not record a boundary between consecutive same-kind commands"
    (let ((*editor-state* (%fresh-editor-state "")))
      (setf (loom::editor-state-last-command-self-insert-p *editor-state*) t)
      (let ((buffer (%selected-test-buffer)))
        (buffer-insert-string buffer "x")
        (loom:record-undo-boundary-for-command t)
        (buffer-insert-string buffer "y")
        (loom::undo-command)
        (expect (buffer-line buffer 0) :to-equal ""))))

  (it
    "updates last-command-self-insert-p for the next call"
    (let ((*editor-state* (%fresh-editor-state "")))
      (loom:record-undo-boundary-for-command t)
      (expect (loom::editor-state-last-command-self-insert-p *editor-state*) :to-be t))))

(describe
  "%dispatch-key-event"
  (it
    "routes to minibuffer-handle-key while the minibuffer is active"
    (let* ((state (%fresh-editor-state "hi"))
           (minibuffer (make-minibuffer))
           (*editor-state* state)
           (keymap-state (make-keymap-state (make-keymap)))
           (confirmed nil))
      (setf (editor-state-minibuffer state) minibuffer)
      (minibuffer-activate minibuffer "Prompt: "
                           :on-confirm (lambda (input) (setf confirmed input)))
      (loom::%dispatch-key-event (cl-tty-kit:make-key-event :type :character :code #\a) keymap-state)
      (loom::%dispatch-key-event (cl-tty-kit:make-key-event :type :special :code :enter) keymap-state)
      (expect confirmed :to-equal "a"))))
