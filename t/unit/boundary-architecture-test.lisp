(in-package #:loom/test)
(defun boundary-safe-readtable ()
  (let ((readtable (copy-readtable nil)))
    (set-dispatch-macro-character
     #\# #\.
     (lambda (stream sub-character numeric-argument)
       (declare (ignore sub-character numeric-argument))
       (read stream t nil t))
     readtable)
    readtable))

(defparameter *boundary-package-map*
  ;; LOOM is shared by root and core files; src/main.lisp adds the composition-root layer.
  '(("LOOM/APPLICATION" ("root") (:application) "src/package-application.lisp")
    ("LOOM" ("root" "core")
     (:domain :application :infrastructure :presentation :core :composition-root)
     "src/package.lisp")
    ("LOOM/CORE/BUFFER" ("core/buffer") (:domain)
     "packages/core/buffer/src/package.lisp")
    ("LOOM/CORE/WINDOW-TREE" ("core/window-tree") (:domain)
     "packages/core/window-tree/src/package.lisp")
    ("LOOM/CORE/EDITOR-SESSION" ("core/editor-session") (:domain :application :core)
     "packages/core/editor-session/src/package.lisp")
    ("LOOM/CORE/COMMAND" ("core/command") (:domain :application :core)
     "packages/core/command/src/package.lisp")
    ("LOOM/CORE/MINIBUFFER" ("core/minibuffer") (:domain :application :core)
     "packages/core/minibuffer/src/package.lisp")
    ("LOOM/FEATURE/MODE" ("feature/mode") (:domain :application)
     "packages/feature/mode/src/package.lisp")
    ("LOOM/FEATURE/SYNTAX-HIGHLIGHTING" ("feature/syntax-highlighting")
     (:domain :presentation) "packages/feature/syntax-highlighting/src/package.lisp")
    ("LOOM/FEATURE/PROJECT" ("feature/project") (:domain :application :infrastructure)
     "packages/feature/project/src/package.lisp")
    ("LOOM/FEATURE/SEARCH" ("feature/search") (:domain :application)
     "packages/feature/search/src/package.lisp")
    ("LOOM/FEATURE/BUFFERS" ("feature/buffers")
     (:domain :application)
     "packages/feature/buffers/src/package.lisp")
    ("LOOM/FEATURE/WINDOW" ("feature/window") (:domain :application)
     "packages/feature/window/src/package.lisp")
    ("LOOM/FEATURE/BOOKMARK" ("feature/bookmark") (:domain :application)
     "packages/feature/bookmark/src/package.lisp")
    ("LOOM/FEATURE/WORKSPACE" ("feature/workspace") (:domain :application)
     "packages/feature/workspace/src/package.lisp")
    ("LOOM/FEATURE/FILE-TREE" ("feature/file-tree")
     (:domain :application :infrastructure)
     "packages/feature/file-tree/src/package.lisp")
    ("LOOM/FEATURE/FILES" ("feature/files")
     (:application :infrastructure)
     "packages/feature/files/src/package.lisp")
    ("LOOM/FEATURE/EVALUATION" ("feature/evaluation")
     (:domain :application :infrastructure)
     "packages/feature/evaluation/src/package.lisp")
    ("LOOM/FEATURE/SHELL" ("feature/shell") (:domain :application :infrastructure)
     "packages/feature/shell/src/package.lisp")
    ("LOOM/FEATURE/FORMAT" ("feature/format") (:application)
     "packages/feature/format/src/package.lisp")
    ("LOOM/FEATURE/AUTO-SAVE" ("feature/auto-save")
     (:domain :application :infrastructure)
     "packages/feature/auto-save/src/package.lisp")
    ("LOOM/FEATURE/TERMINAL" ("feature/terminal")
     (:domain :application :infrastructure)
     "packages/feature/terminal/src/package.lisp")
    ("LOOM/FEATURE/GIT" ("feature/git") (:domain :application :infrastructure)
     "packages/feature/git/src/package.lisp")
    ("LOOM/FEATURE/KEYBOARD-MACRO" ("feature/keyboard-macro")
     (:domain :application) "packages/feature/keyboard-macro/src/package.lisp")
    ("LOOM/FEATURE/REGISTER" ("feature/register") (:domain :application)
     "packages/feature/register/src/package.lisp")
    ("LOOM/FEATURE/SESSION" ("feature/session")
     (:domain :application :infrastructure)
     "packages/feature/session/src/package.lisp")
    ("LOOM/FEATURE/USER-INIT" ("feature/user-init") (:application :infrastructure)
     "packages/feature/user-init/src/package.lisp")
    ("LOOM/FEATURE/LSP" ("feature/lsp") (:domain :application :infrastructure)
     "packages/feature/lsp/src/package.lisp")
    ("LOOM/FEATURE/LIFECYCLE" ("feature/lifecycle") (:application) "packages/feature/lifecycle/src/package.lisp")
    ("LOOM/FEATURE/HELP" ("feature/help") (:application) "packages/feature/help/src/package.lisp")
    ("LOOM-USER" ("root") (:composition-root) "src/package-user.lisp")))

(defparameter *boundary-report-vs-fail* :fail)
;; Slice-local allowlists mark matches KNOWN, not approved.
(defvar *boundary-allowlist* nil)

(defstruct boundary-record path slice layer package text)
(defstruct boundary-token package symbol internal-p qualified-p head-p line)
(defstruct boundary-edge source-package target-package source-slice target-slice
  file line reference)
(defstruct boundary-finding category slice file line reference)

(defun boundary-package-row (name)
  (find name *boundary-package-map* :key #'first :test #'string-equal))

(defun boundary-package-slices (name)
  (or (second (boundary-package-row name)) '("external")))

(defun boundary-package-definition-file (name)
  (fourth (boundary-package-row name)))

(defun boundary-path-layer (path)
  (cond
    ((or (search "packages/core/" path)
         (search "packages/feature/" path))
     (let ((start (search "/src/" path)))
       (if (null start)
           :declaration
           (let ((file (subseq path (+ start 5))))
             (cond ((string= file "package.lisp") :declaration)
                   ((uiop:string-prefix-p "command-specs-" file)
                    :declaration)
                   ((uiop:string-prefix-p "domain-" file) :domain)
                   ((uiop:string-prefix-p "application-" file) :application)
                   ((uiop:string-prefix-p "infrastructure-" file) :infrastructure)
                   ((uiop:string-prefix-p "presentation-" file) :presentation)
                   ((search "packages/core/" path) :core)
                   (t :unknown))))))
    ((search "src/domain/" path) :domain)
    ((search "src/application/" path) :application)
    ((search "src/infrastructure/" path) :infrastructure)
    ((search "src/presentation/" path) :presentation)
    ((string= path "src/main.lisp") :composition-root)
    ((search "src/package" path) :declaration)
    ((search "src/" path) :composition-root)
    (t :unknown)))

(defun boundary-path-slice (path)
  (cond ((search "packages/core/editor/" path) "core")
        ((search "packages/core/" path)
         (let* ((start (+ (search "packages/core/" path)
                          (length "packages/core/")))
                (end (position #\/ path :start start)))
           (format nil "core/~A" (subseq path start end))))
        ((search "packages/feature/" path)
         (let* ((start (+ (search "packages/feature/" path)
                          (length "packages/feature/")))
                (end (position #\/ path :start start)))
           (format nil "feature/~A" (subseq path start end))))
        (t "root")))

(defun boundary-lisp-components
    (component
     &optional
       (visited-systems (make-hash-table :test #'equal)))
  (let ((system-name
          (when (typep component 'asdf:system)
            (asdf:component-name component))))
    (unless (and system-name (gethash system-name visited-systems))
      (when system-name
        (setf (gethash system-name visited-systems) t))
      (append
       (when (typep component 'asdf:source-file)
         (let ((pathname (asdf:component-pathname component)))
           (when (and (pathname-type pathname)
                      (string-equal (pathname-type pathname) "lisp"))
             (list pathname))))
       (when (typep component 'asdf:module)
         (mapcan (lambda (child)
                   (boundary-lisp-components child visited-systems))
                 (asdf:component-children component)))
       (when system-name
         (loop for dependency in (asdf:system-depends-on component)
               for dependency-name = (cond
                                       ((stringp dependency) dependency)
                                       ((consp dependency) (first dependency)))
               when (and (stringp dependency-name)
                         (not (uiop:string-suffix-p "/test" dependency-name))
                         (or (uiop:string-prefix-p "loom-core-" dependency-name)
                             (uiop:string-prefix-p "loom-feature-" dependency-name)))
                 append (let ((dependency-system
                               (asdf:find-system dependency-name nil)))
                          (when dependency-system
                            (boundary-lisp-components dependency-system visited-systems)))))))))

(defun boundary-relative-path (pathname)
  (namestring
   (enough-namestring pathname (asdf:system-source-directory "loom"))))

(defun boundary-first-form (text)
  (let ((*package* (find-package "CL-USER"))
        (*read-eval* nil)
        (*readtable* (boundary-safe-readtable)))
    (read-from-string text nil nil)))

(defun boundary-source-package-name (text)
  (let ((form (boundary-first-form text)))
    (when (and (consp form)
               (symbolp (first form))
               (string-equal (symbol-name (first form)) "IN-PACKAGE")
               (second form))
      (string (second form)))))

(defvar *boundary-source-records* nil)

;; The ASDF component set is fixed for one suite run, so both checks share this scan.
(eval-when (:load-toplevel :execute)
  (setf *boundary-source-records*
        (loop for pathname in (boundary-lisp-components (asdf:find-system "loom"))
              for path = (boundary-relative-path pathname)
              for text = (uiop:read-file-string pathname)
              for package-name = (boundary-source-package-name text)
              for layer = (boundary-path-layer path)
              collect (make-boundary-record
                       :path path :slice (boundary-path-slice path)
                       :layer layer
                       :package (or (and package-name (find-package package-name))
                                    (unless (eq layer :declaration)
                                      (find-package "ASDF-USER")))
                       :text text))))

(defun boundary-source-records ()
  *boundary-source-records*)

(defun boundary-name-part (text)
  (with-output-to-string (out)
    (let ((escaped nil) (bars nil))
      (loop for character across text
            do (cond (escaped (write-char character out) (setf escaped nil))
                     ((char= character #\\) (setf escaped t))
                     ((char= character #\|) (setf bars (not bars)))
                     (bars (write-char character out))
                     (t (write-char (char-upcase character) out)))))))

(defun boundary-package-separator (token)
  (let ((escaped nil) (bars nil))
    (loop for index from 0 below (1- (length token))
          for character = (char token index)
          do (cond (escaped (setf escaped nil))
                   ((char= character #\\) (setf escaped t))
                   ((char= character #\|) (setf bars (not bars)))
                   ((and (not bars) (char= character #\:)
                         (char= (char token (1+ index)) #\:))
                    (return-from boundary-package-separator (values index 2)))
                   ((and (not bars) (char= character #\:))
                    (return-from boundary-package-separator (values index 1)))))))

(defun boundary-token-delimiter-p (character)
  (or (find character '(#\Space #\Tab #\Newline #\Return #\Page
                        #\( #\) #\' #\` #\, #\" #\; #\#))))

(defun boundary-line-count (text start end)
  (loop for index from start below end
        count (char= (char text index) #\Newline)))

(defun boundary-scan-source (text record)
  (let ((position 0) (line 1) (lists nil) (tokens nil)
        (package (boundary-record-package record)))
    (labels ((advance-to (end)
               (incf line (boundary-line-count text position end))
               (setf position end))
             (skip-string ()
               (let ((closed nil))
                 (when lists (setf (car lists) nil))
                 (incf position)
                 (loop while (< position (length text))
                       for character = (char text position)
                       do (cond ((char= character #\\)
                                 (incf position)
                                 (when (< position (length text))
                                   (when (char= (char text position) #\Newline)
                                     (incf line))
                                   (incf position)))
                                ((char= character #\")
                                 (incf position) (setf closed t) (return))
                                (t (when (char= character #\Newline) (incf line))
                                   (incf position))))
                 (unless closed
                   (error "Unterminated string while scanning ~A"
                          (boundary-record-path record)))))
             (skip-block-comment ()
               (let ((depth 1))
                 (incf position 2)
                 (loop while (and (> depth 0) (< position (length text)))
                       do (cond ((and (char= (char text position) #\#)
                                      (< (1+ position) (length text))
                                      (char= (char text (1+ position)) #\|))
                                 (incf depth) (incf position 2))
                                ((and (char= (char text position) #\|)
                                      (< (1+ position) (length text))
                                      (char= (char text (1+ position)) #\#))
                                 (decf depth) (incf position 2))
                                (t (when (char= (char text position) #\Newline)
                                     (incf line))
                                   (incf position))))
                 (unless (zerop depth)
                   (error "Unterminated block comment while scanning ~A"
                          (boundary-record-path record)))))
             (skip-discard ()
               (let ((start (+ position 2)))
                 (multiple-value-bind (object end)
    (let ((*package* package)
          (*read-suppress* t)
          (*read-eval* nil)
          (*readtable* (boundary-safe-readtable)))
      (read-from-string text nil :boundary-eof :start start))
  (declare (ignore object))
  (when (<= end start)
    (error "Unreadable #; form while scanning ~A"
           (boundary-record-path record)))
  (advance-to end))))
             (skip-character ()
               (when lists (setf (car lists) nil))
               (incf position 2)
               (when (< position (length text))
                 (if (boundary-token-delimiter-p (char text position))
                     (incf position)
                     (loop while (and (< position (length text))
                                      (not (boundary-token-delimiter-p
                                            (char text position))))
                           do (incf position)))))
             (scan-token ()
               (let ((start position) (bars nil) (escaped nil))
                 (loop while (< position (length text))
                       for character = (char text position)
                       while (or escaped bars
                                 (not (boundary-token-delimiter-p character)))
                       do (cond (escaped (setf escaped nil))
                                ((char= character #\\) (setf escaped t))
                                ((char= character #\|) (setf bars (not bars))))
                          (incf position))
                 (when (= start position) (incf position))
                 (let* ((raw (subseq text start position))
                        (head (and lists (car lists)))
                        (separator nil) (width nil) (name raw) (target nil))
                   (when lists (setf (car lists) nil))
                   (multiple-value-setq (separator width)
                     (boundary-package-separator raw))
                   (when separator
                     (setf target (boundary-name-part (subseq raw 0 separator))
                           name (boundary-name-part (subseq raw (+ separator width)))))
                   (unless separator (setf name (boundary-name-part raw)))
                   (when (and name (> (length name) 0))
                     (push (make-boundary-token
                            :package target :symbol name
                            :internal-p (eql width 2)
                            :qualified-p (not (null separator))
                            :head-p head :line line)
                           tokens))))))
      (loop while (< position (length text))
            for character = (char text position)
            do (cond
                 ((find character '(#\Space #\Tab #\Newline #\Return #\Page))
                  (when (char= character #\Newline) (incf line))
                  (incf position))
                 ((char= character #\;)
                  (loop while (and (< position (length text))
                                   (not (char= (char text position) #\Newline)))
                        do (incf position)))
                 ((and (char= character #\#) (< (1+ position) (length text))
                       (char= (char text (1+ position)) #\|))
                  (skip-block-comment))
                 ((and (char= character #\#) (< (1+ position) (length text))
                       (char= (char text (1+ position)) #\;))
                  (skip-discard))
                 ((and (char= character #\#) (< (1+ position) (length text))
                       (char= (char text (1+ position)) #\\))
                  (skip-character))
                 ((char= character #\") (skip-string))
                 ((char= character #\()
                  (when lists (setf (car lists) nil))
                  (push t lists) (incf position))
                 ((char= character #\))
                  (when lists (pop lists)) (incf position))
                 ((find character '(#\' #\` #\,))
                  (when lists (setf (car lists) nil)) (incf position))
                 ((char= character #\#) (when lists (setf (car lists) nil))
                  (incf position))
                 (t (scan-token))))
      (nreverse tokens))))

(defun boundary-read-forms (text package)
  (let ((position 0) (forms nil))
    (let ((*package* package)
          (*read-eval* nil)
          (*readtable* (boundary-safe-readtable)))
      (loop while (< position (length text))
            do (multiple-value-bind (form next)
                   (read-from-string text nil :boundary-eof :start position)
                 (when (eq form :boundary-eof) (return))
                 (when (<= next position)
                   (error "Reader made no progress at offset ~D" position))
                 (push form forms)
                 (setf position next))))
    (nreverse forms)))

(defun boundary-function-owners (records)
  (labels ((definitions (form)
             (when (consp form)
               (let* ((operator (first form))
                      (operator-name (if (symbolp operator)
                                         (string-upcase (symbol-name operator))
                                         "")))
                 (cond ((string= operator-name "EVAL-WHEN")
                        (mapcan #'definitions (cddr form)))
                       ((string= operator-name "PROGN")
                        (mapcan #'definitions (cdr form)))
                       ((member operator-name
                                '("DEFUN" "DEFMETHOD" "DEFGENERIC" "DEFMACRO")
                                :test #'string=)
                        (list form)))))))
    (loop for record in records
          unless (or (eq (boundary-record-layer record) :declaration)
                     (null (boundary-record-package record)))
            append
            (loop for form in
                    (mapcan #'definitions
                            (boundary-read-forms (boundary-record-text record)
                                                 (boundary-record-package record)))
                  for name = (second form)
                  when (symbolp name)
                    collect (list (package-name (boundary-record-package record))
                                  (symbol-name name) (boundary-record-slice record)
                                  (boundary-record-layer record))))))

(defun boundary-edge-from-package (source-package target-package file line reference)
  (loop for source-slice in (boundary-package-slices source-package)
        append (loop for target-slice in
                         (boundary-package-slices (package-name target-package))
                     collect (make-boundary-edge
                              :source-package source-package
                              :target-package (package-name target-package)
                              :source-slice source-slice :target-slice target-slice
                              :file file :line line :reference reference))))

(defun boundary-introspected-edges (records)
  (labels ((option-line (source-name option)
             ;; Unqualified keywords such as :USE have an empty package name in scanner tokens.
             (let* ((path (boundary-package-definition-file source-name))
                    (record (find path records :key #'boundary-record-path
                                  :test #'string=))
                    (token
                      (and record
                           (find-if
                            (lambda (item)
                              (and (boundary-token-head-p item)
                                   (or (null (boundary-token-package item)) (string= "" (boundary-token-package item)))
                                   (string-equal (boundary-token-symbol item) option)))
                            (boundary-scan-source (boundary-record-text record) record)))))
               (if token (boundary-token-line token) 1))))
    (loop for row in *boundary-package-map*
          for source-name = (first row)
          for package = (find-package source-name)
          when package
            append
            (let ((uses (package-use-list package)) (edges nil))
              (dolist (used uses)
                (setf edges
                      (nconc edges
                             (boundary-edge-from-package
                              source-name used (boundary-package-definition-file source-name)
                              (option-line source-name "USE")
                              (format nil "package-use ~A -> ~A" source-name
                                      (package-name used))))))
              (do-symbols (symbol package)
                (multiple-value-bind (present status)
                    (find-symbol (symbol-name symbol) package)
                  (declare (ignore present))
                  (let ((home (symbol-package symbol)))
                    (when (and (eq status :internal) home
                               (not (member home uses :test #'eq))
                               (not (eq home package)))
                      (setf edges
                            (nconc edges
                                   (boundary-edge-from-package
                                    source-name home
                                    (boundary-package-definition-file source-name)
                                    (option-line source-name "IMPORT-FROM")
                                    (format nil "import ~A::~A" (package-name home)
                                            (symbol-name symbol)))))))))
              ;; DO-SYMBOLS returns NIL, so return the accumulated edges after iteration.
              edges))))

(defun boundary-edge-key (edge)
  (list (boundary-edge-source-package edge) (boundary-edge-target-package edge)
        (boundary-edge-source-slice edge) (boundary-edge-target-slice edge)
        (boundary-edge-file edge) (boundary-edge-line edge)
        (boundary-edge-reference edge)))
(defun boundary-token-edges (records)
  (labels ((package-designator-name (value)
             (cond ((stringp value) value)
                   ((keywordp value) (symbol-name value))
                   ((and (consp value) (eq (first value) 'quote)
                         (symbolp (second value)))
                    (symbol-name (second value)))))
           (lookup-references (form)
             (when (consp form)
               (let* ((operator (first form))
                      (operator-name
                        (if (and (symbolp operator)
                                 (eq (symbol-package operator)
                                     (find-package "COMMON-LISP")))
                            (symbol-name operator)
                            ""))
                      (lookup-p
                        (member operator-name
                                (list "FIND-PACKAGE" "FIND-SYMBOL" "INTERN")
                                :test (function string=)))
                      (designator
                        (cond ((string= operator-name "FIND-PACKAGE")
                               (second form))
                              ((member operator-name (list "FIND-SYMBOL" "INTERN")
                                       :test (function string=))
                               (third form))))
                      (target-name (and lookup-p
                                        (package-designator-name designator))))
                 (unless (member operator-name (list "QUOTE" "FUNCTION")
                                 :test (function string=))
                   (append (when lookup-p (list (list operator-name target-name)))
                           (lookup-references (car form))
                           (lookup-references (cdr form)))))))
           (dynamic-edges (record)
             (let* ((package (boundary-record-package record))
                    (references
                      (mapcan #'lookup-references
                              (boundary-read-forms (boundary-record-text record)
                                                   package)))
                    (call-tokens
                      (remove-if-not
                       (lambda (token)
                         (and (boundary-token-head-p token)
                              (member (boundary-token-symbol token)
                                      '("FIND-PACKAGE" "FIND-SYMBOL" "INTERN")
                                      :test #'string=)))
                       (boundary-scan-source (boundary-record-text record) record))))
               (loop for (operator target-name) in references
                     for token in call-tokens
                     for target-package = (and target-name (find-package target-name))
                     when (and target-package (not (eq package target-package)))
                       append
                       (loop for target-slice in
                                 (boundary-package-slices (package-name target-package))
                             collect (make-boundary-edge
                                      :source-package (package-name package)
                                      :target-package (package-name target-package)
                                      :source-slice (boundary-record-slice record)
                                      :target-slice target-slice
                                      :file (boundary-record-path record)
                                      :line (boundary-token-line token)
                                      :reference (format nil "~A ~A"
                                                         operator target-name)))))))
    (append
     (loop for record in records
           for source-package = (boundary-record-package record)
           when source-package
             append
             (loop for token in (boundary-scan-source
                                 (boundary-record-text record) record)
                   for target = (and (boundary-token-qualified-p token)
                                     (find-package (boundary-token-package token)))
                   when (and target (not (eq source-package target)))
                     append
                     (loop for target-slice in
                               (boundary-package-slices (package-name target))
                           collect (make-boundary-edge
                                    :source-package (package-name source-package)
                                    :target-package (package-name target)
                                    :source-slice (boundary-record-slice record)
                                    :target-slice target-slice
                                    :file (boundary-record-path record)
                                    :line (boundary-token-line token)
                                    :reference (format nil "~A:~A"
                                                       (boundary-token-package token)
                                                       (boundary-token-symbol token))))))
     (loop for record in records
           when (and (boundary-record-package record) (not (eq (boundary-record-layer record) :declaration)))
             append (dynamic-edges record)))))

(defun boundary-unique-edges (edges)
  (remove-duplicates edges :key #'boundary-edge-key :test #'equal))

(defun boundary-direction-violation-p (edge)
  (let ((source (boundary-edge-source-slice edge))
        (target (boundary-edge-target-slice edge)))
    (labels ((rank (slice)
               (cond ((string= slice "root") 0)
                     ((uiop:string-prefix-p "feature/" slice) 1)
                     ((string= slice "core") 2)
                     (t 3))))
      (> (rank source) (rank target)))))

(defun boundary-edge-findings (edges)
  (loop for edge in edges
        when (boundary-direction-violation-p edge)
          collect (make-boundary-finding
                   :category :package-direction
                   :slice (boundary-edge-source-slice edge)
                   :file (boundary-edge-file edge) :line (boundary-edge-line edge)
                   :reference (format nil "~A -> ~A (~A)"
                                      (boundary-edge-source-slice edge)
                                      (boundary-edge-target-slice edge)
                                      (boundary-edge-reference edge)))))

(defun boundary-inter-slice-edges (edges)
  (labels ((known-slice-p (slice)
             (not
              (null
               (some (lambda (row)
                       (member slice (second row) :test #'string=))
                     *boundary-package-map*)))))
    (remove-duplicates
     (loop for edge in edges
           for source = (boundary-edge-source-slice edge)
           for target = (boundary-edge-target-slice edge)
           when (and (known-slice-p source) (known-slice-p target)
                     (not (string= source target)))
             collect edge)
     :key (lambda (edge) (list (boundary-edge-source-slice edge)
                               (boundary-edge-target-slice edge)))
     :test #'equal)))

(defun boundary-layer-call-findings (records owners)
  (loop for record in records
        for source-package = (boundary-record-package record)
        when source-package
          append
          (loop for token in (boundary-scan-source (boundary-record-text record) record)
                for target-package =
                  (if (boundary-token-qualified-p token)
                      (find-package (boundary-token-package token))
                      (let ((symbol (find-symbol (boundary-token-symbol token)
                                                 source-package)))
                        (and symbol (symbol-package symbol))))
                when (and (boundary-token-head-p token) target-package)
                  append
                  (loop for owner in owners
                        when (and (string-equal (first owner)
                                                (package-name target-package))
                                  (string-equal (second owner)
                                                (boundary-token-symbol token))
                                  (boundary-layer-forbidden-p
                                   (boundary-record-layer record) (fourth owner)))
                          collect (make-boundary-finding
                                   :category :layer-direction
                                   :slice (boundary-record-slice record)
                                   :file (boundary-record-path record)
                                   :line (boundary-token-line token)
                                   :reference (format nil "~A call to ~A (~A)"
                                                      (boundary-record-layer record)
                                                      (boundary-token-symbol token)
                                                      (fourth owner)))))))

(defun boundary-layer-forbidden-p (source target)
  (not
   (null
    (or (and (eq source :domain)
             (member target '(:application :infrastructure :presentation)))
        (and (eq source :application)
             (member target '(:infrastructure :presentation)))
        (and (eq source :infrastructure)
             (member target '(:application :presentation)))
        (and (eq source :presentation)
             (member target '(:domain :infrastructure)))))))

(defparameter *boundary-cl-io-symbols*
  '("OPEN" "CLOSE" "READ" "READ-CHAR" "READ-LINE" "READ-BYTE" "WRITE"
    "WRITE-CHAR" "WRITE-LINE" "WRITE-STRING" "WITH-OPEN-FILE" "WITH-OPEN-STREAM"
    "FILE-POSITION" "FILE-LENGTH" "FILE-WRITE-DATE" "FILE-AUTHOR" "DELETE-FILE"
    "RENAME-FILE" "PROBE-FILE" "DIRECTORY" "TRUENAME" "ENSURE-DIRECTORIES-EXIST"
    "LISTEN" "PEEK-CHAR" "UNREAD-CHAR" "TERPRI" "FRESH-LINE" "FINISH-OUTPUT"
    "FORCE-OUTPUT" "CLEAR-OUTPUT" "*STANDARD-INPUT*" "*STANDARD-OUTPUT*"
    "*ERROR-OUTPUT*" "*TRACE-OUTPUT*" "*DEBUG-IO*" "*QUERY-IO*" "*TERMINAL-IO*"))

(defun boundary-io-package-p (name)
  (or (member (string-upcase name)
              '("UIOP" "HOST-KIT" "CL-HOST-KIT" "CL-PROCESS-KIT" "CL-TTY-KIT"
                "CL-VCS-KIT" "SB-EXT" "SB-POSIX")
              :test #'string=)
      (uiop:string-prefix-p "UIOP/" (string-upcase name))))

(defun boundary-domain-findings (records)
  (loop for record in records
        for package = (boundary-record-package record)
        when (and package (eq (boundary-record-layer record) :domain))
          append
          (loop for token in (boundary-scan-source (boundary-record-text record) record)
                for name = (boundary-token-symbol token)
                for target-package = (and (boundary-token-package token)
                                          (find-package (boundary-token-package token)))
                for symbol = (and (not (boundary-token-qualified-p token))
                                  (find-symbol name package))
                append
                (append
                 (when (string-equal name "*EDITOR-STATE*")
                   (list (make-boundary-finding
                          :category :domain-editor-state :slice (boundary-record-slice record)
                          :file (boundary-record-path record) :line (boundary-token-line token)
                          :reference name)))
                 (when (or (and target-package
                                (or (boundary-io-package-p (package-name target-package))
                                    (and (string-equal (package-name target-package)
                                                       "COMMON-LISP")
                                         (member name *boundary-cl-io-symbols*
                                                 :test #'string-equal))))
                           (and symbol
                                (member (symbol-name symbol) *boundary-cl-io-symbols*
                                        :test #'string-equal)
                                (eq (symbol-package symbol) (find-package "COMMON-LISP"))))
                   (list (make-boundary-finding
                          :category :domain-io :slice (boundary-record-slice record)
                          :file (boundary-record-path record) :line (boundary-token-line token)
                          :reference (or (boundary-token-package token) name))))))))

(defun boundary-domain-package-findings (records)
  (let* ((domain-slices
           (remove-duplicates
            (loop for record in records
                  for package = (boundary-record-package record)
                  when (and package (eq (boundary-record-layer record) :domain))
                    collect (list (package-name package)
                                  (boundary-record-slice record)))
            :test #'equal))
         (edges (boundary-introspected-edges records)))
    (loop for (package-name slice) in domain-slices
          append
          (loop for edge in edges
                when (and (string= (boundary-edge-source-package edge) package-name)
                          (boundary-io-package-p
                           (boundary-edge-target-package edge)))
                  collect (make-boundary-finding
                           :category :domain-io-package :slice slice
                           :file (boundary-edge-file edge)
                           :line (boundary-edge-line edge)
                           :reference
                           (format nil "package dependency ~A -> ~A"
                                   package-name
                                   (boundary-edge-target-package edge)))))))

(defun boundary-infrastructure-findings (records)
  (loop for record in records
        when (eq (boundary-record-layer record) :infrastructure)
        append
        (loop for token in (boundary-scan-source (boundary-record-text record) record)
              when (string-equal (boundary-token-symbol token) "*EDITOR-STATE*")
              collect (make-boundary-finding
                       :category :infrastructure-editor-state
                       :slice (boundary-record-slice record)
                       :file (boundary-record-path record)
                       :line (boundary-token-line token)
                       :reference "*editor-state*"))))
(defun boundary-internal-references (records)
  (loop for record in records
        append
        (loop for token in (boundary-scan-source (boundary-record-text record) record)
              when (boundary-token-internal-p token)
                collect (list (boundary-record-slice record) (boundary-record-path record)
                              (boundary-token-line token)
                              (format nil "~A::~A" (boundary-token-package token)
                                      (boundary-token-symbol token))))))
(defun boundary-internal-reference-findings (records)
  (loop for record in records
        append
        (loop for token in (boundary-scan-source (boundary-record-text record) record)
              when (boundary-token-internal-p token)
                append
                (let* ((package-name (boundary-token-package token))
                       (package-row (and package-name
                                         (boundary-package-row package-name)))
                       (target-package (and package-name
                                            (find-package package-name))))
                  (when (and package-row target-package)
                    (multiple-value-bind (symbol status)
                        (find-symbol (boundary-token-symbol token) target-package)
                      (declare (ignore symbol))
                      (when (and (eq status :internal)
                                 (not (member (boundary-record-slice record)
                                              (second package-row)
                                              :test #'string-equal)))
                        (list
                         (make-boundary-finding
                          :category :package-internal-reference
                          :slice (boundary-record-slice record)
                          :file (boundary-record-path record)
                          :line (boundary-token-line token)
                          :reference
                          (format nil "~A::~A" package-name
                                  (boundary-token-symbol token)))))))))))

(defun boundary-d1-cycle-findings (edges)
  ;; Cycle pairs: C1 root/feature; C2 LOOM/LOOM-APPLICATION;
  ;; C3 LOOM/APPLICATION/window; C4 core/window.
  (let ((pairs nil))
    (labels ((edge-between (from to predicate)
               (find-if (lambda (edge)
                          (and (string= (boundary-edge-source-slice edge) from)
                               (string= (boundary-edge-target-slice edge) to)
                               (funcall predicate edge))) edges))
             (record-cycle (name forward reverse)
               (when (and forward reverse)
                 (push (make-boundary-finding
                        :category :d1-cycle
                        :slice (boundary-edge-source-slice forward)
                        :file (boundary-edge-file forward) :line (boundary-edge-line forward)
                        :reference name)
                       pairs))))
      (dolist (edge edges)
        (when (uiop:string-prefix-p "feature/" (boundary-edge-target-slice edge))
          (record-cycle
           (format nil "C1 root <-> ~A" (boundary-edge-target-slice edge))
           (edge-between "root" (boundary-edge-target-slice edge)
                         (lambda (item) (declare (ignore item)) t))
           (edge-between (boundary-edge-target-slice edge) "root"
                         (lambda (item) (declare (ignore item)) t))))
        (when (and (string= (boundary-edge-source-package edge) "LOOM")
                   (string= (boundary-edge-target-package edge) "LOOM/APPLICATION"))
          (record-cycle "C2 loom <-> loom/application" edge
                        (find-if (lambda (other)
                                   (and (string= (boundary-edge-source-package other)
                                                 "LOOM/APPLICATION")
                                        (string= (boundary-edge-target-package other) "LOOM")))
                                 edges)))
        (when (and (string= (boundary-edge-source-package edge) "LOOM/APPLICATION")
                   (string= (boundary-edge-target-package edge)
                            "LOOM/FEATURE/WINDOW"))
          (record-cycle "C3 loom/application <-> window" edge
                        (find-if (lambda (other)
                                   (and (string= (boundary-edge-source-package other)
                                                 "LOOM/FEATURE/WINDOW")
                                        (string= (boundary-edge-target-package other)
                                                 "LOOM/APPLICATION")))
                                 edges)))
        (when (and (or (and (string= (boundary-edge-source-slice edge) "core")
                            (string= (boundary-edge-target-slice edge) "feature/window"))
                       (and (string= (boundary-edge-source-slice edge) "feature/window")
                            (string= (boundary-edge-target-slice edge) "core")))
                   (find-if (lambda (other)
                              (and (string= (boundary-edge-source-slice other)
                                            (boundary-edge-target-slice edge))
                                   (string= (boundary-edge-target-slice other)
                                            (boundary-edge-source-slice edge))))
                            edges))
          (record-cycle "C4 core <-> window" edge edge)))
    (remove-duplicates pairs :key (lambda (finding) (boundary-finding-reference finding))
                       :test #'string=))))

(defun boundary-unallowlisted (findings allowlist)
  (let ((remaining
          (loop for slice-entry in allowlist
                append (loop for entry in (cdr slice-entry)
                             collect (cons (first slice-entry) entry))))
        (new nil)
        (statuses nil))
    (dolist (finding findings)
      (let* ((entry-key
               (list (boundary-finding-slice finding)
                     (boundary-finding-category finding)
                     (boundary-finding-file finding)
                     (boundary-finding-reference finding)))
             (match
               (find-if (lambda (entry)
                          (equal entry-key
                                 (list (car entry)
                                       (first (cdr entry))
                                       (second (cdr entry))
                                       (third (cdr entry)))))
                        remaining)))
        (if match
            (progn
              (push (cons finding t) statuses)
              (setf remaining (delete match remaining :test #'eq :count 1)))
            (progn
              (push (cons finding nil) statuses)
              (push finding new)))))
    (values (nreverse new) (nreverse statuses) remaining)))

(defun boundary-sorted-findings (findings)
  (sort (copy-list findings)
        (lambda (left right)
          (let ((left-key (list (string (boundary-finding-category left))
                                (boundary-finding-slice left) (boundary-finding-file left)
                                (boundary-finding-line left) (boundary-finding-reference left)))
                (right-key (list (string (boundary-finding-category right))
                                 (boundary-finding-slice right) (boundary-finding-file right)
                                 (boundary-finding-line right) (boundary-finding-reference right))))
            (string< (prin1-to-string left-key) (prin1-to-string right-key))))))

(defun boundary-report (findings edges internal-refs
                         &optional (allowlist *boundary-allowlist*))
  (let* ((sorted-findings (boundary-sorted-findings findings))
         (counts (make-hash-table :test #'eq))
         (allowlist-counts (make-hash-table :test #'eq)))
    (multiple-value-bind (new statuses stale)
        (boundary-unallowlisted sorted-findings allowlist)
      (format t "~&Boundary architecture report (~A mode):~%" *boundary-report-vs-fail*)
      (dolist (status statuses)
        (let ((finding (car status)))
          (incf (gethash (boundary-finding-category finding) counts 0))
          (format t "  ~A ~A ~A ~A:~D ~A~%"
                  (if (cdr status) "KNOWN" "*** NEW ***")
                  (boundary-finding-slice finding) (boundary-finding-category finding)
                  (boundary-finding-file finding) (boundary-finding-line finding)
                  (boundary-finding-reference finding))))
      (format t "Violation totals by category:~%")
      (dolist (category (sort (loop for key being the hash-keys of counts collect key)
                              #'string< :key #'string))
        (format t "  ~A: ~D~%" category (gethash category counts)))
      (format t "  total: ~D~%" (length findings))
      (format t "  unallowlisted: ~D~%" (length new))
      (dolist (slice-entry allowlist)
        (dolist (entry (cdr slice-entry))
          (incf (gethash (first entry) allowlist-counts 0))))
      (format t "Allowlist entries by kind:~%")
      (dolist (kind (sort (loop for key being the hash-keys of allowlist-counts collect key)
                          #'string< :key #'string))
        (format t "  ~A: ~D~%" kind (gethash kind allowlist-counts)))
      (format t "  total: ~D~%"
              (loop for count being the hash-values of allowlist-counts sum count))
      (format t "Stale allowlist entries (removable): ~D~%" (length stale))
      (dolist (item stale)
        (let ((entry (cdr item)))
          (format t "  REMOVABLE ~A ~A ~A ~A [~A]~%"
                  (car item) (first entry) (second entry) (third entry)
                  (fourth entry))))
      (format t "Current inter-slice edges (informational; compare with per-slice ASDF DAGs later):~%")
      (dolist (edge (sort (copy-list (boundary-inter-slice-edges edges))
                          #'string< :key (lambda (item)
                                           (format nil "~A ~A" (boundary-edge-source-slice item)
                                                   (boundary-edge-target-slice item)))))
        (format t "  ~A -> ~A ~A:~D ~A~%"
                (boundary-edge-source-slice edge) (boundary-edge-target-slice edge)
                (boundary-edge-file edge) (boundary-edge-line edge)
                (boundary-edge-reference edge)))
      (format t "Internal symbol references using :: (~D):~%" (length internal-refs))
      (dolist (reference (sort (copy-list internal-refs)
                               #'string< :key #'prin1-to-string))
        (format t "  ~A:~D ~A~%" (second reference) (third reference) (fourth reference)))
      (format t "Limits: package-qualified references and :: locations are scanned lexically, including both reader-conditional branches. Direct FIND-PACKAGE, FIND-SYMBOL, and INTERN calls with literal package designators are resolved only in forms read in the active host branch. Layer checks match list-head tokens to top-level defun/defgeneric/defmethod/defmacro definitions, including definitions under eval-when/progn; macro expansion, local bindings, computed package names, function-designator references such as #'foo, and indirect calls are unresolved.~%")
      (when (and (eq *boundary-report-vs-fail* :fail) new)
        (error "Boundary architecture has ~D unallowlisted findings" (length new))))))

(progn
  (defun boundary-proper-list-length (object)
    (let ((seen (make-hash-table :test #'eq))
          (cursor object)
          (count 0))
      (loop while (consp cursor)
            do (when (gethash cursor seen)
                 (return-from boundary-proper-list-length nil))
               (setf (gethash cursor seen) t)
               (incf count)
               (setf cursor (cdr cursor)))
      (and (null cursor) count)))

  (defun boundary-allowlist-entry-p (entry)
    (and (= (or (boundary-proper-list-length entry) -1) 4)
         (member (first entry)
                 '(:d1-cycle :domain-editor-state :domain-io :domain-io-package
                   :infrastructure-editor-state :layer-direction :package-direction
                   :package-internal-reference)
                 :test #'eq)
         (every (lambda (field)
                  (and (stringp field) (plusp (length field))))
                (rest entry))
         (notany (lambda (character)
                   (member character '(#\Newline #\Return)))
                 (fourth entry))))

  (defun boundary-validate-allowlist-groups (groups expected-slices)
    (unless (and (boundary-proper-list-length groups)
                 (boundary-proper-list-length expected-slices))
      (error "Boundary allowlist groups and expected slices must be proper lists"))
    (let ((expected (make-hash-table :test #'equal))
          (seen (make-hash-table :test #'equal)))
      (dolist (slice expected-slices)
        (unless (and (stringp slice) (plusp (length slice)))
          (error "Malformed expected boundary slice: ~S" slice))
        (when (gethash slice expected)
          (error "Duplicate expected boundary slice: ~A" slice))
        (setf (gethash slice expected) t))
      (dolist (group groups)
        (unless (and (boundary-proper-list-length group)
                     (plusp (boundary-proper-list-length group))
                     (stringp (first group))
                     (plusp (length (first group))))
          (error "Malformed boundary allowlist group: ~S" group))
        (let ((slice (first group)))
          (unless (gethash slice expected)
            (error "Unexpected boundary allowlist slice: ~A" slice))
          (when (gethash slice seen)
            (error "Duplicate boundary allowlist slice: ~A" slice))
          (dolist (entry (rest group))
            (unless (boundary-allowlist-entry-p entry)
              (error "Malformed boundary allowlist entry in ~A: ~S" slice entry)))
          (setf (gethash slice seen) t)))
      (dolist (slice expected-slices)
        (unless (gethash slice seen)
          (error "Missing boundary allowlist slice: ~A" slice)))
      groups))

  (defun boundary-allowlist-relative-path (slice)
    (unless (stringp slice)
      (error "Malformed boundary allowlist slice name: ~S" slice))
    (cond ((member slice '("root" "core") :test #'string=)
           "t/boundary-allowlist.lisp")
          ((or (uiop:string-prefix-p "core/" slice)
               (uiop:string-prefix-p "feature/" slice))
           (format nil "packages/~A/t/boundary-allowlist.lisp" slice))
          (t (error "No boundary allowlist path for slice: ~A" slice))))

  (defun boundary-expected-allowlist-slices (records)
    (remove-duplicates
     (append (mapcan (lambda (row) (copy-list (second row)))
                     *boundary-package-map*)
             (mapcar #'boundary-record-slice records))
     :test #'string=))

  (defun boundary-read-allowlist-file (relative-path expected-slices)
    (let* ((pathname (asdf:system-relative-pathname "loom" relative-path))
           (forms (boundary-read-forms (uiop:read-file-string pathname)
                                       (find-package "CL-USER"))))
      (unless (= (or (boundary-proper-list-length forms) -1) 1)
        (error "Boundary allowlist file must contain exactly one form: ~A"
               relative-path))
      (boundary-validate-allowlist-groups (first forms) expected-slices)))

  (defun boundary-load-allowlists (records)
    (let* ((expected-slices (boundary-expected-allowlist-slices records))
           (relative-paths
             (remove-duplicates (mapcar #'boundary-allowlist-relative-path expected-slices)
                                :test #'equal))
           (groups nil))
      (dolist (relative-path relative-paths)
        (let* ((file-slices
                 (remove-if-not
                  (lambda (slice)
                    (equal relative-path (boundary-allowlist-relative-path slice)))
                  expected-slices))
               (file-groups
                 (boundary-read-allowlist-file relative-path file-slices)))
          (setf groups (nconc groups file-groups))))
      (boundary-validate-allowlist-groups groups expected-slices)))

  (defun boundary-current-report ()
    (let* ((records (boundary-source-records))
           (owners (boundary-function-owners records))
           (edges (boundary-unique-edges
                   (append (boundary-introspected-edges records)
                           (boundary-token-edges records))))
           (findings (append (boundary-edge-findings edges)
                             (boundary-layer-call-findings records owners)
                             (boundary-domain-findings records)
                             (boundary-domain-package-findings records)
                             (boundary-infrastructure-findings records)
                             (boundary-d1-cycle-findings edges)
                             (boundary-internal-reference-findings records)))
           (internal-refs (boundary-internal-references records))
           (allowlist (boundary-load-allowlists records)))
      (unless records (error "No Lisp components found in ASDF system loom"))
      (dolist (record records)
        (let* ((package (boundary-record-package record))
               (row (and package
                         (boundary-package-row (package-name package))))
               (layer (boundary-record-layer record)))
          ;; Package declarations are metadata, so they have no source layer.
          (unless (or (eq layer :declaration)
                      (and row (member layer (third row))))
            (error "Package layer map mismatch for ~A in ~A: ~A"
                   (or (and package (package-name package)) "<no package>")
                   (boundary-record-path record) layer))))
      (boundary-report
       (remove-duplicates
        findings
        :key (lambda (finding)
               (list (boundary-finding-slice finding)
                     (boundary-finding-category finding)
                     (boundary-finding-file finding)
                     (boundary-finding-line finding)
                     (boundary-finding-reference finding)))
        :test #'equal)
       edges internal-refs allowlist)))
)

(defun boundary-self-test ()
  (let* ((window-package (find-package "LOOM/FEATURE/WINDOW"))
         (qualified-record (make-boundary-record
                            :path "synthetic/core.lisp" :slice "core" :layer :core
                            :package (find-package "LOOM")
                            :text "(loom/feature/window:split-window-below)"))
         (qualified-token (find-if #'boundary-token-qualified-p
                                   (boundary-scan-source
                                    (boundary-record-text qualified-record)
                                    qualified-record)))
         (qualified-edge (first (boundary-token-edges (list qualified-record))))
         (edge-finding (first (boundary-edge-findings (list qualified-edge))))
         (layer-record (make-boundary-record
                        :path "synthetic/feature/buffers/domain-test.lisp"
                        :slice "feature/buffers" :layer :domain
                        :package (find-package "LOOM/FEATURE/BUFFERS")
                        :text "(loom/feature/buffers:switch-to-buffer)"))
         (layer-finding
           (first (boundary-layer-call-findings
                   (list layer-record)
                   (list '("LOOM/FEATURE/BUFFERS" "SWITCH-TO-BUFFER"
                           "feature/buffers" :application)))))
         (dynamic-record (make-boundary-record
                          :path "synthetic/feature/evaluation/infrastructure-test.lisp"
                          :slice "feature/evaluation" :layer :infrastructure
                          :package (find-package "LOOM/FEATURE/EVALUATION")
                          :text "(find-package \"LOOM-USER\")"))
         (dynamic-edge (first (boundary-token-edges (list dynamic-record))))
         (dynamic-finding (first (boundary-edge-findings (list dynamic-edge))))
         (allowed
           (list
            (list (boundary-finding-slice dynamic-finding)
                  (list (boundary-finding-category dynamic-finding)
                        (boundary-finding-file dynamic-finding)
                        (boundary-finding-reference dynamic-finding)
                        "fixture reason")
                  (list (boundary-finding-category dynamic-finding)
                        (boundary-finding-file dynamic-finding)
                        (boundary-finding-reference dynamic-finding)
                        "fixture reason"))))
         (scanner-record (make-boundary-record
                          :path "synthetic/scanner.lisp" :slice "root" :layer :application
                          :package (find-package "LOOM")
                          :text (format nil
                                        "\"LOOM/FEATURE/WINDOW:STRING\" ; LOOM/FEATURE/WINDOW:LINE~%#| LOOM/FEATURE/WINDOW:BLOCK #| nested |# |#~%#; (loom/feature/window:discarded)~%(loom/feature/window:kept)")))
         (scanner-qualified
           (remove-if-not #'boundary-token-qualified-p
                          (boundary-scan-source (boundary-record-text scanner-record)
                                                scanner-record))))
    (unless (and qualified-token qualified-edge edge-finding layer-finding
                 (= (length (boundary-inter-slice-edges (list qualified-edge))) 1)
                 dynamic-edge dynamic-finding (= (length scanner-qualified) 1)
                 (string-equal (boundary-token-package qualified-token)
                               "LOOM/FEATURE/WINDOW")
                 (null (boundary-unallowlisted (list dynamic-finding) allowed)))
      (error "Boundary scanner synthetic fixture failed"))
    (progn
      (expect (boundary-finding-category edge-finding) :to-equal :package-direction)
      (expect (boundary-validate-allowlist-groups
               '(("root" (:package-direction "fixture.lisp" "ref" "reason"))
                 ("core"))
               '("root" "core"))
              :to-equal
              '(("root" (:package-direction "fixture.lisp" "ref" "reason"))
                ("core")))
      (expect (boundary-allowlist-relative-path "core/buffer")
              :to-equal "packages/core/buffer/t/boundary-allowlist.lisp")
      (expect (handler-case
                  (progn
                    (boundary-validate-allowlist-groups
                     '(("root" (:package-direction "fixture.lisp" 4 "ref" "reason")))
                     '("root"))
                    nil)
                (error () t))
              :to-equal t)
      (expect (handler-case
                  (progn
                    (boundary-validate-allowlist-groups
                     '(("root") ("root")) '("root"))
                    nil)
                (error () t))
              :to-equal t)
      (expect (handler-case
                  (progn
                    (boundary-validate-allowlist-groups '("root") '("root" "core"))
                    nil)
                (error () t))
              :to-equal t))
    (expect (boundary-finding-category layer-finding) :to-equal :layer-direction)
    (expect (boundary-layer-forbidden-p :domain :infrastructure) :to-equal t)
    (expect (boundary-layer-forbidden-p :application :infrastructure) :to-equal t)
    (progn
      (expect (boundary-layer-forbidden-p :infrastructure :domain) :to-equal nil)
      (expect (boundary-layer-forbidden-p :presentation :domain) :to-equal t))
    (expect (boundary-finding-reference dynamic-finding)
            :to-equal "feature/evaluation -> root (FIND-PACKAGE LOOM-USER)")
    (expect (length (boundary-unallowlisted (list dynamic-finding) nil)) :to-equal 1)
    (progn
      (expect (boundary-unallowlisted (list dynamic-finding) allowed) :to-equal nil)
      (expect (length (boundary-unallowlisted
                       (list dynamic-finding dynamic-finding dynamic-finding)
                       allowed))
              :to-equal 1)
      (expect (length (nth-value 2
                                 (boundary-unallowlisted
                                  (list dynamic-finding) allowed)))
              :to-equal 1))
    (expect (handler-case
                (progn
                  (let ((*boundary-report-vs-fail* :fail)
                        (*boundary-allowlist* nil))
                    (boundary-report (list dynamic-finding) nil nil))
                  nil)
              (error () t))
            :to-equal t)
    (let* ((edges
            (list
             (make-boundary-edge
              :source-package "LOOM/APPLICATION" :target-package "LOOM/FEATURE/WINDOW"
              :source-slice "root" :target-slice "feature/window"
              :file "synthetic/application.lisp" :line 5 :reference "application -> window")
             (make-boundary-edge
              :source-package "LOOM/FEATURE/WINDOW" :target-package "LOOM/APPLICATION"
              :source-slice "feature/window" :target-slice "root"
              :file "synthetic/window.lisp" :line 3 :reference "window -> application")
             (make-boundary-edge
              :source-package "LOOM" :target-package "LOOM/FEATURE/WINDOW"
              :source-slice "core" :target-slice "feature/window"
              :file "synthetic/core.lisp" :line 8 :reference "core -> window")
             (make-boundary-edge
              :source-package "LOOM/FEATURE/WINDOW" :target-package "LOOM"
              :source-slice "feature/window" :target-slice "core"
              :file "synthetic/window.lisp" :line 9 :reference "window -> core")))
           (findings (boundary-d1-cycle-findings edges)))
      (expect (not (null (find "C3 loom/application <-> window" findings
                               :key #'boundary-finding-reference :test #'string=)))
              :to-equal t)
      (expect (not (null (find "C4 core <-> window" findings
                               :key #'boundary-finding-reference :test #'string=)))
              :to-equal t))
    (let ((target-package nil)
          (use-source nil)
          (import-source nil))
      (unwind-protect
          (let* ((suffix (symbol-name (gensym "BOUNDARY-EDGE-")))
                 (target-name (format nil "~A-TARGET" suffix))
                 (use-name (format nil "~A-USE" suffix))
                 (import-name (format nil "~A-IMPORT" suffix))
                 (records
                  (list
                   (make-boundary-record
                    :path "synthetic/target-package.lisp" :slice "core"
                    :layer :declaration
                    :text (format nil "(defpackage ~A)" target-name))
                   (make-boundary-record
                    :path "synthetic/use-package.lisp" :slice "feature/test"
                    :layer :declaration
                    :text (format nil "(defpackage ~A~%  (:use ~A))"
                                  use-name target-name))
                   (make-boundary-record
                    :path "synthetic/import-package.lisp" :slice "feature/test"
                    :layer :declaration
                    :text (format nil "(defpackage ~A~%  (:import-from ~A #:private-edge))"
                                  import-name target-name)))))
            (setf target-package (make-package target-name :use nil)
                  use-source (make-package use-name :use nil)
                  import-source (make-package import-name :use nil))
            (cl:use-package target-package use-source)
            (cl:import (list (cl:intern "PRIVATE-EDGE" target-package)) import-source)
            (let* ((*boundary-package-map*
                    (list
                     (list target-name '("core") '(:core)
                           "synthetic/target-package.lisp")
                     (list use-name '("feature/test") '(:application)
                           "synthetic/use-package.lisp")
                     (list import-name '("feature/test") '(:application)
                           "synthetic/import-package.lisp")))
                   (edges (boundary-introspected-edges records))
                   (use-edge
                    (find-if (lambda (edge)
                               (and (string= (boundary-edge-source-package edge) use-name)
                                    (string= (boundary-edge-target-package edge) target-name)))
                             edges))
                   (import-edge
                    (find-if (lambda (edge)
                               (and (string= (boundary-edge-source-package edge) import-name)
                                    (string= (boundary-edge-target-package edge) target-name)))
                             edges)))
              (expect (and use-edge
                           (= (boundary-edge-line use-edge) 2)
                           (string= (boundary-edge-reference use-edge)
                                    (format nil "package-use ~A -> ~A" use-name target-name)))
                      :to-equal t)
              (expect (and import-edge
                           (= (boundary-edge-line import-edge) 2)
                           (string= (boundary-edge-reference import-edge)
                                    (format nil "import ~A::PRIVATE-EDGE" target-name)))
                      :to-equal t)))
        (when import-source (delete-package import-source))
        (when use-source (delete-package use-source))
        (when target-package (delete-package target-package))))
    (progn
      (let ((target-package nil))
        (unwind-protect
            (let* ((target-name (symbol-name (gensym "BOUNDARY-IREF-")))
                   (package (make-package target-name :use nil)))
              (setf target-package package)
              (let* ((internal-symbol (intern "PRIVATE-REFERENCE" package))
                     (external-symbol (intern "PUBLIC-REFERENCE" package)))
                (declare (ignore internal-symbol))
                (export external-symbol package)
                (let* ((*boundary-package-map*
                         (list (list target-name (list "core")
                                     (list :core) "synthetic/target.lisp")))
                       (make-record
                         (lambda (path slice symbol-name)
                           (make-boundary-record
                            :path path :slice slice :layer :application :package *package*
                            :text (format nil "NIL~%  (~A::~A)" target-name symbol-name))))
                       (cross-record
                         (funcall make-record "synthetic/cross.lisp" "feature/other"
                                  "PRIVATE-REFERENCE"))
                       (same-slice-record
                         (funcall make-record "synthetic/same-slice.lisp" "core"
                                  "PRIVATE-REFERENCE"))
                       (external-record
                         (funcall make-record "synthetic/external.lisp" "feature/other"
                                  "PUBLIC-REFERENCE"))
                       (cross-findings
                         (boundary-internal-reference-findings (list cross-record))))
                  (expect (let ((finding (first cross-findings)))
                            (and (= (length cross-findings) 1)
                                 (eq (boundary-finding-category finding)
                                     :package-internal-reference)
                                 (string= (boundary-finding-slice finding) "feature/other")
                                 (string= (boundary-finding-file finding)
                                          "synthetic/cross.lisp")
                                 (= (boundary-finding-line finding) 2)
                                 (string= (boundary-finding-reference finding)
                                          (format nil "~A::PRIVATE-REFERENCE" target-name))))
                          :to-equal t)
                  (expect (boundary-internal-reference-findings (list same-slice-record))
                          :to-equal nil)
                  (expect (boundary-internal-reference-findings (list external-record))
                          :to-equal nil)
                  (let* ((entry
                           (list :package-internal-reference "synthetic/cross.lisp"
                                 (format nil "~A::PRIVATE-REFERENCE" target-name)
                                 "fixture reason"))
                         (groups (list (list "feature/other" entry))))
                    (expect (boundary-validate-allowlist-groups groups
                                                                (list "feature/other"))
                            :to-equal groups)))))
          (when target-package (delete-package target-package))))
      (expect *boundary-report-vs-fail* :to-equal :fail)
      t)))

(describe
  "boundary architecture audit"
  (it "detects forbidden package and same-package layer edges, then allowlists one"
    (expect (boundary-self-test) :to-equal t))
  (it "reports current package, layer, state, I/O, and D.1 findings"
    (boundary-current-report))
  (it "reads #. forms without evaluating them"
    (expect (boundary-read-forms
             "#.(error \"reader evaluation ran\")"
             (find-package "CL-USER"))
            :to-equal
            (list (list (find-symbol "ERROR" "COMMON-LISP")
                        "reader evaluation ran"))))
  (it "scans all migrated command specs in aggregate boundary sources"
    (let* ((records (boundary-source-records))
           (spec-records
             (remove-if-not
              (lambda (record)
                (search "/command-specs-" (boundary-record-path record)))
              records)))
      (expect (length spec-records) :to-equal 38)
      (expect (every
               (lambda (record)
                 (uiop:string-prefix-p "packages/"
                                       (boundary-record-path record)))
               spec-records)
              :to-equal t)
      (expect (notany
               (lambda (record)
                 (search "src/application/command-definitions"
                         (boundary-record-path record)))
               records)
              :to-equal t)))
  (it "keeps help package dependencies out of root"
    (let* ((records (boundary-source-records))
           (edges (boundary-unique-edges
                   (append (boundary-introspected-edges records)
                           (boundary-token-edges records))))
           (help-to-root
             (remove-if-not
              (lambda (finding)
                (and (string= (boundary-finding-slice finding) "feature/help")
                     (search "-> root" (boundary-finding-reference finding))))
              (boundary-edge-findings edges))))
      (expect help-to-root :to-equal nil))))
