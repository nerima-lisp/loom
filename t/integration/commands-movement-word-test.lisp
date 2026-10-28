(in-package #:loom/test)

(describe
  "word motion helper definition"
  (it
    "expands a helper into a zero-argument visible-buffer operation"
    (let ((expansion
            (macroexpand-1
             '(loom::define-word-motion-helper test-word-motion test-offset))))
      (expect (first expansion) :to-be 'defun)
      (expect (second expansion) :to-be 'test-word-motion)
      (expect (third expansion) :to-equal '())
      (expect (first (fourth expansion)) :to-be 'loom::%run-word-motion-helper))))

(describe
  "movement commands word and buffer motion"
  (it
    "moves by words and reaches both buffer boundaries"
    (let ((*editor-state* (%fresh-editor-state "one two")))
      (let ((buffer (%selected-test-buffer)))
        (loom::forward-word)
        (expect buffer :to-have-point (cons 0 3))
        (loom::forward-word)
        (expect buffer :to-have-point (cons 0 7))
        (loom::beginning-of-buffer)
        (expect buffer :to-have-point (cons 0 0))
        (loom::end-of-buffer)
        (expect buffer :to-have-point (cons 0 7)))))
  (it
    "moves to the absolute narrowed end with one offset mapping"
    (let ((*editor-state*
            (%fresh-editor-state (format nil "zero~%visible~%after"))))
      (let* ((buffer (%selected-test-buffer))
             (position-to-offset-symbol
               (find-symbol "%POSITION-TO-OFFSET" "LOOM/CORE/BUFFER"))
             (offset-to-position-symbol
               (find-symbol "%OFFSET-TO-POSITION-VALUES" "LOOM/CORE/BUFFER"))
             (line-count-symbol (find-symbol "%LINE-COUNT" "LOOM/CORE/BUFFER"))
             (original-position-to-offset
               (symbol-function position-to-offset-symbol))
             (original-offset-to-position
               (symbol-function offset-to-position-symbol))
             (original-line-count (symbol-function line-count-symbol))
             (position-to-offset-calls 0)
             (offset-to-position-calls 0)
             (line-count-calls 0)
             (counts nil))
        (buffer-narrow-to-region buffer 1 2 1 7)
        (let ((expected-offset (buffer-narrow-end-offset buffer)))
          (unwind-protect
               (progn
                 (setf (symbol-function position-to-offset-symbol)
                       (lambda (target line column)
                         (incf position-to-offset-calls)
                         (funcall original-position-to-offset target line column))
                       (symbol-function offset-to-position-symbol)
                       (lambda (target offset)
                         (incf offset-to-position-calls)
                         (funcall original-offset-to-position target offset))
                       (symbol-function line-count-symbol)
                       (lambda (target)
                         (incf line-count-calls)
                         (funcall original-line-count target)))
                 (loom::end-of-buffer)
                 (setf counts (list position-to-offset-calls
                                    offset-to-position-calls
                                    line-count-calls)))
            (setf (symbol-function position-to-offset-symbol)
                  original-position-to-offset
                  (symbol-function offset-to-position-symbol)
                  original-offset-to-position
                  (symbol-function line-count-symbol)
                  original-line-count))
          (expect expected-offset :to-equal 12)
          (expect counts :to-equal (list 0 1 0))
          (expect (buffer-point-offset buffer) :to-equal expected-offset)
          (expect buffer :to-have-point (cons 1 7))))))

  (it
    "moves backward by words to the beginning of each previous word"
    (let ((*editor-state* (%fresh-editor-state "one, two")))
      (let ((buffer (%selected-test-buffer)))
        (loom::end-of-buffer)
        (loom::backward-word)
        (expect buffer :to-have-point (cons 0 5))
        (loom::backward-word)
        (expect buffer :to-have-point (cons 0 0))))))
