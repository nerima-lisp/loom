;;;; t/unit/terminal-event-test.lisp
;;;;
;;;; Terminal key and paste event translation.
(in-package #:loom/test)

(describe
  "terminal event translation"
  (it-each ((:character #\a nil "a")
            (:character #\c (:control) (:string 3))
            (:character #\x (:alt) (:alt-character #\x))
            (:special :control-x nil (:string 24))
            (:special :up nil (:escape-sequence "[A"))
            (:special :up (:alt) (:double-escape "[A")))
      "translates ~S/~S/~S into ~S"
    (type code modifiers expected-spec)
    (let* ((event (cl-tty-kit:make-key-event
                   :type type :code code :modifiers modifiers))
           (expected-payload
             (cond
               ((stringp expected-spec) expected-spec)
               ((eq (first expected-spec) :string)
                (string (code-char (second expected-spec))))
               ((eq (first expected-spec) :alt-character)
                (format nil "~C~C" (code-char 27) (second expected-spec)))
               ((eq (first expected-spec) :escape-sequence)
                (format nil "~C~A" (code-char 27) (second expected-spec)))
               ((eq (first expected-spec) :double-escape)
                (format nil "~C~C~A"
                        (code-char 27)
                        (code-char 27)
                        (second expected-spec)))
               (t expected-spec))))
      (expect
       (loom/feature/terminal::%terminal-event-payload event)
       :to-equal
       expected-payload)))

  (it-each ((#\@ :nul)
            (#\[ :escape)
            (#\_ :unit-separator)
            (#\Space nil))
      "maps control character ~S to ~S"
    (character expected-tag)
    (let ((expected-code
            (case expected-tag
              (:nul (code-char 0))
              (:escape (code-char 27))
              (:unit-separator (code-char 31))
              (otherwise nil))))
      (if expected-code
          (expect
           (loom/feature/terminal::%terminal-control-character character)
           :to-equal
           expected-code)
          (expect
           (loom/feature/terminal::%terminal-control-character character)
           :to-be nil))))

  (it-each ((:character #\a nil "" :none)
            (:character #\@ (:control) nil (:string 0))
            (:paste "pasted" nil nil "pasted")
            (:special :page-down nil nil (:escape-sequence "[6~"))
            (:special :unknown nil nil :none))
      "produces terminal payload ~S for type ~S"
    (type code modifiers text expected-spec)
    (let* ((event-args (list :type type :code code))
           (event-args (if modifiers
                           (append event-args (list :modifiers modifiers))
                           event-args))
           (event-args (if text
                           (append event-args (list :text text))
                           event-args))
           (event (apply #'cl-tty-kit:make-key-event event-args))
           (expected-payload
             (cond
               ((eq expected-spec :none) nil)
               ((stringp expected-spec) expected-spec)
               ((eq (first expected-spec) :string)
                (string (code-char (second expected-spec))))
               ((eq (first expected-spec) :escape-sequence)
                (format nil "~C~A" (code-char 27) (second expected-spec)))
               (t expected-spec))))
      (if expected-payload
          (expect
           (loom/feature/terminal::%terminal-event-payload event)
           :to-equal
           expected-payload)
          (expect
           (loom/feature/terminal::%terminal-event-payload event)
           :to-be nil))))

  (it-each ((:release nil)
            (:repeat t))
      "accepts terminal event kind ~S => ~S"
    (kind acceptable-p)
    (let ((event (cl-tty-kit:make-key-event
                  :type :character :code #\a :kind kind)))
      (if acceptable-p
          (expect
           (loom/feature/terminal::%terminal-event-kind-acceptable-p event)
           :to-be-truthy)
          (expect
           (loom/feature/terminal::%terminal-event-kind-acceptable-p event)
           :to-be nil)))))
