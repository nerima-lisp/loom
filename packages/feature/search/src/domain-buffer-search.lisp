;;;; packages/feature/search/src/domain-buffer-search.lisp
;;;;
;;;; Domain layer: bounded regular-expression search over BUFFER's public text
;;;; and position APIs. The piece-table implementation remains in buffer.lisp;
;;;; this file owns search policy and span construction.
(in-package #:loom/feature/search)

(defparameter +regex-search-timeout-seconds+ 1.0
  "Deadline for each regex operation in the search feature.

Keeping this policy beside the regex domain logic makes the core editor
independent of search-engine concerns while still bounding the event loop.")

(defun %scan-next-occurrence (text pattern start)
  "Return the domain-local regex match at or after START, with wrap-around."
  (unless (zerop (length pattern))
    (let ((regex (cl-regex-kit:compile-regex pattern)))
      (or (cl-regex-kit:scan regex text :start start
                                        :timeout +regex-search-timeout-seconds+)
          (and (plusp start)
               (cl-regex-kit:scan regex text :end start
                                             :timeout +regex-search-timeout-seconds+))))))

(defun %search-spans-in-text (text pattern start)
  "Return BUFFER-SPAN values for all regex matches in one search cycle."
  (let ((regex (cl-regex-kit:compile-regex pattern)))
    (flet ((spans-in (from to)
             (mapcar (lambda (match)
                       (make-buffer-span (cl-regex-kit:match-start match)
                                         (cl-regex-kit:match-end match)))
                     (cl-regex-kit:all-matches regex text :start from :end to
                                                          :timeout +regex-search-timeout-seconds+))))
      (append (spans-in start (length text))
              (spans-in 0 start)))))

(defun buffer-search-forward (buffer pattern)
  "Return the next BUFFER-SPAN for PATTERN from point, wrapping once, or NIL."
  (let ((match (%scan-next-occurrence (buffer-text buffer)
                                      pattern
                                      (buffer-point-offset buffer))))
    (when match
      (make-buffer-span (cl-regex-kit:match-start match)
                        (cl-regex-kit:match-end match)))))

(defun buffer-search-backward (buffer pattern)
  "Return the previous BUFFER-SPAN for PATTERN from point, wrapping once."
  (unless (zerop (length pattern))
    (let* ((spans (%search-spans-in-text (buffer-text buffer) pattern 0))
           (point (buffer-point-offset buffer))
           (prior (remove-if-not (lambda (span)
                                   (< (buffer-span-start span) point))
                                 spans)))
      (or (car (last prior))
          (car (last spans))))))

(defun buffer-search-spans (buffer pattern start)
  "Return BUFFER-SPAN values for PATTERN, starting at START and wrapping once."
  (declare (type buffer-offset start))
  (unless (zerop (length pattern))
    (%search-spans-in-text (buffer-text buffer) pattern start)))
