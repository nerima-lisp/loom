;;;; t/unit/minibuffer-test.lisp
;;;;
;;;; Application layer: the minibuffer protocol (src/application/minibuffer.lisp).
;;;; Exercises activate/confirm, activate/cancel, Backspace editing, and that
;;;; MINIBUFFER-MESSAGE is a transient status independent of MINIBUFFER-ACTIVE-P.
;;;; Key events are built with CL-TTY-KIT:MAKE-KEY-EVENT, the library's real
;;;; public constructor, rather than a hand-rolled test double.
(in-package #:loom/test)

(defun %char-key (character)
  (cl-tty-kit:make-key-event :type :character :code character))

(defun %special-key (code)
  (cl-tty-kit:make-key-event :type :special :code code))

(defun %type-string (minibuffer string)
  (loop for character across string
        do (minibuffer-handle-key minibuffer (%char-key character))))

(describe
  "minibuffer-activate and confirm"
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
              :to-equal "Replace with: "))))

(describe
  "minibuffer-activate and cancel"
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
  "minibuffer-handle-key backspace editing"
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
      (expect (minibuffer-input-string minibuffer) :to-equal ""))))

(describe
  "minibuffer-handle-key history recall"
  (it
    "Up walks history newest-first, replacing the current input each step"
    ;; CL-HISTORY-KIT's default :LINE-PREFIX mode matches only entries whose
    ;; text starts with the input typed so far, so recall is exercised here
    ;; against empty input (matching every entry) rather than partial text.
    (let* ((history (history-kit:make-history))
           (minibuffer (make-minibuffer :history history)))
      (history-kit:history-add history "first")
      (history-kit:history-add history "second")
      (minibuffer-activate minibuffer "M-x ")
      (minibuffer-handle-key minibuffer (%special-key :up))
      (expect (minibuffer-input-string minibuffer) :to-equal "second")
      (minibuffer-handle-key minibuffer (%special-key :up))
      (expect (minibuffer-input-string minibuffer) :to-equal "first")
      (minibuffer-handle-key minibuffer (%special-key :down))
      (expect (minibuffer-input-string minibuffer) :to-equal "second")))

  (it
    "adds confirmed input to history and resets navigation on the next activation"
    (let* ((history (history-kit:make-history))
           (minibuffer (make-minibuffer :history history))
           (confirmed nil))
      (minibuffer-activate minibuffer "M-x "
                           :on-confirm (lambda (input) (setf confirmed input)))
      (%type-string minibuffer "a")
      (minibuffer-handle-key minibuffer (%special-key :enter))
      (expect confirmed :to-equal "a")
      ;; Re-activating and recalling Up surfaces the just-confirmed entry,
      ;; proving RET's HISTORY-KIT:HISTORY-ADD ran; if navigation were not
      ;; reset by either activation, this Up would instead continue from
      ;; wherever the PREVIOUS activation's history walk left off.
      (minibuffer-activate minibuffer "M-x ")
      (minibuffer-handle-key minibuffer (%special-key :up))
      (expect (minibuffer-input-string minibuffer) :to-equal "a")))

  (it
    "ignores an unrecognized special key, leaving the input unchanged"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-activate minibuffer "M-x ")
      (%type-string minibuffer "ab")
      (minibuffer-handle-key minibuffer (%special-key :left))
      (expect (minibuffer-input-string minibuffer) :to-equal "ab"))))

(describe
  "minibuffer completion"
  (it
    "passes current input to the completion function and completes a unique candidate"
    (let ((seen nil)
          (minibuffer (make-minibuffer)))
      (minibuffer-activate
       minibuffer "M-x "
       :completion-function
       (lambda (input)
         (setf seen input)
         '("forward-char" "forward-word" "backward-char")))
      (%type-string minibuffer "forward-c")
      (minibuffer-handle-key minibuffer (%special-key :tab))
      (expect seen :to-equal "forward-c")
      (expect (minibuffer-input-string minibuffer) :to-equal "forward-char")))

  (it
    "uses the longest common prefix for multiple matches"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-activate
       minibuffer "Prompt: "
       :completion-function
       (lambda (input)
         (declare (ignore input))
         '("alpha-one" "alpha-two")))
      (%type-string minibuffer "a")
      (minibuffer-handle-key minibuffer (%special-key :tab))
      (expect (minibuffer-input-string minibuffer) :to-equal "alpha-")))

  (it
    "leaves input unchanged when no candidate matches"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-activate
       minibuffer "Prompt: "
       :completion-function
       (lambda (input)
         (declare (ignore input))
         '("alpha")))
      (%type-string minibuffer "z")
      (minibuffer-handle-key minibuffer (%special-key :tab))
      (expect (minibuffer-input-string minibuffer) :to-equal "z"))))

(describe
  "minibuffer-message"
  (it
    "does not affect minibuffer-active-p when the minibuffer is inactive"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-message minibuffer "Saved.")
      (expect (minibuffer-active-p minibuffer) :to-be-falsy)))

  (it
    "does not affect minibuffer-active-p when the minibuffer is active"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-activate minibuffer "Prompt: ")
      (minibuffer-message minibuffer "Wrote file.")
      (expect (minibuffer-active-p minibuffer) :to-be-truthy)
      (expect (minibuffer-input-string minibuffer) :to-equal ""))))

(describe
  "minibuffer-handle-key when inactive"
  (it
    "is a no-op"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-handle-key minibuffer (%char-key #\x))
      (expect (minibuffer-active-p minibuffer) :to-be-falsy)
      (expect (minibuffer-input-string minibuffer) :to-equal ""))))

(describe
  "minibuffer-prompt-string when inactive"
  (it
    "returns nil instead of the last activation's prompt"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-activate minibuffer "Find file: ")
      (minibuffer-handle-key minibuffer (%special-key :control-g))
      (expect (minibuffer-prompt-string minibuffer) :to-be-falsy))))

;; The classification MINIBUFFER-HANDLE-KEY dispatches on, tested directly
;; rather than only through the keystrokes above, so a new kind cannot be
;; added to the CASE without a row here naming the key that produces it --
;; the same dedicated-helper precedent t/integration/commands-test.lisp set for
;; %DEFKEYS-SINGLE-CHORD-P.
(describe
  "%minibuffer-key-kind"
  (it-each
      (("C-g as a C0 :special event" :special :control-g nil :cancel)
       ("C-g as a kitty CSI-u :character event" :character #\g (:control) :cancel)
       ("Backspace" :special :backspace nil :backspace)
       ("Up" :special :up nil :history-previous)
       ("Down" :special :down nil :history-next)
       ("Enter" :special :enter nil :confirm)
       ("Tab" :special :tab nil :complete)
       ("an ordinary character" :character #\a nil :character)
       ("an unhandled special key" :special :left nil :ignore))
      "classifies ~A" (label type code modifiers expected)
    (declare (ignore label))
    (let ((key-event (cl-tty-kit:make-key-event :type type :code code :modifiers modifiers)))
      (expect (loom::%minibuffer-key-kind key-event type code) :to-equal expected))))
