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
    (expect (major-mode-names) :to-contain "Markdown")))

(describe
  "major-mode-for-path"
  (it-each
      (("source.lisp" :common-lisp)
       ("src/main.rs" :rust)
       ("scripts/run.sh" :shell)
       ("docs/guide.md" :markdown)
       ("docs/guide.markdown" :markdown)
       ("config.json" :json)
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

(describe
  "syntax-highlight-line-for-mode"
  (it
    "uses mode metadata to classify non-Lisp source"
    (let ((line "def answer(): # note"))
      (expect (%mode-token-kinds line :python)
              :to-equal
              '(:keyword :whitespace :plain :delimiter :delimiter :delimiter
                :whitespace :comment))
      (expect (%mode-token-texts line :python)
              :to-equal
              '("def" " " "answer" "(" ")" ":" " " "# note"))
      (expect (apply #'concatenate 'string (%mode-token-texts line :python))
              :to-equal line)))

  (it
    "classifies generic numbers, keywords, and strings"
    (let ((line ":value 42 \"text\""))
      (expect (%mode-token-kinds line :python)
              :to-equal
              '(:delimiter :plain :whitespace :number :whitespace :string))
      (expect (apply #'concatenate 'string (%mode-token-texts line :python))
              :to-equal line)))

  (it
    "keeps Common Lisp on its reader-aware tokenizer"
    (expect (%mode-token-kinds "(defun run ()) ; note" :common-lisp)
            :to-contain :keyword)
    (expect (%mode-token-kinds "(defun run ()) ; note" "lisp")
            :to-contain :comment)))
