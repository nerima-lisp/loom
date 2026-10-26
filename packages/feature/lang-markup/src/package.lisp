(defpackage #:loom/feature/lang-markup
  (:use #:cl)
  (:export #:markup-display-lines))
(in-package #:loom/feature/lang-markup)

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
  (defun %markup-source-from-buffer (buffer)
    (with-output-to-string (source)
      (loop for line-number from 0 below
            (loom/core/buffer:buffer-line-count buffer)
            do (when (plusp line-number)
                 (write-char #\Newline source))
            (write-string
             (loom/core/buffer:buffer-line buffer line-number)
             source))))
  (defun %markup-horizontal-whitespace-only-p (line start)
    (loop for index from start below (length line)
          always (find (char line index) '(#\Space #\Tab))))
  (defun %markup-source-line-start (source line-number)
    (loop with start = 0
          repeat line-number
          do (setf start
                   (1+ (position #\Newline source :start start)))
          finally (return start)))
  (defun %markup-markdown-item-continuation
      (list-node item index line line-start)
    (let* ((span (cl-markdown-kit:node-span item))
           (start (- (cl-parser-kit:span-start span) line-start))
           (task-p (cl-markdown-kit:task-list-item-p item))
           (kind (cl-markdown-kit:list-node-kind list-node))
           (base-marker
            (case kind
              (:unordered
               (string (cl-markdown-kit:list-node-marker-character list-node)))
              (:ordered
               (format nil "~D~C"
                       (1+ (+ (cl-markdown-kit:list-node-start-number list-node)
                              index))
                       (cl-markdown-kit:list-node-delimiter-character
                        list-node)))))
           (continuation
            (concatenate 'string base-marker
                         (if task-p " [ ] " " ")))
           (raw-marker-end
            (if task-p
                (- (cl-parser-kit:span-end
                    (cl-markdown-kit:task-list-item-task-marker-span item))
                   line-start)
              (case kind
                (:unordered (1+ start))
                (:ordered
                 (1+ (position
                      (cl-markdown-kit:list-node-delimiter-character list-node)
                      line :start start))))))
           (marker-end
            (if (and (< raw-marker-end (length line))
                     (find (char line raw-marker-end) '(#\Space #\Tab)))
                (1+ raw-marker-end)
              raw-marker-end)))
      (if (%markup-horizontal-whitespace-only-p line marker-end)
          (values nil start (length line))
        (values continuation nil nil))))
  (defun %markup-markdown-newline-continuation (buffer line-number)
    (let* ((source (%markup-source-from-buffer buffer))
           (line (loom/core/buffer:buffer-line buffer line-number))
           (line-start (%markup-source-line-start source line-number))
           (document (cl-markdown-kit:parse-string source)))
      (labels ((visit (node)
                      (when (cl-markdown-kit:list-node-p node)
                        (loop for item in (cl-markdown-kit:list-node-items node)
                              for index from 0
                              for span = (cl-markdown-kit:node-span item)
                              when (= (cl-parser-kit:span-start-line span)
                                      (1+ line-number))
                              do (return-from %markup-markdown-newline-continuation
                                              (%markup-markdown-item-continuation
                                               node item index line line-start))))
                      (dolist (child (cl-markdown-kit:node-children node))
                        (visit child))))
        (dolist (node (cl-markdown-kit:document-children document))
          (visit node)))
      (values nil nil nil)))
  (defun %markup-org-continuation-marker (bullet)
    ;; Org-kit uses the first item's type for the list; later bullets can differ.
    (multiple-value-bind (number end)
        (parse-integer bullet :junk-allowed t)
      (if number
          (concatenate 'string
                       (format nil "~D" (1+ number))
                       (subseq bullet end))
        bullet)))
  (defun %markup-org-item-continuation (node line-number line)
    (let ((list-node (org-kit:node-parent node)))
      (when (and list-node
                 (eq (org-kit:node-type list-node) :plain-list))
        (multiple-value-bind (item-line item-column)
            (org-kit:node-start-position node)
          (when (= item-line (1+ line-number))
            (multiple-value-bind (bullet bullet-p)
                (org-kit:node-property node :bullet)
              (multiple-value-bind (list-type list-type-p)
                  (org-kit:node-property list-node :type)
                (when (and bullet-p list-type-p
                           (member list-type '(:ordered :unordered)))
                  (let* ((marker-start
                          (search bullet line :start2 (1- item-column)))
                         (marker-end (+ marker-start (length bullet)))
                         (continuation
                          (%markup-org-continuation-marker bullet)))
                    (if (%markup-horizontal-whitespace-only-p line marker-end)
                        (values nil marker-start (length line))
                      (values continuation nil nil)))))))))))
  (defun %markup-org-newline-continuation (buffer line-number)
    (let* ((source (%markup-source-from-buffer buffer))
           (line (loom/core/buffer:buffer-line buffer line-number))
           (root
            (org-kit:document-root
             (org-kit:parse-org source))))
      (org-kit:map-nodes
       (lambda (node)
         (when (eq (org-kit:node-type node) :item)
           (multiple-value-bind (continuation delete-start delete-end)
               (%markup-org-item-continuation node line-number line)
             (when (or continuation delete-start)
               (return-from %markup-org-newline-continuation
                            (values continuation delete-start delete-end))))))
       root))
    (values nil nil nil))

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

(loom/feature/mode:register-major-mode-display-lines-provider
 :markdown #'loom/feature/lang-markup:markup-display-lines)

(loom/feature/mode:register-major-mode-display-lines-provider
 :org #'loom/feature/lang-markup:markup-display-lines)
(loom/feature/mode:register-major-mode-newline-continuation
     :markdown #'%markup-markdown-newline-continuation)
(loom/feature/mode:register-major-mode-newline-continuation
     :org #'%markup-org-newline-continuation)
