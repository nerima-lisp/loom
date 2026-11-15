(in-package #:loom/test)

(describe "kill and yank commands"
          (it "normalizes word-kill ranges and coalescing direction"
              (flet ((forward (text offset)
                       (declare (ignore text))
                       (1+ offset))
                     (backward (text offset)
                       (declare (ignore text))
                       (1- offset)))
                (multiple-value-bind (start end prepend)
                    (loom/feature/kill-ring::%kill-word-range "ignored"
                                                              5
                                                              2
                                                              #'backward
                                                              #'forward
                                                              :prepend-when-positive
                                                              t)
                  (expect (list start end prepend) :to-equal '(3 5 t)))
                (multiple-value-bind (start end prepend)
                    (loom/feature/kill-ring::%kill-word-range "ignored"
                                                              5
                                                              -2
                                                              #'forward
                                                              #'forward
                                                              :prepend-when-positive
                                                              t)
                  (expect (list start end prepend) :to-equal '(5 7 nil)))
                (multiple-value-bind (start end prepend)
                    (loom/feature/kill-ring::%kill-word-range "ignored"
                                                              5
                                                              0
                                                              #'forward
                                                              #'backward)
                  (expect (list start end prepend) :to-equal '(nil nil nil)))))
          (it "kill-word removes the next word and adds it to the kill ring"
              (%expect-word-kill
               (loom/feature/kill-ring:kill-word "one two" " two" '("one"))))
          (it "backward-kill-word removes the previous word"
              (%expect-word-kill
               (loom/feature/kill-ring:backward-kill-word "one two"
                                                          "one "
                                                          '("two")
                                                          :point
                                                          (0 7))))
          (it "kill-word with a negative prefix removes the previous word"
              (%expect-word-kill
               (loom/feature/kill-ring:kill-word "one two"
                                                 "one "
                                                 '("two")
                                                 :point
                                                 (0 7)
                                                 :prefix
                                                 -1)))
          (it "backward-kill-word with a negative prefix removes the next word"
              (%expect-word-kill
               (loom/feature/kill-ring:backward-kill-word "one two"
                                                          " two"
                                                          '("one")
                                                          :point
                                                          (0 0)
                                                          :prefix
                                                          -1)))
          (it "kill-word is a no-op at the end of the buffer"
              (%expect-word-kill
               (loom/feature/kill-ring:kill-word "one" "one" nil :point (0 3))))
          (it "backward-kill-word is a no-op at the beginning of the buffer"
              (%expect-word-kill
               (loom/feature/kill-ring:backward-kill-word "one"
                                                          "one"
                                                          nil
                                                          :point
                                                          (0 0))))
          (it "kill-line at end of a non-last line kills through the newline"
              (let ((*editor-state*
                     (%fresh-editor-state (format nil "one~%two"))))
                (let ((buffer (%selected-test-buffer)))
                  (buffer-set-point buffer 0 3)
                  (loom/feature/kill-ring:kill-line)
                  (expect (buffer-text buffer) :to-equal "onetwo")
                  (expect (first (editor-state-kill-ring *editor-state*))
                          :to-equal
                          (format nil "~%")))))
          (it "kill-line is a no-op at the very end of the buffer"
              (let ((*editor-state* (%fresh-editor-state "hi")))
                (let ((buffer (%selected-test-buffer)))
                  (buffer-set-point buffer 0 2)
                  (loom/feature/kill-ring:kill-line)
                  (expect (buffer-text buffer) :to-equal "hi")
                  (expect (editor-state-kill-ring *editor-state*) :to-be nil))))
          (it "kill-region reports no active region when the mark is unset"
              (%with-minibuffer-state (minibuffer "hello")
                                      (loom/feature/kill-ring:kill-region)
                                      (expect
                                       (loom:minibuffer-message-string
                                        minibuffer)
                                       :to-equal
                                       "The mark is not set now, so no region is active")))
          (it "kill-region kills forward from point to mark"
              (let ((*editor-state* (%fresh-editor-state "hello world")))
                (let ((buffer (%selected-test-buffer)))
                  (buffer-set-point buffer 0 0)
                  (buffer-set-mark buffer 0 5)
                  (loom/feature/kill-ring:kill-region)
                  (expect (buffer-line buffer 0) :to-equal " world")
                  (expect (first (editor-state-kill-ring *editor-state*))
                          :to-equal
                          "hello"))))
          (it "kill-region kills backward from mark to point"
              (let ((*editor-state* (%fresh-editor-state "hello world")))
                (let ((buffer (%selected-test-buffer)))
                  (buffer-set-mark buffer 0 0)
                  (buffer-set-point buffer 0 5)
                  (loom/feature/kill-ring:kill-region)
                  (expect (buffer-line buffer 0) :to-equal " world")
                  (expect (first (editor-state-kill-ring *editor-state*))
                          :to-equal
                          "hello"))))
          (it
           "kill-region spans multiple lines when point and mark are on different lines"
           (let ((*editor-state*
                  (%fresh-editor-state (format nil "one~%two~%three"))))
             (let ((buffer (%selected-test-buffer)))
               (buffer-set-point buffer 0 0)
               (buffer-set-mark buffer 2 0)
               (loom/feature/kill-ring:kill-region)
               (expect (buffer-text buffer) :to-equal "three"))))
          (it
           "kill-region spans multiple lines when point is on a later line than mark"
           (let ((*editor-state*
                  (%fresh-editor-state (format nil "one~%two~%three"))))
             (let ((buffer (%selected-test-buffer)))
               (buffer-set-mark buffer 0 0)
               (buffer-set-point buffer 2 0)
               (loom/feature/kill-ring:kill-region)
               (expect (buffer-text buffer) :to-equal "three"))))
          (it "zap-to-char kills through the Nth forward occurrence in one undo"
              (let ((*editor-state* (%fresh-editor-state "aXaXb" :with-minibuffer t))
                    (loom:*current-prefix-argument* 2))
                (let* ((buffer (%selected-test-buffer))
                       (minibuffer
                        (loom/core/editor-session:editor-state-minibuffer
                         *editor-state*)))
                  (buffer-set-point buffer 0 0)
                  (loom/feature/kill-ring:zap-to-char)
                  (minibuffer-handle-key minibuffer
                                         (cl-tty-kit:make-key-event :type
                                                                    :character
                                                                    :code
                                                                    #\X))
                  (expect (buffer-text buffer) :to-equal "b")
                  (expect (first (editor-state-kill-ring *editor-state*))
                          :to-equal
                          "aXaX")
                  (buffer-undo buffer)
                  (expect (buffer-text buffer) :to-equal "aXaXb"))))
          (it "zap-to-char kills backward through the Nth occurrence"
              (let ((*editor-state* (%fresh-editor-state "aXaXb" :with-minibuffer t))
                    (loom:*current-prefix-argument* -2))
                (let* ((buffer (%selected-test-buffer))
                       (minibuffer
                        (loom/core/editor-session:editor-state-minibuffer
                         *editor-state*)))
                  (buffer-set-point buffer 0 5)
                  (loom/feature/kill-ring:zap-to-char)
                  (minibuffer-handle-key minibuffer
                                         (cl-tty-kit:make-key-event :type
                                                                    :character
                                                                    :code
                                                                    #\X))
                  (expect (buffer-text buffer) :to-equal "a")
                  (expect (first (editor-state-kill-ring *editor-state*))
                          :to-equal
                          "XaXb"))))
          (it "zap-to-char coalesces forward and backward kills"
              (let ((*editor-state* (%fresh-editor-state "aaXbb" :with-minibuffer t))
                    (loom:*current-prefix-argument* 1))
                (let* ((buffer (%selected-test-buffer))
                       (minibuffer
                        (loom/core/editor-session:editor-state-minibuffer
                         *editor-state*)))
                  (setf (editor-state-kill-ring *editor-state*) '("old")
                        (editor-state-last-command-kill-p *editor-state*) t)
                  (buffer-set-point buffer 0 0)
                  (loom/feature/kill-ring:zap-to-char)
                  (minibuffer-handle-key minibuffer
                                         (cl-tty-kit:make-key-event :type
                                                                    :character
                                                                    :code
                                                                    #\X))
                  (expect (editor-state-kill-ring *editor-state*)
                          :to-equal
                          '("oldaaX"))))
              (let ((*editor-state* (%fresh-editor-state "aaXbb" :with-minibuffer t))
                    (loom:*current-prefix-argument* -1))
                (let* ((buffer (%selected-test-buffer))
                       (minibuffer
                        (loom/core/editor-session:editor-state-minibuffer
                         *editor-state*)))
                  (setf (editor-state-kill-ring *editor-state*) '("old")
                        (editor-state-last-command-kill-p *editor-state*) t)
                  (buffer-set-point buffer 0 5)
                  (loom/feature/kill-ring:zap-to-char)
                  (minibuffer-handle-key minibuffer
                                         (cl-tty-kit:make-key-event :type
                                                                    :character
                                                                    :code
                                                                    #\X))
                  (expect (editor-state-kill-ring *editor-state*)
                          :to-equal
                          '("Xbbold")))))
          (it
           "zap-to-char reports a miss without changing the buffer or kill ring"
           (let ((*editor-state* (%fresh-editor-state "abc" :with-minibuffer t))
                 (loom:*current-prefix-argument* 2))
             (let* ((buffer (%selected-test-buffer))
                    (minibuffer
                     (loom/core/editor-session:editor-state-minibuffer
                      *editor-state*)))
               (setf (editor-state-kill-ring *editor-state*) '("old"))
               (loom/feature/kill-ring:zap-to-char)
               (minibuffer-handle-key minibuffer
                                      (cl-tty-kit:make-key-event :type
                                                                 :character
                                                                 :code
                                                                 #\X))
               (expect (buffer-text buffer) :to-equal "abc")
               (expect (editor-state-kill-ring *editor-state*)
                       :to-equal
                       '("old"))
               (expect (loom:minibuffer-message-string minibuffer)
                       :to-equal
                       "Search failed: \"X\""))))
          (it "zap-to-char refuses to edit a read-only buffer"
              (let ((*editor-state* (%fresh-editor-state "aXb" :with-minibuffer t))
                    (loom:*current-prefix-argument* 1))
                (let* ((buffer (%selected-test-buffer))
                       (minibuffer
                        (loom/core/editor-session:editor-state-minibuffer
                         *editor-state*)))
                  (loom/core/buffer:buffer-set-read-only buffer t)
                  (loom/feature/kill-ring:zap-to-char)
                  (signals loom/core/buffer:buffer-read-only-error
                           (minibuffer-handle-key minibuffer
                                                  (cl-tty-kit:make-key-event
                                                   :type
                                                   :character
                                                   :code
                                                   #\X)))
                  (expect (buffer-text buffer) :to-equal "aXb")))))
