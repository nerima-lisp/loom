;;;; t/unit/buffer-storage-test.lisp
(in-package #:loom/test)

(describe
  "buffer-load / buffer-save"
  (it
    "constructs an empty scratch buffer with stable editing defaults"
    (let ((buffer (make-buffer)))
      (expect (buffer-name buffer) :to-equal "*scratch*")
      (expect (buffer-path buffer) :to-be-falsy)
      (expect (buffer-text buffer) :to-equal "")
      (expect (buffer-line-count buffer) :to-equal 1)
      (expect (buffer-point-line buffer) :to-equal 0)
      (expect (buffer-point-column buffer) :to-equal 0)
      (expect (buffer-major-mode buffer) :to-equal :fundamental)
      (expect (buffer-truncate-lines buffer) :to-equal :default)
      (expect (buffer-modified-p buffer) :to-be-falsy)
      (expect (buffer-read-only-p buffer) :to-be-falsy)))

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
    "loads an empty file as a single editable empty line"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "empty.txt" dir)))
        (host-kit:write-file-string "" path)
        (let ((buffer (buffer-load path)))
          (expect (buffer-text buffer) :to-equal "")
          (expect (buffer-line-count buffer) :to-equal 1)
          (buffer-insert-string buffer "content")
          (expect (buffer-line buffer 0) :to-equal "content")
          (expect (buffer-modified-p buffer) :to-be-truthy)))))

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

(describe
  "piece table storage"
  (it
    "preserves initial text while later edits use the add buffer"
    (let ((buffer (make-buffer :initial-content (format nil "alpha~%omega"))))
      (buffer-set-point buffer 0 5)
      (buffer-insert-string buffer "-beta")
      (buffer-delete-region buffer 1 1 1 3)
      (expect (buffer-text buffer) :to-equal (format nil "alpha-beta~%oga"))
      (expect (loom::%buffer-original buffer) :to-equal (format nil "alpha~%omega"))
      (expect (length (loom::%buffer-add-buffer buffer)) :to-equal 5)
      (expect (length (loom::%buffer-pieces buffer)) :to-equal 4))))

  (it
    "extracts a region spanning original and added pieces"
    (let ((buffer (make-buffer :initial-content "abcd")))
      (buffer-set-point buffer 0 2)
      (buffer-insert-string buffer "XY")
      (expect (buffer-region-string buffer 0 1 0 5) :to-equal "bXYc")))

  (it
    "keeps the original source stable across edits and history replay"
    (let ((buffer (make-buffer :initial-content (format nil "one~%two"))))
      (buffer-set-point buffer 0 3)
      (buffer-insert-string buffer "-edited")
      (buffer-set-point buffer 1 0)
      (buffer-delete-region buffer 1 0 1 3)
      (expect (buffer-text buffer) :to-equal (format nil "one-edited~%"))
      (expect (loom::%buffer-original buffer) :to-equal (format nil "one~%two"))
      (buffer-undo buffer)
      (expect (buffer-text buffer) :to-equal (format nil "one~%two"))
      (buffer-redo buffer)
      (expect (buffer-text buffer) :to-equal (format nil "one-edited~%"))
      (expect (loom::%pieces-text buffer) :to-equal (buffer-text buffer))))

(describe
  "%raw-insert-at and %raw-delete-region"
  (it
    "%raw-insert-at is a no-op for an empty string"
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

(describe
  "buffer-read-only-error reporting"
  (it
    "reports the rejecting buffer name"
    (let ((buffer (make-buffer :name "*locked*" :initial-content "hello")))
      (buffer-set-read-only buffer t)
      (handler-case
          (progn (buffer-insert-string buffer "!")
                 (error "expected buffer-insert-string to signal"))
        (buffer-read-only-error (condition)
          (expect (princ-to-string condition)
                  :to-equal "Buffer *locked* is read-only"))))))

(describe
  "piece-table position helpers"
  (cl-weave:it-property
      "splits every generated character into one line"
      ((character (cl-weave:gen-character :alphabet "abc")))
    (let ((lines (loom::%split-newlines (string character))))
      (expect lines :to-equal (list (string character)))))

  (cl-weave:it-property
      "advances a point by generated single-line text"
      ((column (cl-weave:gen-integer :min 0 :max 32))
       (character (cl-weave:gen-character :alphabet "abc")))
    (multiple-value-bind (line end-column)
        (loom::%advance-position 2 column (string character))
      (expect line :to-equal 2)
      (expect end-column :to-equal (1+ column))))

  (it
    "preserves empty lines around generated newlines"
    (dolist (text (list ""
                        (string #\Newline)
                        (format nil "a~%")
                        (format nil "~%a")
                        (format nil "a~%~%b")))
      (expect (length (loom::%split-newlines text))
              :to-equal (1+ (count #\Newline text)))))

  (it
    "advances across multiple generated lines"
    (let ((text (format nil "a~%b")))
    (multiple-value-bind (line column)
        (loom::%advance-position 3 4 text)
      (expect line :to-equal (+ 3 (count #\Newline text)))
      (expect column :to-equal
              (length (subseq text (1+ (or (position #\Newline text :from-end t) -1)))))))))

  (it
    "advances to column zero after a trailing newline"
    (multiple-value-bind (line column)
        (loom::%advance-position 1 7 (format nil "prefix~%"))
      (expect line :to-equal 2)
      (expect column :to-equal 0)))

  (it
    "recognizes narrowing only when the visible interval is reduced"
    (cl-weave:it-each
        ((0 4 nil)
         (1 4 t)
         (0 3 t))
        "narrowing interval [~D, ~D) is ~:[not narrowed~;narrowed~]"
        (start end expected)
      (let ((buffer (make-buffer :initial-content "abcd")))
        (setf (loom::%buffer-narrow-start-offset buffer) start
              (loom::%buffer-narrow-end-offset buffer) end)
        (if expected
            (expect (loom::%buffer-narrowed-p buffer) :to-be-truthy)
            (expect (loom::%buffer-narrowed-p buffer) :to-be-falsy)))))
