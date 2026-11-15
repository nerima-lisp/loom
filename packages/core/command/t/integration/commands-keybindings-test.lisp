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
            :to-equal '((:control) . #\f)))
  (it "rejects an unknown chord modifier"
    (expect (handler-case
                (progn (loom/application:defkeys-chord '(:meta #\f)) nil)
              (error () t))
            :to-be-truthy))
  (it "rejects an invalid chord code"
    (expect (handler-case
                (progn (loom/application:defkeys-chord '(:control :alt)) nil)
              (error () t))
            :to-be-truthy)))
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
(progn
  (defvar *char-command-test-minibuffer* nil)
  (defvar *char-command-test-result* nil)
  (defvar *char-command-test-cancelled-p* nil)
  (defun %char-command-test-command ()
    (loom/application:with-prompts
     (minibuffer *char-command-test-minibuffer*
                 :on-cancel (setf *char-command-test-cancelled-p* t))
     ((character "Choose: "
                 :input-kind :char
                 :allowed-characters "rdi"))
     (setf *char-command-test-result* character)))
  (describe
   "with-prompts character command behavior"
   (it "accepts an allowed key, keeps invalid guidance in the prompt, and cancels cleanly"
       (let* ((*char-command-test-minibuffer*
               (loom/core/minibuffer:make-minibuffer))
              (*char-command-test-result* nil)
              (*char-command-test-cancelled-p* nil)
              (spec
               (loom/core/command:command-spec
                "test-char-prompt" %char-command-test-command
                :mutates nil :prompts (:char) :needs-region nil
                :external nil :modes (:all))))
         (funcall (getf spec :command))
         (loom/core/minibuffer:minibuffer-handle-key
          *char-command-test-minibuffer*
          (cl-tty-kit:make-key-event :type :character :code #\x))
         (expect (loom/core/minibuffer:minibuffer-message-string *char-command-test-minibuffer*) :to-be nil)
         (expect
          (loom/core/minibuffer:minibuffer-prompt-string
           *char-command-test-minibuffer*)
          :to-equal "Choose: Allowed keys: r, d, i")
         (expect
          (loom/core/minibuffer:minibuffer-active-p
           *char-command-test-minibuffer*)
          :to-be-truthy)
         (expect
          (loom/core/minibuffer:minibuffer-input-string
           *char-command-test-minibuffer*)
          :to-equal "")
         (loom/core/minibuffer:minibuffer-handle-key
          *char-command-test-minibuffer*
          (cl-tty-kit:make-key-event :type :character :code #\d))
         (expect *char-command-test-result* :to-equal "d")
         (expect *char-command-test-cancelled-p* :to-be-falsy)
         (expect
          (loom/core/minibuffer:minibuffer-active-p
           *char-command-test-minibuffer*)
          :to-be-falsy)
         (expect
          (loom/core/minibuffer:minibuffer-prompt-string
           *char-command-test-minibuffer*)
          :to-be nil)
         (expect
          (loom/core/minibuffer:minibuffer-message-string
           *char-command-test-minibuffer*)
          :to-be nil)
         (setf *char-command-test-result* nil
               *char-command-test-cancelled-p* nil)
         (funcall (getf spec :command))
         (loom/core/minibuffer:minibuffer-handle-key
          *char-command-test-minibuffer*
          (cl-tty-kit:make-key-event :type :character :code #\x))
         (loom/core/minibuffer:minibuffer-handle-key
          *char-command-test-minibuffer*
          (cl-tty-kit:make-key-event :type :special :code :control-g))
         (expect *char-command-test-cancelled-p* :to-be-truthy)
         (expect *char-command-test-result* :to-be nil)
         (expect
          (loom/core/minibuffer:minibuffer-active-p
           *char-command-test-minibuffer*)
          :to-be-falsy)
         (expect
          (loom/core/minibuffer:minibuffer-prompt-string
           *char-command-test-minibuffer*)
          :to-be nil)
         (expect
          (loom/core/minibuffer:minibuffer-message-string
           *char-command-test-minibuffer*)
          :to-be nil)))
   (it "shows guidance for any character and does not call ON-CHANGE on acceptance"
       (let ((minibuffer (loom/core/minibuffer:make-minibuffer))
             (confirmed nil)
             (changes nil))
         (loom/core/minibuffer:minibuffer-activate
          minibuffer "Choose: "
          :input-kind :char
          :on-change (lambda (input) (push input changes))
          :on-confirm (lambda (input) (setf confirmed input)))
         (loom/core/minibuffer:minibuffer-handle-key
          minibuffer
          (cl-tty-kit:make-key-event :type :special :code :up))
         (expect (loom/core/minibuffer:minibuffer-message-string minibuffer) :to-be nil)
         (expect (loom/core/minibuffer:minibuffer-prompt-string minibuffer)
                 :to-equal "Choose: Type a character.")
         (expect (loom/core/minibuffer:minibuffer-active-p minibuffer)
                 :to-be-truthy)
         (expect (loom/core/minibuffer:minibuffer-input-string minibuffer)
                 :to-equal "")
         (loom/core/minibuffer:minibuffer-handle-key
          minibuffer
          (cl-tty-kit:make-key-event :type :character :code #\z))
         (expect confirmed :to-equal "z")
         (expect changes :to-be nil)
         (expect (loom/core/minibuffer:minibuffer-message-string minibuffer)
                 :to-be nil)
         (expect (loom/core/minibuffer:minibuffer-prompt-string minibuffer)
                 :to-be nil)))
   (it "composes ON-KEY with character handling and prioritizes both C-g encodings"
       (let ((minibuffer (loom/core/minibuffer:make-minibuffer))
             (handled nil)
             (confirmed nil))
         (loom/core/minibuffer:minibuffer-activate
          minibuffer "Choose: "
          :input-kind :char
          :allowed-characters "d"
          :on-key (lambda (event)
                    (push event handled)
                    (equal (cl-tty-kit:key-event-code event) #\z))
          :on-confirm (lambda (input) (setf confirmed input)))
         (loom/core/minibuffer:minibuffer-handle-key
          minibuffer
          (cl-tty-kit:make-key-event :type :character :code #\z))
         (expect (length handled) :to-equal 1)
         (expect (loom/core/minibuffer:minibuffer-active-p minibuffer)
                 :to-be-truthy)
         (expect (loom/core/minibuffer:minibuffer-input-string minibuffer)
                 :to-equal "")
         (expect (loom/core/minibuffer:minibuffer-message-string minibuffer)
                 :to-be nil)
         (loom/core/minibuffer:minibuffer-handle-key
          minibuffer
          (cl-tty-kit:make-key-event :type :special :code :up))
         (expect (length handled) :to-equal 2)
         (expect (loom/core/minibuffer:minibuffer-message-string minibuffer) :to-be nil)
         (expect (loom/core/minibuffer:minibuffer-prompt-string minibuffer)
                 :to-equal "Choose: Allowed keys: d")
         (loom/core/minibuffer:minibuffer-handle-key
          minibuffer
          (cl-tty-kit:make-key-event :type :character :code #\d))
         (expect confirmed :to-equal "d")
         (expect (length handled) :to-equal 3))
       (dolist
           (event
            (list
             (cl-tty-kit:make-key-event :type :special :code :control-g)
             (cl-tty-kit:make-key-event
              :type :character :code #\g :modifiers '(:control))))
         (let ((minibuffer (loom/core/minibuffer:make-minibuffer))
               (cancelled nil)
               (handled-count 0))
           (loom/core/minibuffer:minibuffer-activate
            minibuffer "Choose: "
            :input-kind :char
            :on-key (lambda (key-event)
                      (declare (ignore key-event))
                      (incf handled-count)
                      t)
            :on-cancel (lambda () (setf cancelled t)))
           (loom/core/minibuffer:minibuffer-handle-key minibuffer event)
           (expect cancelled :to-be-truthy)
           (expect handled-count :to-equal 0)
           (expect (loom/core/minibuffer:minibuffer-active-p minibuffer)
                   :to-be-falsy)
           (expect (loom/core/minibuffer:minibuffer-prompt-string minibuffer)
                   :to-be nil)
           (expect (loom/core/minibuffer:minibuffer-message-string minibuffer)
                   :to-be nil))))))
