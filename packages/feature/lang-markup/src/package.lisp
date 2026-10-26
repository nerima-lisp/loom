(defpackage #:loom/feature/lang-markup
  (:use #:cl)
  (:export #:markup-display-lines))

(progn
  (defun %markup-source-lines (source)
    (let ((start 0)
          (length (length source))
          (lines nil))
      (loop for newline = (position #\Newline source :start start)
            do (progn
                 (let ((end (or newline length)))
                   (when (and (> end start)
                              (char= (char source (1- end)) #\Return))
                     (decf end))
                   (push (subseq source start end) lines))
                 (unless newline
                   (return (nreverse lines)))
                 (setf start (1+ newline))))))

  (defun %markup-assign-line-kind (kinds first last kind)
    (loop for line from first to last
          for index = (1- line)
          when (and (<= 0 index) (< index (length kinds)))
            do (setf (aref kinds index) kind)))

  (defun %markup-markdown-kinds (source kinds)
    (labels ((visit (node)
               (let ((kind
                       (case (cl-markdown-kit:node-kind node)
                         (:heading :heading)
                         (:code-block :code)
                         (:html-block
                          (when (eql 2 (cl-markdown-kit:html-block-kind node))
                            :comment)))))
                 (when kind
                   (let* ((span (cl-markdown-kit:node-span node))
                          (first (cl-parser-kit:span-start-line span))
                          (last (cl-parser-kit:span-end-line span)))
                     (when (= 1 (cl-parser-kit:span-end-column span))
                       (decf last))
                     (%markup-assign-line-kind kinds first last kind)))
                 (dolist (child (cl-markdown-kit:node-children node))
                   (visit child)))))
      (dolist (node
               (cl-markdown-kit:document-children
                (cl-markdown-kit:parse-string source)))
        (visit node)))
    kinds)

  (defun %markup-org-kinds (source kinds)
    (org-kit:map-nodes
     (lambda (node)
       (case (org-kit:node-type node)
         (:headline
          (multiple-value-bind (line) (org-kit:node-start-position node)
            (when line
              (%markup-assign-line-kind kinds line line :heading))))
         ((:comment :comment-block)
          (multiple-value-bind (first last) (org-kit:node-line-range node)
            (when first
              (%markup-assign-line-kind kinds first last :comment))))
         (:src-block
          (multiple-value-bind (first last) (org-kit:node-line-range node)
            (when first
              (%markup-assign-line-kind kinds first last :code))))))
     (org-kit:document-root (org-kit:parse-org source)))
    kinds)

  (defun markup-display-lines (source mode)
    "Return one (KIND TEXT) display run for every source line."
    (check-type source string)
    (let* ((lines (%markup-source-lines source))
           (kinds (make-array (length lines) :initial-element :plain)))
      (ecase mode
        (:markdown (%markup-markdown-kinds source kinds))
        (:org (%markup-org-kinds source kinds)))
      (loop for line in lines
            for kind across kinds
            collect (list (list kind line)))))

  (defun loom/feature/lang-markup::org-comment-dwim ()
    (let* ((buffer
             (loom/core/window-tree:window-buffer
              (loom/core/window-tree:window-tree-selected-window
               (loom/core/editor-session:editor-state-window-tree
                loom/core/editor-session:*editor-state*))))
           (span
             (and buffer
                  (loom/core/buffer:buffer-active-region-span buffer))))
      (if (and span
               (> (loom/core/buffer:buffer-span-end span)
                  (loom/core/buffer:buffer-span-start span)))
          (loom/feature/mode:comment-dwim)
          (loom/feature/mode:comment-line))))
  (eval-when (:load-toplevel :execute)
    (loom/core/command::register-internal-command
     :feature/lang-markup
     "lang-markup/org-comment-dwim"
     #'loom/feature/lang-markup::org-comment-dwim
     :mutates t :prompts nil :needs-region nil :external nil
     :modes (list :org)))
  (loom/feature/mode:register-major-mode
   :markdown
   :name "Markdown"
   :extensions '("md" "markdown")
   :comment-prefix nil
   :comment-start "<!-- " :comment-end " -->"
   :skip-closing-delimiter nil
   :indentation-width 2 :tab-width 8
   :truncate-lines nil :language-id "markdown"
   :keywords nil
   :keybindings '(((:alt #\;) . loom/feature/mode:comment-dwim)))
  (loom/feature/mode:register-major-mode
   :org
   :name "Org"
   :extensions '("org")
   :comment-prefix "#"
   :comment-start "#" :comment-end nil
   :skip-closing-delimiter nil
   :indentation-width 2 :tab-width 8
   :truncate-lines nil :language-id "org"
   :keywords '("CANCELLED" "CLOSED" "DEADLINE" "DONE" "NEXT"
               "SCHEDULED" "TODO" "WAITING")
   :keybindings '(((:alt #\;) . loom/feature/lang-markup::org-comment-dwim))))
