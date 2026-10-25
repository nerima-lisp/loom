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
