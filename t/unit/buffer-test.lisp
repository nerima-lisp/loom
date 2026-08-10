;;;; t/unit/buffer-test.lisp
;;;;
;;;; Domain layer: the buffer protocol (packages/core/editor/src/domain-buffer.lisp), exercised
;;;; against real MAKE-BUFFER buffers -- text storage, point/mark, edits,
;;;; the undo ring, and (via CL-HOST-KIT:WITH-TEMPORARY-DIRECTORY) the
;;;; trivial-in-terms-of-the-rest-of-the-protocol BUFFER-LOAD/BUFFER-SAVE.
(in-package #:loom/test)

(defmatcher :to-have-point (buffer expected)
  "buffer's point to equal the given (line . column)"
  (let ((actual-point (cons (buffer-point-line buffer) (buffer-point-column buffer)))
        (expected-point (first expected)))
    (values (equal actual-point expected-point) actual-point expected-point)))

(describe
  "make-buffer"
  (it
    "defaults to an empty *scratch* buffer with point/mark at 0,0"
    (let ((buffer (make-buffer)))
      (with-soft-assertions
        (expect (buffer-name buffer) :to-equal "*scratch*")
        (expect (buffer-path buffer) :to-be nil)
        (expect (buffer-line-count buffer) :to-equal 1)
        (expect (buffer-line buffer 0) :to-equal "")
        (expect buffer :to-have-point (cons 0 0))
        (expect (buffer-read-only-p buffer) :to-be-falsy)
        (expect (buffer-modified-p buffer) :to-be-falsy))))

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
      (signals error (buffer-line buffer 1))
      (signals error (buffer-line buffer -1)))))

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
      (expect buffer :to-have-point (cons 1 3))))

  (it
    "clamps an out-of-range position"
    (let ((buffer (make-buffer :initial-content (format nil "hi~%there"))))
      (buffer-set-point buffer 99 99)
      (expect buffer :to-have-point (cons 1 5))
      (buffer-set-point buffer -5 -5)
      (expect buffer :to-have-point (cons 0 0)))))

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
      (expect buffer :to-have-point (cons 0 2))
      (expect (buffer-modified-p buffer) :to-be-truthy)))

  (it
    "splits the buffer across a newline in the inserted text"
    (let ((buffer (make-buffer :initial-content "helloworld")))
      (buffer-set-point buffer 0 5)
      (buffer-insert-string buffer (format nil "~%"))
      (expect (buffer-line-count buffer) :to-equal 2)
      (expect (buffer-line buffer 0) :to-equal "hello")
      (expect (buffer-line buffer 1) :to-equal "world")
      (expect buffer :to-have-point (cons 1 0))))

  (it
    "single-line insert on a non-first line of a multi-line buffer leaves other lines untouched"
    (let ((buffer (make-buffer :initial-content (format nil "one~%hllo~%three"))))
      (buffer-set-point buffer 1 1)
      (buffer-insert-string buffer "e")
      (expect (buffer-line-count buffer) :to-equal 3)
      (expect (buffer-line buffer 0) :to-equal "one")
      (expect (buffer-line buffer 1) :to-equal "hello")
      (expect (buffer-line buffer 2) :to-equal "three")
      (expect buffer :to-have-point (cons 1 2))))

  (it
    "is a no-op for an empty string, leaving point and modified-p unchanged"
    (let ((buffer (make-buffer :initial-content "hello")))
      (buffer-set-point buffer 0 2)
      (buffer-insert-string buffer "")
      (expect (buffer-line buffer 0) :to-equal "hello")
      (expect buffer :to-have-point (cons 0 2))
      (expect (buffer-modified-p buffer) :to-be-falsy))))

(describe
  "buffer-mark-saved"
  (it
    "clears the modified state and returns the buffer"
    (let ((buffer (make-buffer :initial-content "hello")))
      (buffer-insert-string buffer "!")
      (expect (buffer-modified-p buffer) :to-be-truthy)
      (expect (buffer-mark-saved buffer) :to-be buffer)
      (expect (buffer-modified-p buffer) :to-be-falsy))))

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
      (expect buffer :to-have-point (cons 0 5))))

  (it
    "forward deletes the character at point and leaves point where it is"
    (let ((buffer (make-buffer :initial-content "hello")))
      (buffer-set-point buffer 0 0)
      (buffer-delete-char buffer)
      (expect (buffer-line buffer 0) :to-equal "ello")
      (expect (buffer-point-column buffer) :to-equal 0)))

  (it
    "forward at the end of a non-last line joins with the next line"
    (let ((buffer (make-buffer :initial-content (format nil "one~%two"))))
      (buffer-set-point buffer 0 3)
      (buffer-delete-char buffer)
      (expect (buffer-text buffer) :to-equal "onetwo")
      (expect buffer :to-have-point (cons 0 3))))

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
        (expect buffer :to-have-point (cons 0 1)))))

  (it
    "signals an error when end precedes start"
    (let ((buffer (make-buffer :initial-content "hello")))
      (signals error (buffer-delete-region buffer 0 3 0 1))))

  (it
    "signals an error when a position is out of range even though ordering is valid"
    (let ((buffer (make-buffer :initial-content "hello")))
      (signals error (buffer-delete-region buffer 0 0 99 99))))

  (it
    "single-line delete on a non-first line of a multi-line buffer leaves other lines untouched"
    (let ((buffer (make-buffer :initial-content (format nil "one~%hello~%three"))))
      (let ((deleted (buffer-delete-region buffer 1 1 1 2)))
        (expect deleted :to-equal "e")
        (expect (buffer-line-count buffer) :to-equal 3)
        (expect (buffer-line buffer 0) :to-equal "one")
        (expect (buffer-line buffer 1) :to-equal "hllo")
        (expect (buffer-line buffer 2) :to-equal "three")
        (expect buffer :to-have-point (cons 1 1))))))

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
    "a second consecutive call does not push a duplicate boundary marker"
    (let ((buffer (make-buffer :initial-content "")))
      (buffer-insert-string buffer "a")
      (buffer-record-undo-boundary buffer)
      (buffer-record-undo-boundary buffer)
      (buffer-insert-string buffer "b")
      (expect (buffer-line buffer 0) :to-equal "ab")
      ;; if the second boundary call had pushed another marker, this undo
      ;; would land on an empty group instead of undoing "b"
      (buffer-undo buffer)
      (expect (buffer-line buffer 0) :to-equal "a")))

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
  "buffer-redo"
  (it
    "replays a single undone edit and is then exhausted"
    (let ((buffer (make-buffer :initial-content "hello")))
      (buffer-set-point buffer 0 5)
      (buffer-insert-string buffer "!")
      (buffer-undo buffer)
      (expect (buffer-line buffer 0) :to-equal "hello")
      (buffer-redo buffer)
      (expect (buffer-line buffer 0) :to-equal "hello!")
      (buffer-redo buffer)
      (expect (buffer-line buffer 0) :to-equal "hello!")))

  (it
    "replays a whole undo group in original edit order"
    (let ((buffer (make-buffer :initial-content "")))
      (buffer-insert-string buffer "a")
      (buffer-insert-string buffer "b")
      (buffer-undo buffer)
      (expect (buffer-line buffer 0) :to-equal "")
      (buffer-redo buffer)
      (expect (buffer-line buffer 0) :to-equal "ab")))

  (it
    "clears redo history after a new edit"
    (let ((buffer (make-buffer :initial-content "hello")))
      (buffer-set-point buffer 0 5)
      (buffer-insert-string buffer "!")
      (buffer-undo buffer)
      (buffer-insert-string buffer "?")
      (buffer-redo buffer)
      (expect (buffer-line buffer 0) :to-equal "hello?"))))

(describe
  "buffer read-only"
  (it
    "rejects text mutations and undo/redo without changing history"
    (let ((buffer (make-buffer :initial-content "hello")))
      (buffer-set-point buffer 0 5)
      (buffer-insert-string buffer "!")
      (buffer-undo buffer)
      (buffer-set-read-only buffer t)
      (expect (buffer-read-only-p buffer) :to-be-truthy)
      (signals buffer-read-only-error
        (buffer-insert-string buffer "x"))
      (signals buffer-read-only-error
        (buffer-delete-char buffer))
      (signals buffer-read-only-error
        (buffer-delete-region buffer 0 0 0 1))
      (signals buffer-read-only-error
        (buffer-undo buffer))
      (signals buffer-read-only-error
        (buffer-redo buffer))
      (expect (buffer-text buffer) :to-equal "hello")
      (buffer-set-read-only buffer nil)
      (buffer-redo buffer)
      (expect (buffer-text buffer) :to-equal "hello!"))))

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
          (expect (buffer-read-only-p buffer) :to-be-falsy)
          (expect (buffer-modified-p buffer) :to-be-falsy)))))

  (it
    "marks a non-writable real file read-only"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "readonly.txt" dir)))
        (host-kit:write-file-string "locked" path)
        (sb-posix:chmod (namestring path) #o444)
        (unwind-protect
             (let ((buffer (buffer-load path)))
               (expect (buffer-read-only-p buffer) :to-be-truthy)
               (signals buffer-read-only-error
                 (buffer-insert-string buffer "!")))
          (sb-posix:chmod (namestring path) #o644)))))

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
    "refuses to save a read-only buffer without changing the file"
    (host-kit:with-temporary-directory (dir)
      (let* ((path (merge-pathnames "locked.txt" dir))
             (buffer (make-buffer :path path :initial-content "new")))
        (host-kit:write-file-string "old" path)
        (buffer-set-read-only buffer t)
        (signals buffer-read-only-error
          (buffer-save buffer))
        (expect (host-kit:read-file-string path) :to-equal "old"))))

  (it
    "signals an error saving a buffer with no path"
    (let ((buffer (make-buffer :initial-content "hi")))
      (signals error (buffer-save buffer)))))
(describe "piece table storage"
  (it "preserves initial text while later edits use the add buffer"
    (let ((buffer (make-buffer :initial-content (format nil "alpha~%omega"))))
      (buffer-set-point buffer 0 5)
      (buffer-insert-string buffer "-beta")
      (buffer-delete-region buffer 1 1 1 3)
      (expect (buffer-text buffer) :to-equal (format nil "alpha-beta~%oga"))
      (expect (loom::%buffer-original buffer) :to-equal (format nil "alpha~%omega"))
      (expect (length (loom::%buffer-add-buffer buffer)) :to-equal 5)
      (expect (length (loom::%buffer-pieces buffer)) :to-equal 4))))

(describe
  "buffer-offset-position"
  (it
    "clamps an offset past the end of the text to the last line's own end"
    (let ((buffer (make-buffer :initial-content (format nil "one~%two"))))
      (let ((position (buffer-offset-position buffer 9999)))
        (expect (buffer-position-line position) :to-equal 1)
        (expect (buffer-position-column position) :to-equal 3)))))

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

(describe
  "%raw-insert-at and %raw-delete-region"
  (it
    "%raw-insert-at is a no-op for an empty string"
    ;; Every current caller (BUFFER-INSERT-STRING, undo's re-insertion of a
    ;; deleted span) already guards against an empty string before ever
    ;; reaching here, so this exercises %RAW-INSERT-AT's own guard directly.
    (let ((buffer (make-buffer :initial-content "hello")))
      (loom::%raw-insert-at buffer 0 2 "")
      (expect (buffer-line buffer 0) :to-equal "hello")
      (expect (length (loom::%buffer-pieces buffer)) :to-equal 1)))

  (it
    "%raw-delete-region is a no-op for an empty (start = end) region"
    (let ((buffer (make-buffer :initial-content "hello")))
      (loom::%raw-delete-region buffer 0 2 0 2)
      (expect (buffer-line buffer 0) :to-equal "hello")
      (expect (length (loom::%buffer-pieces buffer)) :to-equal 1))))
