(in-package #:loom/test)

(describe
  "search replacement commands"
  ;; The response keys follow the GNU Emacs Manual query-replace contract:
  ;; https://www.gnu.org/s/emacs/manual/html_node/emacs/Query-Replace.html
  (it
    "replaces literal occurrences from point to buffer end"
    (%with-selected-minibuffer-buffer (minibuffer buffer "red RED red red")
      (buffer-set-point buffer 0 4)
      (loom/feature/search::replace-string)
      (%expect-minibuffer-prompt minibuffer "Replace string: ")
      (%confirm-minibuffer minibuffer "red")
      (%expect-minibuffer-prompt minibuffer (%replace-with-prompt-string))
      (%confirm-minibuffer minibuffer "redred")
      (expect (buffer-text buffer) :to-equal "red REDRED redred redred")
      (expect (buffer-point-column buffer) :to-equal 24)
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Replaced 3 occurrence(s)")))

  ;; Case folding and replacement casing follow the GNU Emacs Manual:
  ;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Replacement-and-Lax-Matches.html
  (it
    "folds lowercase literal patterns and preserves match case"
    (%with-selected-minibuffer-buffer (minibuffer buffer "foo FOO Foo fOo")
      (loom/feature/search::replace-string)
      (%confirm-minibuffer minibuffer "foo")
      (%confirm-minibuffer minibuffer "bar")
      (expect (buffer-text buffer) :to-equal "bar BAR Bar bar")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Replaced 4 occurrence(s)")))
  (it
    "keeps uppercase literal patterns case-sensitive"
    (%with-selected-minibuffer-buffer (minibuffer buffer "foo FOO Foo")
      (loom/feature/search::replace-string)
      (%confirm-minibuffer minibuffer "FOO")
      (%confirm-minibuffer minibuffer "bar")
      (expect (buffer-text buffer) :to-equal "foo bar Foo")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Replaced 1 occurrence(s)")))

  (it
    "treats regexp metacharacters and capture syntax literally in replace-string"
    (%with-selected-minibuffer-buffer (minibuffer buffer "a.b ab a.b")
      (loom/feature/search::replace-string)
      (%confirm-minibuffer minibuffer "a.b")
      (%confirm-minibuffer minibuffer "\\1&")
      (expect (buffer-text buffer) :to-equal "\\1& ab \\1&")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Replaced 2 occurrence(s)")))

  (it
    "reports not found when the text to replace does not occur anywhere"
    (%with-selected-minibuffer-buffer (minibuffer buffer "alpha")
      (loom/feature/search::replace-string)
      (%confirm-minibuffer minibuffer "nonexistent")
      (%confirm-minibuffer minibuffer "replacement")
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Not found")
      (expect (buffer-text buffer) :to-equal "alpha")))

  (it
    "reports not found for an empty replacement target without searching"
    (%with-selected-minibuffer-buffer (minibuffer buffer "alpha")
      (loom/feature/search::replace-string)
      (%confirm-minibuffer minibuffer "")
      (%confirm-minibuffer minibuffer "replacement")
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Not found")
      (expect (buffer-text buffer) :to-equal "alpha")))

  ;; Regexp replacement references are documented at:
  ;; https://www.gnu.org/s/emacs/manual/html_node/emacs/Regexp-Replace.html
  (it
    "expands regexp captures and the whole match in replace-regexp"
    (%with-selected-minibuffer-buffer (minibuffer buffer "foo-42 bar-7")
      (loom/feature/search::replace-regexp)
      (%expect-minibuffer-prompt minibuffer (%replace-regex-prompt-string))
      (%confirm-minibuffer minibuffer "([a-z]+)-(\\d+)")
      (%confirm-minibuffer minibuffer "\\2/\\1/\\&")
      (expect (buffer-text buffer)
              :to-equal "42/foo/foo-42 7/bar/bar-7")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Replaced 2 occurrence(s)")))
  ;; Regexp replacement references are documented at:
  ;; https://www.gnu.org/s/emacs/manual/html_node/emacs/Regexp-Replace.html
  (it
    "expands \\# with the number of prior replacements in replace-regexp"
    (%with-selected-minibuffer-buffer (minibuffer buffer "a a a")
      (loom/feature/search::replace-regexp)
      (%confirm-minibuffer minibuffer "a")
      (%confirm-minibuffer minibuffer "\\#:\\&")
      (expect (buffer-text buffer) :to-equal "0:a 1:a 2:a")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Replaced 3 occurrence(s)")))

  (it
    "folds lowercase regexp patterns and preserves match case"
    (%with-selected-minibuffer-buffer (minibuffer buffer "foo-42 FOO-7 Foo-8 fOo-5")
      (loom/feature/search::replace-regexp)
      (%confirm-minibuffer minibuffer "([a-z]+)-(\\d+)")
      (%confirm-minibuffer minibuffer "bar/\\2")
      (expect (buffer-text buffer) :to-equal "bar/42 BAR/7 Bar/8 bar/5")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Replaced 4 occurrence(s)")))
  (it
    "keeps uppercase regexp patterns case-sensitive"
    (%with-selected-minibuffer-buffer (minibuffer buffer "foo-1 FOO-2 Foo-3")
      (loom/feature/search::replace-regexp)
      (%confirm-minibuffer minibuffer "([A-Z]+)-(\\d+)")
      (%confirm-minibuffer minibuffer "bar/\\2")
      (expect (buffer-text buffer) :to-equal "foo-1 bar/2 Foo-3")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Replaced 1 occurrence(s)")))
  ;; Explicit inline flags are supported by cl-regex-kit:
  ;; https://github.com/nerima-lisp/cl-regex-kit#cl-regex-kit
  (it
    "honors an explicit case-insensitive regexp flag"
    (%with-selected-minibuffer-buffer (minibuffer buffer "foo FOO Foo")
      (loom/feature/search::replace-regexp)
      (%confirm-minibuffer minibuffer "(?i)FOO")
      (%confirm-minibuffer minibuffer "bar")
      (expect (buffer-text buffer) :to-equal "bar bar bar")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Replaced 3 occurrence(s)")))
  (it
    "replaces variable-length regexp matches in replace-regexp"
    (%with-minibuffer-state (minibuffer "a    b  c")
      (loom/feature/search::replace-regexp)
      (%confirm-minibuffer minibuffer "\\s+")
      (%confirm-minibuffer minibuffer " ")
      (expect (buffer-text (%selected-test-buffer)) :to-equal "a b c")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Replaced 2 occurrence(s)")))

  (it
    "moves point to a match only a regular expression describes"
    (%with-selected-minibuffer-buffer (minibuffer buffer "abc 1234 def")
      (loom/feature/search::search-forward)
      (%confirm-minibuffer minibuffer "\\d+")
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Found")
      (expect buffer :to-have-point (cons 0 4))))

  (it
    "reports a malformed search pattern in the minibuffer instead of crashing"
    (%with-minibuffer-state (minibuffer "abc"
                             (keymap-state (make-keymap-state (make-keymap))))
      (loom/feature/search::search-forward)
      (%search-type-string minibuffer "(")
      (loom::%dispatch-key-event (%search-special-key :enter) keymap-state)
      (expect (loom:minibuffer-message-string minibuffer)
              :to-contain "Invalid regular expression")
      (expect (%selected-test-buffer) :to-have-point (cons 0 0))))

  (it
    "hands its deadline to the regex engine on both the search and replace paths"
    (let ((buffer (make-buffer :initial-content "abc 123"))
          (loom/feature/search::+regex-search-timeout-seconds+ -1))
      (signals type-error (buffer-search-forward buffer "\\d+"))
      (signals type-error
        (buffer-search-spans buffer "\\d+" 0))))

  (it
    "supports y, n, and ! in literal query-replace"
    (%with-selected-minibuffer-buffer (minibuffer buffer "red RED red red")
      (buffer-set-point buffer 0 4)
      (loom/feature/search::query-replace)
      (%expect-minibuffer-prompt minibuffer "Query replace: ")
      (%confirm-minibuffer minibuffer "red")
      (%expect-minibuffer-prompt minibuffer "Query replace with: ")
      (%confirm-minibuffer minibuffer "blue")
      (expect (minibuffer-active-p minibuffer) :to-be t)
      (minibuffer-handle-key minibuffer (%search-char-key #\y))
      (expect (buffer-text buffer) :to-equal "red BLUE red red")
      (expect (minibuffer-active-p minibuffer) :to-be t)
      (minibuffer-handle-key minibuffer (%search-char-key #\n))
      (expect (buffer-text buffer) :to-equal "red BLUE red red")
      (minibuffer-handle-key minibuffer (%search-char-key #\!))
      (expect (buffer-text buffer) :to-equal "red BLUE red blue")
      (expect (buffer-point-column buffer) :to-equal 17)
      (expect (minibuffer-active-p minibuffer) :to-be nil)
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Replaced 2 occurrence(s)")))
  (it
    "leaves point after the final match when query-replace reaches end of buffer"
    (%with-selected-minibuffer-buffer (minibuffer buffer "red red")
      (loom/feature/search::query-replace)
      (%confirm-minibuffer minibuffer "red")
      (%confirm-minibuffer minibuffer "blue")
      (minibuffer-handle-key minibuffer (%search-char-key #\y))
      (expect (buffer-text buffer) :to-equal "blue red")
      (minibuffer-handle-key minibuffer (%search-char-key #\y))
      (expect (buffer-text buffer) :to-equal "blue blue")
      (expect (buffer-point-column buffer) :to-equal 9)
      (expect (minibuffer-active-p minibuffer) :to-be nil)
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Replaced 2 occurrence(s)")))

  (it
    "lets q finish query-replace while retaining earlier changes"
    (%with-selected-minibuffer-buffer (minibuffer buffer "red red")
      (loom/feature/search::query-replace)
      (%confirm-minibuffer minibuffer "red")
      (%confirm-minibuffer minibuffer "blue")
      (minibuffer-handle-key minibuffer (%search-char-key #\y))
      (minibuffer-handle-key minibuffer (%search-char-key #\q))
      (expect (buffer-text buffer) :to-equal "blue red")
      (expect (minibuffer-active-p minibuffer) :to-be nil)
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Replaced 1 occurrence(s)")))

  (it
    "lets RET finish query-replace while retaining earlier changes"
    (%with-selected-minibuffer-buffer (minibuffer buffer "red red")
      (loom/feature/search::query-replace)
      (%confirm-minibuffer minibuffer "red")
      (%confirm-minibuffer minibuffer "blue")
      (minibuffer-handle-key minibuffer (%search-char-key #\y))
      (minibuffer-handle-key minibuffer (%search-special-key :enter))
      (expect (buffer-text buffer) :to-equal "blue red")
      (expect (minibuffer-active-p minibuffer) :to-be nil)
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Replaced 1 occurrence(s)")))

  (it
    "lets C-g abort query-replace while retaining earlier changes"
    (%with-selected-minibuffer-buffer (minibuffer buffer "red red")
      (loom/feature/search::query-replace)
      (%confirm-minibuffer minibuffer "red")
      (%confirm-minibuffer minibuffer "blue")
      (minibuffer-handle-key minibuffer (%search-char-key #\y))
      (minibuffer-handle-key minibuffer (%search-special-key :control-g))
      (expect (buffer-text buffer) :to-equal "blue red")
      (expect (minibuffer-active-p minibuffer) :to-be nil)))

  (it
    "expands captures in regexp query-replace"
    (%with-selected-minibuffer-buffer (minibuffer buffer "foo-42 FOO-7")
      (loom/feature/search::query-replace-regexp)
      (%confirm-minibuffer minibuffer "([a-z]+)-(\\d+)")
      (%confirm-minibuffer minibuffer "\\2/\\1")
      (minibuffer-handle-key minibuffer (%search-char-key #\y))
      (minibuffer-handle-key minibuffer (%search-char-key #\!))
      (expect (buffer-text buffer) :to-equal "42/foo 7/FOO")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Replaced 2 occurrence(s)")))
  (it
    "counts only prior replacements in regexp query-replace"
    (%with-selected-minibuffer-buffer (minibuffer buffer "a a a")
      (loom/feature/search::query-replace-regexp)
      (%confirm-minibuffer minibuffer "a")
      (%confirm-minibuffer minibuffer "\\#:\\&")
      (minibuffer-handle-key minibuffer (%search-char-key #\n))
      (minibuffer-handle-key minibuffer (%search-char-key #\y))
      (expect (buffer-text buffer) :to-equal "a 0:a a")
      (minibuffer-handle-key minibuffer (%search-char-key #\y))
      (expect (buffer-text buffer) :to-equal "a 0:a 1:a")
      (expect (minibuffer-active-p minibuffer) :to-be nil)
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Replaced 2 occurrence(s)")))
  ;; Replacement commands use the active region when it is set, per the GNU Emacs Manual:
  ;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Replace.html
  (it
    "limits replace-string to the active region"
    (%with-selected-minibuffer-buffer (minibuffer buffer "red red red")
      (buffer-set-point buffer 0 4)
      (buffer-set-mark buffer 0 7)
      (loom/feature/search::replace-string)
      (%confirm-minibuffer minibuffer "red")
      (%confirm-minibuffer minibuffer "blue")
      (expect (buffer-text buffer) :to-equal "red blue red")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Replaced 1 occurrence(s)")))
  (it
    "limits replace-regexp to the active region"
    (%with-selected-minibuffer-buffer (minibuffer buffer "foo-42 bar-7 baz-9")
      (buffer-set-point buffer 0 7)
      (buffer-set-mark buffer 0 12)
      (loom/feature/search::replace-regexp)
      (%confirm-minibuffer minibuffer "([a-z]+)-(\\d+)")
      (%confirm-minibuffer minibuffer "\\2/\\1")
      (expect (buffer-text buffer) :to-equal "foo-42 7/bar baz-9")
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Replaced 1 occurrence(s)")))
  (it
    "limits query-replace to the active region"
    (%with-selected-minibuffer-buffer (minibuffer buffer "red red red")
      (buffer-set-point buffer 0 4)
      (buffer-set-mark buffer 0 7)
      (loom/feature/search::query-replace)
      (%confirm-minibuffer minibuffer "red")
      (%confirm-minibuffer minibuffer "blue")
      (minibuffer-handle-key minibuffer (%search-char-key #\y))
      (expect (buffer-text buffer) :to-equal "red blue red")
      (expect (minibuffer-active-p minibuffer) :to-be nil)
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Replaced 1 occurrence(s)")))
  (it
    "limits query-replace-regexp to the active region"
    (%with-selected-minibuffer-buffer (minibuffer buffer "foo-42 bar-7 baz-9")
      (buffer-set-point buffer 0 12)
      (buffer-set-mark buffer 0 7)
      (loom/feature/search::query-replace-regexp)
      (%confirm-minibuffer minibuffer "([a-z]+)-(\\d+)")
      (%confirm-minibuffer minibuffer "\\2/\\1")
      (minibuffer-handle-key minibuffer (%search-char-key #\y))
      (expect (buffer-text buffer) :to-equal "foo-42 7/bar baz-9")
      (expect (minibuffer-active-p minibuffer) :to-be nil)
      (expect (loom:minibuffer-message-string minibuffer)
              :to-equal "Replaced 1 occurrence(s)"))))
