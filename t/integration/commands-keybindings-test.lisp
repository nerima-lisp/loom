(in-package #:loom/test)
(describe
  "%defkeys-single-chord-p"
  (it "is true for a bare keyword (an unmodified special key)"
    (expect (loom/application:defkeys-single-chord-p :backspace) :to-be-truthy))
  (it "is true for a (:control code) chord"
    (expect (loom/application:defkeys-single-chord-p '(:control #\f)) :to-be-truthy))
  (it "is true for a (:alt code) chord"
    (expect (loom/application:defkeys-single-chord-p '(:alt #\x)) :to-be-truthy))
  (it "is false for a multi-chord sequence"
    (expect (loom/application:defkeys-single-chord-p '((:control #\x) (:control #\f))) :to-be-falsy)))
(describe
  "%defkeys-chord"
  (it "normalizes a bare atom into an unmodified descriptor"
    (expect (loom/application:defkeys-chord :enter) :to-equal '(nil . :enter)))
  (it "normalizes a modified chord into a descriptor"
    (expect (loom/application:defkeys-chord '(:control #\f))
            :to-equal '((:control) . #\f))))
(describe
  "%defkeys-key-sequence"
  (it "wraps a single modified chord in a sequence"
    (expect (loom/application:defkeys-key-sequence '(:control #\f))
            :to-equal '(((:control) . #\f))))
  (it "normalizes a multi-chord sequence"
    (expect (loom/application:defkeys-key-sequence '((:control #\x) (:control #\f)))
            :to-equal '(((:control) . #\x) ((:control) . #\f))))
  (it "wraps a bare atom in an unmodified sequence"
    (expect (loom/application:defkeys-key-sequence :enter)
            :to-equal '((nil . :enter)))))
(describe
  "with-prompts macroexpansion"
  (it "expands into a LET binding the minibuffer once, then nested prompts"
    (let ((expansion (macroexpand-1
                       '(loom/application:with-prompts (m (foo))
                            ((old "Replace: ") (new "With: "))
                          (use old new)))))
      (expect (first expansion) :to-equal 'let)
      (expect (second expansion) :to-equal '((m (foo))))
      (let ((outer-activate (third expansion)))
        (expect (first outer-activate) :to-equal 'loom:minibuffer-activate)
        (expect (second outer-activate) :to-equal 'm)
        (expect (third outer-activate) :to-equal "Replace: ")
        (expect (fourth outer-activate) :to-equal :on-confirm)
        (let ((outer-lambda (fifth outer-activate)))
          (expect (first outer-lambda) :to-equal 'lambda)
          (expect (second outer-lambda) :to-equal '(old))
          (let ((inner-activate (third outer-lambda)))
            (expect (first inner-activate) :to-equal 'loom:minibuffer-activate)
            (expect (third inner-activate) :to-equal "With: ")
            (let ((inner-lambda (fifth inner-activate)))
              (expect (second inner-lambda) :to-equal '(new))
              (expect (third inner-lambda) :to-equal '(progn (use old new)))))))))
  (it "expands to just the body, wrapped in a LET, when BINDINGS is empty"
    (let ((expansion (macroexpand-1
                       '(loom/application:with-prompts
                          (m (foo)) () (use-nothing)))))
      (expect expansion :to-equal '(let ((m (foo))) (progn (use-nothing))))))
  (it "omits the :on-cancel keyword entirely when ON-CANCEL is not supplied"
    (let ((expansion (macroexpand-1
                       '(loom/application:with-prompts
                          (m (foo)) ((old "Replace: ")) (use old)))))
      (expect (length (third expansion)) :to-equal 5)))
  (it "threads :on-cancel into every activation in the chain, after :on-confirm"
    (let* ((expansion (macroexpand-1
                        '(loom/application:with-prompts
                          (m (foo) :on-cancel (bail m))
                             ((old "Replace: ") (new "With: "))
                           (use old new))))
           (outer-activate (third expansion))
           (inner-activate (third (fifth outer-activate))))
      (expect (fourth outer-activate) :to-equal :on-confirm)
      (expect (sixth outer-activate) :to-equal :on-cancel)
      (expect (seventh outer-activate) :to-equal '(lambda () (bail m)))
      (expect (sixth inner-activate) :to-equal :on-cancel)
      (expect (seventh inner-activate) :to-equal '(lambda () (bail m))))))
(describe
  "prompt cancellation"
  ;; Every prompting command passes WITH-PROMPTS an :ON-CANCEL that reports
  ;; "Quit", the same message KEYBOARD-QUIT gives for a top-level C-g, so
  ;; abandoning a prompt is acknowledged rather than silent. Driven through
  ;; MINIBUFFER-HANDLE-KEY with a real C-g key event (the sibling tests drive
  ;; %MINIBUFFER-ON-CONFIRM directly, which cannot exercise the cancel path).
  (it-each
      (("find-file" loom/feature/file-tree:find-file)
       ("save-buffer on a path-less buffer" loom/feature/file-tree:save-buffer)
       ("write-file" loom/feature/file-tree:write-file)
       ("search-forward" loom/feature/search::search-forward)
       ("search-backward" loom/feature/search::search-backward)
       ("replace-string" loom/feature/search::replace-string)
       ("goto-line" loom::goto-line)
       ("switch-to-buffer" loom/feature/window:switch-to-buffer)
       ("execute-extended-command" loom::execute-extended-command))
      "~A reports Quit on C-g" (label command)
    (declare (ignore label))
    (%with-minibuffer-state (minibuffer "hi")
      (funcall command)
      (expect (minibuffer-active-p minibuffer) :to-be-truthy)
      (minibuffer-handle-key minibuffer (%special-key :control-g))
      (expect (minibuffer-active-p minibuffer) :to-be-falsy)
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Quit")))

  (it
    "cancelling replace-string's second prompt quits without replacing"
    ;; WITH-PROMPTS threads :ON-CANCEL into every activation in the chain,
    ;; not only the first, so a C-g after the first answer is confirmed still
    ;; reports Quit -- and the buffer is left untouched, proving the body
    ;; (and so %PERFORM-REPLACEMENT) never ran.
    (%with-minibuffer-state (minibuffer "alpha alpha")
      (loom/feature/search::replace-string)
      (%type-string minibuffer "alpha")
      (minibuffer-handle-key minibuffer (%special-key :enter))
      (expect (minibuffer-prompt-string minibuffer) :to-equal "With: ")
      (minibuffer-handle-key minibuffer (%special-key :control-g))
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Quit")
      (expect (buffer-text (%selected-test-buffer)) :to-equal "alpha alpha")))

  (it
    "cancelling file-tree-create-file-command creates nothing"
    (host-kit:with-temporary-directory (dir)
      (%with-minibuffer-state (minibuffer "")
        (setf (editor-state-file-tree *editor-state*) (%fresh-file-tree dir))
        (loom/feature/file-tree:file-tree-create-file-command)
        (%type-string minibuffer (namestring (merge-pathnames "unwanted.txt" dir)))
        (minibuffer-handle-key minibuffer (%special-key :control-g))
        (expect (loom:minibuffer-message-string minibuffer) :to-equal "Quit")
        (expect (host-kit:path-exists-p (merge-pathnames "unwanted.txt" dir))
                :to-be-falsy))))

  (it
    "cancelling file-tree-create-directory-command creates nothing"
    (host-kit:with-temporary-directory (dir)
      (%with-minibuffer-state (minibuffer "")
        (setf (editor-state-file-tree *editor-state*) (%fresh-file-tree dir))
        (loom/feature/file-tree:file-tree-create-directory-command)
        (%type-string minibuffer (namestring (merge-pathnames "unwanted-dir/" dir)))
        (minibuffer-handle-key minibuffer (%special-key :control-g))
        (expect (loom:minibuffer-message-string minibuffer) :to-equal "Quit")
        (expect (host-kit:path-exists-p (merge-pathnames "unwanted-dir/" dir))
                :to-be-falsy))))

  (it
    "cancelling file-tree-rename-command leaves the selected entry unchanged"
    (host-kit:with-temporary-directory (dir)
      (let ((old-path (merge-pathnames "old.txt" dir))
            (new-path (merge-pathnames "new.txt" dir)))
        (host-kit:write-file-string "content" old-path)
        (%with-minibuffer-state (minibuffer "")
          (setf (editor-state-file-tree *editor-state*) (%fresh-file-tree dir))
          (loom/feature/file-tree:file-tree-select-next)
          (loom/feature/file-tree:file-tree-rename-command)
          (%type-string minibuffer (namestring new-path))
          (minibuffer-handle-key minibuffer (%special-key :control-g))
          (expect (loom:minibuffer-message-string minibuffer) :to-equal "Quit")
          (expect (host-kit:path-exists-p old-path) :to-be-truthy)
          (expect (host-kit:path-exists-p new-path) :to-be-falsy)))))

  (it
    "cancelling save-buffers-kill-terminal's quit prompt reports Quit"
    (%with-minibuffer-state (minibuffer "")
      (buffer-insert-string (%selected-test-buffer) "unsaved")
      (loom::save-buffers-kill-terminal)
      (expect (minibuffer-active-p minibuffer) :to-be-truthy)
      (minibuffer-handle-key minibuffer (%special-key :control-g))
      (expect (loom:minibuffer-message-string minibuffer) :to-equal "Quit"))))
