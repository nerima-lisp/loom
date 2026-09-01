;;;; t/unit/buffer-view-test.lisp
;;;;
;;;; Domain layer: the visible-region and offset/coordinate helpers defined in
;;;; packages/core/editor/src/domain-buffer-narrowing.lisp and
;;;; packages/core/editor/src/domain-buffer-positions.lisp.
(in-package #:loom/test)

(describe
  "buffer-offset-position"
  (it
    "clamps an offset past the end of the text to the last line's own end"
    (let ((buffer (make-buffer :initial-content (format nil "one~%two"))))
      (let ((position (buffer-offset-position buffer 9999)))
        (expect (buffer-position-line position) :to-equal 1)
        (expect (buffer-position-column position) :to-equal 3)))))

  (it "maps newline boundaries to the following line"
    (let ((buffer (make-buffer :initial-content (format nil "one~%two"))))
      (let ((newline (buffer-offset-position buffer 3))
            (following (buffer-offset-position buffer 4)))
        (expect (buffer-position-line newline) :to-equal 0)
        (expect (buffer-position-column newline) :to-equal 3)
        (expect (buffer-position-line following) :to-equal 1)
        (expect (buffer-position-column following) :to-equal 0))))

(describe
  "buffer point offsets"
  (it "returns zero for the initial point of an empty buffer"
    (let ((buffer (make-buffer)))
      (expect (buffer-point-offset buffer) :to-equal 0)))

  (it "counts preceding lines when converting a multiline point"
    (let ((buffer (make-buffer :initial-content (format nil "zero~%one~%two"))))
      (buffer-set-point buffer 1 2)
      (expect (buffer-point-offset buffer) :to-equal 7)))

  (it "counts line separators at the end of the final line"
    (let ((buffer (make-buffer :initial-content (format nil "zero~%one"))))
      (buffer-set-point buffer 1 3)
      (expect (buffer-point-offset buffer) :to-equal 8)))

  (it "converts an offset in the middle of a multiline visible region"
    (let ((buffer (make-buffer :initial-content (format nil "zero~%one~%two"))))
      (buffer-narrow-to-region buffer 0 2 2 1)
      (let ((position (buffer-visible-offset-position buffer 6)))
        (expect (buffer-position-line position) :to-equal 1)
        (expect (buffer-position-column position) :to-equal 1)))))

(describe
  "buffer narrowing"
  (it "keeps the full text while exposing a half-open visible region"
    (let ((buffer (make-buffer :initial-content "0123456789")))
      (buffer-narrow-to-region buffer 0 2 0 7)
      (expect (buffer-text buffer) :to-equal "0123456789")
      (expect (buffer-visible-text buffer) :to-equal "23456")
      (expect (buffer-narrow-start-offset buffer) :to-equal 2)
      (expect (buffer-narrow-end-offset buffer) :to-equal 7)
      (expect (buffer-narrowed-p buffer) :to-be-truthy)
      (expect (buffer-visible-line-count buffer) :to-equal 1)
      (expect (buffer-visible-line buffer 0) :to-equal "23456")
      (expect (buffer-region-string buffer 0 0 0 4) :to-equal "23")))

  (it "widens back to the complete piece-table length"
    (let ((buffer (make-buffer :initial-content "0123456789")))
      (buffer-narrow-to-region buffer 0 2 0 7)
      (buffer-widen buffer)
      (expect (buffer-narrowed-p buffer) :to-be-falsy)
      (expect (buffer-narrow-start-offset buffer) :to-equal 0)
      (expect (buffer-narrow-end-offset buffer) :to-equal 10)
      (expect (buffer-visible-text buffer) :to-equal "0123456789")))

  (it "clamps point, mark, and nested narrowing to the visible region"
    (let ((buffer (make-buffer :initial-content "0123456789")))
      (buffer-set-point buffer 0 0)
      (buffer-set-mark buffer 0 9)
      (buffer-narrow-to-region buffer 0 2 0 8)
      (let ((point-line (buffer-point-line buffer))
            (point-column (buffer-point-column buffer)))
        (expect point-line :to-equal 0)
        (expect point-column :to-equal 2))
      (multiple-value-bind (mark-line mark-column) (buffer-mark buffer)
        (expect mark-line :to-equal 0)
        (expect mark-column :to-equal 8))
      (buffer-narrow-to-region buffer 0 0 0 10)
      (expect (buffer-narrow-start-offset buffer) :to-equal 2)
      (expect (buffer-narrow-end-offset buffer) :to-equal 8)
      (buffer-narrow-to-region buffer 0 4 0 6)
      (expect (buffer-narrow-start-offset buffer) :to-equal 4)
      (expect (buffer-narrow-end-offset buffer) :to-equal 6)
      (let ((point-line (buffer-point-line buffer))
            (point-column (buffer-point-column buffer)))
        (expect point-line :to-equal 0)
        (expect point-column :to-equal 4))))

  (it "clamps point without creating an unset mark"
    (let ((buffer (make-buffer :initial-content "0123456789")))
      (buffer-set-point buffer 0 0)
      (buffer-narrow-to-region buffer 0 2 0 8)
      (expect (buffer-point-column buffer) :to-equal 2)
      (multiple-value-bind (mark-line mark-column) (buffer-mark buffer)
        (expect mark-line :to-be nil)
        (expect mark-column :to-be nil))))

  (it "maps only offsets inside the visible region"
    (let ((buffer (make-buffer :initial-content "0123456789")))
      (buffer-narrow-to-region buffer 0 2 0 7)
      (let ((start (buffer-visible-offset-position buffer 2))
            (end (buffer-visible-offset-position buffer 7)))
        (expect (buffer-position-line start) :to-equal 0)
        (expect (buffer-position-column start) :to-equal 0)
        (expect (buffer-position-line end) :to-equal 0)
        (expect (buffer-position-column end) :to-equal 5))
      (expect (buffer-visible-offset-position buffer 1) :to-be nil)
      (expect (buffer-visible-offset-position buffer 8) :to-be nil)))

  (it "reports point coordinates relative to a multiline visible region"
    (let ((buffer (make-buffer :initial-content (format nil "zero~%one~%two"))))
      (buffer-narrow-to-region buffer 0 2 2 1)
      (buffer-set-point buffer 1 1)
      (expect (buffer-visible-point-line buffer) :to-equal 1)
      (expect (buffer-visible-point-column buffer) :to-equal 1)
      (expect (buffer-visible-line-count buffer) :to-equal 3)))

  (it "rejects a visible line number outside the narrowed view"
    (let ((buffer (make-buffer :initial-content "one")))
      (signals error (buffer-visible-line buffer 1))))

  (it "rejects a region whose end precedes its start"
    (let ((buffer (make-buffer :initial-content "0123456789")))
      (signals error (buffer-region-string buffer 0 7 0 2))))

  (it "keeps narrowing bounds consistent across edit undo and redo"
    (let ((buffer (make-buffer :initial-content "0123456789")))
      (buffer-narrow-to-region buffer 0 2 0 7)
      (buffer-set-point buffer 0 4)
      (buffer-insert-string buffer "X")
      (expect (buffer-text buffer) :to-equal "0123X456789")
      (expect (buffer-visible-text buffer) :to-equal "23X456")
      (expect (buffer-narrow-start-offset buffer) :to-equal 2)
      (expect (buffer-narrow-end-offset buffer) :to-equal 8)
      (buffer-undo buffer)
      (expect (buffer-text buffer) :to-equal "0123456789")
      (expect (buffer-visible-text buffer) :to-equal "23456")
      (expect (buffer-narrow-end-offset buffer) :to-equal 7)
      (buffer-redo buffer)
      (expect (buffer-text buffer) :to-equal "0123X456789")
      (expect (buffer-visible-text buffer) :to-equal "23X456")
      (expect (buffer-narrow-end-offset buffer) :to-equal 8)))

  (it "clamps deletion and region extraction without touching hidden text"
    (let ((buffer (make-buffer :initial-content "0123456789")))
      (buffer-narrow-to-region buffer 0 2 0 8)
      (buffer-set-point buffer 0 5)
      (expect (buffer-delete-region buffer 0 0 0 3) :to-equal "2")
      (expect (buffer-text buffer) :to-equal "013456789")
      (expect (buffer-visible-text buffer) :to-equal "34567")
      (expect (buffer-narrow-start-offset buffer) :to-equal 2)
      (expect (buffer-narrow-end-offset buffer) :to-equal 7)
      (expect (buffer-delete-region buffer 0 7 0 9) :to-equal "")
      (expect (buffer-text buffer) :to-equal "013456789")
      (expect (buffer-narrow-end-offset buffer) :to-equal 7))))
