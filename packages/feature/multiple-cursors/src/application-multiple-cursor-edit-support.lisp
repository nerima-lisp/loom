;;;; packages/feature/multiple-cursors/src/application-multiple-cursor-edit-support.lisp
;;;;
;;;; Shared translation helpers for the multiple-cursor edit protocol.
(in-package #:loom/feature/multiple-cursors)

(defun %translated-offsets-after-insert (offsets text-length)
  (mapcar (lambda (offset)
            (+ offset
               (* text-length
                  (count-if (lambda (insert-offset)
                              (<= insert-offset offset))
                            offsets))))
          offsets))

(defun %translated-primary-after-insert (primary offsets text-length)
  (+ primary
     (* text-length
        (count-if (lambda (insert-offset)
                    (<= insert-offset primary))
                  offsets))))

(defun %inserted-ranges (offsets translated-offsets text-length)
  (mapcar (lambda (_offset translated-offset)
            (declare (ignore _offset))
            (cons (- translated-offset text-length)
                  translated-offset))
          offsets
          translated-offsets))

(defun %offset-after-deletions (offset ranges)
  "Translate OFFSET after deleting the half-open RANGES before it."
  (- offset
     (loop for range in ranges
           when (<= (cdr range) offset)
             sum (- (cdr range) (car range)))))

(defun %translated-offsets-after-delete (offsets ranges)
  (mapcar (lambda (offset)
            (%offset-after-deletions offset ranges))
          offsets))

(defun %delete-offset-range (buffer range)
  (let* ((start (buffer-offset-position buffer (car range)))
         (end (buffer-offset-position buffer (cdr range))))
    (buffer-delete-region buffer
                          (buffer-position-line start)
                          (buffer-position-column start)
                          (buffer-position-line end)
                          (buffer-position-column end))))

(defun %translate-endpoint-offsets (offsets old-ranges new-ranges)
  (let ((old-endpoints (mapcar #'cdr old-ranges))
        (new-endpoints (mapcar #'cdr new-ranges)))
    (mapcar
     (lambda (offset)
       (or (loop for old-end in old-endpoints
                 for new-end in new-endpoints
                 when (= offset old-end)
                   return new-end)
           offset))
     offsets)))
