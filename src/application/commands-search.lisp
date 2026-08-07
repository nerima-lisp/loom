;;;; src/application/commands-search.lisp
;;;;
;;;; Application layer: search and replace commands (see
;;;; application/commands-internal.lisp for the shared command-authoring
;;;; convention every commands-*.lisp file follows). The buffer-offset/
;;;; match math these commands drive lives in domain/buffer.lisp
;;;; (%BUFFER-POINT-OFFSET, %BUFFER-OFFSET-POSITION, %FIND-NEXT-OCCURRENCE,
;;;; %REPLACEMENT-MATCH-SPANS) as pure text operations with no minibuffer
;;;; concerns; this file owns only the prompting and dispatch around them.
;;;;
;;;; Both commands take a CL-REGEX-KIT regular expression as the text they
;;;; search FOR. REPLACE-STRING's replacement stays a literal string inserted
;;;; as-is at each match: no $1-style capture-group expansion, which is what
;;;; keeps replacement a per-match delete+insert (and so one undo entry per
;;;; match) rather than a single whole-buffer rewrite.
(in-package #:loom)

(defun %perform-replacement (buffer old new start)
  "Replace every occurrence of regular expression OLD with the literal text
NEW in BUFFER, in one non-overlapping cycle beginning at START (see
%REPLACEMENT-MATCH-SPANS), and return the number of occurrences replaced.
NEW is inserted verbatim -- capture-group references such as $1 are not
expanded. A pure buffer mutation with no minibuffer concerns, called once
REPLACE-STRING has both prompted-for strings."
  (let* ((text (buffer-text buffer))
         (spans (and (plusp (length old)) (%replacement-match-spans text old start))))
    (dolist (span (sort (copy-list spans) #'> :key #'car))
      (multiple-value-bind (start-line start-column)
          (%buffer-offset-position buffer (car span))
        (multiple-value-bind (end-line end-column)
            (%buffer-offset-position buffer (cdr span))
          (buffer-delete-region buffer start-line start-column end-line end-column)
          (buffer-insert-string buffer new))))
    (length spans)))

(defun replace-string ()
  "Prompt for a regular expression and a literal replacement, and replace
every match once. The search side is a CL-REGEX-KIT pattern (case-sensitive
unless it opens with the inline (?i) flag); the replacement is inserted
verbatim, with no capture-group expansion."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((old "Replace (regex): ")
       (new "With: "))
    (let* ((buffer (%selected-buffer))
           (count (%perform-replacement buffer old new (%buffer-point-offset buffer))))
      (if (plusp count)
          (minibuffer-message minibuffer (format nil "Replaced ~D occurrence(s)" count))
          (minibuffer-message minibuffer "Not found")))))

(defun search-forward ()
  "Prompt for a regular expression and move point to its next match. The
pattern is a CL-REGEX-KIT pattern, case-sensitive unless it opens with the
inline (?i) flag."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((pattern "Search (regex): "))
    (let* ((buffer (%selected-buffer))
           (match (%find-next-occurrence buffer pattern)))
      (if match
          (multiple-value-bind (line column)
              (%buffer-offset-position buffer (cl-regex-kit:match-start match))
            (buffer-set-point buffer line column)
            (minibuffer-message minibuffer "Found"))
          (minibuffer-message minibuffer "Not found")))))
