(in-package #:loom/feature/search)

(defun %replace-span (buffer span new)
  (let ((start-position
          (buffer-offset-position buffer (buffer-span-start span)))
        (end-position
          (buffer-offset-position buffer (buffer-span-end span))))
    (buffer-delete-region
     buffer
     (buffer-position-line start-position)
     (buffer-position-column start-position)
     (buffer-position-line end-position)
     (buffer-position-column end-position))
    (buffer-insert-string buffer new)))

(defun %replacement-match-records (buffer pattern start regexp-p)
  (unless (and (not regexp-p) (string= pattern ""))
    (let* ((text (buffer-visible-text buffer))
           (offset (buffer-narrow-start-offset buffer))
           (region (loom/core/buffer:buffer-active-region-span buffer))
           (start-index
             (max 0
                  (min (length text)
                       (- (if region
                              (buffer-span-start region)
                              start)
                          offset))))
           (end-index
             (max start-index
                  (min (length text)
                       (- (if region
                              (buffer-span-end region)
                              (+ offset (length text)))
                          offset))))
           (source (if regexp-p
                       pattern
                       (cl-regex-kit:escape pattern)))
           (case-fold-p (%search-pattern-case-fold-p pattern))
           (regex (cl-regex-kit:compile-regex
                   source :case-insensitive case-fold-p)))
      (loop for match in
              (cl-regex-kit:all-matches
               regex text :start start-index :end end-index
               :timeout +regex-search-timeout-seconds+)
            collect
            (list (make-buffer-span
                   (+ offset (cl-regex-kit:match-start match))
                   (+ offset (cl-regex-kit:match-end match)))
                  (cl-regex-kit:match-captures match text))))))

(defun %shift-replacement-record-span (record delta)
  (let ((span (first record)))
    (make-buffer-span (+ (buffer-span-start span) delta)
                      (+ (buffer-span-end span) delta))))

(defun %regexp-replacement-text (replacement captures &optional (replacement-count 0))
  (with-output-to-string (stream)
    (loop for index from 0 below (length replacement)
          for character = (char replacement index)
          do (if (char= character #\\)
                 (if (= index (1- (length replacement)))
                     (write-char character stream)
                   (let ((next (char replacement (1+ index))))
                     (cond
                      ((char= next #\\)
                       (write-char next stream)
                       (incf index))
                      ((char= next #\&)
                       (when (aref captures 0)
                         (write-string (aref captures 0) stream))
                       (incf index))
                      ((char= next #\#)
                       (format stream "~D" replacement-count)
                       (incf index))
                      ((char<= #\1 next #\9)
                       (let* ((capture-index (digit-char-p next))
                              (capture (when (< capture-index
                                                (length captures))
                                         (aref captures capture-index))))
                         (when capture
                           (write-string capture stream)))
                       (incf index))
                      (t
                       (write-char character stream)
                       (write-char next stream)
                       (incf index)))))
               (write-char character stream)))))

(progn
  (defun %replacement-record-text
      (record pattern replacement regexp-p &optional (replacement-count 0))
    (let* ((captures (second record))
           (match (aref captures 0))
           (expanded (if regexp-p
                         (%regexp-replacement-text
                          replacement captures replacement-count)
                       replacement)))
      (if (or (some #'upper-case-p pattern)
              (some #'upper-case-p replacement)
              (notany (lambda (character)
                        (not (char= (char-downcase character)
                                    (char-upcase character))))
                      match))
          expanded
        (cond
         ((string= match (string-upcase match))
          (string-upcase expanded))
         ((string= match (string-capitalize match))
          (string-capitalize expanded))
         (t expanded)))))

  (defun %perform-replacement (buffer records pattern replacement regexp-p)
    (let* ((record-texts
            (loop for record in records
                  for replacement-count from 0
                  collect
                  (list record
                        (%replacement-record-text
                         record pattern replacement regexp-p replacement-count))))
           (final-offset
            (when records
              (+ (buffer-span-end (first (car (last records))))
                 (loop for record-text in record-texts
                       for record = (first record-text)
                       for span = (first record)
                       for new-text = (second record-text)
                       sum (- (length new-text)
                              (- (buffer-span-end span)
                                 (buffer-span-start span))))))))
      (dolist (record-text
               (sort (copy-list record-texts)
                     #'>
                     :key (lambda (item)
                            (buffer-span-start (first (first item))))))
        (let ((record (first record-text)))
          (%replace-span buffer
                         (first record)
                         (second record-text))))
      (when final-offset
        (let ((position (buffer-offset-position buffer final-offset)))
          (buffer-set-point buffer
                            (buffer-position-line position)
                            (buffer-position-column position))))
      (length records)))

  (defun %selected-search-buffer ()
    (let ((window-tree (editor-state-window-tree *editor-state*)))
      (loom/core/window-tree:window-buffer
       (loom/core/window-tree:window-tree-selected-window window-tree))))

  (defun %run-replacement-command (prompt regexp-p)
    (let ((minibuffer (editor-state-minibuffer *editor-state*))
          (buffer (%selected-search-buffer)))
      (with-prompts (minibuffer minibuffer
                     :on-cancel (minibuffer-message minibuffer "Quit"))
          ((pattern prompt)
           (replacement "With: "))
        (handler-case
            (let* ((records (%replacement-match-records
                             buffer pattern (buffer-point-offset buffer) regexp-p))
                   (count (%perform-replacement
                           buffer records pattern replacement regexp-p)))
              (if (plusp count)
                  (minibuffer-message
                   minibuffer (format nil "Replaced ~D occurrence(s)" count))
                  (minibuffer-message minibuffer "Not found")))
          (cl-regex-kit:regex-syntax-error (condition)
            (minibuffer-message
             minibuffer
             (format nil "Invalid regular expression: ~A" condition)))))))

  (defun replace-string ()
    "Prompt for literal text and a literal replacement, then replace from point
to buffer end, or only within the active region. Replacement text is inserted
verbatim."
    (%run-replacement-command "Replace string: " nil))

  (defun replace-regexp ()
    "Prompt for a regular expression and replacement text, expanding \\& and
\\1 through \\9 from each match. \\# expands to the number of prior replacements."
    (%run-replacement-command "Replace (regex): " t))

  (defun %shift-query-replacement-records (records current-index current-record delta)
  (if (zerop delta)
      records
      (loop for record in records
            for index from 0
            collect
            (if (and (> index current-index)
                     (>= (buffer-span-start (first record))
                         (buffer-span-end (first current-record))))
                (list (%shift-replacement-record-span record delta)
                      (second record))
                record))))

  (defun %query-replacement-finish (minibuffer count)
    (when (loom/core/minibuffer:minibuffer-active-p minibuffer)
      ;; The consumed q and ! keys do not reach minibuffer's normal exit path.
      (loom/core/minibuffer::%minibuffer-deactivate minibuffer))
    (minibuffer-message
     minibuffer (format nil "Replaced ~D occurrence(s)" count)))

  (defun %query-replacement-key-action (key-event)
    (let* ((descriptor (loom/core/command:key-event->descriptor key-event))
           (modifiers (car descriptor))
           (code (cdr descriptor)))
      (cond
        ((and (null modifiers) (eql code :enter)) :finish)
        ((and (equal modifiers (list :control))
              (eql code #\g))
         :cancel)
        ((and (null modifiers) (eql code #\y)) :replace)
        ((and (null modifiers) (eql code #\n)) :skip)
        ((and (null modifiers) (eql code #\!)) :replace-rest)
        ((and (null modifiers) (eql code #\q)) :finish)
        (t :ignore))))

  (defun %run-query-replace (buffer minibuffer pattern replacement regexp-p)
    (handler-case
        (let ((records (%replacement-match-records
                        buffer pattern (buffer-point-offset buffer) regexp-p)))
          (if (null records)
              (minibuffer-message minibuffer "Not found")
              (let ((index 0)
                    (count 0))
                (labels ((finish ()
                           (%query-replacement-finish minibuffer count))
                         (present-current ()
                           (if (< index (length records))
                               (let* ((span (first (nth index records)))
                                      (position
                                        (buffer-offset-position
                                         buffer (buffer-span-start span))))
                                 (buffer-set-point
                                  buffer
                                  (buffer-position-line position)
                                  (buffer-position-column position)))
                               (finish)))
                         (replace-current ()
                           (let* ((record (nth index records))
                                  (span (first record))
                                  (new-text
                                    (%replacement-record-text record pattern replacement regexp-p count))
                                  (delta
                                    (- (length new-text)
                                       (- (buffer-span-end span)
                                          (buffer-span-start span)))))
                             (%replace-span buffer span new-text)
                             (incf count)
                             (setf records
                                   (%shift-query-replacement-records
                                    records index record delta))
                             (incf index)))
                         (replace-rest ()
                           (replace-current)
                           (loop while (< index (length records))
                                 do (replace-current))
                           (finish))
                         (handle-key (key-event)
                           (case (%query-replacement-key-action key-event)
                             (:replace
                              (replace-current)
                              (present-current)
                              t)
                             (:skip
                              (incf index)
                              (present-current)
                              t)
                             (:replace-rest
                              (replace-rest)
                              t)
                             (:finish
                              (finish)
                              t)
                             (:cancel nil)
                             (otherwise t))))
                  (loom/core/minibuffer:minibuffer-activate
                   minibuffer
                   "Query replace: "
                   :on-key (function handle-key)
                   :on-confirm (lambda (input)
                                 (declare (ignore input))
                                 (finish))
                   :on-cancel (lambda ()
                                (minibuffer-message minibuffer "Quit")))
                  (present-current)))))
      (cl-regex-kit:regex-syntax-error (condition)
        (minibuffer-message
         minibuffer
         (format nil "Invalid regular expression: ~A" condition)))))

  (defun %start-query-replace (regexp-p)
    (let ((buffer (%selected-search-buffer))
          (minibuffer (editor-state-minibuffer *editor-state*)))
      (with-prompts (minibuffer minibuffer
                     :on-cancel (minibuffer-message minibuffer "Quit"))
          ((pattern (if regexp-p
                        "Query replace regexp: "
                        "Query replace: "))
           (replacement (if regexp-p
                            "Query replace regexp with: "
                            "Query replace with: ")))
        (%run-query-replace buffer minibuffer pattern replacement regexp-p))))

  (defun query-replace ()
    "Interactively replace literal occurrences from point to buffer end, or only
within the active region. Use y to replace, n to skip, ! to replace the rest, and
q or RET to exit. C-g exits the current query while retaining replacements
already made."
    (%start-query-replace nil))

  (defun query-replace-regexp ()
    "Interactively replace regexp matches, expanding \\&, \\1 through \\9, and
\\# (the number of prior replacements). Use y to replace, n to skip, ! to
replace the rest, and q or RET to exit. C-g exits the current query while
retaining replacements already made."
    (%start-query-replace t)))

(defun %report-search-result (minibuffer buffer span)
  (if span
      (let ((position (buffer-offset-position buffer
                                               (buffer-span-start span))))
        (buffer-set-point buffer
                          (buffer-position-line position)
                          (buffer-position-column position))
        (minibuffer-message minibuffer "Found"))
      (minibuffer-message minibuffer "Not found")))

(defun %run-search-command (prompt search-fn)
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((pattern prompt))
    (let* ((buffer (loom/core/window-tree:window-buffer (loom/core/window-tree:window-tree-selected-window (editor-state-window-tree *editor-state*))))
           (span (funcall search-fn buffer pattern)))
      (%report-search-result minibuffer buffer span))))

(defmacro %define-search-command (name docstring prompt search-fn)
  `(defun ,name ()
     ,docstring
     (%run-search-command ,prompt #',search-fn)))

(%define-search-command
 search-forward
 "Prompt for a regular expression and move point to its next match. Patterns
without uppercase letters ignore case by default; patterns containing uppercase
letters are case-sensitive by default. The inline (?i) flag requests
case-insensitive matching."
 "Search (regex): "
 buffer-search-forward)

(%define-search-command
 search-backward
 "Prompt for a regular expression and move point to its previous match."
 "Search backward (regex): "
 buffer-search-backward)
