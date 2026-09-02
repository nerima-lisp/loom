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
    "returns a snapshot that can be changed independently"
    (let ((minibuffer (make-minibuffer
                       :history (history-kit:make-history))))
      (minibuffer-set-history-entries minibuffer '("new" "old"))
      (let ((snapshot (minibuffer-history-entries minibuffer)))
        (pop snapshot)
        (expect snapshot :to-equal '("old"))
        (expect (minibuffer-history-entries minibuffer)
                :to-equal '("new" "old")))))

    (it
      "rejects non-string history entries"
       (signals error
                (minibuffer-set-history-entries
                 (make-minibuffer :history (history-kit:make-history))
                 '("ok" 42)))))
    (it
      "treats a missing history store as an empty optional feature"
      (let ((minibuffer (make-minibuffer)))
        (expect (minibuffer-history-entries minibuffer) :to-be nil)
        (expect (minibuffer-set-history-entries minibuffer '("ignored"))
                :to-be minibuffer)
        (expect (minibuffer-history-entries minibuffer) :to-be nil)))

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
  "minibuffer query protocol"
  (it-each
      (("inactive" nil nil "" nil)
       ("active" t "Prompt: " "" nil)
       ("message" nil nil "" "Saved."))
      "returns stable public values for ~A state"
      (label active prompt input message)
    (let ((minibuffer (make-minibuffer)))
      (when active
        (minibuffer-activate minibuffer prompt))
      (when message
        (minibuffer-message minibuffer message))
      (expect (minibuffer-active-p minibuffer) :to-be active)
      (expect (minibuffer-prompt-string minibuffer) :to-equal prompt)
      (expect (minibuffer-input-string minibuffer) :to-equal input)
      (expect (minibuffer-message-string minibuffer) :to-equal message))))
