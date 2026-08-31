;;;; t/integration/commands-editing-search-navigation-test.lisp
;;;;
;;;; Search navigation command integration tests.
(in-package #:loom/test)

(describe
  "search navigation commands"
  (it
    "routes forward search through one result continuation"
    (let ((buffer (make-buffer :initial-content "alpha beta"))
          (matches 0)
          (misses 0))
      (loom/feature/search::%search-forward-cps
       buffer "beta"
       (lambda (span)
         (incf matches)
         (expect (buffer-span-start span) :to-equal 6))
       (lambda () (incf misses)))
      (expect matches :to-equal 1)
      (expect misses :to-equal 0)))

  (it
    "routes an absent forward search to the miss continuation"
    (let ((buffer (make-buffer :initial-content "alpha"))
          (matches 0)
          (misses 0))
      (loom/feature/search::%search-forward-cps
       buffer "missing"
       (lambda (span) (declare (ignore span)) (incf matches))
       (lambda () (incf misses)))
      (expect matches :to-equal 0)
      (expect misses :to-equal 1)))

  (it
    "routes backward search through one result continuation"
    (let ((buffer (make-buffer :initial-content "one two one"))
          (matches 0)
          (misses 0))
      (buffer-set-point buffer 0 11)
      (loom/feature/search::%search-backward-cps
       buffer "one"
       (lambda (span)
         (incf matches)
         (expect (buffer-span-start span) :to-equal 8))
       (lambda () (incf misses)))
      (expect matches :to-equal 1)
      (expect misses :to-equal 0)))

  (it
    "routes an absent backward search to the miss continuation"
    (let ((buffer (make-buffer :initial-content "alpha"))
          (matches 0)
          (misses 0))
      (loom/feature/search::%search-backward-cps
       buffer "missing"
       (lambda (span) (declare (ignore span)) (incf matches))
       (lambda () (incf misses)))
      (expect matches :to-equal 0)
      (expect misses :to-equal 1)))

  (it
    "searches case-sensitively from point and wraps once"
    (%with-selected-minibuffer-buffer (minibuffer buffer "alpha ALPHA alpha")
      (buffer-set-point buffer 0 6)
      (loom/feature/search::search-forward)
      (%expect-minibuffer-prompt minibuffer (%search-regex-prompt-string))
      (funcall (loom::%minibuffer-on-confirm minibuffer) "alpha")
      (expect (buffer-point-column buffer) :to-equal 12)
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Found")
      (buffer-set-point buffer 0 17)
      (loom/feature/search::search-forward)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "alpha")
      (expect (buffer-point-column buffer) :to-equal 0)))

  (it
    "searches backward to the previous match"
    (%with-selected-minibuffer-buffer (minibuffer buffer "one two one")
      (buffer-set-point buffer 0 11)
      (loom/feature/search::search-backward)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "one")
      (expect buffer :to-have-point (cons 0 8))
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Found")))

  (it
    "reports not found when backward search does not find the pattern"
    (%with-selected-minibuffer-buffer (minibuffer buffer "alpha")
      (buffer-set-point buffer 0 2)
      (loom/feature/search::search-backward)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "nonexistent")
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Not found")
      (expect buffer :to-have-point (cons 0 2))))

  (it
    "wraps backward search to the last match when point is before every match"
    (let ((buffer (make-buffer :initial-content "one two one")))
      (buffer-set-point buffer 0 0)
      (let ((span (buffer-search-backward buffer "one")))
        (expect span :to-be-truthy)
        (expect (buffer-span-start span) :to-equal 8))))

  (it
    "reports not found when the searched text does not occur anywhere"
    (%with-selected-minibuffer-buffer (minibuffer buffer "alpha")
      (loom/feature/search::search-forward)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "nonexistent")
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Not found")
      (expect (buffer-text buffer) :to-equal "alpha")))

  (it
    "reports not found for an empty search string without moving point"
    (%with-selected-minibuffer-buffer (minibuffer buffer "alpha")
      (buffer-set-point buffer 0 2)
      (loom/feature/search::search-forward)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "")
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Not found")
      (expect buffer :to-have-point (cons 0 2))))

  (it
    "returns no spans for an empty search pattern at the domain boundary"
    (let ((buffer (make-buffer :initial-content "alpha")))
      (expect (buffer-search-forward buffer "") :to-be nil)
      (expect (buffer-search-backward buffer "") :to-be nil)
      (expect (buffer-search-spans buffer "" 0) :to-be nil)))

  (it
    "clamps search starts and preserves absolute coordinates inside a narrowing"
    (let ((buffer (make-buffer :initial-content "zero one two one")))
      (buffer-narrow-to-region buffer 0 5 0 16)
      (let ((spans (buffer-search-spans buffer "one" 0)))
        (expect (mapcar #'buffer-span-start spans) :to-equal '(5 13)))
      (buffer-set-point buffer 0 0)
      (let ((span (buffer-search-forward buffer "one")))
        (expect (buffer-span-start span) :to-equal 5))))

  (it
    "clamps a point outside the visible text before searching"
    (let ((buffer (make-buffer :initial-content "alpha beta")))
      (buffer-set-point buffer 0 100)
      (let ((span (buffer-search-forward buffer "alpha")))
        (expect (buffer-span-start span) :to-equal 0))))

  (it
    "finds an occurrence on a later line of a multi-line buffer, searching from a later starting line"
    (%with-selected-minibuffer-buffer (minibuffer buffer (format nil "one~%two~%three~%four"))
      (buffer-set-point buffer 1 0)
      (loom/feature/search::search-forward)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "four")
      (expect buffer :to-have-point (cons 3 0)))))
