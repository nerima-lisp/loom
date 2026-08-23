;;;; t/unit/major-mode-test.lisp
;;;;
;;;; Pure major-mode metadata, path inference, and mode-aware tokenization.
(in-package #:loom/test)

(defun %mode-token-kinds (line mode)
  (mapcar #'syntax-token-kind
          (syntax-highlight-line-for-mode line mode)))

(defun %mode-token-texts (line mode)
  (mapcar #'syntax-token-text
          (syntax-highlight-line-for-mode line mode)))

(defun %loom-test-extension-command ()
  :extension-command)

(describe
  "major-mode catalog"
  (it
    "resolves display names and common aliases"
    (expect (major-mode-from-name "Python") :to-be :python)
    (expect (major-mode-from-name "lisp") :to-be :common-lisp)
    (expect (major-mode-from-name "bash") :to-be :shell)
    (expect (major-mode-from-name nil) :to-be nil)
    (expect (major-mode-known-p :rust) :to-be-truthy)
    (expect (major-mode-known-p "unknown") :to-be-falsy)
    (expect (major-mode-from-name 'python) :to-be :python)
    (expect (major-mode-from-name "Common Lisp") :to-be :common-lisp)
    (expect (major-mode-from-name "plain text") :to-be :text)
    (expect (major-mode-from-name 42) :to-be nil))

  (it
    "returns safe defaults for unknown mode metadata"
    (expect (major-mode-name :unknown) :to-be nil)
    (expect (major-mode-comment-prefix :unknown) :to-be nil)
    (expect (major-mode-indentation-width :unknown) :to-equal 2)
    (expect (major-mode-language-id :unknown) :to-be nil)
    (expect (major-mode-keywords :unknown) :to-equal nil))

  (it
    "exposes the metadata used by editing and language features"
    (expect (major-mode-name :common-lisp) :to-equal "Common Lisp")
    (expect (major-mode-comment-prefix :python) :to-equal "#")
    (expect (major-mode-indentation-width :python) :to-equal 4)
    (expect (major-mode-language-id :rust) :to-equal "rust")
    (expect (major-mode-keywords :python) :to-contain "def")
    (expect (major-mode-names) :to-contain "Markdown"))

  (it
    "resolves the daily-driver target languages by short alias"
    (expect (major-mode-from-name "elisp") :to-be :emacs-lisp)
    (expect (major-mode-from-name "el") :to-be :emacs-lisp)
    (expect (major-mode-from-name "Emacs Lisp") :to-be :emacs-lisp)
    (expect (major-mode-from-name "ts") :to-be :typescript)
    (expect (major-mode-from-name "tsx") :to-be :typescript-react)
    (expect (major-mode-from-name "nix") :to-be :nix)
    (expect (major-mode-from-name "org") :to-be :org))

  (it-each
      ((:emacs-lisp "Emacs Lisp" ";" "emacs-lisp" "defcustom")
       (:nix "Nix" "#" "nix" "inherit")
       (:typescript "TypeScript" "//" "typescript" "interface")
       (:typescript-react "TypeScript React" "//" "typescriptreact"
        "interface")
       (:org "Org" "#" "org" "TODO"))
      "exposes ~A metadata"
      (mode name comment-prefix language-id keyword)
    (expect (major-mode-name mode) :to-equal name)
    (expect (major-mode-comment-prefix mode) :to-equal comment-prefix)
    (expect (major-mode-language-id mode) :to-equal language-id)
    (expect (major-mode-indentation-width mode) :to-equal 2)
    (expect (major-mode-keywords mode) :to-contain keyword)))

(describe
  "major-mode-for-path"
  (it-each
      (("source.lisp" :common-lisp)
       ("src/main.rs" :rust)
       ("scripts/run.sh" :shell)
       ("docs/guide.md" :markdown)
       ("docs/guide.markdown" :markdown)
       ("config.json" :json)
       ("flake.nix" :nix)
       ("src/app.ts" :typescript)
       ("src/app.mts" :typescript)
       ("src/app.cts" :typescript)
       ("src/App.tsx" :typescript-react)
       ("init.el" :emacs-lisp)
       ("notes.org" :org)
       ("NOTES.ORG" :org)
       ("notes.txt" :text)
       ("Dockerfile" :shell)
       ("Makefile" :shell)
       ("LICENSE" :text)
       ("COPYING" :text)
       ("src\\lib/main.rs" :rust)
       ("README" :text)
       ("notes.unknown" :fundamental)
       ("file." :fundamental)
       (42 :fundamental))
      "infers ~A as ~A" (path mode)
    (expect (major-mode-for-path path) :to-be mode)))

(describe
  "major-mode-for-path pathname input"
  (it
    "accepts pathname objects without touching the file system"
    (expect (major-mode-for-path (pathname "src/main.rs")) :to-be :rust)))
