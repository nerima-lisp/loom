;;;; t/unit/minibuffer-input-activation-test.lisp
;;;;
;;;; Activation, cancellation, editing, and inactive behavior for
;;;; src/application/minibuffer-input.lisp.
(in-package #:loom/test)

(describe
  "minibuffer activation and cancellation"
  (it
    "types input and invokes ON-CONFIRM with it, then deactivates"
    (let ((minibuffer (make-minibuffer))
          (confirmed nil))
      (minibuffer-activate minibuffer "Find file: "
                           :on-confirm (lambda (input) (setf confirmed input)))
      (expect (minibuffer-active-p minibuffer) :to-be-truthy)
      (expect (minibuffer-prompt-string minibuffer) :to-equal "Find file: ")
      (%type-string minibuffer "hello")
      (expect (minibuffer-input-string minibuffer) :to-equal "hello")
      (minibuffer-handle-key minibuffer (%special-key :enter))
      (expect confirmed :to-equal "hello")
      (expect (minibuffer-active-p minibuffer) :to-be-falsy)
      (expect (minibuffer-input-string minibuffer) :to-equal "")))

  (it
    "keeps a prompt activated by ON-CONFIRM active"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-activate
       minibuffer "Search: "
       :on-confirm
       (lambda (input)
         (declare (ignore input))
         (minibuffer-activate minibuffer "Replace with: ")))
      (%type-string minibuffer "needle")
      (minibuffer-handle-key minibuffer (%special-key :enter))
      (expect (minibuffer-active-p minibuffer) :to-be-truthy)
      (expect (minibuffer-prompt-string minibuffer)
              :to-equal "Replace with: ")))

  (it
    "C-g invokes ON-CANCEL and deactivates without calling ON-CONFIRM"
    (let ((minibuffer (make-minibuffer))
          (cancelled nil)
          (confirmed nil))
      (minibuffer-activate minibuffer "Find file: "
                           :on-confirm (lambda (input) (setf confirmed input))
                           :on-cancel (lambda () (setf cancelled t)))
      (%type-string minibuffer "abc")
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event :type :character :code #\g :modifiers '(:control)))
      (expect cancelled :to-be-truthy)
      (expect confirmed :to-be-falsy)
      (expect (minibuffer-active-p minibuffer) :to-be-falsy)))

  (it
    "also recognizes the plain :SPECIAL :CONTROL-G form"
    (let ((minibuffer (make-minibuffer))
          (cancelled nil))
      (minibuffer-activate minibuffer "Prompt: " :on-cancel (lambda () (setf cancelled t)))
      (minibuffer-handle-key minibuffer (%special-key :control-g))
      (expect cancelled :to-be-truthy)
      (expect (minibuffer-active-p minibuffer) :to-be-falsy)))

  (it
    "deactivates on C-g with no ON-CANCEL callback, without signaling"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-activate minibuffer "Prompt: ")
      (minibuffer-handle-key minibuffer (%special-key :control-g))
      (expect (minibuffer-active-p minibuffer) :to-be-falsy))))

(describe
  "minibuffer editing and inactive behavior"
  (it
    "deletes the last character of the input"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-activate minibuffer "Prompt: ")
      (%type-string minibuffer "abc")
      (minibuffer-handle-key minibuffer (%special-key :backspace))
      (expect (minibuffer-input-string minibuffer) :to-equal "ab")))

  (it
    "is a no-op on empty input"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-activate minibuffer "Prompt: ")
      (minibuffer-handle-key minibuffer (%special-key :backspace))
      (expect (minibuffer-input-string minibuffer) :to-equal "")))

  (it
    "ignores input when inactive"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-handle-key minibuffer (%char-key #\x))
      (expect (minibuffer-active-p minibuffer) :to-be-falsy)
      (expect (minibuffer-input-string minibuffer) :to-equal "")))

  (it
    "returns nil prompt when inactive after cancellation"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-activate minibuffer "Find file: ")
      (minibuffer-handle-key minibuffer (%special-key :control-g))
      (expect (minibuffer-prompt-string minibuffer) :to-be-falsy)))

  (it
    "updates the prompt only while active"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-set-prompt minibuffer "Inactive: ")
      (expect (minibuffer-prompt-string minibuffer) :to-be-falsy)
      (minibuffer-activate minibuffer "Active: ")
      (minibuffer-set-prompt minibuffer "Updated: ")
      (expect (minibuffer-prompt-string minibuffer) :to-equal "Updated: "))))

(describe
  "minibuffer input callbacks"
  (it
    "lets ON-KEY consume an event before the default editor handles it"
    (let ((minibuffer (make-minibuffer))
          (seen nil))
      (minibuffer-activate
       minibuffer "Prompt: "
       :on-key (lambda (event)
                 (setf seen event)
                 t))
      (minibuffer-handle-key minibuffer (%char-key #\x))
      (expect seen :to-be-truthy)
      (expect (minibuffer-input-string minibuffer) :to-equal "")))

  (it
    "continues default handling when ON-KEY does not consume an event"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-activate
       minibuffer "Prompt: "
       :on-key (lambda (event)
                 (declare (ignore event))
                 nil))
      (minibuffer-handle-key minibuffer (%char-key #\x))
      (expect (minibuffer-input-string minibuffer) :to-equal "x")))

  (it
    "reports the current input through ON-CHANGE after editing"
    (let ((minibuffer (make-minibuffer))
          (changes nil))
      (minibuffer-activate
       minibuffer "Prompt: "
       :on-change (lambda (input)
                    (push input changes)))
      (%type-string minibuffer "ab")
      (minibuffer-handle-key minibuffer (%special-key :backspace))
      (expect changes :to-equal '("a" "ab" "a")))))

(describe
  "minibuffer activation contracts"
  (it
    "rejects non-function interactive callbacks"
    (let ((minibuffer (make-minibuffer)))
      (dolist (keyword '(:completion-function :on-change :on-key))
        (signals error
                 (minibuffer-activate minibuffer "Prompt: " keyword 42))))))
