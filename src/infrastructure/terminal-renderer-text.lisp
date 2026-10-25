(in-package #:loom)

(defun %loom-renderer-grapheme-advance (grapheme cell-column tab-width)
  (if (string= grapheme (string #\Tab))
      (- tab-width (mod cell-column tab-width))
      (max 1
           (cl-tty-kit:grapheme-width grapheme)
           (if (find (code-char #xFE0F) grapheme) 2 0))))

(defun %loom-renderer-cell-prefix-widths (string &key (tab-width 8))
  (check-type string string)
  (check-type tab-width (integer 1 *))
  (let ((widths (make-array (1+ (length string)) :initial-element 0))
        (source-index 0)
        (cell-column 0))
    (dolist (grapheme (cl-tty-kit:string-graphemes string) widths)
      (let* ((grapheme-length (length grapheme))
             (end (+ source-index grapheme-length))
             (advance (%loom-renderer-grapheme-advance
                       grapheme cell-column tab-width)))
        (unless (string= grapheme (string #\Tab))
          (loop for offset from 1 to grapheme-length
                do (setf (aref widths (+ source-index offset))
                         (+ cell-column
                            (max 1
                                 (cl-tty-kit:grapheme-width
                                  (subseq grapheme 0 offset)))))))
        (setf (aref widths end) (+ cell-column advance))
        (incf source-index grapheme-length)
        (incf cell-column advance)))))

(defun %loom-renderer-expand-tabs (string &key (tab-width 8) (start-column 0))
  (check-type string string)
  (check-type tab-width (integer 1 *))
  (check-type start-column (integer 0 *))
  (let ((mapping (make-array (1+ (length string)) :initial-element 0))
        (source-index 0)
        (display-index 0)
        (cell-column start-column))
    (values
     (with-output-to-string (output)
       (dolist (grapheme (cl-tty-kit:string-graphemes string))
         (let* ((grapheme-length (length grapheme))
                (source-end (+ source-index grapheme-length)))
           (if (string= grapheme (string #\Tab))
               (let ((spaces (%loom-renderer-grapheme-advance
                              grapheme cell-column tab-width)))
                 (setf (aref mapping source-index) display-index)
                 (write-string (make-string spaces :initial-element #\Space)
                               output)
                 (incf display-index spaces)
                 (incf cell-column spaces)
                 (setf (aref mapping source-end) display-index))
               (progn
                 (write-string grapheme output)
                 (loop for offset from 0 to grapheme-length
                       do (setf (aref mapping (+ source-index offset))
                                (+ display-index offset)))
                 (incf display-index grapheme-length)
                 (incf cell-column
                       (%loom-renderer-grapheme-advance
                        grapheme cell-column tab-width))))
           (setf source-index source-end)))
       )
     mapping)))

(defun loom-renderer-string-width (renderer string &key (tab-width 8))
  "Return STRING's terminal-cell width, counting each grapheme cluster once."
  (declare (ignore renderer))
  (check-type string string)
  (check-type tab-width (integer 1 *))
  (let ((cell-column 0))
    (dolist (grapheme (cl-tty-kit:string-graphemes string) cell-column)
      (incf cell-column
            (%loom-renderer-grapheme-advance grapheme cell-column tab-width)))))

(defun loom-renderer-clip-index (renderer string start-column
                                 &key (tab-width 8))
  "Return the first grapheme past START-COLUMN and a blank for a clipped wide glyph."
  (declare (ignore renderer))
  (check-type string string)
  (check-type start-column (integer 0 *))
  (check-type tab-width (integer 1 *))
  (let ((source-index 0)
        (cell-column 0))
    (dolist (grapheme (cl-tty-kit:string-graphemes string)
             (values (length string) 0))
      (let* ((end-index (+ source-index (length grapheme)))
             (advance (%loom-renderer-grapheme-advance
                       grapheme cell-column tab-width))
             (end-column (+ cell-column advance)))
        (when (> end-column start-column)
          (return-from loom-renderer-clip-index
            (if (and (< cell-column start-column)
                     (not (string= grapheme (string #\Tab))))
                (values end-index (- end-column start-column))
                (values source-index 0))))
        (setf source-index end-index
              cell-column end-column)))))

(defun loom-renderer-truncate-string (renderer string width
                                      &key (tab-width 8))
  "Return the longest grapheme-aligned prefix of STRING that fits WIDTH cells."
  (declare (ignore renderer))
  (check-type string string)
  (check-type width (integer 0 *))
  (check-type tab-width (integer 1 *))
  (let ((source-index 0)
        (cell-column 0))
    (dolist (grapheme (cl-tty-kit:string-graphemes string))
      (let ((advance (%loom-renderer-grapheme-advance
                      grapheme cell-column tab-width)))
        (when (> (+ cell-column advance) width)
          (return-from loom-renderer-truncate-string
            (subseq string 0 source-index)))
        (incf source-index (length grapheme))
        (incf cell-column advance)))
    string))
