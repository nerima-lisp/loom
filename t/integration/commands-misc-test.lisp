(in-package #:loom/test)

(describe
  "%quit-answer-action"
  (it "resolves \"s\" to :save-and-continue when the buffer has a path"
    (expect (loom::%quit-answer-action "s" t) :to-be :save-and-continue))
  (it "resolves \"s\" to :retry when the buffer has no path"
    (expect (loom::%quit-answer-action "s" nil) :to-be :retry))
  (it "resolves \"d\" to :discard-and-continue regardless of path"
    (expect (loom::%quit-answer-action "d" t) :to-be :discard-and-continue)
    (expect (loom::%quit-answer-action "d" nil) :to-be :discard-and-continue))
  (it "resolves \"c\" to :cancel regardless of path"
    (expect (loom::%quit-answer-action "c" t) :to-be :cancel)
    (expect (loom::%quit-answer-action "c" nil) :to-be :cancel))
  (it "resolves an unrecognized answer to :retry"
    (expect (loom::%quit-answer-action "x" t) :to-be :retry)))

(describe
  "keyboard-quit"
  (it "reports a Quit message"
    (%with-minibuffer-state (minibuffer "")
      (loom::keyboard-quit)
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Quit"))))

(describe
  "minibuffer query protocol"
  (it "starts inactive with stable empty query values"
    (let ((minibuffer (make-minibuffer)))
      (expect (minibuffer-active-p minibuffer) :to-be nil)
      (expect (minibuffer-prompt-string minibuffer) :to-be nil)
      (expect (minibuffer-input-string minibuffer) :to-equal "")
      (expect (minibuffer-message-string minibuffer) :to-be nil))))
