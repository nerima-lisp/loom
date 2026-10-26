(in-package #:loom/test)

(describe
  "minibuffer history recall"
  (it
    "walks history newest-first and replaces the current input each step"
    (let* ((history (history-kit:make-history))
           (minibuffer (make-minibuffer :history history)))
      (history-kit:history-add history "first")
      (history-kit:history-add history "second")
      (minibuffer-activate minibuffer "M-x ")
      (minibuffer-handle-key minibuffer (%special-key :up))
      (expect (minibuffer-input-string minibuffer) :to-equal "second")
      (minibuffer-handle-key minibuffer (%special-key :up))
      (expect (minibuffer-input-string minibuffer) :to-equal "first")
      (minibuffer-handle-key minibuffer (%special-key :down))
      (expect (minibuffer-input-string minibuffer) :to-equal "second")))

  (it
    "adds confirmed input to history and resets navigation on activation"
    (let* ((history (history-kit:make-history))
           (minibuffer (make-minibuffer :history history))
           (confirmed nil))
      (minibuffer-activate minibuffer "M-x "
                           :on-confirm (lambda (input) (setf confirmed input)))
      (%type-string minibuffer "a")
      (minibuffer-handle-key minibuffer (%special-key :enter))
      (expect confirmed :to-equal "a")
      (minibuffer-activate minibuffer "M-x ")
      (minibuffer-handle-key minibuffer (%special-key :up))
      (expect (minibuffer-input-string minibuffer) :to-equal "a")))

  (it
    "ignores an unrecognized special key"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-activate minibuffer "M-x ")
      (%type-string minibuffer "ab")
      (minibuffer-handle-key minibuffer (%special-key :left))
      (expect (minibuffer-input-string minibuffer) :to-equal "ab"))))
(describe
  "minibuffer editing and meta history"
  ;; GNU Emacs documents these editing keys for minibuffer input.
  ;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Minibuffer-Edit.html
  ;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Moving-Point.html
  ;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Killing-by-Lines.html
  ;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Yanking.html
  ;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Words.html
  ;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Minibuffer-History.html
  (it
    "moves point with C-a, C-e, C-f, and C-b before inserting"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-activate minibuffer "Input: ")
      (%type-string minibuffer "abcd")
      (expect (loom/core/minibuffer:minibuffer-input-point minibuffer) :to-equal 4)
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event
        :type :character :code #\a :modifiers '(:control)))
      (expect (loom/core/minibuffer:minibuffer-input-point minibuffer) :to-equal 0)
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event
        :type :character :code #\f :modifiers '(:control)))
      (expect (loom/core/minibuffer:minibuffer-input-point minibuffer) :to-equal 1)
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event
        :type :character :code #\b :modifiers '(:control)))
      (expect (loom/core/minibuffer:minibuffer-input-point minibuffer) :to-equal 0)
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event
        :type :character :code #\e :modifiers '(:control)))
      (expect (loom/core/minibuffer:minibuffer-input-point minibuffer) :to-equal 4)
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event
        :type :character :code #\b :modifiers '(:control)))
      (expect (loom/core/minibuffer:minibuffer-input-point minibuffer) :to-equal 3)
      (%type-string minibuffer "X")
      (expect (minibuffer-input-string minibuffer) :to-equal "abcXd")
      (expect (loom/core/minibuffer:minibuffer-input-point minibuffer) :to-equal 4)))

  (it
    "kills from point to the end and yanks at point"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-activate minibuffer "Input: ")
      (%type-string minibuffer "abcdef")
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event
        :type :character :code #\a :modifiers '(:control)))
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event
        :type :character :code #\f :modifiers '(:control)))
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event
        :type :character :code #\f :modifiers '(:control)))
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event
        :type :character :code #\k :modifiers '(:control)))
      (expect (minibuffer-input-string minibuffer) :to-equal "ab")
      (expect (loom/core/minibuffer:minibuffer-input-point minibuffer) :to-equal 2)
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event
        :type :character :code #\b :modifiers '(:control)))
      (expect (loom/core/minibuffer:minibuffer-input-point minibuffer) :to-equal 1)
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event
        :type :character :code #\y :modifiers '(:control)))
      (expect (minibuffer-input-string minibuffer) :to-equal "acdefb")
      (expect (loom/core/minibuffer:minibuffer-input-point minibuffer) :to-equal 5)
      (%type-string minibuffer "X")
      (expect (minibuffer-input-string minibuffer) :to-equal "acdefXb")
      (expect (loom/core/minibuffer:minibuffer-input-point minibuffer) :to-equal 6)))

  (it
    "kills the previous word with the M-DEL event"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-activate minibuffer "Input: ")
      (%type-string minibuffer "one two")
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event
        :type :special :code :backspace :modifiers '(:alt)))
      (expect (minibuffer-input-string minibuffer) :to-equal "one ")
      (expect (loom/core/minibuffer:minibuffer-input-point minibuffer) :to-equal 4)
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event
        :type :special :code :backspace :modifiers '(:alt)))
      (expect (minibuffer-input-string minibuffer) :to-equal "")
      (expect (loom/core/minibuffer:minibuffer-input-point minibuffer) :to-equal 0)))

  (it
    "uses M-p and M-n for history without replacing the Up and Down path"
    (let* ((history (history-kit:make-history))
           (minibuffer (make-minibuffer :history history)))
      (history-kit:history-add history "first")
      (history-kit:history-add history "second")
      (minibuffer-activate minibuffer "Input: ")
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event
        :type :character :code #\p :modifiers '(:alt)))
      (expect (minibuffer-input-string minibuffer) :to-equal "second")
      (expect (loom/core/minibuffer:minibuffer-input-point minibuffer) :to-equal 6)
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event
        :type :character :code #\p :modifiers '(:alt)))
      (expect (minibuffer-input-string minibuffer) :to-equal "first")
      (expect (loom/core/minibuffer:minibuffer-input-point minibuffer) :to-equal 5)
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event
        :type :character :code #\n :modifiers '(:alt)))
      (expect (minibuffer-input-string minibuffer) :to-equal "second")
      (expect (loom/core/minibuffer:minibuffer-input-point minibuffer) :to-equal 6)
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event
        :type :character :code #\n :modifiers '(:alt)))
      (expect (minibuffer-input-string minibuffer) :to-equal "")
      (expect (loom/core/minibuffer:minibuffer-input-point minibuffer) :to-equal 0)
      (minibuffer-activate minibuffer "Input: ")
      (minibuffer-handle-key minibuffer (%special-key :up))
      (expect (minibuffer-input-string minibuffer) :to-equal "second")
      (expect (loom/core/minibuffer:minibuffer-input-point minibuffer) :to-equal 6)
      (minibuffer-handle-key minibuffer (%special-key :down))
      (expect (minibuffer-input-string minibuffer) :to-equal "")
      (expect (loom/core/minibuffer:minibuffer-input-point minibuffer) :to-equal 0))))
(describe
  "minibuffer terminal control events"
  ;; GNU Emacs documents these editing keys and minibuffer input bindings.
  ;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Minibuffer-Edit.html
  ;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Moving-Point.html
  ;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Killing-by-Lines.html
  ;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Yanking.html
  (it
    "dispatches terminal special C-a, C-e, C-f, C-b, C-k, and C-y events"
    (let ((minibuffer (make-minibuffer)))
      (minibuffer-activate minibuffer "Input: ")
      (%type-string minibuffer "abcdef")
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event :type :special :code :control-a))
      (expect (loom/core/minibuffer:minibuffer-input-point minibuffer) :to-equal 0)
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event :type :special :code :control-f))
      (expect (loom/core/minibuffer:minibuffer-input-point minibuffer) :to-equal 1)
      (%type-string minibuffer "X")
      (expect (minibuffer-input-string minibuffer) :to-equal "aXbcdef")
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event :type :special :code :control-e))
      (expect (loom/core/minibuffer:minibuffer-input-point minibuffer) :to-equal 7)
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event :type :special :code :control-b))
      (expect (loom/core/minibuffer:minibuffer-input-point minibuffer) :to-equal 6)
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event :type :special :code :control-k))
      (expect (minibuffer-input-string minibuffer) :to-equal "aXbcde")
      (expect (loom/core/minibuffer:minibuffer-input-point minibuffer) :to-equal 6)
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event :type :special :code :control-a))
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event :type :special :code :control-y))
      (expect (minibuffer-input-string minibuffer) :to-equal "faXbcde")
      (expect (loom/core/minibuffer:minibuffer-input-point minibuffer) :to-equal 1)))
  (it
  "does not refresh completion candidates when C-a only moves point"
  (let ((calls 0)
        (changes 0)
        (minibuffer (make-minibuffer)))
    (minibuffer-activate
     minibuffer "Find: "
     :on-change (lambda (input)
                  (declare (ignore input))
                  (incf changes))
     :completion-function (lambda (input)
                            (declare (ignore input))
                            (incf calls)
                            '("alpha" "alpine")))
    (%type-string minibuffer "alpha")
    (let ((calls-before-movement calls)
          (changes-before-movement changes))
      (minibuffer-handle-key
       minibuffer
       (cl-tty-kit:make-key-event
        :type :character :code #\a :modifiers '(:control)))
      (expect (minibuffer-input-string minibuffer) :to-equal "alpha")
      (expect calls :to-equal calls-before-movement)
      (expect changes :to-equal changes-before-movement)
      (expect (loom/core/minibuffer:minibuffer-input-point minibuffer) :to-equal 0)))))
