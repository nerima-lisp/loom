(in-package #:loom/test)

(describe "buffer-load / buffer-save"
          (it "constructs an empty scratch buffer with stable editing defaults"
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
          (it "loads a file's contents into a new buffer named after the file"
              (host-kit:with-temporary-directory (dir)
                                                 (let ((path
                                                        (merge-pathnames
                                                         "notes.txt"
                                                         dir)))
                                                   (host-kit:write-file-string
                                                    (format nil
                                                            "line one~%line two")
                                                    path)
                                                   (let ((buffer
                                                          (buffer-load path)))
                                                     (expect
                                                      (buffer-name buffer)
                                                      :to-equal
                                                      "notes.txt")
                                                     (expect
                                                      (buffer-path buffer)
                                                      :to-equal
                                                      path)
                                                     (expect
                                                      (buffer-line-count buffer)
                                                      :to-equal
                                                      2)
                                                     (expect
                                                      (buffer-line buffer 0)
                                                      :to-equal
                                                      "line one")
                                                     (expect
                                                      (buffer-read-only-p
                                                       buffer)
                                                      :to-be-falsy)
                                                     (expect
                                                      (buffer-modified-p buffer)
                                                      :to-be-falsy)))))
          (it "marks a non-writable real file read-only"
              (host-kit:with-temporary-directory (dir)
                                                 (let ((path
                                                        (merge-pathnames
                                                         "readonly.txt"
                                                         dir)))
                                                   (host-kit:write-file-string
                                                    "locked"
                                                    path)
                                                   (sb-posix:chmod
                                                    (namestring path)
                                                    #o444)
                                                   (unwind-protect
                                                       (let ((buffer
                                                              (buffer-load path)))
                                                         (expect
                                                          (buffer-read-only-p
                                                           buffer)
                                                          :to-be-truthy)
                                                         (signals
                                                          buffer-read-only-error
                                                          (buffer-insert-string
                                                           buffer
                                                           "!")))
                                                     (sb-posix:chmod
                                                      (namestring path)
                                                      #o644)))))
          (it "loads an empty file as a single editable empty line"
              (host-kit:with-temporary-directory (dir)
                                                 (let ((path
                                                        (merge-pathnames
                                                         "empty.txt"
                                                         dir)))
                                                   (host-kit:write-file-string
                                                    ""
                                                    path)
                                                   (let ((buffer
                                                          (buffer-load path)))
                                                     (expect
                                                      (buffer-text buffer)
                                                      :to-equal
                                                      "")
                                                     (expect
                                                      (buffer-line-count buffer)
                                                      :to-equal
                                                      1)
                                                     (buffer-insert-string
                                                      buffer
                                                      "content")
                                                     (expect
                                                      (buffer-line buffer 0)
                                                      :to-equal
                                                      "content")
                                                     (expect
                                                      (buffer-modified-p buffer)
                                                      :to-be-truthy)))))
          (it "saves buffer-text to buffer-path and clears modified-p"
              (host-kit:with-temporary-directory (dir)
                                                 (let* ((path
                                                         (merge-pathnames
                                                          "out.txt"
                                                          dir))
                                                        (buffer
                                                         (make-buffer :path
                                                                      path
                                                                      :initial-content
                                                                      "hi")))
                                                   (buffer-set-point buffer 0 2)
                                                   (buffer-insert-string buffer
                                                                         " there")
                                                   (expect
                                                    (buffer-modified-p buffer)
                                                    :to-be-truthy)
                                                   (let ((loom/core/editor-session:*editor-session*
                                                          (%make-test-editor-session)))
                                                     (buffer-save buffer))
                                                   (expect
                                                    (buffer-modified-p buffer)
                                                    :to-be-falsy)
                                                   (expect
                                                    (host-kit:read-file-string
                                                     path)
                                                    :to-equal
                                                    "hi there"))))
          (it "refuses to save a read-only buffer without changing the file"
              (host-kit:with-temporary-directory (dir)
                                                 (let* ((path
                                                         (merge-pathnames
                                                          "locked.txt"
                                                          dir))
                                                        (buffer
                                                         (make-buffer :path
                                                                      path
                                                                      :initial-content
                                                                      "new")))
                                                   (host-kit:write-file-string
                                                    "old"
                                                    path)
                                                   (buffer-set-read-only buffer
                                                                         t)
                                                   (signals
                                                    buffer-read-only-error
                                                    (let ((loom/core/editor-session:*editor-session*
                                                           (%make-test-editor-session)))
                                                      (buffer-save buffer)))
                                                   (expect
                                                    (host-kit:read-file-string
                                                     path)
                                                    :to-equal
                                                    "old"))))
          (it "signals an error saving a buffer with no path"
              (let ((buffer (make-buffer :initial-content "hi")))
                (signals error
                         (let ((loom/core/editor-session:*editor-session*
                                (%make-test-editor-session)))
                           (buffer-save buffer))))))

(describe "buffer edits"
          (it "replays grouped edits through the public buffer API"
              (let ((buffer
                     (make-buffer :initial-content (format nil "alpha~%omega"))))
                (buffer-set-point buffer 0 5)
                (buffer-insert-string buffer "-beta")
                (expect (buffer-text buffer)
                        :to-equal
                        (format nil "alpha-beta~%omega"))
                (buffer-delete-region buffer 1 1 1 3)
                (expect (buffer-text buffer)
                        :to-equal
                        (format nil "alpha-beta~%oga"))
                (buffer-undo buffer)
                (expect (buffer-text buffer)
                        :to-equal
                        (format nil "alpha~%omega"))
                (buffer-redo buffer)
                (expect (buffer-text buffer)
                        :to-equal
                        (format nil "alpha-beta~%oga"))))
          (it "extracts a region spanning inserted text"
              (let ((buffer (make-buffer :initial-content "abcd")))
                (buffer-set-point buffer 0 2)
                (buffer-insert-string buffer "XY")
                (expect (buffer-region-string buffer 0 1 0 5) :to-equal "bXYc"))))

(it "extracts a region spanning original and added pieces"
    (let ((buffer (make-buffer :initial-content "abcd")))
      (buffer-set-point buffer 0 2)
      (buffer-insert-string buffer "XY")
      (expect (buffer-region-string buffer 0 1 0 5) :to-equal "bXYc")))

(it "keeps edits replayable through the buffer API"
    (let ((buffer (make-buffer :initial-content (format nil "one~%two"))))
      (buffer-set-point buffer 0 3)
      (buffer-insert-string buffer "-edited")
      (buffer-set-point buffer 1 0)
      (buffer-delete-region buffer 1 0 1 3)
      (expect (buffer-text buffer) :to-equal (format nil "one-edited~%"))
      (buffer-undo buffer)
      (expect (buffer-text buffer) :to-equal (format nil "one~%two"))
      (buffer-redo buffer)
      (expect (buffer-text buffer) :to-equal (format nil "one-edited~%"))))

(describe "empty buffer edits"
          (it "leaves text and point unchanged for an empty insertion"
              (let ((buffer (make-buffer :initial-content "hello")))
                (buffer-set-point buffer 0 2)
                (buffer-insert-string buffer "")
                (expect (buffer-text buffer) :to-equal "hello")
                (expect buffer :to-have-point (cons 0 2))
                (expect (buffer-modified-p buffer) :to-be-falsy)))
          (it "leaves text and point unchanged for an empty deletion"
              (let ((buffer (make-buffer :initial-content "hello")))
                (buffer-set-point buffer 0 2)
                (buffer-delete-region buffer 0 2 0 2)
                (expect (buffer-text buffer) :to-equal "hello")
                (expect buffer :to-have-point (cons 0 2))
                (expect (buffer-modified-p buffer) :to-be-falsy))))

(describe "buffer-read-only-error reporting"
          (it "reports the rejecting buffer name"
              (let ((buffer
                     (make-buffer :name "*locked*" :initial-content "hello")))
                (buffer-set-read-only buffer t)
                (handler-case (progn
                                (buffer-insert-string buffer "!")
                                (error
                                 "expected buffer-insert-string to signal"))
                  (buffer-read-only-error (condition)
                    (expect (princ-to-string condition)
                            :to-equal
                            "Buffer *locked* is read-only"))))))

(describe "buffer positions"
          (it "maps offsets across lines and clamps them to text bounds"
              (let* ((buffer
                      (make-buffer :initial-content (format nil "ab~%cd")))
                     (position (buffer-offset-position buffer 99)))
                (expect (buffer-position-line position) :to-equal 1)
                (expect (buffer-position-column position) :to-equal 2)
                (setf position (buffer-offset-position buffer 2))
                (expect (buffer-position-line position) :to-equal 0)
                (expect (buffer-position-column position) :to-equal 2)))
          (cl-weave:it-property "keeps each generated character on one line"
                                ((character
                                  (cl-weave:gen-character :alphabet "abc")))
                                (let ((buffer
                                       (make-buffer :initial-content
                                                    (string character))))
                                  (expect (buffer-line-count buffer)
                                          :to-equal
                                          1)
                                  (expect (buffer-line buffer 0)
                                          :to-equal
                                          (string character))))
          (cl-weave:it-property
           "moves point after generated single-line insertions"
           ((column (cl-weave:gen-integer :min 0 :max 32))
            (character (cl-weave:gen-character :alphabet "abc")))
           (let ((buffer
                  (make-buffer :initial-content
                               (make-string column :initial-element #\a))))
             (buffer-set-point buffer 0 column)
             (buffer-insert-string buffer (string character))
             (expect (buffer-point-column buffer) :to-equal (1+ column))))
          (it "preserves empty lines around newlines"
              (dolist
                  (text
                   (list ""
                         (string #\Newline)
                         (format nil "a~%")
                         (format nil "~%a")
                         (format nil "a~%~%b")))
                (let ((buffer (make-buffer :initial-content text)))
                  (expect (buffer-line-count buffer)
                          :to-equal
                          (1+ (count #\Newline text))))))
          (it "moves point across inserted lines"
              (let ((buffer (make-buffer :initial-content "x")))
                (buffer-set-point buffer 0 1)
                (buffer-insert-string buffer (format nil "a~%b"))
                (expect (buffer-point-line buffer) :to-equal 1)
                (expect (buffer-point-column buffer) :to-equal 1))))

(it "moves point to the next line after a trailing newline"
    (let ((buffer (make-buffer :initial-content "prefix")))
      (buffer-set-point buffer 0 6)
      (buffer-insert-string buffer (string #\Newline))
      (expect (buffer-point-line buffer) :to-equal 1)
      (expect (buffer-point-column buffer) :to-equal 0)))

(it "recognizes narrowing through the buffer API"
    (cl-weave:it-each ((0 4 nil) (1 4 t) (0 3 t))
                      "narrowing interval [~D, ~D) is ~:[not narrowed~;narrowed~]"
                      (start end expected)
                      (let ((buffer (make-buffer :initial-content "abcd")))
                        (when expected
                          (buffer-narrow-to-region buffer 0 start 0 end))
                        (if expected
                            (expect (buffer-narrowed-p buffer) :to-be-truthy)
                            (expect (buffer-narrowed-p buffer) :to-be-falsy)))))
