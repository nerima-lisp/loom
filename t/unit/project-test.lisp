;;;; t/unit/project-test.lisp
;;;;
;;;; Pure project boundary, path, and search-result rules.
(in-package #:loom/test)

(describe
  "project markers"
  (it
    "recognizes configured markers case-insensitively"
    (expect (project-marker-name-p ".GIT") :to-be-truthy)
    (expect (project-marker-name-p "flake.nix") :to-be-truthy)
    (expect (project-marker-name-p "unknown.marker") :to-be-falsy)
    (expect (project-marker-names) :to-contain ".git")
    (expect (project-ignored-directory-names) :to-contain "target")))

(describe
  "project path boundaries"
  (it
    "walks upward until a marker predicate accepts a directory"
    (let ((visited '()))
      (let ((root
              (project-root-for-path
               #P"/workspace/project/src/main.lisp"
               (lambda (directory)
                 (push (namestring directory) visited)
                 (string= (namestring directory) "/workspace/project/")))))
        (expect (namestring root) :to-equal "/workspace/project/")
        (let ((walk (nreverse visited)))
          (expect (first walk) :to-equal "/workspace/project/src/")
          (expect (second walk) :to-equal "/workspace/project/")))))

  (it
    "converts file paths and stops at the filesystem root"
    (expect (namestring (project-directory-path #P"/tmp/project/file.lisp"))
            :to-equal
            "/tmp/project/")
    (expect (project-parent-directory #P"/") :to-be nil)
    (expect (namestring (project-parent-directory #P"/tmp/project/"))
            :to-equal
            "/tmp/"))

  (it
    "returns no root when no marker is found"
    (expect (project-root-for-path
             #P"/workspace/project/src/main.lisp"
             (lambda (directory)
               (declare (ignore directory))
               nil))
            :to-be nil))

  (it
    "returns a stable path relative to the project root"
    (expect (project-relative-path
             #P"/workspace/project/"
             #P"/workspace/project/src/main.lisp")
            :to-equal "src/main.lisp"))

  (it
    "removes the explicit current-directory prefix"
    (expect (project-relative-path #P"./" #P"./src/main.lisp")
            :to-equal
            "src/main.lisp")))

(describe
  "project-search-lines"
  (it
    "returns one-based matching line plists"
    (expect (project-search-lines
             "needle"
             (format nil "first~%needle here~%last"))
            :to-equal
            '((:line 2 :text "needle here"))))

  (it
    "returns no matches for an empty query"
    (expect (project-search-lines "" "needle") :to-be nil)))

(describe
  "project completion"
  (it
    "matches candidates case-insensitively and preserves all candidates for empty input"
    (let ((candidates '("src/Main.lisp" "README.md" "docs/API.md")))
      (expect (loom/feature/project::%project-completion-candidates
               "main" candidates)
              :to-equal
              '("src/Main.lisp"))
      (expect (loom/feature/project::%project-completion-candidates
               "" candidates)
              :to-equal
              candidates)
      (expect (loom/feature/project::%project-completion-candidates
               "missing" candidates)
              :to-be
              nil)))

  (it
    "uses the current directory when the selected buffer has no file path"
    (let ((*editor-state* (%fresh-editor-state "plain")))
      (expect (namestring (loom/feature/project::%project-start-path))
              :to-equal
              (namestring (truename "."))))))
