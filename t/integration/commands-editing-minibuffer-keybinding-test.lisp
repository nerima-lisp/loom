;;;; t/integration/commands-editing-minibuffer-keybinding-test.lisp
;;;;
;;;; Search-related keybinding and goto-line integration tests.
(in-package #:loom/test)

(describe
  "search keybindings and goto-line"
  (it-each
      (("C-s" (((:control) . #\s)) loom/feature/search::search-forward)
       ("M-%" (((:alt) . #\%)) loom/feature/search::replace-string)
       ("C-w" (((:control) . #\w)) loom::kill-region)
       ("C-o" (((:control) . #\o)) loom::open-line)
       ("C-x n n" (((:control) . #\x)
                   (nil . #\n)
                   (nil . #\n))
        loom::narrow-to-region)
       ("C-x n w" (((:control) . #\x)
                   (nil . #\n)
                   (nil . #\w))
        loom::widen)
       ("M-g g" (((:alt) . #\g) (nil . #\g)) loom::goto-line))
      "binds ~A to its default command" (label key-sequence command)
    (declare (ignore label))
    (let ((keymap (make-keymap)))
      (loom/application:install-default-keybindings keymap)
      (expect (keymap-lookup keymap key-sequence) :to-be command)))

  (it
    "moves to a one-based line entered in the minibuffer"
    (%with-minibuffer-state (minibuffer (format nil "one~%two~%three"))
      (loom::goto-line)
      (%expect-minibuffer-prompt minibuffer (%goto-line-prompt-string))
      (%confirm-minibuffer minibuffer "3")
      (expect (buffer-point-line (%selected-test-buffer)) :to-equal 2)))

  (it-each
      (("reports a non-positive line number without moving point"
        "0"
        "Line number must be positive")
       ("reports unparseable input without moving point"
        "not-a-number"
        "Enter a line number"))
      "~A" (label input expected-message)
    (%with-minibuffer-state (minibuffer (format nil "one~%two"))
      (loom::goto-line)
      (%confirm-minibuffer minibuffer input)
      (expect (loom:minibuffer-message-string minibuffer) :to-equal expected-message)
      (expect (buffer-point-line (%selected-test-buffer)) :to-equal 0))))
