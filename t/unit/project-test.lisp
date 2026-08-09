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
    "returns a stable path relative to the project root"
    (expect (project-relative-path
             #P"/workspace/project/"
             #P"/workspace/project/src/main.lisp")
            :to-equal "src/main.lisp")))

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
