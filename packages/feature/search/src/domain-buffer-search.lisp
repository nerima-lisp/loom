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

(defun %visible-buffer-span (buffer span)
  "Translate a local visible TEXT SPAN to BUFFER's absolute coordinates."
  (let ((offset (buffer-narrow-start-offset buffer)))
    (make-buffer-span (+ offset (buffer-span-start span))
                      (+ offset (buffer-span-end span)))))

(defun %search-visible-point (buffer text)
  "Return BUFFER's point clamped to the visible TEXT coordinate space."
  (let ((offset (buffer-narrow-start-offset buffer)))
    (max 0 (min (length text)
                (- (buffer-point-offset buffer) offset)))))

(defun %search-backward-span (spans point)
  "Return the latest SPANS match before POINT, wrapping when necessary."
  (let ((prior (remove-if-not (lambda (span)
                                (< (buffer-span-start span) point))
                              spans)))
    (or (car (last prior))
        (car (last spans)))))

(defun %search-forward-cps (buffer pattern on-match on-miss)
  "Search from BUFFER's point and invoke exactly one result continuation."
  (let* ((text (buffer-visible-text buffer))
         (offset (buffer-narrow-start-offset buffer))
         (point (%search-visible-point buffer text))
         (match (%scan-next-occurrence text pattern point)))
    (if match
        (funcall on-match
                 (make-buffer-span (+ offset (cl-regex-kit:match-start match))
                                   (+ offset (cl-regex-kit:match-end match))))
        (funcall on-miss))))

(defun buffer-search-forward (buffer pattern)
  "Return the next BUFFER-SPAN for PATTERN from point, wrapping once, or NIL."
  (%search-forward-cps buffer pattern #'identity (constantly nil)))

(defun %search-backward-cps (buffer pattern on-match on-miss)
  "Search before BUFFER's point and invoke exactly one result continuation."
  (let* ((text (buffer-visible-text buffer))
         (point (%search-visible-point buffer text))
         (spans (unless (zerop (length pattern))
                  (%search-spans-in-text text pattern 0)))
         (span (%search-backward-span spans point)))
    (if span
        (funcall on-match (%visible-buffer-span buffer span))
        (funcall on-miss))))

(defun buffer-search-backward (buffer pattern)
  "Return the previous BUFFER-SPAN for PATTERN from point, wrapping once."
  (%search-backward-cps buffer pattern #'identity (constantly nil)))

(defun buffer-search-spans (buffer pattern start)
  "Return BUFFER-SPAN values for PATTERN, starting at START and wrapping once."
  (declare (type buffer-offset start))
  (unless (zerop (length pattern))
    (let* ((text (buffer-visible-text buffer))
           (offset (buffer-narrow-start-offset buffer))
           (local-start (max 0 (min (length text) (- start offset)))))
      (mapcar (lambda (span)
                (%visible-buffer-span buffer span))
              (%search-spans-in-text text pattern local-start)))))
