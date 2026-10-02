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
           (collect (subseq string (1+ quote) end))
           (setf start (1+ end))))

(defun script-sibling-names (relative-path)
  (let* ((source (repo-file-string relative-path))
         (marker "(sibling-names '(")
         (start (search marker source))
         (end (and start
                   (search "))" source :start2 (+ start (length marker))))))
    (unless (and start end)
      (error "Missing sibling-names list in ~A." relative-path))
    (quoted-strings-in (subseq source start end))))

(defun all-asdf-dependencies ()
  (remove-duplicates
   (append (system-dependencies "loom")
           (remove "loom" (system-dependencies "loom/test")
                   :test #'string=))
   :test #'string=))

(describe
  "dependency declaration contracts"
  (it
    "keeps loom.asd runtime dependencies equal to flake.nix lispDependencies"
    (expect (sort (system-dependencies "loom") #'string<)
            :to-equal
            (sort (flake-dependency-block-names "lispDependencies ="
                                                "lispCheckDependencies ="
                                                :from-end t)
                  #'string<)))

  (it
    "pins every loom/test dependency in flake.nix"
    (let* ((input-repositories (flake-input-repositories))
           (test-dependencies (remove "loom"
                                      (system-dependencies "loom/test")
                                      :test #'string=)))
      (dolist (dependency test-dependencies)
        (expect input-repositories :to-contain dependency))))

  (it
    "keeps cl-weave explicit in flake.nix test-only dependencies"
    (expect (flake-dependency-block-names "lispCheckDependencies ="
                                          "timeoutSeconds =")
            :to-contain "cl-weave"))

  (it
    "keeps run-tests and coverage on the same local dependency set"
    (expect (sort (script-sibling-names "run-tests.lisp") #'string<)
            :to-equal
            (sort (script-sibling-names "scripts/coverage.lisp") #'string<)))

  (it
    "keeps every ASDF dependency available to both standalone runners"
    (let ((runner-dependencies
            (script-sibling-names "run-tests.lisp")))
      (expect (sort (all-asdf-dependencies) #'string<)
              :to-equal
              (sort (remove "loom" runner-dependencies :test #'string=)
                    #'string<))))

  (it
    "keeps runner dependencies declared by an ASDF system"
    (let ((declared-dependencies (all-asdf-dependencies)))
      (dolist (dependency (script-sibling-names "run-tests.lisp"))
        (expect declared-dependencies :to-contain dependency)))))
