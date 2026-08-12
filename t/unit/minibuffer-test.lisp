;;;; t/unit/minibuffer-test.lisp
;;;;
;;;; Application layer: the core minibuffer state/protocol
;;;; (src/application/minibuffer.lisp). Input handling, completion, and key
;;;; classification live in t/unit/minibuffer-input-test.lisp.
(in-package #:loom/test)

(describe
  "minibuffer history snapshots"
  (it
    "exports and restores newest-first entries"
    (let ((minibuffer (make-minibuffer
                       :history (history-kit:make-history))))
      (minibuffer-set-history-entries minibuffer '("new" "old"))
      (expect (minibuffer-history-entries minibuffer)
              :to-equal '("new" "old"))
      (minibuffer-set-history-entries minibuffer '("latest"))
      (expect (minibuffer-history-entries minibuffer)
              :to-equal '("latest"))))

  (it
    "rejects non-string history entries"
    (signals error
             (minibuffer-set-history-entries
              (make-minibuffer :history (history-kit:make-history))
              '("ok" 42)))))

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
