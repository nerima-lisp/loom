(in-package #:loom/test)

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
