(in-package #:loom/test)

(progn
  ;; GNU Emacs Manual: C-h is the prefix for help commands:
  ;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Help-Summary.html
  ;; GNU Emacs Manual: C-h b/k/m/x help-command semantics:
  ;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Help-Summary.html
  (defun %help-test-buffer ()
    (loom/feature/buffers:find-buffer-by-name
     (loom/core/editor-session:editor-state-session
      loom/core/editor-session:*editor-state*)
     "*Help*"))

  (defun %help-test-buffer-text ()
    (let ((buffer (%help-test-buffer)))
      (and buffer (loom/core/buffer:buffer-text buffer))))

  (defun %install-help-test-keybindings ()
    (loom/core/command:install-default-keybindings
     (loom/core/editor-session:editor-state-keymap
      loom/core/editor-session:*editor-state*)))

  (describe "help commands"
    (it "moves generic help to F1 and binds C-h as the help prefix"
      (let ((keymap (make-keymap)))
        (loom/core/command:install-default-keybindings keymap)
        (expect (keymap-lookup keymap
                               (list (cons (list :control) #\h)))
                :to-equal
                :prefix)
        (expect (keymap-lookup keymap (list (cons nil :f1)))
                :to-equal
                "help")
        (dolist
            (binding
             (list
              (list (list (cons (list :control) #\h)
                          (cons nil #\k))
                    "describe-key")
              (list (list (cons (list :control) #\h)
                          (cons nil #\x))
                    "describe-command")
              (list (list (cons (list :control) #\h)
                          (cons nil #\b))
                    "describe-bindings")
              (list (list (cons (list :control) #\h)
                          (cons nil #\m))
                    "describe-mode")))
          (expect (keymap-lookup keymap (first binding))
                  :to-equal
                  (second binding)))))

    (it "shows a help summary in the *Help* result buffer"
      (%with-minibuffer-state (minibuffer "")
        (%install-help-test-keybindings)
        (loom/feature/help:help-command)
        (let* ((help-buffer (%help-test-buffer))
               (window
                 (loom/core/window-tree:window-tree-selected-window
                  (loom/core/editor-session:editor-state-window-tree
                   loom/core/editor-session:*editor-state*))))
          (expect help-buffer :to-be-truthy)
          (expect (loom/core/window-tree:window-buffer window)
                  :to-be
                  help-buffer)
          (expect (search "C-h k" (%help-test-buffer-text))
                  :to-be-truthy)
          (progn
            (expect (loom/core/buffer:buffer-modified-p help-buffer)
                    :to-be nil)
            (expect (minibuffer-message-string minibuffer) :to-be nil)))))

    ;; GNU Emacs Manual: C-h k displays the command bound to a key sequence.
    ;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Key-Help.html
    (it "describes a key through the active keymap"
      (expect (loom/feature/help::%help-parse-key-chord "M-DEL")
              :to-equal
              (cons '(:alt) :backspace))
      (expect (loom/feature/help::%help-parse-key-chord "F1")
              :to-equal
              (cons nil :f1))
      (expect (loom/feature/help::%help-parse-key-chord "C-M-UP")
              :to-equal
              (cons '(:control :alt) :up))
      (expect (loom/feature/help::%help-parse-key-sequence "C-h k")
              :to-equal
              (list (cons '(:control) #\h) #\k))
      (%with-minibuffer-state (minibuffer "")
        (%install-help-test-keybindings)
        (loom/feature/help:describe-key)
        (%expect-minibuffer-prompt minibuffer "Describe key: ")
        (%confirm-minibuffer minibuffer "C-f")
        (expect (search "forward-char" (%help-test-buffer-text))
                :to-be-truthy)))

    (it "describes a named command"
      (%with-minibuffer-state (minibuffer "")
        (%install-help-test-keybindings)
        (loom/feature/help:describe-command)
        (%expect-minibuffer-prompt minibuffer "Describe command: ")
        (expect
         (funcall
          (loom/core/minibuffer::%minibuffer-completion-function minibuffer)
          "forward")
         :to-contain
         "forward-char")
        (%confirm-minibuffer minibuffer "forward-char")
        (expect (search "forward-char" (%help-test-buffer-text))
                :to-be-truthy)))

    (it "lists global and selected mode bindings"
      (%with-registered-major-modes (:loom-help-test-mode)
        (loom/feature/mode:register-major-mode
         :loom-help-test-mode
         :name "Help Test Mode"
         :keybindings (list (cons #\q (function loom::forward-char))))
        (%with-minibuffer-state (minibuffer "")
          (%install-help-test-keybindings)
          (loom/core/buffer:buffer-set-major-mode
           (%selected-test-buffer) :loom-help-test-mode)
          (loom/feature/help:describe-bindings)
          (expect (search "Global bindings" (%help-test-buffer-text))
                  :to-be-truthy)
          (expect (search "C-f" (%help-test-buffer-text))
                  :to-be-truthy)
          (expect (search "Help Test Mode bindings" (%help-test-buffer-text))
                  :to-be-truthy)
          (expect (search "q  forward-char" (%help-test-buffer-text))
                  :to-be-truthy))))

    (progn
      (it "describes the selected buffer major mode"
        (%with-minibuffer-state (minibuffer "")
          (%install-help-test-keybindings)
          (let ((buffer (%selected-test-buffer)))
            (loom/core/buffer:buffer-set-major-mode buffer :python))
          (loom/feature/help:describe-mode)
          (expect (search "Python" (%help-test-buffer-text))
                  :to-be-truthy)))
      (it "includes the active mode description"
        (%with-registered-major-modes (:loom-help-test-mode)
          (loom/feature/mode:register-major-mode
           :loom-help-test-mode
           :name "Help Test Mode"
           :description "Description from the active mode.")
          (%with-minibuffer-state (minibuffer "")
            (%install-help-test-keybindings)
            (loom/core/buffer:buffer-set-major-mode
             (%selected-test-buffer) :loom-help-test-mode)
            (loom/feature/help:describe-mode)
            (expect (search "Help Test Mode" (%help-test-buffer-text))
                    :to-be-truthy)
            (expect
             (search "Description from the active mode." (%help-test-buffer-text))
             :to-be-truthy)))))))
