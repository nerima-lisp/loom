(in-package #:loom/test)

(describe
  "minibuffer completion"
  (it
    "passes current input to the completion function and completes a unique candidate"
    (let ((seen-inputs nil)
          (minibuffer (make-minibuffer)))
      (minibuffer-activate
       minibuffer "M-x "
       :completion-function
       (lambda (input)
         (push input seen-inputs)
         '("forward-char" "forward-word" "backward-char")))
      (%type-string minibuffer "forward-c")
      (minibuffer-handle-key minibuffer (%special-key :tab))
      (expect (member "forward-c" seen-inputs :test #'string=) :to-be-truthy)
      (expect (minibuffer-input-string minibuffer) :to-equal "forward-char")))

  (it
    "uses the longest common prefix for multiple matches"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-activate
       minibuffer "Prompt: "
       :completion-function
       (lambda (input)
         (declare (ignore input))
         '("alpha-one" "alpha-two")))
      (%type-string minibuffer "a")
      (minibuffer-handle-key minibuffer (%special-key :tab))
      (expect (minibuffer-input-string minibuffer) :to-equal "alpha-")))

  (it
    "leaves input unchanged when no candidate matches"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-activate
       minibuffer "Prompt: "
       :completion-function
       (lambda (input)
         (declare (ignore input))
         '("alpha")))
      (%type-string minibuffer "z")
      (minibuffer-handle-key minibuffer (%special-key :tab))
      (expect (minibuffer-input-string minibuffer) :to-equal "z")))

  (it
    "does not match a candidate shorter than the input"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-activate
       minibuffer "Prompt: "
       :completion-function
       (lambda (input)
         (declare (ignore input))
         '("a")))
      (%type-string minibuffer "ab")
      (minibuffer-handle-key minibuffer (%special-key :tab))
      (expect (minibuffer-input-string minibuffer) :to-equal "ab")))

  (it-each
      (("inactive minibuffer" nil :missing "")
       ("missing completion function" t :missing "Al")
       ("empty candidates" t :empty "Al"))
      "leaves input unchanged for ~A"
      (label active-p completion-function expected)
    (let ((minibuffer (make-minibuffer)))
      (declare (ignore label))
      (when (eq completion-function :empty)
        (minibuffer-activate minibuffer "Prompt: "
                              :completion-function
                              (lambda (input)
                                (declare (ignore input))
                                nil)))
      (when (eq completion-function :missing)
        (minibuffer-activate minibuffer "Prompt: "))
      (unless active-p
        (setf (loom/core/minibuffer::%minibuffer-active-p minibuffer) nil))
      (setf (loom/core/minibuffer::%minibuffer-input minibuffer) "Al")
      (expect (minibuffer-complete minibuffer) :to-be minibuffer)
      (expect (minibuffer-input-string minibuffer) :to-equal expected)))

  (it
    "matches completion candidates without regard to case"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-activate
       minibuffer "Prompt: "
       :completion-function
       (lambda (input)
         (declare (ignore input))
         '("Alpha-one" "ALPHA-two")))
      (%type-string minibuffer "a")
      (minibuffer-handle-key minibuffer (%special-key :tab))
      (expect (minibuffer-input-string minibuffer) :to-equal "Alpha-")))

  (it
    "rejects invalid completion functions and candidate results"
    (let ((minibuffer (make-minibuffer)))
      (signals error
        (minibuffer-activate minibuffer "Prompt: " :completion-function 42))
      (minibuffer-activate
       minibuffer "Prompt: "
       :completion-function
       (lambda (input)
         (declare (ignore input))
         42))
      (signals error (minibuffer-complete minibuffer))
      (minibuffer-activate
       minibuffer "Prompt: "
       :completion-function
       (lambda (input)
         (declare (ignore input))
         '("valid" 42)))
      (signals error (minibuffer-complete minibuffer))))
  ;; Ordered in-order and flex matching follow Emacs completion styles.
  ;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Completion-Styles.html
  (it
  "matches partial input parts against path-like candidates"
  (let ((minibuffer (make-minibuffer)))
    (minibuffer-activate
     minibuffer "Find file: "
     :completion-function
     (lambda (input)
       (declare (ignore input))
       '("/tmp/alpha-one.txt" "/tmp/alpha-two.txt" "/tmp/beta-one.txt")))
    (%type-string minibuffer "/tmp/al-on")
    (expect (loom/core/minibuffer:minibuffer-completion-candidates minibuffer)
            :to-equal '("/tmp/alpha-one.txt"))))
  (it
  "matches flex input as an ordered subsequence"
  (let ((minibuffer (make-minibuffer)))
    (minibuffer-activate
     minibuffer "Find file: "
     :completion-function
     (lambda (input)
       (declare (ignore input))
       '("/tmp/alpha-one.txt" "/tmp/beta-two.txt")))
    (%type-string minibuffer "aon")
    (expect (loom/core/minibuffer:minibuffer-completion-candidates minibuffer)
            :to-equal '("/tmp/alpha-one.txt"))
    (minibuffer-handle-key minibuffer (%special-key :tab))
    (expect (minibuffer-input-string minibuffer)
            :to-equal "/tmp/alpha-one.txt")))
  (it
  "clears candidates and leaves input unchanged when there are no matches"
  (let ((minibuffer (make-minibuffer)))
    (minibuffer-activate
     minibuffer "Find file: "
     :completion-function
     (lambda (input)
       (declare (ignore input))
       '("/tmp/alpha-one.txt")))
    (%type-string minibuffer "zzz")
    (expect (loom/core/minibuffer:minibuffer-completion-candidates minibuffer)
            :to-equal nil)
    (minibuffer-handle-key minibuffer (%special-key :tab))
    (expect (minibuffer-input-string minibuffer) :to-equal "zzz")
    (expect (loom/core/minibuffer:minibuffer-completion-candidates minibuffer)
            :to-equal nil))))
