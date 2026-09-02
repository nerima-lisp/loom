;;;; packages/feature/search/src/application-commands-search.lisp
;;;;
;;;; Application layer: search and replace commands (see
;;;; application/commands-internal.lisp for the shared command-authoring
;;;; convention every commands-*.lisp file follows). The buffer-offset/
;;;; position/span API these commands drive lives in domain/buffer.lisp;
;;;; regex compilation and scanning stay there, while this file owns only
;;;; prompting and dispatch around the domain operations.
;;;;
;;;; Both commands take a regular-expression pattern as the text they search
;;;; for. REPLACE-STRING's replacement stays a literal string inserted
;;;; as-is at each match: no $1-style capture-group expansion, which is what
;;;; keeps replacement a per-match delete+insert (and so one undo entry per
;;;; match) rather than a single whole-buffer rewrite.
(in-package #:loom/feature/search)

(defun %perform-replacement (buffer old new start)
  "Replace every occurrence of regular expression OLD with the literal text
NEW in BUFFER, in one non-overlapping cycle beginning at START (see
BUFFER-SEARCH-SPANS), and return the number of occurrences replaced.
NEW is inserted verbatim -- capture-group references such as $1 are not
expanded. A pure buffer mutation with no minibuffer concerns, called once
REPLACE-STRING has both prompted-for strings."
  (let ((spans (and (string/= old "")
                    (buffer-search-spans buffer old start))))
    (dolist (span (sort (copy-list spans) #'> :key #'buffer-span-start))
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
    (length spans)))

(defun replace-string ()
  "Prompt for a regular expression and a literal replacement, and replace
every match once. The search side is case-sensitive unless it opens with the
inline (?i) flag; the replacement is inserted verbatim, with no capture-group
expansion."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((old "Replace (regex): ")
       (new "With: "))
    (let* ((buffer (%selected-buffer))
           (count (%perform-replacement buffer old new (buffer-point-offset buffer))))
      (if (plusp count)
          (minibuffer-message minibuffer (format nil "Replaced ~D occurrence(s)" count))
          (minibuffer-message minibuffer "Not found")))))

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
    (let* ((buffer (%selected-buffer))
           (span (funcall search-fn buffer pattern)))
      (%report-search-result minibuffer buffer span))))

(defmacro %define-search-command (name docstring prompt search-fn)
  `(defun ,name ()
     ,docstring
     (%run-search-command ,prompt #',search-fn)))

(%define-search-command
 search-forward
 "Prompt for a regular expression and move point to its next match. The
pattern is case-sensitive unless it opens with the inline (?i) flag."
 "Search (regex): "
 buffer-search-forward)

(%define-search-command
 search-backward
 "Prompt for a regular expression and move point to its previous match."
 "Search backward (regex): "
 buffer-search-backward)
