;;;; t/unit/isearch-test.lisp
;;;;
;;;; The incremental-search session's pure transitions: what each keystroke
;;;; selects, what a repeat advances to, and what a failure leaves alone.
(in-package #:loom/test)

(defun %isearch-match-start (session)
  (let ((match (isearch-session-match session)))
    (and match (buffer-span-start match))))

(describe
  "isearch-apply-pattern"
  (it
    "selects the first match at or after the origin"
    (let* ((buffer (make-buffer :initial-content "one two one"))
           (session (make-isearch-session buffer 0)))
      (isearch-apply-pattern session "o")
      (expect (%isearch-match-start session) :to-equal 0)
      (expect (isearch-session-failed-p session) :to-be nil)
      (expect (mapcar #'buffer-span-start (isearch-session-matches session))
              :to-equal '(0 6 8))))

  (it
    "grows the match in place as the pattern lengthens"
    (let* ((buffer (make-buffer :initial-content "alpha beta"))
           (session (make-isearch-session buffer 0)))
      (isearch-apply-pattern session "b")
      (expect (%isearch-match-start session) :to-equal 6)
      (isearch-apply-pattern session "be")
      (expect (%isearch-match-start session) :to-equal 6)
      (expect (buffer-span-end (isearch-session-match session)) :to-equal 8)))

  (it
    "reports failure and keeps no match when nothing matches"
    (let* ((buffer (make-buffer :initial-content "alpha"))
           (session (make-isearch-session buffer 0)))
      (isearch-apply-pattern session "zzz")
      (expect (isearch-session-failed-p session) :to-be-truthy)
      (expect (isearch-session-match session) :to-be nil)
      (expect (isearch-session-matches session) :to-equal nil)))

  (it
    "treats the empty pattern the prompt opens with as no search, not a failure"
    (let* ((buffer (make-buffer :initial-content "alpha"))
           (session (make-isearch-session buffer 0)))
      (isearch-apply-pattern session "")
      (expect (isearch-session-failed-p session) :to-be nil)
      (expect (isearch-session-match session) :to-be nil)))

  (it
    "searches only the visible region while the buffer is narrowed"
    (let ((buffer (make-buffer :initial-content "one two one")))
      (buffer-narrow-to-region buffer 0 4 0 7)
      (let ((session (make-isearch-session
                      buffer (buffer-narrow-start-offset buffer))))
        (isearch-apply-pattern session "one")
        (expect (isearch-session-matches session) :to-equal nil)
        (isearch-apply-pattern session "two")
        (expect (%isearch-match-start session) :to-equal 4))))

  (it
    "starts a backward session on the last match at or before the origin"
    (let* ((buffer (make-buffer :initial-content "one two one"))
           (session (make-isearch-session buffer 7 :direction :backward)))
      (isearch-apply-pattern session "one")
      (expect (%isearch-match-start session) :to-equal 0))))

(describe
  "isearch-repeat"
  (it
    "advances forward through every match and then wraps"
    (let* ((buffer (make-buffer :initial-content "one two one"))
           (session (make-isearch-session buffer 0)))
      (isearch-apply-pattern session "o")
      (expect (%isearch-match-start session) :to-equal 0)
      (isearch-repeat session :forward)
      (expect (%isearch-match-start session) :to-equal 6)
      (isearch-repeat session :forward)
      (expect (%isearch-match-start session) :to-equal 8)
      (isearch-repeat session :forward)
      (expect (%isearch-match-start session) :to-equal 0)))

  (it
    "turns around without leaving the match set"
    (let* ((buffer (make-buffer :initial-content "one two one"))
           (session (make-isearch-session buffer 0)))
      (isearch-apply-pattern session "o")
      (isearch-repeat session :forward)
      (isearch-repeat session :forward)
      (expect (%isearch-match-start session) :to-equal 8)
      (isearch-repeat session :backward)
      (expect (%isearch-match-start session) :to-equal 6)
      (expect (isearch-session-direction session) :to-be :backward)))

  (it
    "leaves a failed search where it is instead of moving on"
    (let* ((buffer (make-buffer :initial-content "alpha"))
           (session (make-isearch-session buffer 0)))
      (isearch-apply-pattern session "zzz")
      (isearch-repeat session :forward)
      (expect (isearch-session-match session) :to-be nil)
      (expect (isearch-session-failed-p session) :to-be-truthy))))
