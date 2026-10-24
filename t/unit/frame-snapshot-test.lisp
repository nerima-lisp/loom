(in-package #:loom/test)

(progn
  (describe "frame snapshots"
            (it
             "copies source cells, nested styles, and values returned by accessors"
             (let* ((source-glyph (copy-seq "A"))
                    (source-color (copy-seq "red"))
                    (source-attributes (vector :bold))
                    (source-style
                     (list :foreground
                           source-color
                           :attributes
                           source-attributes))
                    (cells
                     (vector (list source-glyph source-style) (list "B" nil)))
                    (snapshot
                     (make-frame-snapshot 2 1 cells :cursor (list 1 0 t))))
               (setf (char source-glyph 0) #\X)
               (setf (char source-color 0) #\b)
               (setf (aref source-attributes 0) :italic)
               (expect (frame-snapshot-width snapshot) :to-equal 2)
               (expect (frame-snapshot-height snapshot) :to-equal 1)
               (multiple-value-bind (glyph style)
                   (frame-snapshot-cell snapshot 0 0)
                 (expect glyph :to-equal "A")
                 (expect (getf style :foreground) :to-equal "red")
                 (expect (aref (getf style :attributes) 0) :to-equal :bold)
                 (setf (char glyph 0) #\Z)
                 (setf (char (getf style :foreground) 0) #\Z)
                 (setf (aref (getf style :attributes) 0) :underline))
               (multiple-value-bind (glyph style)
                   (frame-snapshot-cell snapshot 0 0)
                 (expect glyph :to-equal "A")
                 (expect (getf style :foreground) :to-equal "red")
                 (expect (aref (getf style :attributes) 0) :to-equal :bold))
               (multiple-value-bind (x y visible-p)
                   (frame-snapshot-cursor snapshot)
                 (expect (list x y visible-p) :to-equal (list 1 0 t)))
               (expect (frame-snapshot-cell snapshot 2 0) :to-be nil)))
            (it "rejects invalid dimensions, cells, glyphs, and cursors"
                (signals error (make-frame-snapshot 0 1 #()))
                (signals error (make-frame-snapshot 1 0 #()))
                (signals error
                         (make-frame-snapshot 2 1 (vector (list "A" nil))))
                (signals error (make-frame-snapshot 1 1 (vector (list 42 nil))))
                (signals error
                         (make-frame-snapshot 1
                                              1
                                              (vector (list "A" nil))
                                              :cursor
                                              (list 1 0 t))))
            (it
             "copies render-operation text and style and validates operation values"
             (let* ((source-text (copy-seq "xy"))
                    (source-color (copy-seq "red"))
                    (source-style (list :foreground source-color))
                    (operation
                     (make-render-operation :text
                                            1
                                            2
                                            source-text
                                            :style
                                            source-style))
                    (cursor-operation (make-render-operation :cursor 0 0 t)))
               (setf (char source-text 0) #\Z)
               (setf (char source-color 0) #\b)
               (expect (render-operation-kind operation) :to-equal :text)
               (expect (render-operation-x operation) :to-equal 1)
               (expect (render-operation-y operation) :to-equal 2)
               (expect (render-operation-text operation) :to-equal "xy")
               (expect (getf (render-operation-style operation) :foreground)
                       :to-equal
                       "red")
               (let ((returned-text (render-operation-text operation))
                     (returned-style (render-operation-style operation)))
                 (setf (char returned-text 0) #\Z)
                 (setf (char (getf returned-style :foreground) 0) #\Z))
               (expect (render-operation-text operation) :to-equal "xy")
               (expect (getf (render-operation-style operation) :foreground)
                       :to-equal
                       "red")
               (expect (render-operation-visible-p cursor-operation) :to-be t)
               (signals error (make-render-operation :unknown 0 0 "x"))
               (signals error (make-render-operation :text -1 0 "x"))
               (signals error (make-render-operation :text 0 0 42))
               (signals error (make-render-operation :cursor 0 0 :visible))
               (signals error (make-render-operation :cursor 0 0 t :style nil))))
            (it
             "applies text and cursor operations without changing the source snapshot"
             (let* ((snapshot
                     (make-frame-snapshot 2
                                          1
                                          (vector
                                           (list "a" (list :foreground "red"))
                                           (list "b" (list :foreground "blue")))
                                          :cursor
                                          (list 0 0 t)))
                    (operations
                     (list (make-render-operation :text 0 0 "x")
                           (make-render-operation :text
                                                  1
                                                  0
                                                  "y"
                                                  :style
                                                  (list :foreground "green"))
                           (make-render-operation :cursor 1 0 nil)))
                    (updated
                     (apply-render-operations snapshot
                                              operations
                                              (lambda (text)
                                                (values
                                                 (map 'vector
                                                      (function string)
                                                      text)
                                                 (make-array (length text)
                                                             :initial-element
                                                             1))))))
               (expect (frame-snapshot-p updated) :to-be t)
               (multiple-value-bind (glyph style)
                   (frame-snapshot-cell updated 0 0)
                 (expect glyph :to-equal "x")
                 (expect (getf style :foreground) :to-equal "red"))
               (multiple-value-bind (glyph style)
                   (frame-snapshot-cell updated 1 0)
                 (expect glyph :to-equal "y")
                 (expect (getf style :foreground) :to-equal "green"))
               (multiple-value-bind (glyph style)
                   (frame-snapshot-cell snapshot 0 0)
                 (expect glyph :to-equal "a")
                 (expect (getf style :foreground) :to-equal "red"))
               (multiple-value-bind (glyph style)
                   (frame-snapshot-cell snapshot 1 0)
                 (expect glyph :to-equal "b")
                 (expect (getf style :foreground) :to-equal "blue"))
               (multiple-value-bind (x y visible-p)
                   (frame-snapshot-cursor updated)
                 (expect (list x y visible-p) :to-equal (list 1 0 nil)))
               (multiple-value-bind (x y visible-p)
                   (frame-snapshot-cursor snapshot)
                 (expect (list x y visible-p) :to-equal (list 0 0 t))))
             (it
              "rejects malformed operation lists, out-of-frame starts, and bad layouts"
              (let ((snapshot (make-frame-snapshot 1 1 (vector (list "a" nil))))
                    (layout
                     (lambda (text)
                       (values (map 'vector (function string) text)
                               (make-array (length text) :initial-element 1)))))
                (signals error
                         (apply-render-operations snapshot
                                                  (list :not-an-operation)
                                                  layout))
                (signals error
                         (apply-render-operations snapshot
                                                  (list
                                                   (make-render-operation :text
                                                                          1
                                                                          0
                                                                          "x"))
                                                  layout))
                (signals error
                         (apply-render-operations snapshot
                                                  (list
                                                   (make-render-operation :text
                                                                          0
                                                                          0
                                                                          "x"))
                                                  (lambda (text)
                                                    (declare (ignore text))
                                                    (values (vector "x") #())))))))))
