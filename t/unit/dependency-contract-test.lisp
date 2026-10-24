(in-package #:loom/test)

(defun repo-file-string (relative-path)
  (host-kit:read-file-string
   (merge-pathnames relative-path
                    (asdf:system-source-directory "loom"))))

(defun find-defsystem-form (system-name)
  (let ((defsystem (find-symbol "DEFSYSTEM" "ASDF")))
    (with-input-from-string (stream (repo-file-string "loom.asd"))
      (loop for form = (read stream nil :eof)
            until (eq form :eof)
            when (and (consp form)
                      (eq (first form) defsystem)
                      (string= (second form) system-name))
              return form
            finally (error "Missing ASDF system ~A in loom.asd" system-name)))))

(defun system-dependencies (system-name)
  (copy-list (getf (cddr (find-defsystem-form system-name)) :depends-on)))

(defun flake-input-repositories ()
  (loop for line in (uiop:split-string (repo-file-string "flake.nix")
                                       :separator '(#\Newline))
        for marker = "url = \"github:nerima-lisp/"
        for marker-position = (search marker line)
        when marker-position
          collect (subseq line
                          (+ marker-position (length marker))
                          (search "/v" line :start2 marker-position))))

(defun block-between-markers (string start-marker end-marker &key from-end)
  (let ((start (search start-marker string :from-end from-end)))
    (unless start
      (error "Missing marker ~S" start-marker))
    (let* ((after-start (+ start (length start-marker)))
           (end (search end-marker string :start2 after-start)))
      (unless end
        (error "Missing marker ~S after ~S" end-marker start-marker))
      (subseq string after-start end))))

(defun line-last-identifier (line)
  (let ((current nil)
        (tokens nil))
    (labels ((finish-token ()
               (when current
                 (push (coerce (nreverse current) 'string) tokens)
                 (setf current nil))))
      (loop for character across line
            do (if (or (alpha-char-p character)
                       (digit-char-p character))
                   (push character current)
                   (finish-token)))
      (finish-token))
    (car tokens)))

(defun camel-case-identifier->kebab-case (identifier)
  (with-output-to-string (out)
    (loop for character across identifier
          for index from 0
          do (when (and (upper-case-p character)
                        (> index 0))
               (write-char #\- out))
             (write-char (char-downcase character) out))))

(defun flake-dependency-block-names (start-marker end-marker &key from-end)
  (loop with block = (block-between-markers (repo-file-string "flake.nix")
                                            start-marker
                                            end-marker
                                            :from-end from-end)
        for line in (uiop:split-string block :separator '(#\Newline))
        for token = (line-last-identifier line)
        when (and token
                  (uiop:string-prefix-p "cl" token))
          collect (camel-case-identifier->kebab-case token)))

(defun quoted-strings-in (string)
  (loop with start = 0
        for quote = (position #\" string :start start)
        while quote
        for end = (position #\" string :start (1+ quote))
        do (unless end
             (error "Unterminated quoted string in ~S." string))
        collect (subseq string (1+ quote) end)
        do (setf start (1+ end))))

(defun script-sibling-names (relative-path)
  (let* ((source (repo-file-string relative-path))
         (marker "(sibling-names '(")
         (start (search marker source))
         (end (and start
                   (search "))" source :start2 (+ start (length marker))))))
    (unless (and start end)
      (error "Missing sibling-names list in ~A." relative-path))
    (quoted-strings-in (subseq source start end))))

(defun all-asdf-dependencies (&optional (selection :all) package-directory)
  (let ((defsystem (find-symbol "DEFSYSTEM" "ASDF"))
        (root-directory (asdf:system-source-directory "loom")))
    (labels ((read-defsystem-forms (pathname)
               (with-open-file (stream pathname)
                 (loop for form = (read stream nil :eof)
                       until (eq form :eof)
                       when (and (consp form)
                                 (eq (first form) defsystem))
                         collect form)))
             (asdf-files-under (directory)
               (append (remove-if-not
                        (lambda (pathname)
                          (string-equal (pathname-type pathname) "asd"))
                        (uiop:directory-files directory))
                       (loop for subdirectory in (uiop:subdirectories directory)
                             append (asdf-files-under subdirectory))))
             (slice-asd-file-p (pathname)
               (let ((name (pathname-name pathname)))
                 (and (>= (length name) 5)
                      (string= "loom-" name :end2 5))))
             (test-system-p (form)
               (let* ((name (second form))
                      (suffix "/test")
                      (suffix-start (- (length name) (length suffix))))
                 (and (>= suffix-start 0)
                      (string= suffix name :start2 suffix-start))))
             (external-dependencies (forms local-system-names)
               (remove-duplicates
                (loop for form in forms
                      append (remove-if
                              (lambda (dependency)
                                (member dependency local-system-names
                                        :test #'string=))
                              (getf (cddr form) :depends-on)))
                :test #'string=)))
      (let* ((package-directory
               (or package-directory
                   (merge-pathnames "packages/" root-directory)))
             (package-asd-files
               (sort (asdf-files-under package-directory)
                     #'string< :key #'namestring))
             (package-forms
               (progn
                 (dolist (pathname package-asd-files)
                   (unless (slice-asd-file-p pathname)
                     (error "Invalid slice ASDF file ~A; expected a loom-*.asd filename."
                            (file-namestring pathname))))
                 (loop for pathname in package-asd-files
                       append (read-defsystem-forms pathname))))
             (all-forms
               (append (read-defsystem-forms
                        (merge-pathnames "loom.asd" root-directory))
                       package-forms)))
        (unless package-forms
          (error "No slice ASDF systems found under packages/."))
        (let* ((local-system-names (mapcar #'second all-forms))
               (production-forms (remove-if #'test-system-p all-forms))
               (test-forms (remove-if-not #'test-system-p all-forms))
               (production-dependencies
                 (external-dependencies production-forms local-system-names))
               (test-dependencies
                 (external-dependencies test-forms local-system-names)))
          (ecase selection
            (:all (remove-duplicates
                   (append production-dependencies test-dependencies)
                   :test #'string=))
            (:production production-dependencies)
            (:test test-dependencies)))))))

(describe
  "dependency declaration contracts"
  (it
    "keeps the production dependency union equal to flake.nix lispDependencies"
    (let* ((production-dependencies (all-asdf-dependencies :production))
           (flake-dependencies
             (flake-dependency-block-names "lispDependencies ="
                                           "lispCheckDependencies ="
                                           :from-end t)))
      (expect production-dependencies :to-be-truthy)
      (expect flake-dependencies :to-be-truthy)
      (expect (sort production-dependencies #'string<)
              :to-equal
              (sort flake-dependencies #'string<))))

  (it
    "pins every root and slice test dependency in flake inputs"
    (let* ((input-repositories (flake-input-repositories))
           (root-test-dependencies (remove "loom"
                                          (system-dependencies "loom/test")
                                          :test #'string=))
           (test-dependencies
             (remove-duplicates
              (append root-test-dependencies
                      (all-asdf-dependencies :test))
              :test #'string=)))
      (dolist (dependency test-dependencies)
        (expect input-repositories :to-contain dependency))))

  (it
    "matches flake test-only dependencies to the slice test dependency difference"
    (let* ((production-dependencies (all-asdf-dependencies :production))
           (test-dependencies (all-asdf-dependencies :test))
           (flake-check-dependencies
             (flake-dependency-block-names "lispCheckDependencies ="
                                           "timeoutSeconds =")))
      (expect flake-check-dependencies :to-be-truthy)
      (expect (sort flake-check-dependencies #'string<)
              :to-equal
              (sort (set-difference test-dependencies production-dependencies
                                    :test #'string=)
                    #'string<))
      (expect flake-check-dependencies :to-contain "cl-weave")))

  (it
    "keeps run-tests and coverage on the same local dependency set"
    (expect (sort (script-sibling-names "run-tests.lisp") #'string<)
            :to-equal
            (sort (script-sibling-names "scripts/coverage.lisp") #'string<)))

  (it
    "discovers all slice ASDF files and rejects noncanonical names"
    (let ((runner-dependencies (script-sibling-names "run-tests.lisp")))
      (expect (sort (all-asdf-dependencies) #'string<)
              :to-equal
              (sort (remove "loom" runner-dependencies :test #'string=)
                    #'string<)))
    (host-kit:with-temporary-directory (directory)
      (host-kit:write-file-string ""
                                 (merge-pathnames "invalid.asd" directory))
      (signals error (all-asdf-dependencies :all directory))))

  (it
    "keeps runner dependencies declared by an ASDF system"
    (let ((declared-dependencies (all-asdf-dependencies)))
      (dolist (dependency (script-sibling-names "run-tests.lisp"))
        (expect declared-dependencies :to-contain dependency)))))
