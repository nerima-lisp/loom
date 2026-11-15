(in-package #:loom/test)

(defun %multiline-token-classes (tokens)
  (loop for token in tokens
        append (make-list (length (syntax-token-text token))
                          :initial-element (syntax-token-kind token))))

(defun %multiline-whole-reference (text)
  ;; This reference consumes the complete source without production lexical
  ;; helpers or line splitting. Each source character retains its semantic kind.
  (let ((state :code)
        (position 0)
        (classes nil))
    (labels ((emit (kind count)
               (dotimes (index count)
                 (unless (char= (char text (+ position index)) #\Newline)
                   (push kind classes)))
               (incf position count))
             (pair-p (first second)
               (and (< (1+ position) (length text))
                    (char= (char text position) first)
                    (char= (char text (1+ position)) second)))
             (whitespace-p (character)
               (find character '(#\Space #\Tab #\Newline #\Return #\Page)))
             (atom-end (start)
               (loop for end from start below (length text)
                     while (and (not (whitespace-p (char text end)))
                                (not (find (char text end)
                                           '(#\( #\) #\[ #\] #\{ #\} #\'
                                             #\` #\, #\# #\; #\"))))
                     finally (return end)))
             (number-p (atom)
               (let* ((start (if (and (> (length atom) 1)
                                      (find (char atom 0) "+-")) 1 0))
                      (body (subseq atom start))
                      (digits (remove #\. body)))
                 (and (plusp (length digits))
                      (<= (count #\. body) 1)
                      (every (lambda (char) (find char "0123456789")) digits))))
             (atom-kind (start end)
               (let ((atom (subseq text start end)))
                 (cond ((number-p atom) :number)
                       ((or (and (plusp (length atom)) (char= (char atom 0) #\:))
                            (member atom (major-mode-keywords :common-lisp)
                                    :test #'string-equal)) :keyword)
                       (t :plain)))))
      (loop while (< position (length text))
            for character = (char text position)
            do (cond
                 ((eq state :line-comment)
                  (if (char= character #\Newline)
                      (progn (setf state :code) (emit :whitespace 1))
                      (emit :comment 1)))
                 ((eq state :string)
                  (cond ((char= character #\\)
                         (emit :string (min 2 (- (length text) position))))
                        ((char= character #\")
                         (emit :string 1) (setf state :code))
                        (t (emit :string 1))))
                 ((integerp state)
                  (cond ((pair-p #\# #\|) (incf state) (emit :comment 2))
                        ((pair-p #\| #\#)
                         (decf state) (emit :comment 2)
                         (when (zerop state) (setf state :code)))
                        (t (emit :comment 1))))
                 ((pair-p #\# #\\)
                  (emit :character 2)
                  (when (< position (length text))
                    (let ((literal (char text position)))
                      (emit :character 1)
                      (when (alphanumericp literal)
                        (emit :character (- (atom-end position) position))))))
                 ((pair-p #\# #\|) (setf state 1) (emit :comment 2))
                 ((char= character #\;) (setf state :line-comment) (emit :comment 1))
                 ((char= character #\") (setf state :string) (emit :string 1))
                 ((whitespace-p character) (emit :whitespace 1))
                 ((find character '(#\( #\) #\[ #\] #\{ #\} #\' #\` #\,))
                  (emit :delimiter 1))
                 (t (let ((end (atom-end (if (char= character #\#)
                                            (1+ position) position))))
                      (emit (atom-kind position end) (- end position)))))))
    (values (nreverse classes) (if (eq state :line-comment) :code state))))


(defun %multiline-generated-lines (seed)
  (let ((fragments #("(defun x ()" "\"" "\\\"" "#|" "|#" "#\\\""
                     "; #|" "text" "\\\\" "#\\Space" " " "42)"))
        (state seed))
    (labels ((pick (limit)
               (setf state (mod (+ (* state 1103515245) 12345) 2147483648))
               (mod (ash state -8) limit)))
      (loop repeat 12
            collect (with-output-to-string (output)
                      (dotimes (index (pick 7))
                        (write-string (aref fragments (pick (length fragments))) output)))))))

(describe
  "Common Lisp multiline reader states"
  (it-each
      (("\"open" :code :string (:string))
       ("continuation\" 42" :string :code (:string :whitespace :number))
       ("escaped\\\" #|" :string :string (:string))
       ("#\\\" rest" :code :code (:character :whitespace :plain))
       ("\"#|\"" :code :code (:string))
       ("; #| ignored" :code :code (:comment))
       ("#| outer #| inner |#" :code 1 (:comment))
       ("still |# 42" 1 :code (:comment :whitespace :number))
       ("#| inner" 2 3 (:comment))
       ("" 3 3 nil))
      "carries ~S from ~S to ~S"
      (line initial expected kinds)
    (multiple-value-bind (tokens state) (syntax-highlight-line line initial)
      (expect state :to-equal expected)
      (expect (mapcar #'syntax-token-kind tokens) :to-equal kinds)
      (expect (apply #'concatenate 'string (mapcar #'syntax-token-text tokens))
              :to-equal line)))

  (cl-weave:it-property
      "matches an independent whole-source reader across generated line boundaries"
      ((seed (cl-weave:gen-integer :min 1 :max 2147483647)))
    (let* ((lines (%multiline-generated-lines seed))
           (whole (format nil "~{~A~^~%~}" lines))
           (state :code)
           (classes nil))
      (dolist (line lines)
        (multiple-value-bind (tokens end-state) (syntax-highlight-line line state)
          (setf state end-state)
          (push (%multiline-token-classes tokens) classes)
          (expect (apply #'concatenate 'string (mapcar #'syntax-token-text tokens))
                  :to-equal line)))
      (multiple-value-bind (expected expected-state) (%multiline-whole-reference whole)
        (expect (apply (function append) (nreverse classes)) :to-equal expected)
        (expect state :to-equal expected-state)))))

(defun %multiline-tokens (buffer line &optional (text (buffer-visible-line buffer line)))
  (loom::%prepare-syntax-line-tokens buffer line text))

(defun %multiline-cache-lines (buffer)
  (loom/feature/syntax-highlighting::syntax-line-cache-lines
   (gethash buffer loom::*syntax-line-caches*)))

(defun %multiline-cache-entry (buffer line)
  (aref (%multiline-cache-lines buffer) line))

(describe
  "Common Lisp buffer syntax cache"
  (it
    "computes hidden lines as states and tokenizes each displayed logical line once"
    (let ((buffer (make-buffer :initial-content (format nil "#|~%hidden~%|#~%42"))))
      (buffer-set-major-mode buffer :common-lisp)
      (let ((tokens (%multiline-tokens buffer 3)))
        (expect (mapcar #'syntax-token-kind tokens) :to-equal '(:number))
        (expect (eq tokens (%multiline-tokens buffer 3)) :to-be t)
        (dotimes (line 3)
          (expect (loom/feature/syntax-highlighting::%syntax-line-entry-token-source
                   (%multiline-cache-entry buffer line)) :to-be nil))
        (expect (length (%multiline-cache-lines buffer)) :to-equal 4))))

  (it
    "stops state propagation at convergence while validating later direct edits"
    (let ((buffer (make-buffer :initial-content (format nil "foo~%42~%42~%42"))))
      (buffer-set-major-mode buffer :common-lisp)
      (let ((original (%multiline-tokens buffer 1)))
        (%multiline-tokens buffer 3)
        (buffer-set-point buffer 0 0)
        (buffer-insert-string buffer "a")
        (buffer-set-point buffer 2 0)
        (buffer-insert-string buffer "\"")
        (expect (eq original (%multiline-tokens buffer 1)) :to-be t)
        (expect (mapcar #'syntax-token-kind (%multiline-tokens buffer 3))
                :to-equal '(:string)))))

  (it
    "restores downstream syntax after deletion and history replay"
    (let ((buffer (make-buffer :initial-content (format nil "foo~%42~%42"))))
      (buffer-set-major-mode buffer :common-lisp)
      (%multiline-tokens buffer 2)
      (buffer-insert-string buffer "\"")
      (expect (mapcar #'syntax-token-kind (%multiline-tokens buffer 2))
              :to-equal '(:string))
      (buffer-record-undo-boundary buffer)
      (buffer-delete-char buffer :backward t)
      (expect (mapcar #'syntax-token-kind (%multiline-tokens buffer 2))
              :to-equal '(:number))
      (buffer-undo buffer)
      (expect (mapcar #'syntax-token-kind (%multiline-tokens buffer 2))
              :to-equal '(:string))
      (buffer-redo buffer)
      (expect (mapcar #'syntax-token-kind (%multiline-tokens buffer 2))
              :to-equal '(:number))))

  (it
    "handles inserted and deleted logical lines"
    (let ((buffer (make-buffer :initial-content (format nil "foo~%42~%7"))))
      (buffer-set-major-mode buffer :common-lisp)
      (%multiline-tokens buffer 2)
      (buffer-insert-string buffer (format nil "#|~%"))
      (expect (mapcar #'syntax-token-kind (%multiline-tokens buffer 3))
              :to-equal '(:comment))
      (buffer-delete-region buffer 0 0 1 0)
      (expect (mapcar #'syntax-token-kind (%multiline-tokens buffer 2))
              :to-equal '(:number))))

  (it
    "falls back to line zero when the C1 history ring expires"
    (let ((buffer (make-buffer :initial-content (format nil "foo~%42"))))
      (buffer-set-major-mode buffer :common-lisp)
      (%multiline-tokens buffer 1)
      (dotimes (index 257) (buffer-insert-string buffer "a"))
      (buffer-insert-string buffer "\"")
      (expect (mapcar #'syntax-token-kind (%multiline-tokens buffer 1))
              :to-equal '(:string))))

  (it
    "uses absolute hidden state and preserves comments in partial narrowed lines"
    (let ((buffer (make-buffer :initial-content (format nil "\"open~%text\" ; hidden note~%42"))))
      (buffer-set-major-mode buffer :common-lisp)
      (buffer-narrow-to-region buffer 1 2 2 2)
      (expect (mapcar #'syntax-token-kind
                      (%multiline-tokens buffer 0))
              :to-equal '(:string :whitespace :comment))
      (buffer-widen buffer)
      (buffer-narrow-to-region buffer 1 10 2 2)
      (expect (mapcar #'syntax-token-kind
                      (%multiline-tokens buffer 0))
              :to-equal '(:comment))))

  (it
    "retains line-local generic modes when switching the buffer mode"
    (let* ((text (format nil "\"open~%42"))
           (buffer (make-buffer :initial-content text)))
      (buffer-set-major-mode buffer :common-lisp)
      (expect (mapcar #'syntax-token-kind (%multiline-tokens buffer 1))
              :to-equal '(:string))
      (buffer-set-major-mode buffer :python)
      (expect (mapcar #'syntax-token-kind (%multiline-tokens buffer 1))
              :to-equal '(:number))
      (buffer-set-major-mode buffer :common-lisp)
      (expect (mapcar #'syntax-token-kind (%multiline-tokens buffer 1))
              :to-equal '(:string))))

  (it-each
      (("#\\\" 42" 2 (:character :whitespace :number))
       ("\"a\\\"z\" 42" 3 (:string :whitespace :number)))
      "preserves reader tokens when narrowing ~S at column ~D"
      (source start kinds)
    (let ((buffer (make-buffer :initial-content source)))
      (buffer-set-major-mode buffer :common-lisp)
      (buffer-narrow-to-region buffer 0 start 0 (length source))
      (let* ((visible (buffer-visible-line buffer 0))
             (tokens (%multiline-tokens buffer 0 visible)))
        (expect (mapcar #'syntax-token-kind tokens) :to-equal kinds)
        (expect (apply #'concatenate 'string (mapcar #'syntax-token-text tokens))
                :to-equal visible))))

  (it
    "reuses expanded display text across wrapped rows"
    (let ((buffer (make-buffer :initial-content (format nil "\"x~%~Ctext" #\Tab))))
      (buffer-set-major-mode buffer :common-lisp)
      (let* ((display "        text")
             (tokens (%multiline-tokens buffer 1 display)))
        (expect (mapcar #'syntax-token-kind tokens) :to-equal '(:string))
        (expect (syntax-token-text (first tokens)) :to-equal display)
        (expect (eq tokens (%multiline-tokens buffer 1 display)) :to-be t)))))

(defun %multiline-call-counts (symbols thunk)
  "Call THUNK while counting calls to each function in SYMBOLS."
  (let* ((counts (make-list (length symbols) :initial-element 0))
         (originals (mapcar #'symbol-function symbols)))
    (unwind-protect
         (progn
           (loop for symbol in symbols
                 for original in originals
                 for cell on counts
                 do (let ((original original) (cell cell))
                      (setf (symbol-function symbol)
                            (lambda (&rest arguments)
                              (incf (car cell))
                              (apply original arguments)))))
           (funcall thunk))
      (loop for symbol in symbols
            for original in originals
            do (setf (symbol-function symbol) original)))
    counts))

(describe
  "Common Lisp syntax prepared for frame drawing"
  (it
    "prepares and lexes a wrapped logical line once for all of its rows"
    (let* ((state (%fresh-layout-state
                   :content (format nil "\"abcdefghijklmnopqrstu~%42")
                   :width 10 :height 8))
           (buffer (window-buffer (%layout-window state)))
           (screen (%layout-screen state))
           (symbols (list 'loom::%prepare-syntax-line-tokens
                          'loom/feature/syntax-highlighting:syntax-highlight-line)))
      (buffer-set-major-mode buffer :common-lisp)
      (buffer-set-truncate-lines buffer nil)
      (expect (%multiline-call-counts symbols (lambda () (loom::compose-frame state)))
              :to-equal '(2 2))
      ;; Common Lisp buffers reserve a two-cell line-number gutter, so the
      ;; text body wraps at eight cells and starts at column 2.
      (expect (cl-tty-kit:screen-row-string screen 1 :start 0 :end 10)
              :to-equal "  hijklmno")
      (dolist (row '(0 1 2 3))
        (expect (cl-tty-kit:cell-style (cl-tty-kit:screen-cell screen 2 row))
                :to-equal '((:fg 2))))
      (expect (%multiline-call-counts symbols (lambda () (loom::compose-frame state)))
              :to-equal '(2 0))))

  (it
    "derives hidden reader state above a scrolled viewport without tokens"
    (let* ((state (%fresh-layout-state
                   :content (format nil "#|~%hidden~%|#~%42")
                   :height 4))
           (window (%layout-window state))
           (buffer (window-buffer window))
           (screen (%layout-screen state)))
      (buffer-set-major-mode buffer :common-lisp)
      (buffer-set-point buffer 3 0)
      (setf (loom/core/window-tree:window-scroll-line window) 3)
      (expect (%multiline-call-counts
               (list 'loom/feature/syntax-highlighting:syntax-highlight-line)
               (lambda () (loom::compose-frame state)))
              :to-equal '(1))
      ;; The two-cell line-number gutter shows logical line 4 before "42".
      (expect (cl-tty-kit:screen-row-string screen 0 :start 0 :end 4) :to-equal "4 42")
      (expect (cl-tty-kit:cell-style (cl-tty-kit:screen-cell screen 2 0))
              :to-equal '((:fg 3)))
      (dotimes (line 3)
        (expect (loom/feature/syntax-highlighting::%syntax-line-entry-token-source
                 (%multiline-cache-entry buffer line))
                :to-be nil)))))
