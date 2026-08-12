;;;; t/unit/multiple-cursor-delete-test.lisp
;;;;
;;;; Multiple-cursor deletion applies the same edit contract at every cursor.
(in-package #:loom/test)

(describe
  "multiple-cursor deletion"
  (it
    "deletes one character at every cursor"
    (let ((*editor-state* (%fresh-editor-state (format nil "abc~%def"))))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 1)
        (multiple-cursors-add-next-line)
        (loom::delete-char)
        (expect (buffer-text buffer)
                :to-equal (format nil "ac~%df"))
        (expect (multiple-cursor-set-offsets
                 (editor-state-multiple-cursors *editor-state*))
                :to-equal '(1 4))
        (expect buffer :to-have-point (cons 0 1)))))

  (it
    "deletes backward at every cursor"
    (let ((*editor-state* (%fresh-editor-state (format nil "abc~%def"))))
      (let ((buffer (%selected-test-buffer)))
        (buffer-set-point buffer 0 2)
        (multiple-cursors-add-next-line)
        (loom::delete-backward-char)
        (expect (buffer-text buffer)
                :to-equal (format nil "ac~%df"))
        (expect (multiple-cursor-set-offsets
                 (editor-state-multiple-cursors *editor-state*))
                :to-equal '(1 4))
        (expect buffer :to-have-point (cons 0 1))))))
