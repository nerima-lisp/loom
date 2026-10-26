(in-package #:loom/test)

(defun %isearch-match-start (session)
  (let ((match (isearch-session-match session)))
    (and match (buffer-span-start match))))

(describe
  "isearch-apply-pattern"
  (it
    "retains the current pattern as part of the session state"
    (let* ((buffer (make-buffer :initial-content "one two"))
           (session (make-isearch-session buffer 0)))
      (isearch-apply-pattern session "two")
      (expect (isearch-session-pattern session) :to-equal "two")))

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
      (expect (%isearch-match-start session) :to-equal 0)))
  (it
  "matches regexp punctuation literally by default"
  ;; GNU Emacs Manual §17.1: https://www.gnu.org/software/emacs/manual/html_node/emacs/Incremental-Search.html
  (let* ((buffer (make-buffer :initial-content ".+x"))
         (session (make-isearch-session buffer 0)))
    (isearch-apply-pattern session ".+")
    (expect (buffer-span-end (isearch-session-match session)) :to-equal 2)))
  (it
  "matches regexp punctuation as a regexp in regexp mode"
  ;; GNU Emacs Manual §17.1: https://www.gnu.org/software/emacs/manual/html_node/emacs/Incremental-Search.html
  (let* ((buffer (make-buffer :initial-content ".+x"))
         (session (make-isearch-session buffer 0 :regexp-p t)))
    (isearch-apply-pattern session ".+")
    (expect (buffer-span-end (isearch-session-match session)) :to-equal 3)))
  (it
  "keeps incomplete regexp input as a failing incremental search"
  ;; GNU Emacs Manual §17.1: https://www.gnu.org/software/emacs/manual/html_node/emacs/Incremental-Search.html
  (let* ((buffer (make-buffer :initial-content "abc"))
         (session (make-isearch-session buffer 0 :regexp-p t)))
    (isearch-apply-pattern session "[")
    (expect (isearch-session-failed-p session) :to-be-truthy)
    (expect (isearch-session-matches session) :to-equal nil))))

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

(describe
  "case-folded search defaults"
  ;; GNU Emacs Manual 17.9: lowercase patterns fold case, uppercase patterns do not.
  ;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Lax-Search.html
  ;; GNU Emacs Manual 17.1.5: isearch uses the same default unless toggled with M-c.
  ;; https://www.gnu.org/s/emacs/manual/html_node/emacs/Special-Isearch.html
  (it
    "case-folds lowercase patterns in forward search and honors uppercase"
    (let ((buffer (make-buffer :initial-content "alpha ALPHA")))
      (buffer-set-point buffer 0 6)
      (let ((span (buffer-search-forward buffer "alpha")))
        (expect (buffer-span-start span) :to-equal 6))
      (buffer-set-point buffer 0 6)
      (expect (buffer-search-forward buffer "Alpha") :to-be nil)))

  (it
    "case-folds lowercase patterns in backward search and honors uppercase"
    (let ((buffer (make-buffer :initial-content "alpha ALPHA")))
      (buffer-set-point buffer 0 11)
      (let ((span (buffer-search-backward buffer "alpha")))
        (expect (buffer-span-start span) :to-equal 6))
      (buffer-set-point buffer 0 11)
      (expect (buffer-search-backward buffer "Alpha") :to-be nil)))

  (it
    "case-folds literal isearch patterns but preserves uppercase sensitivity"
    (let* ((buffer (make-buffer :initial-content "alpha ALPHA"))
           (session (make-isearch-session buffer 6)))
      (isearch-apply-pattern session "alpha")
      (expect (%isearch-match-start session) :to-equal 6)
      (setf session (make-isearch-session
                     (make-buffer :initial-content "alpha") 0))
      (isearch-apply-pattern session "Alpha")
      (expect (isearch-session-failed-p session) :to-be-truthy)))

  (it
    "case-folds regexp isearch patterns but preserves uppercase sensitivity"
    (let* ((buffer (make-buffer :initial-content "FOOO"))
           (session (make-isearch-session buffer 0 :regexp-p t)))
      (isearch-apply-pattern session "foo+")
      (expect (buffer-span-end (isearch-session-match session)) :to-equal 4)
      (setf session (make-isearch-session
                     (make-buffer :initial-content "foo") 0 :regexp-p t))
      (isearch-apply-pattern session "FOO+")
      (expect (isearch-session-failed-p session) :to-be-truthy)))

  (it
    "keeps span matching case-sensitive unless case-fold is requested"
    (let ((buffer (make-buffer :initial-content "alpha ALPHA")))
      (expect (mapcar (function buffer-span-start)
                      (buffer-search-spans buffer "alpha" 0))
              :to-equal (list 0))
      (expect (mapcar (function buffer-span-start)
                      (buffer-search-spans buffer "alpha" 0 :case-fold nil))
              :to-equal (list 0))
      (expect (buffer-search-spans buffer "Alpha" 0) :to-be nil)
      (expect (mapcar (function buffer-span-start)
                      (buffer-search-spans buffer "Alpha" 0 :case-fold t))
              :to-equal (list 0 6)))))
