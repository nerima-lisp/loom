;;;; t/integration/commands-editing-search-replace-test.lisp
;;;;
;;;; Search replacement and regex command integration tests.
(in-package #:loom/test)

(describe
  "search replacement commands"
  (it
    "replaces every case-sensitive occurrence from point and wraps once"
    (%with-selected-minibuffer-buffer (minibuffer buffer "red RED red")
      (buffer-set-point buffer 0 4)
      (loom/feature/search::replace-string)
      (%expect-minibuffer-prompt minibuffer (%replace-regex-prompt-string))
      (funcall (loom::%minibuffer-on-confirm minibuffer) "red")
      (%expect-minibuffer-prompt minibuffer (%replace-with-prompt-string))
      (funcall (loom::%minibuffer-on-confirm minibuffer) "redred")
      (expect (buffer-text buffer) :to-equal "redred RED redred")
      (expect (buffer-point-column buffer) :to-equal 6)
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Replaced 2 occurrence(s)")))

  (it
    "reports not found when the text to replace does not occur anywhere"
    (%with-selected-minibuffer-buffer (minibuffer buffer "alpha")
      (loom/feature/search::replace-string)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "nonexistent")
      (funcall (loom::%minibuffer-on-confirm minibuffer) "replacement")
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Not found")
      (expect (buffer-text buffer) :to-equal "alpha")))

  (it
    "reports not found for an empty replacement target without searching"
    (%with-selected-minibuffer-buffer (minibuffer buffer "alpha")
      (loom/feature/search::replace-string)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "")
      (funcall (loom::%minibuffer-on-confirm minibuffer) "replacement")
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Not found")
      (expect (buffer-text buffer) :to-equal "alpha")))

  (it
    "moves point to a match only a regular expression describes"
    (%with-selected-minibuffer-buffer (minibuffer buffer "abc 1234 def")
      (loom/feature/search::search-forward)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "\\d+")
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Found")
      (expect buffer :to-have-point (cons 0 4))))

  (it
    "replaces variable-length matches rather than a fixed-length literal"
    (%with-minibuffer-state (minibuffer "a    b  c")
      (loom/feature/search::replace-string)
      (funcall (loom::%minibuffer-on-confirm minibuffer) "\\s+")
      (funcall (loom::%minibuffer-on-confirm minibuffer) " ")
      (expect (buffer-text (%selected-test-buffer)) :to-equal "a b c")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Replaced 2 occurrence(s)")))

  (it
    "reports a malformed search pattern in the minibuffer instead of crashing"
    (%with-minibuffer-state (minibuffer "abc"
                             (keymap-state (make-keymap-state (make-keymap))))
      (loom/feature/search::search-forward)
      (%type-string minibuffer "(")
      (loom::%dispatch-key-event (%special-key :enter) keymap-state)
      (expect (loom:minibuffer-message-string minibuffer)
              :to-contain "Invalid regular expression")
      (expect (%selected-test-buffer) :to-have-point (cons 0 0))))

  (it
    "hands its deadline to the regex engine on both the search and replace paths"
    (let ((buffer (make-buffer :initial-content "abc 123"))
          (loom/feature/search::+regex-search-timeout-seconds+ -1))
      (signals type-error (buffer-search-forward buffer "\\d+"))
      (signals type-error
        (buffer-search-spans buffer "\\d+" 0)))))
