;;;; t/integration/commands-editing-isearch-test.lisp
;;;;
;;;; Incremental search driven the way a user drives it: real key events
;;;; through the minibuffer, so the ON-CHANGE and ON-KEY hooks are exercised
;;;; rather than the session transitions being called directly.
(in-package #:loom/test)

(defun %control-key (character)
  (cl-tty-kit:make-key-event :type :character
                             :code character
                             :modifiers '(:control)))

(describe
  "incremental search"
  (it
    "moves point to the next match on every keystroke"
    (%with-selected-minibuffer-buffer (minibuffer buffer "alpha beta alpha")
      (buffer-set-point buffer 0 0)
      (loom/feature/search:isearch-forward)
      (expect (minibuffer-prompt-string minibuffer) :to-equal "I-search: ")
      (%type-string minibuffer "b")
      (expect (buffer-point-column buffer) :to-equal 6)
      (%type-string minibuffer "e")
      (expect (buffer-point-column buffer) :to-equal 6)
      (expect (minibuffer-input-string minibuffer) :to-equal "be")))

  (it
    "advances on a further C-s and turns around on C-r"
    (%with-selected-minibuffer-buffer (minibuffer buffer "one two one")
      (buffer-set-point buffer 0 0)
      (loom/feature/search:isearch-forward)
      (%type-string minibuffer "o")
      (expect (buffer-point-column buffer) :to-equal 0)
      (minibuffer-handle-key minibuffer (%control-key #\s))
      (expect (buffer-point-column buffer) :to-equal 6)
      (minibuffer-handle-key minibuffer (%control-key #\s))
      (expect (buffer-point-column buffer) :to-equal 8)
      (minibuffer-handle-key minibuffer (%control-key #\r))
      (expect (buffer-point-column buffer) :to-equal 6)
      (expect (minibuffer-input-string minibuffer) :to-equal "o")))

  (it
    "reports a failing pattern in the prompt and stops moving point"
    (%with-selected-minibuffer-buffer (minibuffer buffer "alpha beta")
      (buffer-set-point buffer 0 0)
      (loom/feature/search:isearch-forward)
      (%type-string minibuffer "be")
      (expect (buffer-point-column buffer) :to-equal 6)
      (%type-string minibuffer "zz")
      (expect (minibuffer-prompt-string minibuffer)
              :to-equal "Failing I-search: ")
      (expect (buffer-point-column buffer) :to-equal 6)
      (minibuffer-handle-key minibuffer (%control-key #\s))
      (expect (buffer-point-column buffer) :to-equal 6)))

  (it
    "recovers when a backspace makes the pattern match again"
    (%with-selected-minibuffer-buffer (minibuffer buffer "alpha beta")
      (buffer-set-point buffer 0 0)
      (loom/feature/search:isearch-forward)
      (%type-string minibuffer "bez")
      (expect (minibuffer-prompt-string minibuffer)
              :to-equal "Failing I-search: ")
      (minibuffer-handle-key minibuffer (%special-key :backspace))
      (expect (minibuffer-prompt-string minibuffer) :to-equal "I-search: ")
      (expect (buffer-point-column buffer) :to-equal 6)))

  (it
    "returns point to where the search started on C-g"
    (%with-selected-minibuffer-buffer (minibuffer buffer "one two one")
      (buffer-set-point buffer 0 4)
      (loom/feature/search:isearch-forward)
      (%type-string minibuffer "one")
      (expect (buffer-point-column buffer) :to-equal 8)
      (minibuffer-handle-key minibuffer (%special-key :control-g))
      (expect (buffer-point-column buffer) :to-equal 4)
      (expect (minibuffer-active-p minibuffer) :to-be nil)
      (expect (editor-state-isearch *editor-state*) :to-be nil)))

  (it
    "keeps point on RET and ends the session"
    (%with-selected-minibuffer-buffer (minibuffer buffer "one two one")
      (buffer-set-point buffer 0 4)
      (loom/feature/search:isearch-forward)
      (%type-string minibuffer "one")
      (minibuffer-handle-key minibuffer (%special-key :enter))
      (expect (buffer-point-column buffer) :to-equal 8)
      (expect (minibuffer-active-p minibuffer) :to-be nil)
      (expect (editor-state-isearch *editor-state*) :to-be nil)))

  (it
    "files the confirmed pattern in the minibuffer history"
    (let* ((history (history-kit:make-history))
           (*editor-state* (%fresh-editor-state "one two one")))
      (setf (editor-state-minibuffer *editor-state*)
            (make-minibuffer :history history))
      (let ((minibuffer (editor-state-minibuffer *editor-state*)))
        (loom/feature/search:isearch-forward)
        (%type-string minibuffer "two")
        (minibuffer-handle-key minibuffer (%special-key :enter))
        (expect (history-kit:history-entry-texts
                 (history-kit:history-entries history))
                :to-contain "two"))))

  (it
    "starts backward from point with C-r"
    (%with-selected-minibuffer-buffer (minibuffer buffer "one two one")
      (buffer-set-point buffer 0 7)
      (loom/feature/search:isearch-backward)
      (expect (minibuffer-prompt-string minibuffer)
              :to-equal "I-search backward: ")
      (%type-string minibuffer "one")
      (expect (buffer-point-column buffer) :to-equal 0)))

  (it
    "exposes every match, and which one point is on, for the renderer"
    (%with-selected-minibuffer-buffer (minibuffer buffer "one two one")
      (buffer-set-point buffer 0 0)
      (loom/feature/search:isearch-forward)
      (%type-string minibuffer "one")
      (let ((session (editor-state-isearch *editor-state*)))
        (expect (mapcar #'buffer-span-start
                        (loom/feature/search:isearch-session-matches session))
                :to-equal '(0 8))
        (expect (buffer-span-start
                 (loom/feature/search:isearch-session-match session))
                :to-equal 0)
        (minibuffer-handle-key minibuffer (%control-key #\s))
        (expect (buffer-span-start
                 (loom/feature/search:isearch-session-match session))
                :to-equal 8)))))
