(in-package #:loom/test)

(describe
  "movement commands character motion"
  (it-each
      ((loom::define-current-line-boundary-command
         move-to-line-boundary
         "Move to the current line boundary."
         (buffer-point-column buffer))
       (loom::define-buffer-boundary-command
         move-to-buffer-boundary
         "Move to the buffer boundary."
         (buffer-point-offset buffer)))
      "expands boundary command helpers into documented zero-argument functions"
      (macro name documentation form)
    (let ((expansion (macroexpand-1 `(,macro ,name ,documentation ,form))))
      (expect (first expansion) :to-be 'defun)
      (expect (fourth expansion) :to-equal documentation)))

  (it
    "clamps forward-char at the end of the buffer"
    (let ((*editor-state* (%fresh-editor-state "hi")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 2)
        (loom::forward-char)
        (expect (buffer-point-line buffer) :to-equal 0)
        (expect (buffer-point-column buffer) :to-equal 2))))

  (it
    "forward-char crosses onto the next line at end-of-line"
    (let ((*editor-state* (%fresh-editor-state (format nil "hi~%there"))))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 2)
        (loom::forward-char)
        (expect (buffer-point-line buffer) :to-equal 1)
        (expect (buffer-point-column buffer) :to-equal 0))))

  (it
    "clamps backward-char at the start of the buffer"
    (let ((*editor-state* (%fresh-editor-state "hi")))
      (let ((buffer (%selected-test-buffer)))
        (loom::backward-char)
        (expect (buffer-point-line buffer) :to-equal 0)
        (expect (buffer-point-column buffer) :to-equal 0))))

  (it
    "backward-char moves back one column within a line"
    (let ((*editor-state* (%fresh-editor-state "hi")))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 2)
        (loom::backward-char)
        (expect buffer :to-have-point (cons 0 1)))))

  (it
    "backward-char wraps onto the end of the previous line at column 0"
    (let ((*editor-state* (%fresh-editor-state (format nil "hi~%there"))))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 1 0)
        (loom::backward-char)
        (expect buffer :to-have-point (cons 0 2))))))
