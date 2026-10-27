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
    "case-folds lowercase patterns from point and wraps once"
    ;; GNU Emacs Manual 17.9: lowercase patterns fold case; uppercase makes searches case-sensitive.
    ;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Lax-Search.html
    (%with-selected-minibuffer-buffer (minibuffer buffer "alpha ALPHA alpha")
      (buffer-set-point buffer 0 6)
      (loom/feature/search::search-forward)
      (%expect-minibuffer-prompt minibuffer (%search-regex-prompt-string))
      (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "alpha")
      (expect (buffer-point-column buffer) :to-equal 6)
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Found")
      (buffer-set-point buffer 0 17)
      (loom/feature/search::search-forward)
      (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "alpha")
      (expect (buffer-point-column buffer) :to-equal 0)
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Found")
      (loom/feature/search::search-forward)
      (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "Alpha")
      (expect (buffer-point-column buffer) :to-equal 0)
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Not found")))

  (it
    "searches backward to the previous match"
    (%with-selected-minibuffer-buffer (minibuffer buffer "one two one")
      (buffer-set-point buffer 0 11)
      (loom/feature/search::search-backward)
      (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "one")
      (expect buffer :to-have-point (cons 0 8))
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Found")))

  (it
    "reports not found when backward search does not find the pattern"
    (%with-selected-minibuffer-buffer (minibuffer buffer "alpha")
      (buffer-set-point buffer 0 2)
      (loom/feature/search::search-backward)
      (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "nonexistent")
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
      (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "nonexistent")
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Not found")
      (expect (buffer-text buffer) :to-equal "alpha")))

  (it
    "accepts empty forward and backward searches at point without moving it"
    (%with-selected-minibuffer-buffer (minibuffer buffer "alpha")
      (buffer-set-point buffer 0 2)
      (loom/feature/search::search-forward)
      (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "")
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Found")
      (expect buffer :to-have-point (cons 0 2))
      (loom/feature/search::search-backward)
      (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "")
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Found")
      (expect buffer :to-have-point (cons 0 2))))

  (it
    "returns zero-width spans at the visible point but no all-match spans"
    (let ((buffer (make-buffer :initial-content "zero one two one")))
      (buffer-narrow-to-region buffer 0 5 0 16)
      (buffer-set-point buffer 0 7)
      (let ((span (buffer-search-forward buffer "")))
        (expect span :to-be-truthy)
        (expect (buffer-span-start span) :to-equal 7)
        (expect (buffer-span-end span) :to-equal 7))
      (expect (buffer-point-offset buffer) :to-equal 7)
      (let ((span (buffer-search-backward buffer "")))
        (expect span :to-be-truthy)
        (expect (buffer-span-start span) :to-equal 7)
        (expect (buffer-span-end span) :to-equal 7))
      (expect (buffer-point-offset buffer) :to-equal 7)
      (expect (buffer-search-spans buffer "" 5) :to-be nil)))

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
      (funcall (loom/core/minibuffer::%minibuffer-on-confirm minibuffer) "four")
      (expect buffer :to-have-point (cons 3 0)))))
(describe
  "occur"
  ;; GNU Emacs Manual, "Other Repeating Commands", describes occur as listing matching lines.
  ;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Other-Repeating.html
  (it "returns each matching line once with zero-based match coordinates"
    (multiple-value-bind (matches cancelled-p)
        (loom/feature/search::%occur-scan-text
         (format nil "zero alpha~%beta alpha~%last") "alpha" 0 0 t
         (lambda () nil))
      (expect matches :to-equal
              (list (list 0 5 "zero alpha")
                    (list 1 5 "beta alpha")))
      (expect cancelled-p :to-be nil)))
  (it "stops scanning when its cancellation predicate becomes true"
    (multiple-value-bind (matches cancelled-p)
        (loom/feature/search::%occur-scan-text
         (format nil "alpha~%beta") "alpha" 0 0 t
         (lambda () t))
      (expect matches :to-be nil)
      (expect cancelled-p :to-be-truthy)))
  (it "handles C-g through the active occur session hook"
    (let* ((session
             (loom/core/editor-session:make-editor-session
              (list :feature/search)))
           (state
             (loom/core/editor-session:editor-session-slice
              session :feature/search))
           (cancelled-p nil)
           (token
             (loom/core/editor-session:register-background-work
              session :feature/search
              (lambda (session token)
                (declare (ignore session token))
                (values nil t))
              (lambda (session token)
                (declare (ignore session token))
                (setf cancelled-p t))))
           (event
             (cl-tty-kit:make-key-event
              :type :character :code #\g :modifiers (list :control))))
      (setf (loom/feature/search::search-result-state-active-occur state)
            (loom/feature/search::%make-occur-operation :token token))
      (expect
       (loom/core/editor-session:run-session-hooks
        :key-input session event :key)
       :to-equal :handled)
      (expect cancelled-p :to-be-truthy)))
  (it "discards queued matches when C-g is pending before the UI poller"
    (let* ((session
             (loom/core/editor-session:make-editor-session
              (list :feature/buffers :feature/search)))
           (state
             (loom/core/editor-session:editor-session-slice
              session :feature/search))
           (buffer (make-buffer :name "*scratch*" :initial-content "alpha"))
           (result-channel (cl-concurrent-kit:make-channel :buffer-size 1))
           (cancellation-channel
             (cl-concurrent-kit:make-channel :buffer-size 1))
           (cancellation-counter (cl-concurrent-kit:make-atomic-counter))
           (executor
             (cl-concurrent-kit:make-executor
              :size 1 :name "occur race test" :queue-capacity 1))
           (token
             (loom/core/editor-session:register-background-work
              session :feature/search
              (lambda (session token)
                (declare (ignore session token))
                (values nil nil))
              (lambda (session token)
                (declare (ignore session token))
                (cl-concurrent-kit:atomic-counter-incf cancellation-counter)
                (cl-concurrent-kit:send cancellation-channel :cancel))))
           (operation
             (loom/feature/search::%make-occur-operation
              :token token
              :executor executor
              :result-channel result-channel
              :cancellation-channel cancellation-channel
              :cancellation-counter cancellation-counter
              :buffer buffer
              :result-name "*Occur*"))
           (event
             (cl-tty-kit:make-key-event
              :type :character :code #\g :modifiers (list :control))))
      (setf (loom/feature/search::search-result-state-active-occur state)
            operation)
      (cl-concurrent-kit:send
       result-channel (list :matches (list (list 0 0 "alpha"))))
      (expect
       (loom/core/editor-session:run-session-hooks
        :key-input session event :key)
       :to-equal :handled)
      (multiple-value-bind (dirty-p done-p)
          (loom/feature/search::%poll-occur-operation session operation)
        (expect dirty-p :to-be nil)
        (expect done-p :to-be-truthy))
      (expect (loom/feature/search::search-result-state-active-occur state)
              :to-be nil)
      (expect (loom/feature/buffers:find-buffer-by-name
               session "*Occur*")
              :to-be nil))))
