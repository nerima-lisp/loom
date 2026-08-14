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

(describe
  "terminal event boundary translation"
  (it "translates every supported special key and control boundary"
    (dolist (case-data
              '((:enter :literal 13) (:backspace :literal 127)
                (:tab :literal 9) (:backtab :csi "Z")
                (:escape :literal 27) (:up :csi "A")
                (:down :csi "B") (:right :csi "C") (:left :csi "D")
                (:home :csi "H") (:end :csi "F")
                (:delete :csi "3~") (:insert :csi "2~")
                (:page-up :csi "5~") (:page-down :csi "6~")))
      (destructuring-bind (code representation value) case-data
        (let ((expected
                (case representation
                  (:literal (string (code-char value)))
                  (:csi (format nil "~C[~A" (code-char 27) value)))))
          (expect (loom/feature/terminal::%terminal-special-payload code)
                  :to-equal
                  expected))))
    (dolist (case-data '((#\a 1) (#\z 26) (#\[ 27) (#\\ 28)
                         (#\] 29) (#\^ 30) (#\_ 31)))
      (destructuring-bind (character expected-code) case-data
        (expect (loom/feature/terminal::%terminal-control-character character)
                :to-equal
                (code-char expected-code))))
    (expect (loom/feature/terminal::%terminal-control-character #\?)
            :to-be nil))

  (it "preserves paste and character fallback payloads"
    (let ((paste (cl-tty-kit:make-key-event
                  :type :paste :code "pasted"))
          (character (cl-tty-kit:make-key-event
                      :type :character :code #\z :text ""))
          (control-at (cl-tty-kit:make-key-event
                       :type :character :code #\@ :modifiers '(:control)))
          (control-question (cl-tty-kit:make-key-event
                             :type :character :code #\? :modifiers '(:control)))
          (control-space (cl-tty-kit:make-key-event
                          :type :special :code :control-space))
          (unknown (cl-tty-kit:make-key-event
                    :type :special :code :unknown)))
      (expect (loom/feature/terminal::%terminal-event-payload paste)
              :to-equal
              "pasted")
      (expect (loom/feature/terminal::%terminal-event-payload character)
              :to-equal
              "z")
      (expect (loom/feature/terminal::%terminal-event-payload control-at)
              :to-equal
              (string (code-char 0)))
      (expect (loom/feature/terminal::%terminal-event-payload control-question)
              :to-be nil)
      (expect (loom/feature/terminal::%terminal-event-payload control-space)
              :to-equal
              (string (code-char 0)))
      (expect (loom/feature/terminal::%terminal-event-payload unknown)
              :to-be nil))))
