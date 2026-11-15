(in-package #:loom/feature/syntax-highlighting)

(defstruct (%syntax-line-cache (:constructor %make-syntax-line-cache))
  text
  (start-state :code)
  (end-state :code)
  token-source
  (token-offset 0)
  tokens)

(defstruct (%syntax-buffer-cache (:constructor %make-syntax-buffer-cache (mode)))
  mode
  (version 0)
  (valid-through -1)
  (lines (make-array 0 :adjustable t :fill-pointer 0)))

(defvar *syntax-buffer-caches* (make-hash-table :test #'eq :weakness :key))

(defun %syntax-current-buffer-cache (buffer mode)
  (let ((cache (gethash buffer *syntax-buffer-caches*)))
    (unless (and cache (eq mode (%syntax-buffer-cache-mode cache)))
      (setf cache (%make-syntax-buffer-cache mode)
            (gethash buffer *syntax-buffer-caches*) cache))
    (let ((version (buffer-version buffer)))
      (unless (= version (%syntax-buffer-cache-version cache))
        (let ((changed (buffer-changed-line-since
                        buffer (%syntax-buffer-cache-version cache))))
          (setf (%syntax-buffer-cache-valid-through cache)
                (min (%syntax-buffer-cache-valid-through cache)
                     (1- changed))
                (%syntax-buffer-cache-version cache) version))))
    cache))

(defun %syntax-cache-state-through (buffer cache absolute-line)
  (let ((lines (%syntax-buffer-cache-lines cache)))
    (loop for line from (1+ (%syntax-buffer-cache-valid-through cache))
          to absolute-line
          for text = (buffer-line buffer line)
          for previous = (when (plusp line) (aref lines (1- line)))
          for state = (if previous (%syntax-line-cache-end-state previous) :code)
          for old = (when (< line (length lines)) (aref lines line))
          do (unless (and old
                          (eql state (%syntax-line-cache-start-state old))
                          (string= text (%syntax-line-cache-text old)))
               (setf old (%make-syntax-line-cache
                          :text text :start-state state
                          :end-state (nth-value 1 (%syntax-scan-line text state nil)))))
             ;; A converged line reuses its old state and tokens. Later directly
             ;; edited lines still need validation when they enter a viewport.
             (if (< line (length lines))
                 (setf (aref lines line) old)
                 (vector-push-extend old lines))
             (setf (%syntax-buffer-cache-valid-through cache) line))
    (aref lines absolute-line)))

(defun %syntax-trim-token-prefix (tokens offset)
  (loop while (and tokens (>= offset (length (syntax-token-text (first tokens)))))
        do (decf offset (length (syntax-token-text (pop tokens)))))
  (if (and tokens (plusp offset))
      (cons (%make-syntax-token (syntax-token-kind (first tokens))
                                (subseq (syntax-token-text (first tokens)) offset))
            (rest tokens))
      tokens))

(defun syntax-highlight-buffer-line (buffer absolute-line &optional display-line)
  "Return cached tokens for BUFFER's absolute line, optionally using display text.
Hidden preceding lines contribute reader state without constructing tokens."
  (let* ((mode (or (major-mode-from-name (buffer-major-mode buffer)) :fundamental))
         (text (or display-line (buffer-line buffer absolute-line))))
    (unless (eq mode :common-lisp)
      (return-from syntax-highlight-buffer-line
        (syntax-highlight-line-for-mode text mode)))
    (let* ((cache (%syntax-current-buffer-cache buffer mode))
           (entry (%syntax-cache-state-through buffer cache absolute-line))
           (offset (if (and display-line
                            (= absolute-line (buffer-narrow-start-line buffer)))
                       (- (buffer-narrow-start-offset buffer)
                          (buffer-position-offset buffer absolute-line 0))
                       0)))
      (unless (and (%syntax-line-cache-token-source entry)
                   (= offset (%syntax-line-cache-token-offset entry))
                   (string= text (%syntax-line-cache-token-source entry)))
        ;; Lex the hidden prefix of this displayed line together with its visible
        ;; suffix, so narrowing inside an escape or character literal stays exact.
        (let ((source (if (zerop offset) text
                          (concatenate 'string
                                       (subseq (%syntax-line-cache-text entry) 0 offset)
                                       text))))
          (setf (%syntax-line-cache-tokens entry)
                (%syntax-trim-token-prefix
                 (syntax-highlight-line source (%syntax-line-cache-start-state entry))
                 offset)
                (%syntax-line-cache-token-source entry) text
                (%syntax-line-cache-token-offset entry) offset)))
      (%syntax-line-cache-tokens entry))))
