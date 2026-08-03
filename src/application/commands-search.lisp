;;;; src/application/commands-search.lisp
;;;;
;;;; Application layer: search and replace commands (see
;;;; application/commands-internal.lisp for the shared command-authoring
;;;; convention every commands-*.lisp file follows). The buffer-offset/
;;;; occurrence math these commands drive lives in domain/buffer.lisp
;;;; (%BUFFER-POINT-OFFSET, %BUFFER-OFFSET-POSITION, %FIND-NEXT-OCCURRENCE,
;;;; %REPLACEMENT-OCCURRENCES) as pure text operations with no minibuffer
;;;; concerns; this file owns only the prompting and dispatch around them.
(in-package #:loom)

(defmacro with-prompts ((minibuffer-var minibuffer-form) bindings &body body)
  "Prompt for each (VAR PROMPT-STRING) pair in BINDINGS in turn, binding VAR
to the typed input, then run BODY with every VAR bound and MINIBUFFER-VAR
bound to MINIBUFFER-FORM's value (evaluated once).

MINIBUFFER-ACTIVATE returns immediately; the typed answer only arrives later,
asynchronously, through its :ON-CONFIRM callback. A second, dependent prompt
therefore cannot be issued until the first one's callback runs -- the
continuation-passing chain REPLACE-STRING needs (prompt for the text to
replace, THEN prompt for its replacement) is unavoidable by construction.
WITH-PROMPTS is that chain written once, as a macro that expands BINDINGS
into nested MINIBUFFER-ACTIVATE/:ON-CONFIRM continuations, so a multi-prompt
command reads top-to-bottom like ordinary sequential code instead of as a
hand-nested pyramid of lambdas."
  (labels ((expand-bindings (bindings)
             (if bindings
                 (destructuring-bind (var prompt) (first bindings)
                   `(minibuffer-activate ,minibuffer-var ,prompt
                                         :on-confirm (lambda (,var)
                                                       ,(expand-bindings (rest bindings)))))
                 `(progn ,@body))))
    `(let ((,minibuffer-var ,minibuffer-form))
       ,(expand-bindings bindings))))

(defun %perform-replacement (buffer old new start)
  "Replace every occurrence of OLD with NEW in BUFFER, in one non-overlapping
cycle beginning at START (see %REPLACEMENT-OCCURRENCES), and return the
number of occurrences replaced. A pure buffer mutation with no minibuffer
concerns, called once REPLACE-STRING has both prompted-for strings."
  (let* ((text (buffer-text buffer))
         (offsets (and (plusp (length old)) (%replacement-occurrences text old start))))
    (dolist (offset (sort (copy-list offsets) #'>))
      (multiple-value-bind (start-line start-column)
          (%buffer-offset-position buffer offset)
        (multiple-value-bind (end-line end-column)
            (%buffer-offset-position buffer (+ offset (length old)))
          (buffer-delete-region buffer start-line start-column end-line end-column)
          (buffer-insert-string buffer new))))
    (length offsets)))

(defun replace-string ()
  "Prompt for text and replace every case-sensitive occurrence once."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*))
      ((old "Replace: ")
       (new "With: "))
    (let* ((buffer (%selected-buffer))
           (count (%perform-replacement buffer old new (%buffer-point-offset buffer))))
      (if (plusp count)
          (minibuffer-message minibuffer (format nil "Replaced ~D occurrence(s)" count))
          (minibuffer-message minibuffer "Not found")))))

(defun search-forward ()
  "Prompt for text and move point to its next case-sensitive occurrence."
  (let ((minibuffer (editor-state-minibuffer *editor-state*)))
    (minibuffer-activate
     minibuffer "Search: "
     :on-confirm
     (lambda (string)
       (let* ((buffer (%selected-buffer))
              (offset (%find-next-occurrence buffer string)))
         (if offset
             (multiple-value-bind (line column) (%buffer-offset-position buffer offset)
               (buffer-set-point buffer line column)
               (minibuffer-message minibuffer "Found"))
             (minibuffer-message minibuffer "Not found")))))))
