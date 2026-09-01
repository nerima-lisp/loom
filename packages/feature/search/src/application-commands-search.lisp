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
  (let ((spans (and (plusp (length old))
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

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun %search-command-form (name prompt search-fn docstring)
    (let ((buffer-var (gensym "BUFFER-"))
          (span-var (gensym "SPAN-"))
          (position-var (gensym "POSITION-")))
      `(defun ,name ()
         ,docstring
         (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                        :on-cancel (minibuffer-message minibuffer "Quit"))
             ((pattern ,prompt))
           (let* ((,buffer-var (%selected-buffer))
                  (,span-var (,search-fn ,buffer-var pattern)))
             (if ,span-var
                 (let ((,position-var
                         (buffer-offset-position ,buffer-var
                                                  (buffer-span-start ,span-var))))
                   (buffer-set-point ,buffer-var
                                     (buffer-position-line ,position-var)
                                     (buffer-position-column ,position-var))
                   (minibuffer-message minibuffer "Found"))
                 (minibuffer-message minibuffer "Not found")))))))
  )

(defmacro %define-search-command (name prompt search-fn docstring)
  (%search-command-form name prompt search-fn docstring))

(%define-search-command
 search-forward
 "Search (regex): "
 buffer-search-forward
 "Prompt for a regular expression and move point to its next match. The
pattern is case-sensitive unless it opens with the inline (?i) flag.")

(%define-search-command
 search-backward
 "Search backward (regex): "
 buffer-search-backward
 "Prompt for a regular expression and move point to its previous match.")
