;;;; t/buffer-test.lisp
;;;;
;;;; Domain layer: the buffer protocol (src/domain/buffer.lisp), exercised
;;;; against real MAKE-BUFFER buffers -- text storage, point/mark, edits,
;;;; the undo ring, and (via CL-HOST-KIT:WITH-TEMPORARY-DIRECTORY) the
;;;; trivial-in-terms-of-the-rest-of-the-protocol BUFFER-LOAD/BUFFER-SAVE.
(in-package #:loom/test)

(describe
  "make-buffer"
  (it
    "defaults to an empty *scratch* buffer with point/mark at 0,0"
    (let ((buffer (make-buffer)))
      (expect (buffer-name buffer) :to-equal "*scratch*")
      (expect (buffer-path buffer) :to-be nil)
      (expect (buffer-line-count buffer) :to-equal 1)
      (expect (buffer-line buffer 0) :to-equal "")
      (expect (buffer-point-line buffer) :to-equal 0)
      (expect (buffer-point-column buffer) :to-equal 0)
      (expect (buffer-modified-p buffer) :to-be-falsy)))

  (it
    "takes name and path"
    (let ((buffer (make-buffer :name "foo.txt" :path #P"/tmp/foo.txt")))
      (expect (buffer-name buffer) :to-equal "foo.txt")
      (expect (buffer-path buffer) :to-equal #P"/tmp/foo.txt")))

  (it
    "splits initial-content into lines"
    (let ((buffer (make-buffer :initial-content (format nil "one~%two~%three"))))
      (expect (buffer-line-count buffer) :to-equal 3)
      (expect (buffer-line buffer 0) :to-equal "one")
      (expect (buffer-line buffer 1) :to-equal "two")
      (expect (buffer-line buffer 2) :to-equal "three")))

  (it
    "signals an error for an out-of-range buffer-line"
    (let ((buffer (make-buffer)))
      (signals 'error (buffer-line buffer 1))
      (signals 'error (buffer-line buffer -1)))))

(describe
  "buffer-text"
  (it
    "joins lines back with newlines"
    (let ((buffer (make-buffer :initial-content (format nil "one~%two~%three"))))
      (expect (buffer-text buffer) :to-equal (format nil "one~%two~%three")))))

(describe
  "buffer-set-point / buffer-point-line / buffer-point-column"
  (it
    "moves point to an in-range position"
    (let ((buffer (make-buffer :initial-content (format nil "hello~%world"))))
      (buffer-set-point buffer 1 3)
      (expect (buffer-point-line buffer) :to-equal 1)
      (expect (buffer-point-column buffer) :to-equal 3)))

  (it
    "clamps an out-of-range position"
    (let ((buffer (make-buffer :initial-content (format nil "hi~%there"))))
      (buffer-set-point buffer 99 99)
      (expect (buffer-point-line buffer) :to-equal 1)
      (expect (buffer-point-column buffer) :to-equal 5)
      (buffer-set-point buffer -5 -5)
      (expect (buffer-point-line buffer) :to-equal 0)
      (expect (buffer-point-column buffer) :to-equal 0))))

(describe
  "buffer-mark / buffer-set-mark"
  (it
    "starts unset"
    (multiple-value-bind (line column) (buffer-mark (make-buffer))
      (expect line :to-be nil)
      (expect column :to-be nil)))

  (it
    "is set by buffer-set-mark"
    (let ((buffer (make-buffer :initial-content "hello")))
      (buffer-set-mark buffer 0 3)
      (multiple-value-bind (line column) (buffer-mark buffer)
        (expect line :to-equal 0)
        (expect column :to-equal 3)))))

(describe
  "buffer-insert-string"
  (it
    "inserts at point, moves point after the text, and marks modified"
    (let ((buffer (make-buffer :initial-content "hllo")))
      (buffer-set-point buffer 0 1)
      (buffer-insert-string buffer "e")
      (expect (buffer-line buffer 0) :to-equal "hello")
      (expect (buffer-point-line buffer) :to-equal 0)
      (expect (buffer-point-column buffer) :to-equal 2)
      (expect (buffer-modified-p buffer) :to-be-truthy)))

  (it
    "splits the buffer across a newline in the inserted text"
    (let ((buffer (make-buffer :initial-content "helloworld")))
      (buffer-set-point buffer 0 5)
      (buffer-insert-string buffer (format nil "~%"))
      (expect (buffer-line-count buffer) :to-equal 2)
      (expect (buffer-line buffer 0) :to-equal "hello")
      (expect (buffer-line buffer 1) :to-equal "world")
      (expect (buffer-point-line buffer) :to-equal 1)
      (expect (buffer-point-column buffer) :to-equal 0)))

  (it
    "single-line insert on a non-first line of a multi-line buffer leaves other lines untouched"
    (let ((buffer (make-buffer :initial-content (format nil "one~%hllo~%three"))))
      (buffer-set-point buffer 1 1)
      (buffer-insert-string buffer "e")
      (expect (buffer-line-count buffer) :to-equal 3)
      (expect (buffer-line buffer 0) :to-equal "one")
      (expect (buffer-line buffer 1) :to-equal "hello")
      (expect (buffer-line buffer 2) :to-equal "three")
      (expect (buffer-point-line buffer) :to-equal 1)
      (expect (buffer-point-column buffer) :to-equal 2))))

(describe
  "buffer-delete-char"
  (it
    "backward deletes the character before point and moves point back"
    (let ((buffer (make-buffer :initial-content "hello")))
      (buffer-set-point buffer 0 5)
      (buffer-delete-char buffer :backward t)
      (expect (buffer-line buffer 0) :to-equal "hell")
      (expect (buffer-point-column buffer) :to-equal 4)))

  (it
    "backward is a no-op at the start of the buffer"
    (let ((buffer (make-buffer :initial-content "hello")))
      (buffer-delete-char buffer :backward t)
      (expect (buffer-line buffer 0) :to-equal "hello")
      (expect (buffer-modified-p buffer) :to-be-falsy)))

  (it
    "backward at column 0 joins with the previous line"
    (let ((buffer (make-buffer :initial-content (format nil "hello~%world"))))
      (buffer-set-point buffer 1 0)
      (buffer-delete-char buffer :backward t)
      (expect (buffer-line-count buffer) :to-equal 1)
      (expect (buffer-line buffer 0) :to-equal "helloworld")
      (expect (buffer-point-line buffer) :to-equal 0)
      (expect (buffer-point-column buffer) :to-equal 5)))

  (it
    "forward deletes the character at point and leaves point where it is"
    (let ((buffer (make-buffer :initial-content "hello")))
      (buffer-set-point buffer 0 0)
      (buffer-delete-char buffer)
      (expect (buffer-line buffer 0) :to-equal "ello")
      (expect (buffer-point-column buffer) :to-equal 0)))

  (it
    "forward is a no-op at the end of the buffer"
    (let ((buffer (make-buffer :initial-content "hello")))
      (buffer-set-point buffer 0 5)
      (buffer-delete-char buffer)
      (expect (buffer-line buffer 0) :to-equal "hello")
      (expect (buffer-modified-p buffer) :to-be-falsy))))

(describe
  "buffer-delete-region / buffer-region-string"
  (it
    "returns the region text without mutating for buffer-region-string"
    (let ((buffer (make-buffer :initial-content (format nil "hello~%world"))))
      (expect (buffer-region-string buffer 0 1 1 3) :to-equal (format nil "ello~%wor"))
      (expect (buffer-line-count buffer) :to-equal 2)
      (expect (buffer-line buffer 0) :to-equal "hello")))

  (it
    "deletes the region, moves point to start, and returns the deleted text"
    (let ((buffer (make-buffer :initial-content (format nil "hello~%world"))))
      (let ((deleted (buffer-delete-region buffer 0 1 1 3)))
        (expect deleted :to-equal (format nil "ello~%wor"))
        (expect (buffer-line-count buffer) :to-equal 1)
        (expect (buffer-line buffer 0) :to-equal "hld")
        (expect (buffer-point-line buffer) :to-equal 0)
        (expect (buffer-point-column buffer) :to-equal 1))))

  (it
    "signals an error when end precedes start"
    (let ((buffer (make-buffer :initial-content "hello")))
      (signals 'error (buffer-delete-region buffer 0 3 0 1))))

  (it
    "single-line delete on a non-first line of a multi-line buffer leaves other lines untouched"
    (let ((buffer (make-buffer :initial-content (format nil "one~%hello~%three"))))
      (let ((deleted (buffer-delete-region buffer 1 1 1 2)))
        (expect deleted :to-equal "e")
        (expect (buffer-line-count buffer) :to-equal 3)
        (expect (buffer-line buffer 0) :to-equal "one")
        (expect (buffer-line buffer 1) :to-equal "hllo")
        (expect (buffer-line buffer 2) :to-equal "three")
        (expect (buffer-point-line buffer) :to-equal 1)
        (expect (buffer-point-column buffer) :to-equal 1)))))

(describe
  "buffer-undo"
  (it
    "undoes a single insert back to the prior text"
    (let ((buffer (make-buffer :initial-content "hello")))
      (buffer-set-point buffer 0 5)
      (buffer-insert-string buffer " world")
      (expect (buffer-line buffer 0) :to-equal "hello world")
      (buffer-undo buffer)
      (expect (buffer-line buffer 0) :to-equal "hello")
      (expect (buffer-point-column buffer) :to-equal 5)))

  (it
    "undoes a delete by re-inserting the deleted text"
    (let ((buffer (make-buffer :initial-content "hello world")))
      (buffer-delete-region buffer 0 5 0 11)
      (expect (buffer-line buffer 0) :to-equal "hello")
      (buffer-undo buffer)
      (expect (buffer-line buffer 0) :to-equal "hello world")))

  (it
    "a boundary excludes earlier edits from the next undo's group"
    (let ((buffer (make-buffer :initial-content "")))
      (buffer-insert-string buffer "a")
      (buffer-insert-string buffer "b")
      (buffer-record-undo-boundary buffer)
      (buffer-insert-string buffer "c")
      (expect (buffer-line buffer 0) :to-equal "abc")
      ;; only "c" (recorded after the boundary) is undone; "a" and "b"
      ;; (recorded before it) are left alone
      (buffer-undo buffer)
      (expect (buffer-line buffer 0) :to-equal "ab")))

  (it
    "is a no-op once history is exhausted"
    (let ((buffer (make-buffer :initial-content "x")))
      (buffer-undo buffer)
      (expect (buffer-line buffer 0) :to-equal "x")))

  (it
    "walks forward through its own inverse on a second undo, ring-style"
    (let ((buffer (make-buffer :initial-content "hello")))
      (buffer-set-point buffer 0 5)
      (buffer-insert-string buffer "!")
      (expect (buffer-line buffer 0) :to-equal "hello!")
      (buffer-undo buffer)
      (expect (buffer-line buffer 0) :to-equal "hello")
      ;; second undo replays the insert (undo of the undo), not a no-op
      (buffer-undo buffer)
      (expect (buffer-line buffer 0) :to-equal "hello!"))))

(describe
  "buffer-load / buffer-save"
  (it
    "loads a file's contents into a new buffer named after the file"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "notes.txt" dir)))
        (host-kit:write-file-string (format nil "line one~%line two") path)
        (let ((buffer (buffer-load path)))
          (expect (buffer-name buffer) :to-equal "notes.txt")
          (expect (buffer-path buffer) :to-equal path)
          (expect (buffer-line-count buffer) :to-equal 2)
          (expect (buffer-line buffer 0) :to-equal "line one")
          (expect (buffer-modified-p buffer) :to-be-falsy)))))

  (it
    "saves buffer-text to buffer-path and clears modified-p"
    (host-kit:with-temporary-directory (dir)
      (let* ((path (merge-pathnames "out.txt" dir))
             (buffer (make-buffer :path path :initial-content "hi")))
        (buffer-set-point buffer 0 2)
        (buffer-insert-string buffer " there")
        (expect (buffer-modified-p buffer) :to-be-truthy)
        (buffer-save buffer)
        (expect (buffer-modified-p buffer) :to-be-falsy)
        (expect (host-kit:read-file-string path) :to-equal "hi there"))))

  (it
    "signals an error saving a buffer with no path"
    (let ((buffer (make-buffer :initial-content "hi")))
      (signals 'error (buffer-save buffer)))))
