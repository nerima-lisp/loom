(in-package #:loom/test)

(defun %control-key (character)
  (cl-tty-kit:make-key-event :type :character
                             :code character
                             :modifiers '(:control)))

(describe
  "incremental search"
  (it
    "does nothing when no minibuffer is available"
    (let ((*editor-state* (%fresh-editor-state "alpha")))
      (loom/feature/search:isearch-forward)
      (expect (editor-state-isearch *editor-state*) :to-be nil)
      (expect (buffer-point-column (%selected-test-buffer)) :to-equal 0)))

  (it
    "moves point to the next match on every keystroke"
    (%with-selected-minibuffer-buffer (minibuffer buffer "alpha beta alpha")
      (buffer-set-point buffer 0 0)
      (loom/feature/search:isearch-forward)
      (expect (minibuffer-prompt-string minibuffer) :to-equal "I-search: ")
      (%search-type-string minibuffer "b")
      (expect (buffer-point-column buffer) :to-equal 6)
      (%search-type-string minibuffer "e")
      (expect (buffer-point-column buffer) :to-equal 6)
      (expect (minibuffer-input-string minibuffer) :to-equal "be")))

  (it
    "advances on a further C-s and turns around on C-r"
    (%with-selected-minibuffer-buffer (minibuffer buffer "one two one")
      (buffer-set-point buffer 0 0)
      (loom/feature/search:isearch-forward)
      (%search-type-string minibuffer "o")
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
      (%search-type-string minibuffer "be")
      (expect (buffer-point-column buffer) :to-equal 6)
      (%search-type-string minibuffer "zz")
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
      (%search-type-string minibuffer "bez")
      (expect (minibuffer-prompt-string minibuffer)
              :to-equal "Failing I-search: ")
      (minibuffer-handle-key minibuffer (%search-special-key :backspace))
      (expect (minibuffer-prompt-string minibuffer) :to-equal "I-search: ")
      (expect (buffer-point-column buffer) :to-equal 6)))

  (it
    "returns point to where the search started on C-g"
    (%with-selected-minibuffer-buffer (minibuffer buffer "one two one")
      (buffer-set-point buffer 0 4)
      (loom/feature/search:isearch-forward)
      (%search-type-string minibuffer "one")
      (expect (buffer-point-column buffer) :to-equal 8)
      (minibuffer-handle-key minibuffer (%search-special-key :control-g))
      (expect (buffer-point-column buffer) :to-equal 4)
      (expect (minibuffer-active-p minibuffer) :to-be nil)
      (expect (editor-state-isearch *editor-state*) :to-be nil)))

  (it
    "keeps point on RET and ends the session"
    (%with-selected-minibuffer-buffer (minibuffer buffer "one two one")
      (buffer-set-point buffer 0 4)
      (loom/feature/search:isearch-forward)
      (%search-type-string minibuffer "one")
      (minibuffer-handle-key minibuffer (%search-special-key :enter))
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
        (%search-type-string minibuffer "two")
        (minibuffer-handle-key minibuffer (%search-special-key :enter))
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
      (%search-type-string minibuffer "one")
      (expect (buffer-point-column buffer) :to-equal 0)))

  (it
    "reports a failing backward search in the prompt"
    (%with-selected-minibuffer-buffer (minibuffer buffer "alpha beta")
      (buffer-set-point buffer 0 6)
      (loom/feature/search:isearch-backward)
      (%search-type-string minibuffer "zz")
      (expect (minibuffer-prompt-string minibuffer)
              :to-equal "Failing I-search backward: ")
      (expect (buffer-point-column buffer) :to-equal 6)))

  (it
    "exposes every match, and which one point is on, for the renderer"
    (%with-selected-minibuffer-buffer (minibuffer buffer "one two one")
      (buffer-set-point buffer 0 0)
      (loom/feature/search:isearch-forward)
      (%search-type-string minibuffer "one")
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
                :to-equal 8))))
  (it
    "starts forward regexp incremental search through C-M-s key dispatch"
    ;; C-M-s/C-M-r use regexp search; C-s/C-r use incremental literal search.
    ;; GNU Emacs Manual:
    ;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Regexp-Search.html
    ;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Incremental-Search.html
    (%with-selected-minibuffer-buffer
        (minibuffer buffer "ab"
          (keymap (loom/core/command:install-default-keybindings (make-keymap)))
          (keymap-state (make-keymap-state keymap)))
      (setf (editor-state-keymap *editor-state*) keymap)
      (buffer-set-point buffer 0 0)
      (loom::%dispatch-key-event
       (cl-tty-kit:make-key-event :type :character :code #\s
                                  :modifiers (list :control :alt))
       keymap-state)
      (multiple-value-bind (symbol status)
          (find-symbol "ISEARCH-FORWARD-REGEXP" "LOOM/FEATURE/SEARCH")
        (expect status :to-equal :external)
        (expect (fboundp symbol) :to-be-truthy))
      (%search-type-string minibuffer ".")
      (expect (minibuffer-prompt-string minibuffer)
              :to-equal "Regexp I-search: ")
      (expect (buffer-point-column buffer) :to-equal 0)))
  (it
    "starts backward regexp incremental search through C-M-r key dispatch"
    (%with-selected-minibuffer-buffer
        (minibuffer buffer "ab"
          (keymap (loom/core/command:install-default-keybindings (make-keymap)))
          (keymap-state (make-keymap-state keymap)))
      (setf (editor-state-keymap *editor-state*) keymap)
      (buffer-set-point buffer 0 2)
      (loom::%dispatch-key-event
       (cl-tty-kit:make-key-event :type :character :code #\r
                                  :modifiers (list :control :alt))
       keymap-state)
      (multiple-value-bind (symbol status)
          (find-symbol "ISEARCH-BACKWARD-REGEXP" "LOOM/FEATURE/SEARCH")
        (expect status :to-equal :external)
        (expect (fboundp symbol) :to-be-truthy))
      (%search-type-string minibuffer ".")
      (expect (minibuffer-prompt-string minibuffer)
              :to-equal "Regexp I-search backward: ")
      (expect (buffer-point-column buffer) :to-equal 1)))
  (it
    "toggles regexp matching with M-r during forward and backward isearch"
    ;; C-M-s/C-M-r start regexp isearch; M-r toggles regexp mode during isearch.
    ;; GNU Emacs Manual:
    ;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Regexp-Search.html
    ;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Special-Isearch.html
    (%with-selected-minibuffer-buffer (minibuffer buffer "a.")
      (buffer-set-point buffer 0 0)
      (loom/feature/search:isearch-forward)
      (%search-type-string minibuffer ".")
      (expect (minibuffer-prompt-string minibuffer) :to-equal "I-search: ")
      (expect (buffer-point-column buffer) :to-equal 1)
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event :type :character :code #\r
                                  :modifiers (list :alt)))
      (expect (minibuffer-prompt-string minibuffer)
              :to-equal "Regexp I-search: ")
      (expect (buffer-point-column buffer) :to-equal 0)
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event :type :character :code #\r
                                  :modifiers (list :alt)))
      (expect (minibuffer-prompt-string minibuffer) :to-equal "I-search: ")
      (expect (buffer-point-column buffer) :to-equal 1))
    (%with-selected-minibuffer-buffer (minibuffer buffer "ba")
      (buffer-set-point buffer 0 2)
      (loom/feature/search:isearch-backward)
      (%search-type-string minibuffer ".")
      (expect (minibuffer-prompt-string minibuffer)
              :to-equal "Failing I-search backward: ")
      (expect (buffer-point-column buffer) :to-equal 2)
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event :type :character :code #\r
                                  :modifiers (list :alt)))
      (expect (minibuffer-prompt-string minibuffer)
              :to-equal "Regexp I-search backward: ")
      (expect (buffer-point-column buffer) :to-equal 1)
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event :type :character :code #\r
                                  :modifiers (list :alt)))
      (expect (minibuffer-prompt-string minibuffer)
              :to-equal "Failing I-search backward: ")
      (expect (buffer-point-column buffer) :to-equal 1))))
