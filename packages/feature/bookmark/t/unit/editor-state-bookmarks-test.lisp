(in-package #:loom/test)

(describe "editor bookmarks"
  (it "stores bookmark metadata without adapting its representation"
    (let ((bookmark (loom/feature/bookmark:make-editor-bookmark
                     :name "top"
                     :buffer :buffer
                     :path #P"/tmp/notes.txt"
                     :buffer-name "notes.txt"
                     :line 4
                     :column 2)))
      (expect (loom/feature/bookmark:editor-bookmark-name bookmark) :to-equal "top")
      (expect (loom/feature/bookmark:editor-bookmark-buffer bookmark) :to-be :buffer)
      (expect (loom/feature/bookmark:editor-bookmark-path bookmark) :to-equal #P"/tmp/notes.txt")
      (expect (loom/feature/bookmark:editor-bookmark-buffer-name bookmark) :to-equal "notes.txt")
      (expect (loom/feature/bookmark:editor-bookmark-line bookmark) :to-equal 4)
      (expect (loom/feature/bookmark:editor-bookmark-column bookmark) :to-equal 2))))
