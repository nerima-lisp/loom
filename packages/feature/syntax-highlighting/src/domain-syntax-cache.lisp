(in-package #:loom/feature/syntax-highlighting)

(defstruct (%syntax-line-entry (:constructor %make-syntax-line-entry))
  text
  (start-state :code)
  (end-state :code)
  token-source
  (token-offset 0)
  tokens)

(defstruct (syntax-line-cache
            (:constructor make-syntax-line-cache (mode version))
            (:copier nil))
  "Reader states of one buffer's absolute lines for MODE, valid at VERSION."
  mode
  version
  (valid-through -1)
  (lines (make-array 0 :adjustable t :fill-pointer 0)))

(defun syntax-line-cache-invalidate (cache changed-line version)
  "Mark CACHE's states from CHANGED-LINE onward for revalidation at VERSION."
  (setf (syntax-line-cache-valid-through cache)
        (min (syntax-line-cache-valid-through cache) (1- changed-line))
        (syntax-line-cache-version cache) version)
  cache)

(defun %syntax-cache-state-through (buffer cache absolute-line)
  (let ((lines (syntax-line-cache-lines cache)))
    (loop for line from (1+ (syntax-line-cache-valid-through cache))
          to absolute-line
          for text = (buffer-line buffer line)
          for previous = (when (plusp line) (aref lines (1- line)))
          for state = (if previous (%syntax-line-entry-end-state previous) :code)
          for old = (when (< line (length lines)) (aref lines line))
          do (unless (and old
                          (eql state (%syntax-line-entry-start-state old))
                          (string= text (%syntax-line-entry-text old)))
               (setf old (%make-syntax-line-entry
                          :text text :start-state state
                          :end-state (nth-value 1 (%syntax-scan-line text state nil)))))
             ;; A converged line reuses its old state and tokens. Later directly
             ;; edited lines still need validation when they enter a viewport.
             (if (< line (length lines))
                 (setf (aref lines line) old)
                 (vector-push-extend old lines))
             (setf (syntax-line-cache-valid-through cache) line))
    (aref lines absolute-line)))

(defun %syntax-trim-token-prefix (tokens offset)
  (loop while (and tokens (>= offset (length (syntax-token-text (first tokens)))))
        do (decf offset (length (syntax-token-text (pop tokens)))))
  (if (and tokens (plusp offset))
      (cons (%make-syntax-token (syntax-token-kind (first tokens))
                                (subseq (syntax-token-text (first tokens)) offset))
            (rest tokens))
      tokens))

(defun syntax-cached-line-tokens (cache buffer absolute-line text &optional (offset 0))
  "Return tokens for TEXT, displayed from character OFFSET of BUFFER's ABSOLUTE-LINE.
CACHE must be current for BUFFER. Uncached preceding lines contribute reader
state without constructing tokens."
  (let ((mode (or (major-mode-from-name (syntax-line-cache-mode cache)) :fundamental)))
    (unless (eq mode :common-lisp)
      (return-from syntax-cached-line-tokens
        (syntax-highlight-line-for-mode text mode)))
    (let ((entry (%syntax-cache-state-through buffer cache absolute-line)))
      (unless (and (%syntax-line-entry-token-source entry)
                   (= offset (%syntax-line-entry-token-offset entry))
                   (string= text (%syntax-line-entry-token-source entry)))
        ;; Lex the hidden prefix of this displayed line together with its visible
        ;; suffix, so narrowing inside an escape or character literal stays exact.
        (let ((source (if (zerop offset) text
                          (concatenate 'string
                                       (subseq (%syntax-line-entry-text entry) 0 offset)
                                       text))))
          (setf (%syntax-line-entry-tokens entry)
                (%syntax-trim-token-prefix
                 (syntax-highlight-line source (%syntax-line-entry-start-state entry))
                 offset)
                (%syntax-line-entry-token-source entry) text
                (%syntax-line-entry-token-offset entry) offset)))
      (%syntax-line-entry-tokens entry))))
